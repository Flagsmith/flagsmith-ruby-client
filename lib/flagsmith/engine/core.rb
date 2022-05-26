# frozen_string_literal: true

require 'semantic'
require 'securerandom'

require_relative 'environments/models'
require_relative 'features/models'
require_relative 'identities/models'
require_relative 'organisations/models'
require_relative 'projects/models'
require_relative 'segments/evaluator'
require_relative 'segments/models'
require_relative 'utils/hash_func'

module Flagsmith
  module Engine
    # Flags engine methods
    module Core
      include Flagsmith::Engine::Segments::Evaluator

      # rubocop:disable Metrics/CyclomaticComplexity
      def get_identity_feature_states_dict(environment, identity, override_traits = nil)
        # Get feature states from the environment
        feature_states = {}
        environment.feature_states.each do |fs|
          feature_states[fs.feature.id] = fs
        end

        # Override with any feature states defined by matching segments
        identity_segments = get_identity_segments(environment, identity, override_traits)
        identity_segments.each do |matching_segment|
          matching_segment.feature_states.each do |feature_state|
            if feature_states.key?(feature_state.feature.id) &&
               feature_states[feature_state.feature.id].is_higher_segment_priority(
                 feature_state
               )
              next
            end

            feature_states[feature_state.feature.id] = feature_state
          end
        end

        # Override with any feature states defined directly the identity
        identity.identity_features.each do |fs|
          feature_states[fs.feature.id] = fs if feature_states[fs.feature.id]
        end
        feature_states
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      def get_identity_feature_state(environment, identity, feature_name, override_traits = nil)
        feature_states = get_identity_feature_states_dict(environment, identity, override_traits).values

        feature_state = feature_states.find { |f| f.feature.name == feature_name }

        raise Flagsmith::FeatureStateNotFound, 'Feature State Not Found' if feature_state.nil?

        feature_state
      end

      def get_identity_feature_states(environment, identity, override_traits = nil)
        feature_states = get_identity_feature_states_dict(environment, identity, override_traits).values

        return feature_states.select(&:enabled?) if environment.project.hide_disabled_flags

        feature_states
      end

      def get_environment_feature_state(environment, feature_name)
        features_state = environment.feature_states.find { |f| f.feature.name == feature_name }

        raise Flagsmith::FeatureStateNotFound, 'Feature State Not Found' if features_state.nil?

        features_state
      end

      def get_environment_feature_states(environment)
        return environment.feature_states.select(&:enabled?) if environment.project.hide_disabled_flags

        environment.feature_states
      end
    end
  end
end
