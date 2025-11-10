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
require_relative 'evaluation/mappers'

module Flagsmith
  # Core evaluation logic for feature flags
  module Engine
    extend self
    include Flagsmith::Engine::Utils::HashFunc
    include Flagsmith::Engine::Features::TargetingReasons
    include Flagsmith::Engine::Segments::Evaluator

    # Get evaluation result from evaluation context
    #
    # @param evaluation_context [Hash] The evaluation context
    # @return [Hash] Evaluation result with flags and segments
    # returns EvaluationResultWithMetadata
    def get_evaluation_result(evaluation_context)
      segments, segment_overrides = evaluate_segments(evaluation_context)
      flags = evaluate_features(evaluation_context, segment_overrides)
      {
        flags: flags,
        segments: segments
      }
    end

    # Returns { segments: EvaluationResultSegments; segmentOverrides: Record<string, SegmentOverride>; }
    def evaluate_segments(evaluation_context)
      return [], {} if evaluation_context[:segments].nil?

      identity_segments = get_segments_from_context(evaluation_context)

      segments = identity_segments.map do |segment|
        result = {
          name: segment[:name]
        }

        result[:metadata] = segment[:metadata] if segment[:metadata]

        result
      end

      segment_overrides = process_segment_overrides(identity_segments)

      [segments, segment_overrides]
    end

    # Returns Record<string: override.name, SegmentOverride>
    def process_segment_overrides(identity_segments)
      segment_overrides = {}

      identity_segments.each do |segment|
        next unless segment[:overrides]

        overrides_list = segment[:overrides].is_a?(Array) ? segment[:overrides] : []

        overrides_list.each do |override|
          next unless should_apply_override(override, segment_overrides)

          segment_overrides[override[:name]] = {
            feature: override,
            segment_name: segment[:name]
          }
        end
      end

      segment_overrides
    end

    # returns EvaluationResultFlags<Metadata>
    def evaluate_features(evaluation_context, segment_overrides)
      flags = {}

      (evaluation_context[:features] || {}).each_value do |feature|
        segment_override = segment_overrides[feature[:name]]
        final_feature = segment_override ? segment_override[:feature] : feature
        has_override = !segment_override.nil?

        # Evaluate feature value
        evaluated = evaluate_feature_value(final_feature, get_identity_key(evaluation_context))

        # Build flag result
        flag_result = {
          name: final_feature[:name],
          enabled: final_feature[:enabled],
          value: evaluated[:value]
        }

        # Add metadata if present
        flag_result[:metadata] = final_feature[:metadata] if final_feature[:metadata]

        # Set reason
        flag_result[:reason] = evaluated[:reason] ||
          (has_override ? "#{TARGETING_REASON_TARGETING_MATCH}; segment=#{segment_override[:segment_name]}" : TARGETING_REASON_DEFAULT)
        flags[final_feature[:name].to_sym] = flag_result
      end

      flags
    end

    # Returns {value: any; reason?: string}
    def evaluate_feature_value(feature, identity_key = nil)
      return get_multivariate_feature_value(feature, identity_key) if feature[:variants]&.any? && identity_key

      { value: feature[:value], reason: nil }
    end

    # Returns {value: any; reason?: string}
    def get_multivariate_feature_value(feature, identity_key)
      percentage_value = hashed_percentage_for_object_ids([feature[:key], identity_key])
      sorted_variants = (feature[:variants] || []).sort_by { |v| v[:priority] || WEAKEST_PRIORITY }

      start_percentage = 0
      sorted_variants.each do |variant|
        limit = start_percentage + variant[:weight]
        if start_percentage <= percentage_value && percentage_value < limit
          return {
            value: variant[:value],
            reason: "#{TARGETING_REASON_SPLIT}; weight=#{variant[:weight]}"
          }
        end
        start_percentage = limit
      end

      { value: feature[:value], reason: nil }
    end

    # returns boolean
    def should_apply_override(override, existing_overrides)
      current_override = existing_overrides[override[:name]]
      !current_override || is_stronger_priority?(override[:priority], current_override[:feature][:priority])
    end

    private

    # Extract identity key from evaluation context
    #
    # @param evaluation_context [Hash] The evaluation context
    # @return [String, nil] The identity key or nil if no identity
    def get_identity_key(evaluation_context)
      return nil unless evaluation_context[:identity]

      evaluation_context[:identity][:key] ||
        "#{evaluation_context[:environment][:key]}_#{evaluation_context[:identity][:identifier]}"
    end

    # returns boolean
    def is_stronger_priority?(priority_a, priority_b)
      (priority_a || WEAKEST_PRIORITY) < (priority_b || WEAKEST_PRIORITY)
    end
  end
end
