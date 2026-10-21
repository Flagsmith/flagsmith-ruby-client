# frozen_string_literal: true

require 'semantic'
require 'securerandom'

require_relative 'environments/models'
require_relative 'features/models'
require_relative 'features/constants'
require_relative 'identities/models'
require_relative 'organisations/models'
require_relative 'projects/models'
require_relative 'segments/evaluator'
require_relative 'segments/models'
require_relative 'utils/hash_func'
require_relative 'mappers'
require_relative 'flag_dependencies'

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
      evaluation_context = get_enriched_context(evaluation_context)
      resolved_flags = LazyFlags.new
      evaluation_context = evaluation_context.merge(flags: resolved_flags)
      resolved_flags.bind(evaluation_context)

      segments, segment_overrides = evaluate_segments(evaluation_context, resolved_flags)
      flags = evaluate_features(evaluation_context, segment_overrides)
      apply_resolved_flags(flags, resolved_flags) if resolved_flags.used?
      { flags: flags, segments: segments }
    end

    # Returns { segments: EvaluationResultSegments; segmentOverrides: Record<string, SegmentOverride>; }
    def evaluate_segments(evaluation_context, resolved_flags)
      return [], {} if evaluation_context[:segments].nil?

      matched_segments = evaluation_context[:segments].values.select { |segment| resolved_flags.segment_matches?(segment) }

      segments = matched_segments.map do |segment|
        { name: segment[:name], metadata: segment[:metadata] }.compact
      end

      segment_overrides = process_segment_overrides(matched_segments)

      [segments, segment_overrides]
    end

    # Returns Record<string: override.name, SegmentOverride>
    def process_segment_overrides(identity_segments) # rubocop:disable Metrics/MethodLength
      segment_overrides = {}

      identity_segments.each do |segment|
        Array(segment[:overrides]).each do |override|
          next unless should_apply_override(override, segment_overrides)

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
        segment_override = segment_overrides[feature[:name]]
        final_feature = segment_override ? segment_override[:feature] : feature
        reason = segment_override ? get_targeting_match_reason(segment_override) : get_fallback_reason(feature[:name], targeted_feature_names)

        flags[final_feature[:name].to_sym] = get_flag_result(final_feature, identity_key, reason)
      end
    end

    # Returns {name: string; enabled: boolean; value: any; reason: string; variant?: string; metadata?: any}
    def get_flag_result(feature, identity_key, reason)
      value = feature[:value]
      variant = nil

      if identity_key && feature[:variants]&.any?
        variant = 'control'
        matching_variant = get_multivariate_feature_value(feature, identity_key)
        value, variant, reason = matching_variant.values_at(:value, :variant, :reason) if matching_variant
      end

      flag_result = { name: feature[:name], enabled: feature[:enabled], value: value, reason: reason, variant: variant }
      flag_result[:metadata] = feature[:metadata] if feature[:metadata]
      flag_result
    end

    # Returns {value: any; variant?: string; reason: string} or nil
    def get_multivariate_feature_value(feature, identity_key)
      percentage_value = hashed_percentage_for_object_ids([feature[:key], identity_key])
      sorted_variants = (feature[:variants] || []).sort_by { |v| v[:priority] || WEAKEST_PRIORITY }

      find_matching_variant(sorted_variants, percentage_value)
    end

    def find_matching_variant(sorted_variants, percentage_value)
      start_percentage = 0
      sorted_variants.each do |variant|
        limit = start_percentage + variant[:weight]
        if start_percentage <= percentage_value && percentage_value < limit
          return { value: variant[:value], variant: variant[:key], reason: "#{TARGETING_REASON_SPLIT}; weight=#{variant[:weight]}" }
        end

        start_percentage = limit
      end
      nil
    end

    # Returns the names of the features overridden by at least one segment
    def get_targeted_feature_names(evaluation_context)
      names = {}
      evaluation_context[:segments]&.each_value do |segment|
        segment[:overrides]&.each { |override| names[override[:name]] = true }
      end
      names
    end

    # Returns DEFAULT for a feature whose segment overrides did not match, STATIC for a feature without any
    def get_fallback_reason(feature_name, targeted_feature_names)
      targeted_feature_names.key?(feature_name) ? TARGETING_REASON_DEFAULT : TARGETING_REASON_STATIC
    end

    def get_targeting_match_reason(segment_override)
      "#{TARGETING_REASON_TARGETING_MATCH}; segment=#{segment_override[:segment_name]}"
    end

    # returns boolean
    def should_apply_override(override, existing_overrides)
      current_override = existing_overrides[override[:name]]
      !current_override || stronger_priority?(override[:priority], current_override[:feature][:priority])
    end

    def stronger_priority?(priority_a, priority_b)
      (priority_a || WEAKEST_PRIORITY) < (priority_b || WEAKEST_PRIORITY)
    end

    private

    # Flags resolved while evaluating segment conditions take precedence, as they were resolved with the cycle guard
    def apply_resolved_flags(flags, resolved_flags)
      resolved_flags.each { |feature_name, flag_result| flags[feature_name] = flag_result }
      resolved_flags.cyclic_feature_names.each do |feature_name|
        flags[feature_name] = flags[feature_name].merge(reason: TARGETING_REASON_CIRCULAR_DEPENDENCY) if flags.key?(feature_name)
      end
    end

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
