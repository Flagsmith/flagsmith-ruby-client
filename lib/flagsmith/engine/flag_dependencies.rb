# frozen_string_literal: true

require 'set'

module Flagsmith
  module Engine
    # The `$.flags` mapping of an evaluation context, resolving a flag when a segment condition first reads it.
    class LazyFlags < Hash
      # Names of the flags found to be in a dependency cycle.
      attr_reader :cyclic_feature_names

      # Incremented whenever a cycle is cut, so a segment evaluated meanwhile is known to rest on an unresolved flag.
      attr_accessor :cycle_hits

      def initialize
        super() { |_, feature_name| resolve(feature_name) }
        @cyclic_feature_names = Set.new
        @cycle_hits = 0
        @used = false
      end

      def bind(context)
        @context = context
      end

      # Whether a segment condition has read a flag.
      def used?
        @used
      end

      def key?(feature_name)
        !self[feature_name].nil?
      end

      private

      def resolve(feature_name)
        @used = true
        resolver.resolve_feature(feature_name)
        fetch(feature_name, nil)
      end

      def resolver
        @resolver ||= DependencyResolver.new(@context, self)
      end
    end

    # Resolves the flags of a context whose segments depend on other flags, memoising segment verdicts.
    class DependencyResolver
      include Flagsmith::Engine::Features::TargetingReasons

      def initialize(context, flags)
        @context = context
        @flags = flags
        @segments = context[:segments] || {}
        @features_by_name = (context[:features] || {}).values.to_h { |feature| [feature[:name].to_sym, feature] }
        @segment_keys_by_feature_name = segment_keys_by_feature_name
        @segment_matches = {}
        @resolving = []
      end

      def resolve_feature(feature_name)
        return cut_cycle(feature_name) if @resolving.include?(feature_name)

        feature = @features_by_name[feature_name]
        return unless feature

        segment_override = resolve_segment_override(feature_name)
        return if @flags.cyclic_feature_names.include?(feature_name)

        @flags.store(feature_name, flag_result(feature_name, feature, segment_override))
      end

      private

      def cut_cycle(feature_name)
        @flags.cyclic_feature_names.merge(@resolving.drop(@resolving.index(feature_name)))
        @flags.cycle_hits += 1
      end

      def resolve_segment_override(feature_name)
        @resolving.push(feature_name)
        find_segment_override(feature_name)
      ensure
        @resolving.pop # A raise swallowed by JSONPath evaluation must not leave the name looking like a cycle
      end

      def find_segment_override(feature_name)
        matching_segment_overrides(feature_name).reduce(nil) do |winner, candidate|
          next candidate if winner.nil? || Flagsmith::Engine.stronger_priority?(candidate[:feature][:priority], winner[:feature][:priority])

          winner
        end
      end

      def matching_segment_overrides(feature_name)
        @segment_keys_by_feature_name.fetch(feature_name, []).flat_map do |segment_key|
          next [] unless segment_matches?(segment_key)

          segment = @segments[segment_key]
          Array(segment[:overrides])
            .select { |override| override[:name].to_sym == feature_name }
            .map { |override| { feature: override, segment_name: segment[:name] } }
        end
      end

      def segment_matches?(segment_key)
        return @segment_matches[segment_key] if @segment_matches.key?(segment_key)

        cycle_hits = @flags.cycle_hits
        matches = Flagsmith::Engine::Segments::Evaluator.context_in_segment?(@context, @segments[segment_key])
        return false if @flags.cycle_hits != cycle_hits

        @segment_matches[segment_key] = matches
      end

      def flag_result(feature_name, feature, segment_override)
        identity_key = @context.dig(:identity, :key)
        return Flagsmith::Engine.get_flag_result(feature, identity_key, fallback_reason(feature_name)) unless segment_override

        Flagsmith::Engine.get_flag_result(segment_override[:feature], identity_key, Flagsmith::Engine.get_targeting_match_reason(segment_override))
      end

      def fallback_reason(feature_name)
        @segment_keys_by_feature_name.key?(feature_name) ? TARGETING_REASON_DEFAULT : TARGETING_REASON_STATIC
      end

      def segment_keys_by_feature_name
        @segments.each_with_object({}) do |(segment_key, segment), keys_by_name|
          Array(segment[:overrides]).each do |override|
            (keys_by_name[override[:name].to_sym] ||= []) << segment_key
          end
        end
      end
    end
  end
end
