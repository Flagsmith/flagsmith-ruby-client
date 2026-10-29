# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Flagsmith::Client do
  let(:logger) { instance_spy(Logger) }
  let(:api_client) { instance_double(Flagsmith::ApiClient) }
  let(:enable_events) { true }
  let(:experiment_metadata) { { experiment: { id: 42, name: 'Banner experiment', in_experiment: true } } }
  let(:banner_flag) do
    {
      feature: { id: 1, name: 'banner' }, feature_state_value: 'hello treatment', enabled: true,
      variant: 'treatment', metadata: experiment_metadata
    }
  end

  subject do
    described_class.new(environment_key: 'ser.environment-key', enable_events: enable_events, logger: logger)
  end

  before do
    allow(Flagsmith::ApiClient).to receive(:new).and_return(api_client)
    allow(api_client).to receive(:post).with('identities/', anything)
                                       .and_return(OpenStruct.new(body: { flags: [banner_flag], traits: [] }))
    allow(subject.event_processor).to receive(:track_exposure_event) if enable_events
  end

  describe '#get_experiment_flag' do
    it 'returns the identity flag with the experiment it was served in' do
      # Given / When
      flag = subject.get_experiment_flag('banner', 'user_123', plan: 'premium')

      # Then
      expect(flag.value).to eq('hello treatment')
      expect(flag.variant).to eq('treatment')
      expect(flag.experiment).to eq(
        Flagsmith::Flags::Experiment.new(id: 42, name: 'Banner experiment', in_experiment: true)
      )
      expect(api_client).to have_received(:post).with(
        'identities/', { identifier: 'user_123', transient: false, traits: [{ trait_key: :plan, trait_value: 'premium' }] }.to_json
      )
    end

    it 'records the exposure of an identity in a running experiment to its variant' do
      # Given / When
      subject.get_experiment_flag('banner', 'user_123', plan: 'premium')

      # Then
      expect(subject.event_processor).to have_received(:track_exposure_event).with(
        'banner', identifier: 'user_123', value: 'treatment', traits: { plan: 'premium' }, metadata: { experiment_id: 42 }
      )
    end

    context 'when the identity is not in the running experiment' do
      let(:experiment_metadata) { { experiment: { id: 42, name: 'Banner experiment', in_experiment: false } } }

      it 'records no exposure' do
        # Given / When
        subject.get_experiment_flag('banner', 'user_123')

        # Then
        expect(subject.event_processor).not_to have_received(:track_exposure_event)
        expect(logger).to have_received(:debug)
          .with('Not sending $flag_exposure for feature banner: identity is not in a running experiment.')
      end
    end

    context 'when the feature has no running experiment' do
      let(:experiment_metadata) { nil }

      it 'returns the identity flag and records no exposure' do
        # Given / When
        flag = subject.get_experiment_flag('banner', 'user_123')

        # Then
        expect(flag.experiment).to be_nil
        expect(subject.event_processor).not_to have_received(:track_exposure_event)
        expect(logger).to have_received(:debug)
          .with('Not sending $flag_exposure for feature banner: identity is not in a running experiment.')
      end
    end

    context 'when the identity is in the running experiment without a variant' do
      let(:banner_flag) do
        {
          feature: { id: 1, name: 'banner' }, feature_state_value: 'hello', enabled: true, metadata: experiment_metadata
        }
      end

      it 'records no exposure' do
        # Given / When
        subject.get_experiment_flag('banner', 'user_123')

        # Then
        expect(subject.event_processor).not_to have_received(:track_exposure_event)
        expect(logger).to have_received(:debug).with('Not sending $flag_exposure for feature banner: flag has no variant.')
      end
    end

    context 'when the feature is disabled' do
      let(:banner_flag) do
        {
          feature: { id: 1, name: 'banner' }, feature_state_value: 'hello', enabled: false,
          variant: 'treatment', metadata: experiment_metadata
        }
      end

      it 'records no exposure' do
        # Given / When
        subject.get_experiment_flag('banner', 'user_123')

        # Then
        expect(subject.event_processor).not_to have_received(:track_exposure_event)
        expect(logger).to have_received(:debug).with('Not sending $flag_exposure for feature banner: feature is disabled.')
      end
    end

    context 'when the feature is served by the default flag handler' do
      subject do
        described_class.new(
          environment_key: 'ser.environment-key', enable_events: true, logger: logger,
          default_flag_handler: ->(_) { Flagsmith::Flags::DefaultFlag.new(enabled: true, value: 'default') }
        )
      end

      it 'returns the default flag and records no exposure' do
        # Given / When
        flag = subject.get_experiment_flag('unknown', 'user_123')

        # Then
        expect(flag.value).to eq('default')
        expect(subject.event_processor).not_to have_received(:track_exposure_event)
        expect(logger).to have_received(:debug).with('Not sending $flag_exposure for feature unknown: feature not found.')
      end
    end

    context 'when events are not enabled' do
      let(:enable_events) { false }

      it 'raises an error' do
        # Given / When / Then
        expect { subject.get_experiment_flag('banner', 'user_123') }
          .to raise_error(Flagsmith::ClientError, 'The enable_events config param is required to send events.')
      end
    end
  end

  describe '#track_event' do
    it 'records the event' do
      # Given
      allow(subject.event_processor).to receive(:track_event)

      # When
      subject.track_event('checkout_completed', identifier: 'user_123', value: 42, traits: { plan: 'premium' },
                                                metadata: { currency: 'GBP' })

      # Then
      expect(subject.event_processor).to have_received(:track_event).with(
        'checkout_completed', identifier: 'user_123', value: 42, traits: { plan: 'premium' }, metadata: { currency: 'GBP' }
      )
    end

    it 'refuses event names reserved for the SDK' do
      # Given / When / Then
      expect { subject.track_event('$flag_exposure', identifier: 'user_123') }
        .to raise_error(Flagsmith::ClientError,
                        'Event name "$flag_exposure" uses the "$" prefix, which is reserved for events sent by the SDK.')
    end

    context 'when events are not enabled' do
      let(:enable_events) { false }

      it 'raises an error' do
        # Given / When / Then
        expect { subject.track_event('checkout_completed') }
          .to raise_error(Flagsmith::ClientError, 'The enable_events config param is required to send events.')
      end
    end
  end

  describe '#track_exposure_event' do
    it 'records the exposure' do
      # Given / When
      subject.track_exposure_event('banner', identifier: 'user_123', value: 'control', metadata: { experiment_id: 1 })

      # Then
      expect(subject.event_processor).to have_received(:track_exposure_event).with(
        'banner', identifier: 'user_123', value: 'control', traits: nil, metadata: { experiment_id: 1 }
      )
    end

    it 'records no exposure without an identifier' do
      # Given / When
      subject.track_exposure_event('banner', identifier: nil, value: 'control')

      # Then
      expect(subject.event_processor).not_to have_received(:track_exposure_event)
      expect(logger).to have_received(:warn).with(
        'Not sending $flag_exposure for feature banner: an exposure requires an identifier to reconcile with conversion events.'
      )
    end
  end

  describe '#event_processor' do
    it 'sends events to the configured events API' do
      # Given / When
      client = described_class.new(environment_key: 'ser.environment-key', enable_events: true,
                                   events_api_url: 'http://events.test/base', logger: logger)

      # Then
      expect(client.config.events_api_url).to eq('http://events.test/base/')
      expect(client.event_processor).to be_a(Flagsmith::EventProcessor)
    end

    it 'sends events to Flagsmith by default' do
      # Given / When / Then
      expect(subject.config.events_api_url).to eq('https://events.api.flagsmith.com/')
    end
  end
end
