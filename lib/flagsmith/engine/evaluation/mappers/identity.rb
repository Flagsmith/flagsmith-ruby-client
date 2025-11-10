# frozen_string_literal: true

module Flagsmith
  module Engine
    module Evaluation
      module Mappers
        # Handles identity and override mapping
        module Identity
          def self.build_environment_context(identity, override_traits = nil)
            traits = override_traits || identity.identity_traits

            {
              identifier: identity.identifier,
              key: identity.django_id&.to_s || identity.composite_key,
              traits: build_traits_hash(traits)
            }
          end

          def self.build_traits_hash(traits)
            traits_hash = {}
            traits.each do |trait|
              traits_hash[trait.trait_key] = trait.trait_value
            end
            traits_hash
          end

          def self.map_overrides_to_segments(identity_overrides)
            features_to_identifiers = group_by_overrides(identity_overrides)
            build_segments(features_to_identifiers)
          end

          def self.group_by_overrides(identity_overrides)
            features_to_identifiers = {}

            identity_overrides.each do |identity|
              next if identity.identity_features.nil? || identity.identity_features.none?

              overrides_key = build_overrides_key(identity.identity_features)
              overrides_hash = overrides_key.hash

              features_to_identifiers[overrides_hash] ||= { identifiers: [], overrides: overrides_key }
              features_to_identifiers[overrides_hash][:identifiers] << identity.identifier
            end

            features_to_identifiers
          end

          def self.build_overrides_key(identity_features) # rubocop:disable Metrics/MethodLength
            sorted_features = identity_features.to_a.sort_by { |fs| fs.feature.name }
            sorted_features.map do |feature_state|
              {
                feature_key: feature_state.feature.id.to_s,
                name: feature_state.feature.name,
                enabled: feature_state.enabled,
                value: feature_state.get_value,
                priority: Mappers::STRONGEST_PRIORITY,
                metadata: { flagsmith_id: feature_state.feature.id }
              }
            end
          end

          def self.build_segments(features_to_identifiers)
            segments = {}

            features_to_identifiers.each do |overrides_hash, data|
              segment_key = "identity_override_#{overrides_hash}"
              segments[segment_key] = build_segment(segment_key, data)
            end

            segments
          end

          def self.build_segment(segment_key, data)
            {
              key: segment_key,
              name: 'identity_override',
              rules: [build_rule(data[:identifiers])],
              metadata: { source: 'identity_override' },
              overrides: data[:overrides]
            }
          end

          def self.build_rule(identifiers) # rubocop:disable Metrics/MethodLength
            {
              type: 'ALL',
              conditions: [
                {
                  property: '$.identity.identifier',
                  operator: 'IN',
                  value: identifiers
                }
              ],
              rules: []
            }
          end
        end
      end
    end
  end
end
