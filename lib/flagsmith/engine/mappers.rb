# frozen_string_literal: true

require_relative 'mappers/environment'
require_relative 'mappers/identity'
require_relative 'mappers/segments'

module Flagsmith
  module Engine
    # Mappers for converting between models and evaluation contexts
    module Mappers
      STRONGEST_PRIORITY = Float::INFINITY
      WEAKEST_PRIORITY = -Float::INFINITY

      # Condition properties resolvable without an identity
      IDENTITY_FREE_PROPERTY_PREFIXES = ['$.environment.', '$.environment[', '$.flags.', '$.flags['].freeze

      # @param environment [Flagsmith::Engine::Environment] The environment model
      # @param identity [Flagsmith::Engine::Identity, nil] Optional identity model
      # @param override_traits [Array<Flagsmith::Engine::Identities::Trait>, nil] Optional override traits
      # @return [Hash] Evaluation context with environment, features, segments, and optionally identity
      def self.get_evaluation_context(environment, identity = nil, override_traits = nil)
        context = map_environment_model_to_evaluation_context(environment)
        context[:identity] = map_identity_model_to_identity_context(identity, override_traits) if identity
        context
      end

      # Maps environment model to evaluation context
      #
      # @param environment [Flagsmith::Engine::Environment] The environment model
      # @return [Hash] Context with :environment, :features, and :segments keys
      def self.map_environment_model_to_evaluation_context(environment)
        context = {
          environment: Environment.build_environment_context(environment),
          features: Environment.build_features_context(environment.feature_states),
          segments: Segments.build_segments_context(environment.project.segments)
        }

        context[:segments].merge!(Identity.map_overrides_to_segments(environment.identity_overrides)) if environment.identity_overrides&.any?

        context
      end

      # Maps environment model to an evaluation context for flags served without an identity
      #
      # @param environment [Flagsmith::Engine::Environment] The environment model
      # @return [Hash] Context with :environment, :features, and the :segments not needing an identity
      def self.get_environment_flags_evaluation_context(environment)
        {
          environment: Environment.build_environment_context(environment),
          features: Environment.build_features_context(environment.feature_states),
          segments: select_identity_free_segments(Segments.build_segments_context(environment.project.segments))
        }
      end

      # Selects the segments that can be evaluated without an identity, i.e. reading neither identity nor traits
      #
      # @param segments [Hash] Segments context, keyed by segment key
      # @return [Hash] Segments context without the segments needing an identity
      def self.select_identity_free_segments(segments)
        segments.select { |_, segment| identity_free_rules?(segment[:rules]) }
      end

      def self.identity_free_rules?(rules)
        Array(rules).all? do |rule|
          Array(rule[:conditions]).all? { |condition| condition[:property].to_s.start_with?(*IDENTITY_FREE_PROPERTY_PREFIXES) } &&
            identity_free_rules?(rule[:rules])
        end
      end
      private_class_method :identity_free_rules?

      # Maps identity model to identity context
      #
      # @param identity [Flagsmith::Engine::Identity] The identity model
      # @param override_traits [Array<Flagsmith::Engine::Identities::Trait>, nil] Optional override traits
      # @return [Hash] Identity context with :identifier, :key, and :traits
      def self.map_identity_model_to_identity_context(identity, override_traits = nil)
        Identity.build_identity_context(identity, override_traits)
      end

      # Maps segment rule model to rule hash
      #
      # @param rule [Flagsmith::Engine::Segments::Rule] The segment rule model
      # @return [Hash] Mapped rule with :type, :conditions, and :rules
      def self.map_segment_rule_model_to_rule(rule)
        Segments.map_rule(rule)
      end

      # Maps identity overrides to segments
      #
      # @param identity_overrides [Array<Flagsmith::Engine::Identity>] Array of identity override models
      # @return [Hash] Segments hash for identity overrides
      def self.map_identity_overrides_to_segments(identity_overrides)
        Identity.map_overrides_to_segments(identity_overrides)
      end
    end
  end
end
