# frozen_string_literal: true

require 'spec_helper'

require_relative 'shared_mocks.rb'

RSpec.describe Flagsmith do
  include_context 'shared mocks'

  describe '#get_identity_overrides_flags' do
    it 'should return identity overrides in local evaluation' do
      allow_any_instance_of(Flagsmith::Client).to receive(:api_client).and_return(mock_api_client)

      flagsmith = Flagsmith::Client.new(environment_key: mock_api_key, api_url: mock_api_url, enable_local_evaluation: true)
      expect(flagsmith.config.local_evaluation?).to be_truthy

      flag = flagsmith.get_identity_flags("overridden-id").get_flag("some_feature")

      expect(flag.enabled).to be_falsy
      expect(flag.value).to eq("some-overridden-value")
    end
  end

  describe '#get_multivariate_flags' do
    it 'should return a 100% multivariate variation in local evaluation' do
      allow_any_instance_of(Flagsmith::Client).to receive(:api_client).and_return(mock_api_client)

      flagsmith = Flagsmith::Client.new(environment_key: mock_api_key, api_url: mock_api_url, enable_local_evaluation: true)
      expect(flagsmith.config.local_evaluation?).to be_truthy

      flag = flagsmith.get_identity_flags("some-identifier").get_flag("test_mv")

      expect(flag.enabled).to be_falsy
      expect(flag.value).to eq("8888")
    end
  end

  describe 'flag dependency' do
    let(:api_environment_document_response) do
      environment_document = JSON.parse(File.read('spec/sdk/fixtures/environment.json'))
      environment_document['project']['segments'] << {
        'id' => 2,
        'name' => 'some_feature_enabled',
        'rules' => [
          {
            'type' => 'ALL',
            'conditions' => [{ 'operator' => 'EQUAL', 'property_' => '$.flags.some_feature.enabled', 'value' => 'true' }],
            'rules' => []
          }
        ],
        'feature_states' => [
          {
            'django_id' => 81028,
            'enabled' => true,
            'feature_state_value' => 'gated-value',
            'multivariate_feature_state_values' => [],
            'feature' => { 'id' => 83755, 'name' => 'test_mv', 'type' => 'MULTIVARIATE' }
          }
        ]
      }
      environment_document.to_json
    end

    it 'serves an identity the override of a flag gated on another enabled flag' do
      # Given
      allow_any_instance_of(Flagsmith::Client).to receive(:api_client).and_return(mock_api_client)
      flagsmith = Flagsmith::Client.new(environment_key: mock_api_key, api_url: mock_api_url, enable_local_evaluation: true)

      # When
      flag = flagsmith.get_identity_flags('some-identifier').get_flag('test_mv')

      # Then
      expect(flag.enabled).to be_truthy
      expect(flag.value).to eq('gated-value')
      expect(flag.reason).to eq('TARGETING_MATCH; segment=some_feature_enabled')
    end

    it 'serves the environment the override of a flag gated on another enabled flag' do
      # Given
      allow_any_instance_of(Flagsmith::Client).to receive(:api_client).and_return(mock_api_client)
      flagsmith = Flagsmith::Client.new(environment_key: mock_api_key, api_url: mock_api_url, enable_local_evaluation: true)

      # When
      flag = flagsmith.get_environment_flags.get_flag('test_mv')

      # Then
      expect(flag.enabled).to be_truthy
      expect(flag.value).to eq('gated-value')
      expect(flag.reason).to eq('TARGETING_MATCH; segment=some_feature_enabled')
    end
  end
end
