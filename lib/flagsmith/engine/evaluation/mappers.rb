# frozen_string_literal: true

module Flagsmith
  module Engine
    module EvaluationContext
      module Mappers
        STRONGEST_PRIORITY = Float::INFINITY
        WEAKEST_PRIORITY = -Float::INFINITY

        # @param environment [Flagsmith::Engine::Environment] The environment model
        # @param identity [Flagsmith::Engine::Identity, nil] Optional identity model
        # @param override_traits [Array<Flagsmith::Engine::Identities::Trait>, nil] Optional override traits
        # @return [Hash] Evaluation context with environment, features, segments, and optionally identity
        def self.get_evaluation_context(environment, identity = nil, override_traits = nil)
          environment_context = map_environment_model_to_evaluation_context(environment)
          identity_context = identity ? map_identity_model_to_identity_context(identity, override_traits) : nil

          context = environment_context.dup
          context[:identity] = identity_context if identity_context

          context
        end

        # Maps environment model to evaluation context
        #
        # @param environment [Flagsmith::Engine::Environment] The environment model
        # @return [Hash] Context with :environment, :features, and :segments keys
        def self.map_environment_model_to_evaluation_context(environment)
          environment_context = {
            key: environment.api_key,
            name: environment.project.name
          }

          # Map feature states to features hash
          features = {}
          environment.feature_states.each do |fs|
            # Map multivariate values if present
            variants = nil
            if fs.multivariate_feature_state_values&.any?
              variants = fs.multivariate_feature_state_values.map do |mv|
                {
                  value: mv.multivariate_feature_option.value,
                  weight: mv.percentage_allocation,
                  priority: mv.id || uuid_to_big_int(mv.mv_fs_value_uuid)
                }
              end
            end

            feature_hash = {
              key: fs.django_id&.to_s || fs.uuid,
              feature_key: fs.feature.id.to_s,
              name: fs.feature.name,
              enabled: fs.enabled,
              value: fs.get_value
            }

            feature_hash[:variants] = variants if variants
            feature_hash[:priority] = fs.feature_segment.priority if fs.feature_segment&.priority
            feature_hash[:metadata] = { flagsmith_id: fs.feature.id }

            features[fs.feature.name] = feature_hash
          end

          # Map segments from project
          segments = {}
          environment.project.segments.each do |segment|
            overrides = segment.feature_states.map do |fs|
              override_hash = {
                key: fs.django_id&.to_s || fs.uuid,
                feature_key: fs.feature.id.to_s,
                name: fs.feature.name,
                enabled: fs.enabled,
                value: fs.get_value
              }
              override_hash[:priority] = fs.feature_segment.priority if fs.feature_segment&.priority
              override_hash[:metadata] = { flagsmith_id: fs.feature.id }
              override_hash
            end

            segments[segment.id.to_s] = {
              key: segment.id.to_s,
              name: segment.name,
              rules: segment.rules.map { |rule| map_segment_rule_model_to_rule(rule) },
              overrides: overrides,
              metadata: {
                source: 'API',
                flagsmith_id: segment.id
              }
            }
          end

          # Map identity overrides to segments
          if environment.identity_overrides&.any?
            identity_override_segments = map_identity_overrides_to_segments(environment.identity_overrides)
            segments.merge!(identity_override_segments)
          end

          {
            environment: environment_context,
            features: features,
            segments: segments
          }
        end

        def self.uuid_to_big_int(uuid)
          uuid.gsub('-', '').to_i(16)
        end

        # Maps identity model to identity context
        #
        # @param identity [Flagsmith::Engine::Identity] The identity model
        # @param override_traits [Array<Flagsmith::Engine::Identities::Trait>, nil] Optional override traits
        # @return [Hash] Identity context with :identifier, :key, and :traits
        def self.map_identity_model_to_identity_context(identity, override_traits = nil)
          # Use override traits if provided, otherwise use identity's traits
          traits = override_traits || identity.identity_traits

          # Map traits to a hash with trait key => trait value
          traits_hash = {}
          traits.each do |trait|
            traits_hash[trait.trait_key] = trait.trait_value
          end

          {
            identifier: identity.identifier,
            key: identity.django_id&.to_s || identity.composite_key,
            traits: traits_hash
          }
        end

        # Maps segment rule model to rule hash
        #
        # @param rule [Flagsmith::Engine::Segments::Rule] The segment rule model
        # @return [Hash] Mapped rule with :type, :conditions, and :rules
        def self.map_segment_rule_model_to_rule(rule)
          result = {
            type: rule.type
          }

          # Map conditions if present
          result[:conditions] = if rule.conditions&.any?
                                  rule.conditions.map do |condition|
                                    {
                                      property: condition.property,
                                      operator: condition.operator,
                                      value: condition.value
                                    }
                                  end
                                else
                                  []
                                end

          result[:rules] = if rule.rules&.any?
                             rule.rules.map { |nested_rule| map_segment_rule_model_to_rule(nested_rule) }
                           else
                             []
                           end

          result
        end

        # Maps identity overrides to segments
        #
        # @param identity_overrides [Array<Flagsmith::Engine::Identity>] Array of identity override models
        # @return [Hash] Segments hash for identity overrides
        def self.map_identity_overrides_to_segments(identity_overrides)
          segments = {}
          features_to_identifiers = {}

          identity_overrides.each do |identity|
            next if identity.identity_features.nil? || identity.identity_features.none?

            # Sort features by name for consistent hashing
            sorted_features = identity.identity_features.to_a.sort_by { |fs| fs.feature.name }

            # Create override keys for hashing
            overrides_key = sorted_features.map do |fs|
              {
                feature_key: fs.feature.id.to_s,
                name: fs.feature.name,
                enabled: fs.enabled,
                value: fs.get_value,
                priority: STRONGEST_PRIORITY,
                metadata: {
                  flagsmith_id: fs.feature.id
                }
              }
            end

            # Create hash of the overrides to group identities with same overrides
            overrides_hash = overrides_key.hash

            features_to_identifiers[overrides_hash] ||= { identifiers: [], overrides: overrides_key }
            features_to_identifiers[overrides_hash][:identifiers] << identity.identifier
          end

          # Create segments for each unique set of overrides
          features_to_identifiers.each do |overrides_hash, data|
            segment_key = "identity_override_#{overrides_hash}"

            segments[segment_key] = {
              key: segment_key,
              name: 'identity_override',
              rules: [
                {
                  type: 'ALL',
                  conditions: [
                    {
                      property: '$.identity.identifier',
                      operator: 'IN',
                      value: data[:identifiers]
                    }
                  ],
                  rules: []
                }
              ],
              metadata: {
                source: 'identity_override'
              },
              overrides: data[:overrides]
            }
          end

          segments
        end
      end
    end
  end
end
