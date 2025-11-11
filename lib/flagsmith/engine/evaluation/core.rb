# frozen_string_literal: true

require_relative '../utils/hash_func'
require_relative '../features/constants'
require_relative '../segments/evaluator'

module Flagsmith
  module Engine
    module Evaluation
      # Core evaluation logic for feature flags
      module Core
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
          evaluation_context = get_enriched_context(evaluation_context)
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
            { name: segment[:name], metadata: segment[:metadata] }.compact
          end

          segment_overrides = process_segment_overrides(identity_segments)

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

        # returns EvaluationResultFlags<Metadata>
        def evaluate_features(evaluation_context, segment_overrides)
          identity_key = get_identity_key(evaluation_context)

          (evaluation_context[:features] || {}).each_with_object({}) do |(_, feature), flags|
            segment_override = segment_overrides[feature[:name]]
            final_feature = segment_override ? segment_override[:feature] : feature

            flag_result = build_flag_result(final_feature, identity_key, segment_override)
            flags[final_feature[:name].to_sym] = flag_result
          end
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

          variant = find_matching_variant(sorted_variants, percentage_value)
          variant || { value: feature[:value], reason: nil }
        end

        def find_matching_variant(sorted_variants, percentage_value)
          start_percentage = 0
          sorted_variants.each do |variant|
            limit = start_percentage + variant[:weight]
            return { value: variant[:value], reason: "#{TARGETING_REASON_SPLIT}; weight=#{variant[:weight]}" } if start_percentage <= percentage_value && percentage_value < limit

            start_percentage = limit
          end
          nil
        end

        # returns boolean
        def should_apply_override(override, existing_overrides)
          current_override = existing_overrides[override[:name]]
          !current_override || stronger_priority?(override[:priority], current_override[:feature][:priority])
        end

        private

        def build_flag_result(feature, identity_key, segment_override)
          evaluated = evaluate_feature_value(feature, identity_key)

          flag_result = {
            name: feature[:name],
            enabled: feature[:enabled],
            value: evaluated[:value],
            reason: evaluated[:reason] || (segment_override ? "#{TARGETING_REASON_TARGETING_MATCH}; segment=#{segment_override[:segment_name]}" : TARGETING_REASON_DEFAULT)
          }

          flag_result[:metadata] = feature[:metadata] if feature[:metadata]
          flag_result
        end

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
        def stronger_priority?(priority_a, priority_b)
          (priority_a || WEAKEST_PRIORITY) < (priority_b || WEAKEST_PRIORITY)
        end
      end
    end
  end
end
