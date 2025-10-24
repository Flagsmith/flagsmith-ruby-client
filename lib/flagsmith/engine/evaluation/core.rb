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
          if evaluation_context[:identity].nil? || evaluation_context[:segments].nil?
            return [], {}
          end

          identity_segments = [] # To be getIdentitySegments when implemented

          segments = identity_segments.map do |segment|
            result = {
              key: segment[:key],
              name: segment[:name]
            }

            if segment[:metadata]
              result[:metadata] = segment[:metadata].dup
            end

            result
          end

          segment_overrides = process_segment_overrides(identity_segments)

          return segments, segment_overrides
        end

        # Returns Record<string: override.name, SegmentOverride>
        def process_segment_overrides(identity_segments)
          segment_overrides = {}

          identity_segments.each do |segment|
            next unless segment[:overrides]

            overrides_list = segment[:overrides].is_a?(Array) ? segment[:overrides] : []

            overrides_list.each do |override|
              if should_apply_override(override, segment_overrides)
                segment_overrides[override[:name]] = {
                  feature: override,
                  segment_name: segment[:name]
                }
              end
            end
          end

          segment_overrides
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
        def should_apply_override(override, existing_overrides)
          current_override = existing_overrides[override[:name]]
          !current_override || higher_priority?(override[:priority], current_override[:feature][:priority])
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
