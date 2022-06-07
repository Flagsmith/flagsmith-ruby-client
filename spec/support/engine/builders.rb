# frozen_string_literal: true

module Engine
  module Builders
    include Flagsmith::Engine::Segments::Constants

    SEGMENT_CONDITION_PROPERTY = 'foo'
    SEGMENT_CONDITION_STRING_VALUE = 'bar'
    SEGMENT_OVERRIDE_FEATURE_STATE_VALUE = 'segment_override'

    def segment_condition
      Flagsmith::Engine::Segments::Condition.new(
        operator: EQUAL, value: SEGMENT_CONDITION_STRING_VALUE, property: SEGMENT_CONDITION_PROPERTY
      )
    end

    def trait_matching_segment
      condition = segment_condition
      Flagsmith::Engine::Identities::Trait.new(
        trait_key: condition.property, trait_value: condition.value
      )
    end

    def organisation
      Flagsmith::Engine::Organisation.new(
        id: 1, name: 'test Org',
        stop_serving_flags: true, persist_trait_data: false, feature_analitycs: true
      )
    end

    def segment_rule
      rule = Flagsmith::Engine::Segments::Rule.new(type: ALL_RULE)
      rule.conditions = [segment_condition]
      rule
    end

    def segment
      segment = Flagsmith::Engine::Segment.new(id: 1, name: 'test name')
      segment.rules = [segment_rule]
      segment
    end

    def project
      project = Flagsmith::Engine::Project.new(
        id: 1, name: 'test project', organisation: organisation, hide_disabled_flags: false
      )
      project.segments = [segment]
      project
    end

    def feature1
      Flagsmith::Engine::Feature.new(id: 1, name: 'feature_1', type: 'STANDARD')
    end

    def feature2
      Flagsmith::Engine::Feature.new(id: 2, name: 'feature_2', type: 'STANDARD')
    end

    def environment
      env = Flagsmith::Engine::Environment.new(id: 1, api_key: 'api-key', project: project)

      env.feature_states = [
        Flagsmith::Engine::FeatureState.new(feature: feature1, enabled: true, django_id: 1),
        Flagsmith::Engine::FeatureState.new(feature: feature2, enabled: false, django_id: 2)
      ]

      env
    end

    def identity
      Flagsmith::Engine::Identity.new(
        identifier: 'identity_1', environment_api_key: environment.api_key,
        created_date: Time.now
      )
    end

    def identity_in_segment
      Flagsmith::Engine::Identity.new(
        created_date: Time.now, environment_api_key: environment.api_key,
        identifier: 'identity_2', identity_traits: [trait_matching_segment]
      )
    end

    def get_environment_feature_state_for_feature_by_name(environment, feature_name)
      environment.feature_state.find  { |fs| fs.feature.name == feature_name }
    end

    def get_environment_feature_state_for_feature(environment, feature)
      environment.feature_states.find { |f| f.feature == feature }
    end

    def segment_override_fs
      fs = Flagsmith::Engine::FeatureState.new(feature: feature1, enabled: false, django_id: 4)
      fs.set_value(SEGMENT_OVERRIDE_FEATURE_STATE_VALUE)
      fs
    end

    def environment_with_segment_override
      env = environment
      segm = segment

      segm.feature_states << segment_override_fs
      env.project.segments << segm
      env
    end
  end
end
