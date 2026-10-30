# frozen_string_literal: true

require 'semantic'
require 'securerandom'
require 'set'

require_relative 'environments/models'
require_relative 'features/models'
require_relative 'features/constants'
require_relative 'identities/models'
require_relative 'lazy_flags'
require_relative 'organisations/models'
require_relative 'projects/models'
require_relative 'segments/evaluator'
require_relative 'segments/models'
require_relative 'utils/hash_func'
require_relative 'mappers'

module Flagsmith
  # Core evaluation logic for feature flags
  module Engine # rubocop:disable Metrics/ModuleLength
    extend self
    include Flagsmith::Engine::Utils::HashFunc
    include Flagsmith::Engine::Features::TargetingReasons
    include Flagsmith::Engine::Segments::Evaluator

    # Get evaluation result from evaluation context
    #
    # @param evaluation_context [Hash] The evaluation context
    # @return [Hash] Evaluation result with flags and segments
    def get_evaluation_result(evaluation_context)
      lazy_flags = LazyFlags.new(get_enriched_context(evaluation_context))
      evaluation_context = lazy_flags.context
      segments, segment_overrides = evaluate_segments(evaluation_context, lazy_flags)
      flags = evaluate_features(evaluation_context, segment_overrides)
      lazy_flags.apply_to(flags) if lazy_flags.used?
      {
        flags: flags,
        segments: segments
      }
    end

    # Returns { segments: EvaluationResultSegments; segmentOverrides: Record<string, SegmentOverride>; }
    def evaluate_segments(evaluation_context, lazy_flags)
      return [], {} if evaluation_context[:segments].nil?

      matching_segments = evaluation_context[:segments].each_value.select do |segment|
        cycle_hits = lazy_flags.cycle_hits
        context_in_segment?(evaluation_context, segment) && lazy_flags.cycle_hits == cycle_hits
      end

      segments = matching_segments.map do |segment|
        { name: segment[:name], metadata: segment[:metadata] }.compact
      end

      segment_overrides = process_segment_overrides(matching_segments)

      [segments, segment_overrides]
    end

    # Returns Record<string: override.name, SegmentOverride>
    def process_segment_overrides(matching_segments) # rubocop:disable Metrics/MethodLength
      segment_overrides = {}

      matching_segments.each do |segment|
        Array(segment[:overrides]).each do |override|
          next unless wins_over?(override, segment_overrides[override[:name]]&.dig(:feature))

          segment_overrides[override[:name]] = {
            feature: override,
            segment_name: segment[:name]
          }
        end
      end

      segment_overrides
    end

    def evaluate_features(evaluation_context, segment_overrides)
      identity_key = get_identity_key(evaluation_context)
      targeted_feature_names = get_targeted_feature_names(evaluation_context)

      (evaluation_context[:features] || {}).each_with_object({}) do |(_, feature), flags|
        flags[feature[:name].to_sym] =
          get_feature_flag_result(feature, segment_overrides[feature[:name]], identity_key, targeted_feature_names)
      end
    end

    # Returns the flag result of a feature, served by its segment override if any, or else by its environment default
    def get_feature_flag_result(feature, segment_override, identity_key, targeted_feature_names)
      return get_flag_result(segment_override[:feature], identity_key, targeting_match_reason(segment_override)) if segment_override

      get_flag_result(feature, identity_key, fallback_reason(feature[:name], targeted_feature_names))
    end

    # Returns the names of the features overridden by at least one segment
    def get_targeted_feature_names(evaluation_context)
      names = {}
      evaluation_context[:segments]&.each_value do |segment|
        segment[:overrides]&.each { |override| names[override[:name]] = true }
      end
      names
    end

    # Returns the reason for a flag served by a segment override
    def targeting_match_reason(segment_override)
      "#{TARGETING_REASON_TARGETING_MATCH}; segment=#{segment_override[:segment_name]}"
    end

    # Returns the reason for a flag served by its environment default:
    # DEFAULT if the feature has segment overrides that did not match, STATIC if it has none
    def fallback_reason(feature_name, targeted_feature_names)
      targeted_feature_names.key?(feature_name) ? TARGETING_REASON_DEFAULT : TARGETING_REASON_STATIC
    end

    # Returns {name: string; enabled: boolean; value: any; reason: string; variant?: string; metadata?: any}
    def get_flag_result(feature, identity_key, reason)
      evaluated = evaluate_feature_value(feature, identity_key)

      flag_result = {
        name: feature[:name],
        enabled: feature[:enabled],
        value: evaluated[:value],
        reason: evaluated[:reason] || reason,
        variant: evaluated[:variant]
      }

      flag_result[:metadata] = feature[:metadata] if feature[:metadata]
      flag_result
    end

    # Returns {value: any; reason?: string; variant?: string}
    def evaluate_feature_value(feature, identity_key = nil)
      return get_multivariate_feature_value(feature, identity_key) if feature[:variants]&.any? && identity_key

      { value: feature[:value], reason: nil, variant: nil }
    end

    # Returns {value: any; reason?: string; variant: string}
    def get_multivariate_feature_value(feature, identity_key)
      percentage_value = hashed_percentage_for_object_ids([feature[:key], identity_key])
      sorted_variants = (feature[:variants] || []).sort_by { |v| v[:priority] || DEFAULT_PRIORITY }

      variant = find_matching_variant(sorted_variants, percentage_value)
      variant || { value: feature[:value], reason: nil, variant: 'control' }
    end

    def find_matching_variant(sorted_variants, percentage_value)
      start_percentage = 0
      sorted_variants.each do |variant|
        limit = start_percentage + variant[:weight]
        if start_percentage <= percentage_value && percentage_value < limit
          return { value: variant[:value], reason: "#{TARGETING_REASON_SPLIT}; weight=#{variant[:weight]}", variant: variant[:key] }
        end

        start_percentage = limit
      end
      nil
    end

    # Whether a segment override takes precedence over the one held so far.
    # The lowest priority wins, and the first seen wins a tie.
    def wins_over?(candidate, incumbent)
      incumbent.nil? || (candidate[:priority] || DEFAULT_PRIORITY) < (incumbent[:priority] || DEFAULT_PRIORITY)
    end

    private

    # Extract identity key from evaluation context
    #
    # @param evaluation_context [Hash] The evaluation context
    # @return [String, nil] The identity key or nil if no identity
    def get_identity_key(evaluation_context)
      return nil unless evaluation_context[:identity]

      evaluation_context[:identity][:key]
    end
  end
end
