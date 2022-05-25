# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Flagsmith::Engine::Identity do
  context '#build without feature states' do
    let(:identity) do
      Flagsmith::Engine::Identity.build(
        id: 1,
        identifier: 'test-identity',
        environment_api_key: 'api-key',
        created_date: '2021-08-22T06:25:23.406995Z',
        identity_traits: [{ trait_key: 'trait_key', trait_value: 'trait_value' }]
      )
    end

    it '#identity_features count' do
      expect(identity.identity_features.count).to eq(0)
    end

    it '#identity_traits count' do
      expect(identity.identity_traits.count).to eq(1)
    end
  end

  it 'test_build_identity_model_from_dictionary_uses_identity_feature_list_for_identity_features' do
    identity_dict = {
      id: 1, identifier: 'test-identity', environment_api_key: 'api-key',
      created_date: '2021-08-22T06:25:23.406995Z',
      identity_features: [
        { id: 1, enabled: true, feature_state_value: 'some-value',
          feature: { id: 1, name: 'test_feature', type: 'STANDARD' } }
      ]
    }

    identity = Flagsmith::Engine::Identity.build(identity_dict)

    expect(identity.identity_features.count).to eq(1)
  end

  it 'test_build_build_identity_model_from_dict_creates_identity_uuid' do
    identity_model = Flagsmith::Engine::Identity.build(
      identifier: 'test_user',
      environment_api_key: 'some_key'
    )
    expect(identity_model.identity_uuid).not_to be_nil
  end

  it 'test_build_identity_model_from_dictionary_with_feature_states' do
    identity_dict = {
        id: 1,
        identifier: 'test-identity',
        environment_api_key: 'api-key',
        created_date: '2021-08-22T06:25:23.406995Z',
        identity_features: [
            {
                id: 1,
                feature: {
                    id: 1,
                    name: 'test_feature',
                    type: 'STANDARD'
                },
                enabled: true,
                feature_state_value: 'some-value'
            }
        ]
    }

    identity = Flagsmith::Engine::Identity.build(identity_dict)

    expect(identity).to be_instance_of(Flagsmith::Engine::Identity)
    expect(identity.identity_features.count).to eq(1)
    expect(identity.identity_features).to all(be_an(Flagsmith::Engine::Features::State))
  end
end
