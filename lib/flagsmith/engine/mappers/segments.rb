# frozen_string_literal: true

module Flagsmith
  module Engine
    module Mappers
      # Handles segment and rule mapping
      module Segments
        def self.build_segments_context(project_segments)
          segments = {}
          project_segments.each do |segment|
            segments[segment.id.to_s] = build_segment_hash(segment)
          end
          segments
        end

        def self.build_segment_hash(segment)
          {
            key: segment.id.to_s,
            name: segment.name,
            rules: segment.rules.map { |rule| map_rule(rule) },
            overrides: build_overrides(segment.feature_states),
            metadata: {
              source: 'API',
              id: segment.id
            }
          }
        end

        def self.build_overrides(feature_states) # rubocop:disable Metrics/MethodLength
          feature_states.map do |feature_state|
            override_hash = {
              key: feature_state.django_id&.to_s || feature_state.uuid,
              name: feature_state.feature.name,
              enabled: feature_state.enabled,
              value: feature_state.get_value,
              metadata: { id: feature_state.feature.id }
            }
            add_priority_to_override(override_hash, feature_state)
            override_hash
          end
        end

        def self.add_priority_to_override(override_hash, feature_state)
          return unless feature_state.feature_segment&.priority

          override_hash[:priority] = feature_state.feature_segment.priority
        end

        def self.map_rule(rule)
          {
            type: rule.type,
            conditions: map_conditions(rule.conditions),
            rules: (rule.rules || []).map { |nested_rule| map_rule(nested_rule) }
          }
        end

        def self.map_conditions(conditions)
          (conditions || []).map do |condition|
            { property: condition.property, operator: condition.operator, value: condition.value }
          end
        end
      end
    end
  end
end
