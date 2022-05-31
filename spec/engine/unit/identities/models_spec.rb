# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Flagsmith::Engine::Identity do
  let!(:identity) do
    Flagsmith::Engine::Identity.build(
      id: 1,
      identifier: 'test-identity',
      environment_api_key: 'api-key',
      created_date: '2021-08-22T06:25:23.406995Z',
      identity_traits: [{ trait_key: 'trait_key', trait_value: 'trait_value' }]
    )
  end

  context '#build without feature states' do
    it '#identity_features count' do
      expect(identity.identity_features.count).to eq(0)
    end

    it '#identity_traits count' do
      expect(identity.identity_traits.count).to eq(1)
    end

    it '#identity_uuid is default generated' do
      expect(identity.identity_uuid).not_to be_nil
    end
  end

  it '#build with identity feature list' do
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

  context '#buil with feature states' do
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

    engine_identity = Flagsmith::Engine::Identity.build(identity_dict)

    it { expect(engine_identity).to be_instance_of(Flagsmith::Engine::Identity) }

    it 'identity_features count' do
      expect(engine_identity.identity_features.count).to eq(1)
    end

    it 'identity_features' do
      expect(engine_identity.identity_features).to all(be_an(Flagsmith::Engine::FeatureState))
    end
  end

  context '#composite_key' do
    it { expect(identity.composite_key).to eq('api-key_test-identity') }
  end

  context '#update_traits should remove traits with empty value then' do
    let!(:trait_key) { identity.identity_traits.first.trait_key }
    let!(:trait_to_remove) do
      Flagsmith::Engine::Identities::Trait.new(trait_key: trait_key, trait_value: nil)
    end

    it 'identity_traits count' do
      identity.update_traits([trait_to_remove])
      expect(identity.identity_traits.length).to eq(0)
    end
  end

  context '#update_traits with valid value then' do
    let!(:trait_key) { identity.identity_traits.first.trait_key }
    let!(:trait_value) { 'updated_trait_value' }
    let!(:trait_to_update) do
      Flagsmith::Engine::Identities::Trait.new(trait_key: trait_key, trait_value: trait_value)
    end

    before(:each) { identity.update_traits([trait_to_update]) }

    it 'identity_traits count should be 1' do
      expect(identity.identity_traits.length).to eq(1)
    end

    it 'the first of identity_traits is the trait to update' do
      expect(identity.identity_traits.first).to eq(trait_to_update)
    end
  end

  context '#update_traits with new trait' do
    let(:new_trait) do
      Flagsmith::Engine::Identities::Trait.new(trait_key: 'new_key', trait_value: 'foobar')
    end

    before(:each) { identity.update_traits([new_trait]) }

    it 'identity_traits count should be 2' do
      expect(identity.identity_traits.length).to eq(2)
    end

    it 'identity_traits contain new trait' do
      expect(identity.identity_traits).to include(new_trait)
    end
  end

  it 'test_append_feature_state' do
    fs1 = Flagsmith::Engine::FeatureState.new(feature: {}, enabled: true, django_id: 1)
    identity.identity_features.push(fs1)

    expect(identity.identity_features).to include(fs1)
  end
end
