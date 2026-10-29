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

  subject { described_class.new(config, max_buffer_items: max_buffer_items) }

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
      .with('Skipping duplicate $flag_exposure event for feature banner, identifier user_123').once
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
  end

  it 'drops events the events API rejects, without raising' do
    # Given
    respond_to_events_with(400)
    subject.track_event('checkout_completed')

    # When
    expect { subject.flush }.not_to raise_error

    # Then
    expect(sent_batches.length).to eq(1)
    expect(logger).to have_received(:warn).with(/\AUnable to send 1 events to the Flagsmith events API, dropping them: /)
  end

  it 'sends events again once when the events API fails' do
    # Given
    respond_to_events_with(503)
    respond_to_events_with(202)
    subject.track_event('checkout_completed')

    # When
    subject.flush

    # Then
    expect(sent_batches.length).to eq(2)
    expect(sent_batches[1][:body]).to eq(sent_batches[0][:body])
    expect(logger).not_to have_received(:warn)
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
end
