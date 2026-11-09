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

        def self.build_overrides(feature_states)
          feature_states.map { |feature_state| Environment.build_feature_hash(feature_state) }
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
