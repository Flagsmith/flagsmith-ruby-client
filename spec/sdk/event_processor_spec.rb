# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Flagsmith::EventProcessor do
  let(:logger) { instance_spy(Logger) }
  let(:config) do
    Flagsmith::Config.new(
      environment_key: 'ser.environment-key', events_api_url: 'http://events.test', logger: logger,
      custom_headers: { 'X-Proxy-Token' => 'token' }
    )
  end
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:sent_batches) { [] }
  let(:max_buffer_items) { 1000 }

  subject { described_class.new(config, max_buffer_items: max_buffer_items, retry_base_seconds: 0) }

  before do
    allow(Faraday).to receive(:new).and_wrap_original do |original, *args, **options, &block|
      original.call(*args, **options) do |faraday|
        block.call(faraday)
        faraday.adapter :test, stubs
      end
    end
  end

  def respond_to_events_with(status)
    stubs.post('/v1/events') do |env|
      sent_batches << { headers: env.request_headers, body: JSON.parse(env.body) }
      [status, {}, '']
    end
  end

  def reset_connection_to_events
    stubs.post('/v1/events') do |env|
      sent_batches << { headers: env.request_headers, body: JSON.parse(env.body) }
      raise Faraday::ConnectionFailed, 'Connection reset by peer'
    end
  end

  def sent_events
    sent_batches.map { |batch| batch[:body]['events'].map { |event| event['event'] } }
  end

  it 'sends a tracked event to the events API with its details' do
    # Given
    respond_to_events_with(202)

    # When
    subject.track_event('checkout_completed', identifier: 'user_123', value: 42,
                                              traits: { plan: 'premium', age: { value: 30, transient: true } },
                                              metadata: { currency: 'GBP' })
    subject.flush

    # Then
    expect(sent_batches.length).to eq(1)
    expect(sent_batches[0][:body]).to match(
      'events' => [
        {
          'event' => 'checkout_completed',
          'feature_name' => nil,
          'identifier' => 'user_123',
          'value' => '42',
          'traits' => { 'plan' => 'premium', 'age' => 30 },
          'metadata' => { 'currency' => 'GBP', 'sdk_version' => Flagsmith::VERSION },
          'timestamp' => be_within(5_000).of((Time.now.to_f * 1000).to_i)
        }
      ]
    )
    expect(sent_batches[0][:headers]).to include(
      'Content-Type' => 'application/json; charset=utf-8',
      'X-Environment-Key' => 'ser.environment-key',
      'Flagsmith-SDK-User-Agent' => "flagsmith-ruby-sdk/#{Flagsmith::VERSION}",
      'X-Proxy-Token' => 'token'
    )
  end

  it 'sends an exposure as a $flag_exposure event for the feature' do
    # Given
    respond_to_events_with(202)

    # When
    subject.track_exposure_event('banner', identifier: 'user_123', value: 'treatment',
                                           metadata: { 'experiment_id' => 1 })
    subject.flush

    # Then
    expect(sent_batches[0][:body]['events']).to match(
      [
        hash_including(
          'event' => '$flag_exposure', 'feature_name' => 'banner', 'identifier' => 'user_123',
          'value' => 'treatment', 'traits' => nil,
          'metadata' => { 'experiment_id' => 1, 'sdk_version' => Flagsmith::VERSION }
        )
      ]
    )
  end

  it 'sends an exposure only once per flush interval' do
    # Given
    respond_to_events_with(202)
    subject.track_exposure_event('banner', identifier: 'user_123', value: 'treatment')

    # When
    subject.track_exposure_event('banner', identifier: 'user_123', value: 'treatment')
    subject.track_exposure_event('banner', identifier: 'user_456', value: 'treatment')
    subject.flush

    # Then
    expect(sent_batches[0][:body]['events'].map { |event| event['identifier'] }).to eq(%w[user_123 user_456])
    expect(logger).to have_received(:debug)
      .with('Skipping duplicate $flag_exposure event for feature banner').once
  end

  it 'sends an exposure again in a later flush interval' do
    # Given
    respond_to_events_with(202)
    subject.track_exposure_event('banner', identifier: 'user_123', value: 'treatment')
    subject.flush

    # When
    subject.track_exposure_event('banner', identifier: 'user_123', value: 'treatment')
    subject.flush

    # Then
    expect(sent_batches.length).to eq(2)
  end

  it 'sends every tracked event, even when equal' do
    # Given
    respond_to_events_with(202)

    # When
    2.times { subject.track_event('checkout_completed', identifier: 'user_123') }
    subject.flush

    # Then
    expect(sent_batches[0][:body]['events'].length).to eq(2)
  end

  it 'sends a kept batch with the next flush, even with no events tracked since' do
    # Given
    3.times { respond_to_events_with(503) }
    respond_to_events_with(202)
    subject.track_event('checkout')
    subject.flush

    # When
    subject.flush

    # Then
    expect(sent_events).to eq([%w[checkout]] * 4)
  end

  it 'sends an exposure once when tracked again while its batch is kept' do
    # Given
    3.times { respond_to_events_with(503) }
    respond_to_events_with(202)
    subject.track_exposure_event('banner', identifier: 'user_123', value: 'treatment')
    subject.flush

    # When
    subject.track_exposure_event('banner', identifier: 'user_123', value: 'treatment')
    subject.flush

    # Then
    expect(sent_events.last).to eq(%w[$flag_exposure])
  end

  it 'sends an exposure once when tracked again while its batch was in flight, then kept' do
    # Given
    stubs.post('/v1/events') do |env|
      sent_batches << { body: JSON.parse(env.body) }
      sleep 0.05
      [sent_batches.length > 3 ? 202 : 503, {}, '']
    end
    subject.track_exposure_event('banner', identifier: 'user_123', value: 'treatment')
    first_flush = Thread.new { subject.flush }
    Timeout.timeout(5) { sleep 0.01 while sent_batches.empty? }
    subject.track_exposure_event('banner', identifier: 'user_123', value: 'treatment')
    first_flush.join

    # When
    subject.flush

    # Then
    expect(sent_events.last).to eq(%w[$flag_exposure])
  end

  it 'sends nothing when no events were tracked' do
    # Given / When
    subject.flush

    # Then
    stubs.verify_stubbed_calls
    expect(sent_batches).to be_empty
  end

  context 'when the buffer is full' do
    let(:max_buffer_items) { 2 }

    it 'sends the events without waiting for the flush interval' do
      # Given
      respond_to_events_with(202)
      subject.track_event('first')

      # When
      subject.track_event('second')

      # Then
      Timeout.timeout(5) { sleep 0.01 while sent_batches.empty? }
      expect(sent_batches[0][:body]['events'].map { |event| event['event'] }).to eq(%w[first second])
    end

    it 'schedules one flush at a time while a batch is being sent' do
      # Given
      allow(Thread).to receive(:new).and_return(nil)
      subject.track_event('first')

      # When
      subject.track_event('second')
      subject.track_event('third')
      subject.track_event('fourth')

      # Then
      expect(Thread).to have_received(:new).once
    end
  end

  it 'drops events the events API rejects, without raising' do
    # Given
    respond_to_events_with(400)
    respond_to_events_with(202)
    subject.track_event('add_to_cart')
    expect { subject.flush }.not_to raise_error
    subject.track_event('checkout')

    # When
    subject.flush

    # Then
    expect(sent_events).to eq([%w[add_to_cart], %w[checkout]])
    expect(logger).to have_received(:warn).with('Dropping 1 events: the events API rejected it with 400')
  end

  it 'sends a batch again until the events API accepts it' do
    # Given
    respond_to_events_with(503)
    reset_connection_to_events
    respond_to_events_with(202)
    subject.track_event('checkout')

    # When
    subject.flush

    # Then
    expect(sent_events).to eq([%w[checkout], %w[checkout], %w[checkout]])
    expect(logger).to have_received(:warn).with(
      'Unable to send 1 events to the Flagsmith events API, attempt 1 of 3: status 503'
    )
    expect(logger).to have_received(:warn).with(
      'Unable to send 1 events to the Flagsmith events API, attempt 2 of 3: Connection reset by peer'
    )
  end

  it 'sends a batch again when the events API is throttling' do
    # Given
    respond_to_events_with(429)
    respond_to_events_with(202)
    subject.track_event('checkout')

    # When
    subject.flush

    # Then
    expect(sent_events).to eq([%w[checkout], %w[checkout]])
  end

  it 'backs off with full jitter, doubling from the retry base' do
    # Given
    processor = described_class.new(config, retry_base_seconds: 1)
    allow(processor).to receive(:rand).and_return(1.0, 0.5)

    # When / Then
    expect(processor.send(:backoff, 2)).to eq(1.0)
    expect(processor.send(:backoff, 3)).to eq(1.0)
  end

  it 'keeps a batch that keeps failing for the next flush, ahead of events tracked since' do
    # Given
    3.times { respond_to_events_with(503) }
    respond_to_events_with(202)
    subject.track_event('add_to_cart')
    subject.flush
    subject.track_event('checkout')

    # When
    subject.flush

    # Then
    expect(sent_events).to eq([%w[add_to_cart]] * 3 + [%w[add_to_cart checkout]])
    expect(logger).to have_received(:warn).with('Keeping 1 events for the next flush: its last attempt failed')
  end

  it 'drops a batch whose last attempt gets a server error' do
    # Given
    2.times { respond_to_events_with(503) }
    respond_to_events_with(500)
    respond_to_events_with(202)
    subject.track_event('add_to_cart')
    subject.flush
    subject.track_event('checkout')

    # When
    subject.flush

    # Then
    expect(sent_events).to eq([%w[add_to_cart]] * 3 + [%w[checkout]])
    expect(logger).to have_received(:warn).with('Dropping 1 events: its last attempt got 500')
  end

  it 'keeps a batch whose last attempt fails otherwise, after server errors' do
    # Given
    2.times { respond_to_events_with(500) }
    respond_to_events_with(503)
    respond_to_events_with(202)
    subject.track_event('add_to_cart')
    subject.flush
    subject.track_event('checkout')

    # When
    subject.flush

    # Then
    expect(sent_events).to eq([%w[add_to_cart]] * 3 + [%w[add_to_cart checkout]])
  end

  [401, 403].each do |status|
    it "stops tracking events once the events API refuses the environment key with #{status}" do
      # Given
      respond_to_events_with(status)
      subject.track_event('add_to_cart')
      subject.flush

      # When
      subject.track_event('checkout')
      subject.flush

      # Then
      expect(sent_events).to eq([%w[add_to_cart]])
      expect(logger).to have_received(:error).with(
        "The Flagsmith events API refused the environment key with #{status}, stopping event tracking"
      )
    end
  end

  context 'when the buffer is full of events the events API failed' do
    let(:max_buffer_items) { 2 }

    it 'drops the oldest event' do
      # Given
      3.times { respond_to_events_with(503) }
      respond_to_events_with(202)
      subject.track_event('first')
      subject.track_event('second')
      subject.flush

      # When
      subject.track_event('third')
      subject.flush

      # Then
      expect(sent_events.last).to eq(%w[second third])
      expect(sent_events.flatten.count('first')).to eq(3)
      expect(logger).to have_received(:warn).with('Event buffer is full, dropping the oldest first event')
    end

    it 'waits for the next flush rather than attempting the kept batch again' do
      # Given
      3.times { respond_to_events_with(503) }
      subject.track_event('first')
      subject.track_event('second')
      subject.flush
      allow(Thread).to receive(:new).and_call_original

      # When
      subject.track_event('third')
      subject.track_event('fourth')

      # Then
      expect(Thread).not_to have_received(:new)
      expect(sent_events.length).to eq(3)
    end

    it 'does not send again a batch in flight when the flush was requested' do
      # Given
      stubs.post('/v1/events') do |env|
        sent_batches << { body: JSON.parse(env.body) }
        sleep 0.05
        [sent_batches.length > 3 ? 202 : 503, {}, '']
      end
      subject.track_event('first')
      subject.track_event('second')
      Timeout.timeout(5) { sleep 0.01 while sent_batches.empty? }

      # When
      subject.flush

      # Then
      expect(sent_events).to eq([%w[first second]] * 3)
    end

    it 'sends a full buffer without waiting again once the kept batch is sent' do
      # Given
      3.times { respond_to_events_with(503) }
      2.times { respond_to_events_with(202) }
      subject.track_event('first')
      subject.track_event('second')
      subject.flush
      Timeout.timeout(5) { sleep 0.01 while subject.instance_variable_get(:@flush_pending) }
      subject.flush
      allow(Thread).to receive(:new).and_call_original

      # When
      subject.track_event('third')
      subject.track_event('fourth')

      # Then
      expect(Thread).to have_received(:new).once
      Timeout.timeout(5) { sleep 0.01 until sent_events.last == %w[third fourth] }
      expect(sent_events).to eq([%w[first second]] * 4 + [%w[third fourth]])
    end
  end

  context 'when stopped' do
    before do
      respond_to_events_with(202)
      subject.start
      subject.stop
    end

    it 'tracks no more events' do
      # Given / When
      subject.track_event('checkout')
      subject.send(:send_batch)

      # Then
      expect(sent_batches).to be_empty
      expect(logger).to have_received(:debug).with('Not tracking checkout event: the client is closed')
    end

    it 'flushes nothing' do
      # Given
      subject.instance_variable_get(:@events) << { event: 'checkout' }

      # When
      subject.flush

      # Then
      expect(sent_batches).to be_empty
      expect(logger).to have_received(:debug).with('Not flushing events: the client is closed')
    end

    it 'does not start again' do
      # Given / When
      subject.start

      # Then
      expect(Flagsmith::RunningEventProcessors.to_a).not_to include(subject)
    end
  end

  it 'sends the remaining events when stopped' do
    # Given
    respond_to_events_with(202)
    subject.start
    subject.track_event('checkout_completed')

    # When
    subject.stop

    # Then
    expect(sent_batches.length).to eq(1)
  end

  it 'returns from stopping within its timeout while the events API does not answer, and retries no more' do
    # Given
    stubs.post('/v1/events') do |env|
      sent_batches << { body: JSON.parse(env.body) }
      sleep 0.5
      [503, {}, '']
    end
    subject.track_event('checkout')

    # When
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    subject.stop(0.1)

    # Then
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).to be < 0.4
    sleep 0.6
    expect(sent_batches.length).to eq(1)
    expect(logger).to have_received(:warn).with('Gave up sending events after 0.1 seconds while closing')
  end

  it 'takes no batch to send once stopping has returned' do
    # Given
    stubs.post('/v1/events') do |env|
      sent_batches << { body: JSON.parse(env.body) }
      sleep 0.3
      [202, {}, '']
    end
    subject.track_event('first')
    Thread.new { subject.flush }
    Timeout.timeout(5) { sleep 0.01 while sent_batches.empty? }
    subject.track_event('second')

    # When
    subject.stop(0.05)

    # Then
    sleep 0.5
    expect(sent_events).to eq([%w[first]])
  end

  it 'is stopped at exit while it is running' do
    # Given / When
    subject.start

    # Then
    expect(Flagsmith::RunningEventProcessors.to_a).to include(subject)
    subject.stop
  end

  it 'is not kept for exit once stopped' do
    # Given
    subject.start

    # When
    subject.stop

    # Then
    expect(Flagsmith::RunningEventProcessors.to_a).not_to include(subject)
  end
end
