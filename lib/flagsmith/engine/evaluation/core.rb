# frozen_string_literal: true

module Flagsmith
  module Engine
    module Evaluation
      # Core evaluation logic module
      module Core
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
            segments: segments,
          }
        end

        # Returns { segments: EvaluationResultSegments; segmentOverrides: Record<string, SegmentOverride>; }
        def evaluate_segments(evaluation_context)
          if evaluation_context.identities.nil? || evaluation_context.segments.nil?
            return [], {}
          end
          segments = []
          segment_overrides = process_segment_overrides(evaluation_context.identities)
          return segments, segment_overrides
        end

        # Returns Record<string: override.name, SegmentOverride>
        def process_segment_overrides(_identity_segments)
          segment_overrides = {}
          return segment_overrides
        end

        # returns EvaluationResultFlags<Metadata>
        def evaluate_features(evaluation_context, _segment_overrides)
          raise NotImplementedError
        end

        # Returns {value: any; reason?: string}
        def evaluate_feature_value(_feature, _identity_key)
          raise NotImplementedError
        end

        # Returns {value: any; reason?: string}
        def get_multivariate_feature_value(_feature, _identity_key)
          raise NotImplementedError
        end

        # returns boolean
        def should_apply_override(_override, _existing_overrides)
          raise NotImplementedError
        end

        private

        # returns boolean
        def higher_priority?(priority_a, priority_b)
          (priority_a || Float::INFINITY) < (priority_b || Float::INFINITY)
        end

        def get_targeting_match_reason(match_object)
          type = match_object.type

          if type == 'SEGMENT'
            return match_object.override ? "TARGETING_MATCH; segment=#{match_object.override.segment_name}" : 'DEFAULT'
          end

          return "SPLIT; weight=#{match_object.weight}" if type == 'SPLIT'

          'DEFAULT'
        end
      end
    end
  end
end
