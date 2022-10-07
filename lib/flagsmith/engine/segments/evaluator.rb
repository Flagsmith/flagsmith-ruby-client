# frozen_string_literal: true

require_relative 'constants'
require_relative '../utils/hash_func'

module Flagsmith
  module Engine
    module Segments
      # Evaluator methods
      module Evaluator
        include Flagsmith::Engine::Segments::Constants
        include Flagsmith::Engine::Utils::HashFunc

        def get_identity_segments(environment, identity, override_traits = nil)
          environment.project.segments.select do |s|
            evaluate_identity_in_segment(identity, s, override_traits)
          end
        end

        # Evaluates whether a given identity is in the provided segment.
        #
        # :param identity: identity model object to evaluate
        # :param segment: segment model object to evaluate
        # :param override_traits: pass in a list of traits to use instead of those on the
        #     identity model itself
        # :return: True if the identity is in the segment, False otherwise
        def evaluate_identity_in_segment(identity, segment, override_traits = nil)
          segment.rules&.length&.positive? &&
            segment.rules.all? do |rule|
              traits_match_segment_rule(
                override_traits || identity.identity_traits,
                rule,
                segment.id,
                identity.django_id || identity.composite_key
              )
            end
        end

        def traits_match_segment_rule(identity_traits, rule, segment_id, identity_id)
          matching_block = lambda { |condition|
            traits_match_segment_condition(identity_traits, condition, segment_id, identity_id)
          }

          matches_conditions =
            if rule.conditions&.length&.positive?
              rule.conditions.send(rule.matching_function, &matching_block)
            else true
            end

          matches_conditions &&
            rule.rules.all? { |r| traits_match_segment_rule(identity_traits, r, segment_id, identity_id) }
        end

        def traits_match_segment_condition(identity_traits, condition, segment_id, identity_id)
          if condition.operator == PERCENTAGE_SPLIT
            return hashed_percentage_for_object_ids([segment_id, identity_id]) <= condition.value.to_f
          end

          trait = identity_traits.find { |t| t.key.to_s == condition.property }

          if [IS_SET, IS_NOT_SET].include?(condition.operator)
            return handle_trait_existence_conditions(trait, condition.operator)
          end

          return condition.match_trait_value?(trait.trait_value) if trait

          false
        end

        private

        def handle_trait_existence_conditions(matching_trait, operator)
          return operator == IS_NOT_SET if matching_trait.nil?

          operator == IS_SET
        end
      end
    end
  end
end
