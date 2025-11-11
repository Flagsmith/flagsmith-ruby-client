# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Flagsmith::Engine::Mappers do
  describe '.get_evaluation_context' do
    let(:environment_json) do
      JSON.parse(
        File.read('spec/sdk/fixtures/environment.json'),
        symbolize_names: true
      )
    end

    let(:environment) { Flagsmith::Engine::Environment.build(environment_json) }

    it 'produces evaluation context from environment document' do
      # When
      context = described_class.get_evaluation_context(environment)

      # Then - verify structure
      expect(context).to be_a(Hash)
      expect(context[:environment][:key]).to eq('B62qaMZNwfiqT76p38ggrQ')
      expect(context[:environment][:name]).to eq('Test environment')
      expect(context[:identity]).to be_nil

      # Verify segments
      expect(context[:segments]).to be_a(Hash)
      expect(context[:segments]).to have_key('1')

      segment = context[:segments]['1']
      expect(segment[:key]).to eq('1')
      expect(segment[:name]).to eq('regular_segment')
      expect(segment[:rules].length).to eq(1)
      expect(segment[:overrides]).to be_empty.or be_an(Array)
      expect(segment[:metadata][:source]).to eq('API')
      expect(segment[:metadata][:flagsmith_id]).to eq(1)

      # Verify segment rules
      expect(segment[:rules][0][:type]).to eq('ALL')
      expect(segment[:rules][0][:conditions]).to eq([])
      expect(segment[:rules][0][:rules].length).to eq(1)

      nested_rule = segment[:rules][0][:rules][0]
      expect(nested_rule[:type]).to eq('ANY')
      expect(nested_rule[:conditions].length).to eq(1)
      expect(nested_rule[:rules]).to eq([])

      condition = nested_rule[:conditions][0]
      expect(condition[:property]).to eq('age')
      expect(condition[:operator]).to eq('LESS_THAN')
      expect(condition[:value]).to eq(40)

      # Verify identity override segment
      identity_override_segment = context[:segments].values.find { |s| s[:name] == 'identity_override' }
      expect(identity_override_segment).not_to be_nil
      expect(identity_override_segment[:name]).to eq('identity_override')
      expect(identity_override_segment[:rules].length).to eq(1)
      expect(identity_override_segment[:overrides].length).to eq(1)

      override_rule = identity_override_segment[:rules][0]
      expect(override_rule[:type]).to eq('ALL')
      expect(override_rule[:conditions].length).to eq(1)
      expect(override_rule[:rules]).to eq([])

      override_condition = override_rule[:conditions][0]
      expect(override_condition[:property]).to eq('$.identity.identifier')
      expect(override_condition[:operator]).to eq('IN')
      expect(override_condition[:value]).to include('overridden-id')

      override = identity_override_segment[:overrides][0]
      expect(override[:name]).to eq('some_feature')
      expect(override[:enabled]).to be false
      expect(override[:value]).to eq('some-overridden-value')
      expect(override[:priority]).to eq(Flagsmith::Engine::Mappers::STRONGEST_PRIORITY)
      expect(override[:metadata][:flagsmith_id]).to eq(1)

      # Verify features
      expect(context[:features]).to be_a(Hash)
      expect(context[:features]).to have_key('some_feature')

      some_feature = context[:features]['some_feature']
      expect(some_feature[:name]).to eq('some_feature')
      expect(some_feature[:enabled]).to be true
      expect(some_feature[:value]).to eq('some-value')
      expect(some_feature[:priority]).to be_nil
      expect(some_feature[:metadata][:flagsmith_id]).to eq(1)

      # Verify multivariate feature
      expect(context[:features]).to have_key('test_mv')
      test_mv = context[:features]['test_mv']
      expect(test_mv[:name]).to eq('test_mv')
      expect(test_mv[:enabled]).to be false
      expect(test_mv[:value]).to eq('1111')
      expect(test_mv[:priority]).to be_nil
      expect(test_mv[:variants].length).to eq(1)

      variant = test_mv[:variants][0]
      expect(variant[:value]).to eq('8888')
      expect(variant[:weight]).to eq(100.0)
      expect(variant[:priority]).to eq(38451)
    end

    it 'maps multivariate features with multiple variants correctly' do
      # Given
      mv_option1 = Flagsmith::Engine::Features::MultivariateOption.new(id: 100, value: 'variant_a')
      mv_option2 = Flagsmith::Engine::Features::MultivariateOption.new(id: 200, value: 'variant_b')
      mv_option3 = Flagsmith::Engine::Features::MultivariateOption.new(id: 150, value: 'variant_c')

      mv_value1 = Flagsmith::Engine::Features::MultivariateStateValue.new(
        id: 100,
        multivariate_feature_option: mv_option1,
        percentage_allocation: 30
      )

      mv_value2 = Flagsmith::Engine::Features::MultivariateStateValue.new(
        id: 200,
        multivariate_feature_option: mv_option2,
        percentage_allocation: 50
      )

      mv_value3 = Flagsmith::Engine::Features::MultivariateStateValue.new(
        id: 150,
        multivariate_feature_option: mv_option3,
        percentage_allocation: 20
      )

      feature = Flagsmith::Engine::Feature.new(id: 999, name: 'multi_variant_feature', type: 'MULTIVARIATE')
      feature_state = Flagsmith::Engine::FeatureState.new(
        feature: feature,
        enabled: true,
        django_id: 999,
        feature_state_value: 'control',
        multivariate_feature_state_values: [mv_value1, mv_value2, mv_value3]
      )

      env_with_mv = Flagsmith::Engine::Environment.new(
        id: 1,
        api_key: 'test_key',
        project: environment.project,
        feature_states: [feature_state]
      )

      # When
      context = described_class.get_evaluation_context(env_with_mv)

      # Then
      feature_context = context[:features]['multi_variant_feature']
      expect(feature_context[:variants].length).to eq(3)

      expect(feature_context[:variants][0][:value]).to eq('variant_a')
      expect(feature_context[:variants][0][:weight]).to eq(30)
      expect(feature_context[:variants][0][:priority]).to eq(100)

      expect(feature_context[:variants][1][:value]).to eq('variant_b')
      expect(feature_context[:variants][1][:weight]).to eq(50)
      expect(feature_context[:variants][1][:priority]).to eq(200)

      expect(feature_context[:variants][2][:value]).to eq('variant_c')
      expect(feature_context[:variants][2][:weight]).to eq(20)
      expect(feature_context[:variants][2][:priority]).to eq(150)
    end

    it 'handles multivariate features without IDs using UUID' do
      # Given
      mv_option1 = Flagsmith::Engine::Features::MultivariateOption.new(value: 'option_x')
      mv_option2 = Flagsmith::Engine::Features::MultivariateOption.new(value: 'option_y')

      mv_value1 = Flagsmith::Engine::Features::MultivariateStateValue.new(
        id: nil,
        multivariate_feature_option: mv_option1,
        percentage_allocation: 60,
        mv_fs_value_uuid: 'aaaaaaaa-bbbb-cccc-dddd-000000000001'
      )

      mv_value2 = Flagsmith::Engine::Features::MultivariateStateValue.new(
        id: nil,
        multivariate_feature_option: mv_option2,
        percentage_allocation: 40,
        mv_fs_value_uuid: 'aaaaaaaa-bbbb-cccc-dddd-000000000002'
      )

      feature = Flagsmith::Engine::Feature.new(id: 888, name: 'uuid_variant_feature', type: 'MULTIVARIATE')
      feature_state = Flagsmith::Engine::FeatureState.new(
        feature: feature,
        enabled: true,
        django_id: 888,
        feature_state_value: 'default',
        multivariate_feature_state_values: [mv_value1, mv_value2]
      )

      env_with_uuid = Flagsmith::Engine::Environment.new(
        id: 1,
        api_key: 'test_key',
        project: environment.project,
        feature_states: [feature_state]
      )

      # When
      context = described_class.get_evaluation_context(env_with_uuid)

      # Then
      feature_context = context[:features]['uuid_variant_feature']
      expect(feature_context[:variants].length).to eq(2)

      expect(feature_context[:variants][0][:priority]).to be_a(Integer)
      expect(feature_context[:variants][1][:priority]).to be_a(Integer)
      expect(feature_context[:variants][0][:priority]).not_to eq(feature_context[:variants][1][:priority])
    end

    it 'handles environment with no features' do
      # Given
      empty_env = Flagsmith::Engine::Environment.new(
        id: 1,
        api_key: 'test_key',
        project: environment.project,
        feature_states: []
      )

      # When
      context = described_class.get_evaluation_context(empty_env)

      # Then
      expect(context[:features]).to eq({})
      expect(context[:environment][:key]).to eq('test_key')
    end

    it 'produces evaluation context with identity' do
      # Given
      identity = Flagsmith::Engine::Identity.new(
        identifier: 'test_user',
        environment_api_key: 'B62qaMZNwfiqT76p38ggrQ',
        identity_traits: [
          Flagsmith::Engine::Identities::Trait.new(trait_key: 'email', trait_value: 'test@example.com'),
          Flagsmith::Engine::Identities::Trait.new(trait_key: 'age', trait_value: 25)
        ]
      )

      # When
      context = described_class.get_evaluation_context(environment, identity)

      # Then
      expect(context[:identity]).not_to be_nil
      expect(context[:identity][:identifier]).to eq('test_user')
      expect(context[:identity][:key]).to eq('B62qaMZNwfiqT76p38ggrQ_test_user')
      expect(context[:identity][:traits]).to eq({
        'email' => 'test@example.com',
        'age' => 25
      })
    end

    it 'produces evaluation context with override traits' do
      # Given
      identity = Flagsmith::Engine::Identity.new(
        identifier: 'test_user',
        environment_api_key: 'B62qaMZNwfiqT76p38ggrQ',
        identity_traits: [
          Flagsmith::Engine::Identities::Trait.new(trait_key: 'email', trait_value: 'original@example.com')
        ]
      )

      override_traits = [
        Flagsmith::Engine::Identities::Trait.new(trait_key: 'email', trait_value: 'override@example.com'),
        Flagsmith::Engine::Identities::Trait.new(trait_key: 'premium', trait_value: true)
      ]

      # When
      context = described_class.get_evaluation_context(environment, identity, override_traits)

      # Then
      expect(context[:identity][:traits]).to eq({
        'email' => 'override@example.com',
        'premium' => true
      })
    end
  end
end
