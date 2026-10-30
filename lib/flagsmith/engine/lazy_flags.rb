# frozen_string_literal: true

require 'set'

module Flagsmith
  module Engine
    # The `$.flags` of an evaluation context, resolving a flag the first time a segment condition reads it.
    #
    # Flags are only reachable by name: JSONPath reads them through `dig`.
    class LazyFlags
      # The evaluation context, with `$.flags` bound to this instance
      attr_reader :context

      # Incremented whenever a dependency cycle is cut. A segment whose evaluation increments it
      # read a flag that could not be resolved, so it must not match.
      attr_reader :cycle_hits

      def initialize(context)
        @context = context.merge(flags: self)
        @cycle_hits = 0
      end

      # @param feature_name [String]
      # @return [Hash, nil] The flag result, or nil for a feature absent from the context or in a cycle
      def dig(feature_name)
        start unless used?
        resolve(feature_name) unless @resolved.key?(feature_name)
        @resolved[feature_name]
      end

      # Whether a segment condition read any flag
      def used?
        !@resolved.nil?
      end

      # Applies the flags resolved for segment conditions over the single-pass flag results
      #
      # @param flags [Hash{Symbol => Hash}] The flag results, keyed by feature name
      def apply_to(flags)
        @resolved.each_value { |flag| flags[flag[:name].to_sym] = flag }
        @cyclic.each do |feature_name|
          flag = flags[feature_name.to_sym]
          flag[:reason] = Features::TargetingReasons::TARGETING_REASON_CIRCULAR_DEPENDENCY if flag
        end
      end

      private

      def start
        @resolved = {}
        @cyclic = Set.new
        @resolving = []
        @segment_matches = {}
        @segment_keys_by_feature_name = {}
        (@context[:segments] || {}).each do |segment_key, segment|
          Array(segment[:overrides]).each do |override|
            (@segment_keys_by_feature_name[override[:name]] ||= []) << segment_key
          end
        end
      end

      def resolve(feature_name) # rubocop:disable Metrics/MethodLength
        if @resolving.include?(feature_name)
          @cyclic.merge(@resolving[@resolving.index(feature_name)..])
          @cycle_hits += 1
          return
        end

        feature = find_feature(feature_name)
        return unless feature

        @resolving.push(feature_name)
        begin
          segment_override = find_segment_override(feature_name)
        ensure
          @resolving.pop
        end
        return if @cyclic.include?(feature_name)

        @resolved[feature_name] = Engine.get_feature_flag_result(
          feature, segment_override, @context.dig(:identity, :key), @segment_keys_by_feature_name
        )
      end

      def find_feature(feature_name)
        features = @context[:features]
        return nil unless features

        features[feature_name] || features[feature_name.to_sym]
      end

      def find_segment_override(feature_name)
        segment_override = nil
        @segment_keys_by_feature_name.fetch(feature_name, []).each do |segment_key|
          next unless segment_match?(segment_key)

          segment = @context[:segments][segment_key]
          segment[:overrides].each do |override|
            next unless override[:name] == feature_name && Engine.wins_over?(override, segment_override&.dig(:feature))

            segment_override = { feature: override, segment_name: segment[:name] }
          end
        end
        segment_override
      end

      def segment_match?(segment_key)
        return @segment_matches[segment_key] if @segment_matches.key?(segment_key)

        cycle_hits = @cycle_hits
        matches = Segments::Evaluator.context_in_segment?(@context, @context[:segments][segment_key])
        return false if @cycle_hits != cycle_hits # Rests on a flag that could not be resolved

        @segment_matches[segment_key] = matches
      end
    end
  end
end
