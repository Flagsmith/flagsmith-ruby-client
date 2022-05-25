# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Flagsmith::Engine::Environment do
  let(:value_1) { 'value-1' }
  let(:value_2) { 'value-2' }
  let(:feature_state_value) { 'red' }
  let(:feature_name) { 'button' }
  let(:response) do
    {
      id: 1,
      api_key: 'api-key',
      project: {
        id: 1,
        name: 'test project',
        organisation: {
          id: 1,
          name: 'Test Org',
          stop_serving_flags: false,
          persist_trait_data: true,
          feature_analytics: true
        },
        hide_disabled_flags: false
      },
      feature_states: [
        {
          id: 1,
          enabled: true,
          feature_state_value: nil,
          feature: { id: 1, name: 'enabled_feature', type: 'STANDARD' },
          multivariate_feature_state_values: [
            {
              id: 1,
              percentage_allocation: 10.0,
              multivariate_feature_option: {
                value: value_1
              }
            },
            {
              id: 2,
              percentage_allocation: 10.0,
              multivariate_feature_option: {
                value: value_2,
                id: 2
              }
            }
          ]
        },
        {
          id: 2,
          enabled: false,
          feature_state_value: nil,
          feature: { id: 2, name: 'disabled_feature', type: 'STANDARD' }
        },
        {
          id: 3,
          enabled: true,
          feature_state_value: feature_state_value,
          feature: {
            id: 3,
            name: feature_name,
            type: 'STANDARD'
          }
        }
      ]
    }
  end

  subject { described_class.build(response) }

  it { is_expected.to be_instance_of(Flagsmith::Engine::Environment) }

  context 'feature states' do
    it 'length' do
      expect(subject.feature_states.length).to eq(3)
    end

    it 'are instances of Flagsmith::Engine::Features::State' do
      expect(subject.feature_states).to all(be_an(Flagsmith::Engine::Features::State))
    end

    it 'has valid #value' do
      feature = subject.feature_states.find { |fs| fs.feature.name == feature_name }
      expect(feature.get_value).to eq(feature_state_value)
    end

    it 'multivariate_feature_state_values are instances of Flagsmith::Engine::Features::MultivariateStateValue' do
      expect(subject.feature_states.first.multivariate_feature_state_values).to all(be_an(Flagsmith::Engine::Features::MultivariateStateValue))
    end
  end
end

RSpec.describe Flagsmith::Engine::Environments::ApiKey do
  it 'store valid #key' do
    environment_key_json = {
      key: 'ser.7duQYrsasJXqdGsdaagyfU',
      active: true,
      created_at: '2022-02-07T04:58:25.969438+00:00',
      client_api_key: 'RQchaCQ2mYicSCAwKoAg2E',
      id: 10,
      name: 'api key 2',
      expires_at: nil
    }

    environment_api_key = Flagsmith::Engine::Environments::ApiKey.build(environment_key_json)

    expect(environment_api_key.key).to eq(environment_key_json[:key])
  end

  it 'when #expires_at is nil' do
    environment_api_key = Flagsmith::Engine::Environments::ApiKey.new(
      id: 1,
      key: 'ser.random_key',
      name: 'test_key',
      client_api_key: 'test_key',
      created_at: Time.now,
    )
    expect(environment_api_key.valid?).to be_truthy
  end

  it 'when #expires_at is future date' do
    environment_api_key = Flagsmith::Engine::Environments::ApiKey.new(
      id: 1,
      key: 'ser.random_key',
      name: 'test_key',
      client_api_key: 'test_key',
      created_at: Time.now,
      expires_at: Time.now + 1000 * 60 * 60 * 24 * 2
    )
    expect(environment_api_key.valid?).to be_truthy
  end

  it 'when #expires_at is past date' do
    environment_api_key = Flagsmith::Engine::Environments::ApiKey.new(
      id: 1,
      key: 'ser.random_key',
      name: 'test_key',
      client_api_key: 'test_key',
      created_at: Time.now,
      expires_at: Time.now - 1000 * 60 * 60 * 24 * 2
    )
    expect(environment_api_key.valid?).to be_falsy
  end

  it 'when #active is false' do
    environment_api_key = Flagsmith::Engine::Environments::ApiKey.new(
      id: 1,
      key: 'ser.random_key',
      name: 'test_key',
      client_api_key: 'test_key',
      created_at: Time.now
    )

    environment_api_key.active = false
    expect(environment_api_key.valid?).to be_falsy
  end
end
