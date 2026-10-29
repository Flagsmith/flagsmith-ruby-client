# frozen_string_literal: true

require 'set'

module Flagsmith
  # Buffers tracking and exposure events, and sends them to the Flagsmith events API in batches.
  #
  # Events are sent every +flush_interval_seconds+, as soon as +max_buffer_items+ are buffered,
  # or on #flush. Sending events never raises into the application: failures are logged.
  class EventProcessor
    include Flagsmith::SDK::Intervals

    FLAG_EXPOSURE_EVENT = '$flag_exposure'
    ENDPOINT = 'v1/events'
    FLUSH_INTERVAL_SECONDS = 10
    MAX_BUFFER_ITEMS = 1000
    REQUEST_TIMEOUT_SECONDS = 3
    RETRIABLE_STATUSES = [500, 502, 503, 504].freeze

    def initialize(config, flush_interval_seconds: FLUSH_INTERVAL_SECONDS, max_buffer_items: MAX_BUFFER_ITEMS)
      @logger = config.logger
      @flush_interval_seconds = flush_interval_seconds
      @max_buffer_items = max_buffer_items
      @connection = build_connection(config)
      @events = []
      @buffered_exposures = Set.new
      @mutex = Mutex.new
      @flush_mutex = Mutex.new
      @flush_pending = false
    end

    def track_event(event, identifier: nil, value: nil, traits: nil, metadata: nil)
      buffer(payload(event, nil, identifier: identifier, value: value, traits: traits, metadata: metadata))
    end

    # Equal exposures within one flush interval add no information, so only the first is sent.
    def track_exposure_event(feature_name, identifier:, value: nil, traits: nil, metadata: nil)
      buffer(payload(FLAG_EXPOSURE_EVENT, feature_name,
                     identifier: identifier, value: value, traits: traits, metadata: metadata))
    end

    # +scheduled+ is internal: only the flush scheduled by a full buffer clears +@flush_pending+, once it holds
    # the buffer, so at most one such flush is waiting at a time.
    def flush(scheduled: false)
      @flush_mutex.synchronize do
        batch = @mutex.synchronize do
          buffered = @events
          @events = []
          @buffered_exposures.clear
          @flush_pending = false if scheduled
          buffered
        end
        send_events(batch) unless batch.empty?
      end
    end

    def start
      return if @interval

      @interval = set_interval(@flush_interval_seconds) { flush }
      at_exit { stop }
    end

    def stop
      @flush_mutex.synchronize { clear_interval(@interval) } if @interval # never interrupts a batch being sent
      @interval = nil
      flush
    end

    private

    def build_connection(config)
      Faraday.new(url: config.events_api_url, headers: headers(config)) do |f|
        f.options.timeout = REQUEST_TIMEOUT_SECONDS
        f.response :raise_error
        f.request :retry, max: 1, interval: 1, methods: %i[post], retry_statuses: RETRIABLE_STATUSES,
                          exceptions: [*Faraday::Retry::Middleware::DEFAULT_EXCEPTIONS, Faraday::ConnectionFailed]
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
      schedule_flush = @mutex.synchronize do
        next false if duplicate_exposure?(event)

        @events << event
        next false if @flush_pending || @events.length < @max_buffer_items

        @flush_pending = true
      end
      Thread.new { flush(scheduled: true) } if schedule_flush
    end

    def duplicate_exposure?(event)
      return false unless event[:event] == FLAG_EXPOSURE_EVENT
      return false if @buffered_exposures.add?(event.values_at(:feature_name, :identifier, :value))

      @logger.debug "Skipping duplicate #{FLAG_EXPOSURE_EVENT} event for feature #{event[:feature_name]}, identifier #{event[:identifier]}"
      true
    end

    def send_events(events)
      @connection.post(ENDPOINT, { events: events }.to_json)
    rescue StandardError => e
      @logger.warn "Unable to send #{events.length} events to the Flagsmith events API, dropping them: #{e}"
    end
  end
end
