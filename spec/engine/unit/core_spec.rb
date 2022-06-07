# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Flagsmith::Engine::Core, type: :model do
  subject { Class.new { extend Flagsmith::Engine::Core } }

  it 'test_identity_get_feature_state_without_any_override' do
    feature_state = subject.get_identity_feature_state(
      environment, identity, feature1.name
    )

    expect(feature_state.feature).to eq(feature1)
  end

  it 'test_identity_get_feature_state_without_any_override_no_fs' do
    expect {
      subject.get_identity_feature_state(environment, identity, 'nonExistentName')
    }.to raise_error(Flagsmith::FeatureStateNotFound)
  end

  it 'test_identity_get_all_feature_states_no_segments' do
    env = environment
    ident = identity
    overridden_feature = Flagsmith::Engine::Feature.new(
      id: 3, name: 'overridden_feature', type: 'STANDARD'
    )

    env.feature_states << Flagsmith::Engine::FeatureState.new(
      feature: overridden_feature, enabled: false, django_id: 3
    )

    ident.identity_features << Flagsmith::Engine::FeatureState.new(
      feature: overridden_feature, enabled: true, id: 4
    )

    feature_states = subject.get_identity_feature_states(env, ident)

    expect(feature_states.length).to eq(3)

    feature_states.each do |feature_state|
      environment_feature_state = get_environment_feature_state_for_feature(
        env, feature_state.feature
      )
      expected =
        if environment_feature_state&.feature == overridden_feature then true
        else environment_feature_state&.enabled
        end
        expect(feature_state.enabled?).to eq(expected)
    end
  end

  it 'test_identity_get_all_feature_states_with_traits' do
    trait_models = [Flagsmith::Engine::Identities::Trait.new(
      trait_key: Engine::Builders::SEGMENT_CONDITION_PROPERTY,
      trait_value: Engine::Builders::SEGMENT_CONDITION_STRING_VALUE
    )]

    feature_states = subject.get_identity_feature_states(
      environment_with_segment_override, identity_in_segment, trait_models
    )

    expect(feature_states.first.get_value).to eq(Engine::Builders::SEGMENT_OVERRIDE_FEATURE_STATE_VALUE)
  end

  it 'test_identity_get_all_feature_states_with_traits_hideDisabledFlags' do
    trait_models = [Flagsmith::Engine::Identities::Trait.new(
      trait_key: Engine::Builders::SEGMENT_CONDITION_PROPERTY,
      trait_value: Engine::Builders::SEGMENT_CONDITION_STRING_VALUE
    )]

    env = environment_with_segment_override
    env.project.hide_disabled_flags = true

    feature_states = subject.get_identity_feature_states(
      env, identity_in_segment, trait_models
    )
    expect(feature_states.length).to eq(0)
  end

  it 'test_environment_get_all_feature_states' do
    env = environment
    feature_states = subject.get_environment_feature_states(env)

    expect(feature_states).to eq(env.feature_states)
  end

  it 'test_environment_get_feature_states_hides_disabled_flags_if_enabled' do
    env = environment

    env.project.hide_disabled_flags = true

    feature_states = subject.get_environment_feature_states(env)

    expect(feature_states).to_not eq(env.feature_states)
    feature_states.each do |fs|
      expect(fs.enabled).to be_truthy
    end
  end

  it 'test_environment_get_feature_state' do
    env = environment
    feature = feature1
    feature_state = subject.get_environment_feature_state(env, feature.name)

    expect(feature_state.feature).to eq(feature)
  end

  it 'test_environment_get_feature_state_raises_feature_state_not_found' do
      expect {
        subject.get_environment_feature_state(environment, 'not_a_feature_name')
      }.to raise_error(Flagsmith::FeatureStateNotFound)
  end
end
