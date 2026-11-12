# frozen_string_literal: true

require 'set'

module Flagsmith
  # Started event processors, stopped together at exit. A stopped processor leaves, so it is not kept in memory.
  module RunningEventProcessors
    @processors = Set.new
    @mutex = Mutex.new
    at_exit { to_a.each(&:stop) }

    def self.add(processor)
      @mutex.synchronize { @processors.add(processor) }
    end

    def self.delete(processor)
      @mutex.synchronize { @processors.delete(processor) }
    end

    def self.to_a
      @mutex.synchronize { @processors.to_a }
    end
  end

  # Buffers tracking and exposure events, and sends them to the Flagsmith events API in batches.
  #
  # Events are sent every +flush_interval_seconds+, as soon as +max_buffer_items+ are buffered,
  # or on #flush. Sending events never raises into the application: failures are logged.
  #
  # A batch is sent up to +MAX_ATTEMPTS+ times, one batch at a time, backing off with full jitter between
  # attempts. A batch whose last attempt fails transiently is kept for the next flush, unless that attempt got
  # a 500. A batch the events API rejects is dropped, and an events API refusing the environment key stops
  # event tracking. When the buffer is full, the oldest event is dropped. While a failed batch is kept, a full
  # buffer waits for the next flush rather than starting another round of attempts.
  #
  # Once stopped, tracking and flushing do nothing.
  class EventProcessor # rubocop:disable Metrics/ClassLength
    FLAG_EXPOSURE_EVENT = '$flag_exposure'
    ENDPOINT = 'v1/events'
    FLUSH_INTERVAL_SECONDS = 10
    MAX_BUFFER_ITEMS = 1000
    REQUEST_TIMEOUT_SECONDS = 3
    MAX_ATTEMPTS = 3
    RETRY_BASE_SECONDS = 1
    CLOSE_TIMEOUT_SECONDS = 5
    # Retried along with every server error
    RETRIED_STATUSES = [408, 429].freeze
    REFUSED_STATUSES = [401, 403].freeze

    def initialize(config, flush_interval_seconds: FLUSH_INTERVAL_SECONDS, max_buffer_items: MAX_BUFFER_ITEMS,
                   retry_base_seconds: RETRY_BASE_SECONDS)
      @logger = config.logger
      @flush_interval_seconds = flush_interval_seconds
      @max_buffer_items = max_buffer_items
      @retry_base_seconds = retry_base_seconds
      @connection = build_connection(config)
      initialize_buffer
      initialize_state
    end

    def track_event(event, identifier: nil, value: nil, traits: nil, metadata: nil)
      buffer(payload(event, nil, identifier: identifier, value: value, traits: traits, metadata: metadata))
    end

    # Equal exposures within one flush interval add no information, so only the first is sent.
    def track_exposure_event(feature_name, identifier:, value: nil, traits: nil, metadata: nil)
      buffer(payload(FLAG_EXPOSURE_EVENT, feature_name,
                     identifier: identifier, value: value, traits: traits, metadata: metadata))
    end

    # Sends the events tracked so far, and returns once each of them has been delivered, dropped, or kept for
    # the next flush, retries included. Events another flush sent while this one waited are not sent again.
    def flush
      request = @mutex.synchronize { flush_request unless stopping?('flushing events') }
      send_batch(request) if request
    end

    def start
      return if @interval || @stopping

      @interval = Thread.new { send_batch until wait(@flush_interval_seconds) { @stopping } }
      RunningEventProcessors.add(self)
    end

    # Stops flushing every interval, and sends the buffered events, waiting for at most +timeout_seconds+.
    # Events not sent by then are not retried.
    def stop(timeout_seconds = CLOSE_TIMEOUT_SECONDS)
      RunningEventProcessors.delete(self)
      change_state { @stopping = true }
      @interval = nil
      final_flush = Thread.new { send_batch }
      @logger.warn "Gave up sending events after #{timeout_seconds} seconds while closing" unless final_flush.join(timeout_seconds)
      change_state { @closed = true }
    end

    private

    def initialize_buffer
      @events = []
      @buffered_exposures = Set.new
      # Events tracked so far, how many of them were in a batch once sent, and the batches taken to send
      @tracked_count = 0
      @attempted_count = 0
      @batch_count = 0
      @flush_pending = false
      # Whether the buffer holds a batch whose attempts all failed
      @holding_failed_batch = false
    end

    def initialize_state
      @mutex = Mutex.new
      # Held while a batch is in flight, so that one batch is sent at a time
      @flush_mutex = Mutex.new
      @state_changed = ConditionVariable.new
      @refused = false
      @stopping = false
      @closed = false
    end

    # Only the flush scheduled by a full buffer clears +@flush_pending+, once it holds the buffer, so at most one
    # such flush is waiting at a time.
    def scheduled_flush(request)
      send_batch(request) { @flush_pending = false }
    end

    # What a flush requested now asks for: the events tracked so far, as long as no batch taken since sent them
    def flush_request
      [@tracked_count, @batch_count]
    end

    # Sends the buffered events as one batch. Given a +flush_request+, does nothing if a batch taken since the
    # request sent every event tracked up to it.
    def send_batch(...)
      @flush_mutex.synchronize do
        batch, attempted_count = take_batch(...)
        settle(batch, deliver(batch), attempted_count) if batch
      end
    rescue StandardError => e
      @logger.error "Unable to send events to the Flagsmith events API: #{e}"
    end

    def take_batch(request = nil)
      @mutex.synchronize do
        yield if block_given?
        next if @events.empty? || sent_since?(request)

        @holding_failed_batch = false
        @batch_count += 1
        [clear_buffer, @tracked_count]
      end
    end

    def sent_since?(request)
      return false unless request

      tracked_count, batch_count = request
      @batch_count > batch_count && @attempted_count >= tracked_count
    end

    # Returns the events the buffer held
    def clear_buffer
      events = @events
      @events = []
      @buffered_exposures.clear
      events
    end

    def settle(batch, outcome, attempted_count)
      @mutex.synchronize do
        @attempted_count = attempted_count
        hold_failed_batch(batch) if outcome == :kept
        next unless outcome == :refused

        @refused = true
        clear_buffer
      end
    end

    def hold_failed_batch(batch)
      @events = (batch + @events).last(@max_buffer_items)
      @holding_failed_batch = true
    end

    # Returns :delivered, :dropped, :kept or :refused
    def deliver(batch)
      body = { events: batch }.to_json
      status = nil
      (1..MAX_ATTEMPTS).each do |attempt|
        return keep(batch, 'the client is closed') if attempt > 1 && wait(backoff(attempt)) { @closed }

        status = post(body, batch, attempt)
        outcome = outcome_of(status, batch)
        return outcome if outcome

        log_failed_attempt(batch, attempt, "status #{status}") if status
      end
      status == 500 ? drop(batch, 'its last attempt got 500') : keep(batch, 'its last attempt failed')
    end

    # Full jitter: any wait up to the backoff, which doubles from +@retry_base_seconds+
    def backoff(attempt)
      rand * @retry_base_seconds * (2**(attempt - 2))
    end

    # Returns the response status, or nil when the request got none
    def post(body, batch, attempt)
      @connection.post(ENDPOINT, body).status
    rescue Faraday::Error => e
      log_failed_attempt(batch, attempt, e)
      nil
    end

    def log_failed_attempt(batch, attempt, failure)
      @logger.warn "Unable to send #{batch.length} events to the Flagsmith events API, " \
                   "attempt #{attempt} of #{MAX_ATTEMPTS}: #{failure}"
    end

    # Returns the outcome of a batch given its response status, or nil to try again
    def outcome_of(status, batch)
      return nil if status.nil? || status >= 500 || RETRIED_STATUSES.include?(status)
      return :delivered if (200..299).cover?(status)

      if REFUSED_STATUSES.include?(status)
        @logger.error "The Flagsmith events API refused the environment key with #{status}, stopping event tracking"
        return :refused
      end

      drop(batch, "the events API rejected it with #{status}")
    end

    def drop(batch, reason)
      @logger.warn "Dropping #{batch.length} events: #{reason}"
      :dropped
    end

    def keep(batch, reason)
      @logger.warn "Keeping #{batch.length} events for the next flush: #{reason}"
      :kept
    end

    def change_state
      @mutex.synchronize do
        yield
        @state_changed.broadcast
      end
    end

    # Waits for at most +seconds+, until the block is true. Returns the block's value.
    def wait(seconds)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
      @mutex.synchronize do
        until yield
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          break if remaining <= 0

          @state_changed.wait(@mutex, remaining)
        end
        yield
      end
    end

    def build_connection(config)
      Faraday.new(url: config.events_api_url, headers: headers(config)) do |f|
        f.options.timeout = REQUEST_TIMEOUT_SECONDS
      end
    end

    def headers(config)
      config.custom_headers.merge(
        'Content-Type' => 'application/json; charset=utf-8',
        'X-Environment-Key' => config.environment_key,
        'User-Agent' => Flagsmith::SDK::Utils.user_agent,
        'Flagsmith-SDK-User-Agent' => Flagsmith::SDK::Utils.user_agent
      )
    end

    def payload(event, feature_name, details)
      {
        event: event,
        feature_name: feature_name,
        identifier: details[:identifier],
        value: details[:value]&.to_s,
        traits: trait_values(details[:traits]),
        metadata: (details[:metadata] || {}).transform_keys(&:to_s).merge('sdk_version' => Flagsmith::VERSION),
        timestamp: (Time.now.to_f * 1000).to_i
      }
    end

    # Traits given as { value:, transient: } configurations are sent as their value.
    def trait_values(traits)
      return nil if traits.nil? || traits.empty?

      traits.to_h { |key, value| [key.to_s, value.is_a?(Hash) ? value[:value] : value] }
    end

    def buffer(event)
      request = @mutex.synchronize do
        next if stopping?("tracking #{event[:event]} event") || refused?(event) || duplicate_exposure?(event)

        drop_oldest if @events.length >= @max_buffer_items
        @events << event
        @tracked_count += 1
        next unless full_buffer_flush_due?

        @flush_pending = true
        flush_request
      end
      Thread.new { scheduled_flush(request) } if request
    end

    # A full buffer is flushed at once, unless such a flush is already waiting, or it holds a failed batch,
    # which waits for the next flush.
    def full_buffer_flush_due?
      !@flush_pending && !@holding_failed_batch && @events.length >= @max_buffer_items
    end

    def stopping?(action)
      return false unless @stopping

      @logger.debug "Not #{action}: the client is closed"
      true
    end

    def refused?(event)
      return false unless @refused

      @logger.debug "Not tracking #{event[:event]} event: the Flagsmith events API refused the environment key"
      true
    end

    def drop_oldest
      dropped = @events.shift
      @buffered_exposures.delete(exposure_key(dropped)) if dropped[:event] == FLAG_EXPOSURE_EVENT
      @logger.warn "Event buffer is full, dropping the oldest #{dropped[:event]} event"
    end

    def exposure_key(event)
      event.values_at(:feature_name, :identifier, :value)
    end

    def duplicate_exposure?(event)
      return false unless event[:event] == FLAG_EXPOSURE_EVENT
      return false if @buffered_exposures.add?(exposure_key(event))

      @logger.debug "Skipping duplicate #{FLAG_EXPOSURE_EVENT} event for feature #{event[:feature_name]}"
      true
    end
  end
end
