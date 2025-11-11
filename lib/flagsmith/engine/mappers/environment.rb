# frozen_string_literal: true

module Flagsmith
  module Engine
    module Mappers
      # Handles environment and feature mapping
      module Environment
        def self.build_environment_context(environment)
          {
            key: environment.api_key,
            name: environment.name
          }
        end

        def self.build_features_context(feature_states)
          features = {}
          feature_states.each do |feature_state|
            features[feature_state.feature.name] = build_feature_hash(feature_state)
          end
          features
        end

        def self.build_feature_hash(feature_state)
          feature_hash = {
            key: feature_state.django_id&.to_s || feature_state.uuid,
            name: feature_state.feature.name,
            enabled: feature_state.enabled,
            value: feature_state.get_value,
            metadata: { flagsmith_id: feature_state.feature.id }
          }
          add_variants_to_feature(feature_hash, feature_state)
          add_priority_to_feature(feature_hash, feature_state)
          feature_hash
        end

        def self.add_variants_to_feature(feature_hash, feature_state)
          return unless feature_state.multivariate_feature_state_values&.any?

          feature_hash[:variants] = feature_state.multivariate_feature_state_values.map do |mv|
            {
              value: mv.multivariate_feature_option.value,
              weight: mv.percentage_allocation,
              priority: mv.id || uuid_to_big_int(mv.mv_fs_value_uuid)
            }
          end
        end

        def self.uuid_to_big_int(uuid)
          uuid.gsub('-', '').to_i(16)
        end

        def self.add_priority_to_feature(feature_hash, feature_state)
          priority = feature_state.feature_segment&.priority
          feature_hash[:priority] = priority unless priority.nil?
        end
      end
    end
  end
end
