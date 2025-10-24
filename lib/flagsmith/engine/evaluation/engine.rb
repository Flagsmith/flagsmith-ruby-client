# frozen_string_literal: true

module Flagsmith
  module Engine
    module Evaluation
      class Engine
        # returns EvaluationResultWithMetadata
        def get_evaluation_result(_evaluation_context)
          {
            flags: {},
            segments: []
          }
        end

        # Returns { segments: EvaluationResultSegments; segmentOverrides: Record<string, SegmentOverride>; }
        def evaluate_segments(evaluation_context); end

        # Returns Record<string: override.nae, SegmentOverride>
        def process_segment_overrides(identity_segments); end

        # returns EvaluationResultFlags<Metadata>
        def evalute_features(evaluation_context, segment_overrides); end

        # Returns {value: any; reason?: string}
        def evaluate_feature_value(feature, identity_key); end

        # Returns {value: any; reason?: string}
        def get_multivariate_feature_value(feature, identity_key); end

        # returns boolean
        def should_apply_override(override, existing_overrides); end

        private

        # returns boolean
        def higher_priority?(priority_a, priority_b)
          priority_a || priority_b > Float::INFINITY || Float::INFINITY
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
