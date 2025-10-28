# frozen_string_literal: true

require 'json'
require 'jsonpath'
require_relative 'constants'
require_relative 'models'
require_relative '../utils/hash_func'

module Flagsmith
  module Engine
    module Segments
      # Evaluator methods
      module Evaluator
        extend self
        include Flagsmith::Engine::Segments::Constants
        include Flagsmith::Engine::Utils::HashFunc

        # Context-based segment evaluation
        # Returns all segments that the identity belongs to based on segment rules evaluation
        #
        # @param context [Hash] Evaluation context containing identity and segment definitions
        # @return [Array<Hash>] Array of segments that the identity matches
        def get_identity_segments(context)
          return [] unless context[:identity] && context[:segments]

          matching_segments = context[:segments].values.select do |segment|
            next false if segment[:rules].nil? || segment[:rules].empty?

            matches = segment[:rules].all? { |rule| traits_match_segment_rule_from_context(rule, segment[:key], context) }
            matches
          end

          matching_segments
        end

        # Context-based helper functions

        # Evaluates whether a segment rule matches using context
        #
        # @param rule [Hash] The rule to evaluate
        # @param segment_key [String] The segment key (used for percentage split)
        # @param context [Hash] The evaluation context
        # @return [Boolean] True if the rule matches
        def traits_match_segment_rule_from_context(rule, segment_key, context)
          matches_conditions = evaluate_conditions_from_context(rule, segment_key, context)
          matches_sub_rules = evaluate_sub_rules_from_context(rule, segment_key, context)

          matches_conditions && matches_sub_rules
        end

        # Evaluates rule conditions based on rule type (ALL/ANY/NONE)
        #
        # @param rule [Hash] The rule containing conditions and type
        # @param segment_key [String] The segment key
        # @param context [Hash] The evaluation context
        # @return [Boolean] True if conditions match according to rule type
        def evaluate_conditions_from_context(rule, segment_key, context)
          return true if rule[:conditions].nil? || rule[:conditions].empty?

          condition_results = rule[:conditions].map do |condition|
            traits_match_segment_condition_from_context(condition, segment_key, context)
          end

          evaluate_rule_conditions(rule[:type], condition_results)
        end

        # Evaluates nested sub-rules
        #
        # @param rule [Hash] The rule containing nested rules
        # @param segment_key [String] The segment key
        # @param context [Hash] The evaluation context
        # @return [Boolean] True if all sub-rules match
        def evaluate_sub_rules_from_context(rule, segment_key, context)
          return true if rule[:rules].nil? || rule[:rules].empty?

          rule[:rules].all? do |sub_rule|
            traits_match_segment_rule_from_context(sub_rule, segment_key, context)
          end
        end

        # Evaluates a single segment condition using context
        #
        # @param condition [Hash] The condition to evaluate
        # @param segment_key [String] The segment key (used for percentage split hashing)
        # @param context [Hash] The evaluation context
        # @return [Boolean] True if the condition matches
        def traits_match_segment_condition_from_context(condition, segment_key, context)
          if condition[:operator] == PERCENTAGE_SPLIT
            context_value_key = get_context_value(condition[:property], context) || get_identity_key_from_context(context)
            hashed_percentage = hashed_percentage_for_object_ids([segment_key, context_value_key])
            return hashed_percentage <= condition[:value].to_f
          end

          return false if condition[:property].nil?
          trait_value = get_trait_value(condition[:property], context)
          return trait_value != nil if condition[:operator] == IS_SET
          return trait_value.nil? if condition[:operator] == IS_NOT_SET

          if !trait_value.nil?
            # Reuse existing Condition class logic
            condition_obj = Flagsmith::Engine::Segments::Condition.new(
              operator: condition[:operator],
              value: condition[:value],
              property: condition[:property]
            )
            return condition_obj.match_trait_value?(trait_value)
          end

          false
        end

        # Evaluate rule conditions based on type (ALL/ANY/NONE)
        #
        # @param rule_type [String] The rule type
        # @param condition_results [Array<Boolean>] Array of condition evaluation results
        # @return [Boolean] True if conditions match according to rule type
        def evaluate_rule_conditions(rule_type, condition_results)
          case rule_type
          when 'ALL'
            condition_results.empty? || condition_results.all?
          when 'ANY'
            !condition_results.empty? && condition_results.any?
          when 'NONE'
            condition_results.empty? || condition_results.none?
          else
            false
          end
        end

        # Get trait value from context, supporting JSONPath expressions
        #
        # @param property [String] The property name or JSONPath
        # @param context [Hash] The evaluation context
        # @return [Object, nil] The trait value or nil
        def get_trait_value(property, context)
          if property.start_with?('$.')
            context_value = get_context_value(property, context)
            if !context_value.nil? && !non_primitive?(context_value)
              return context_value
            end
          end

          traits = context.dig(:identity, :traits) || {}
          traits[property] || traits[property.to_sym]
        end

        # Get value from context using JSONPath syntax
        #
        # @param json_path [String] JSONPath expression (e.g., '$.identity.identifier')
        # @param context [Hash] The evaluation context
        # @return [Object, nil] The value at the path or nil
        def get_context_value(json_path, context)
          return nil unless context && json_path&.start_with?('$.')
          results = JsonPath.new(json_path, use_symbols: true).on(context)
          results.first
        rescue StandardError
          nil
        end

        # Get identity key from context
        #
        # @param context [Hash] The evaluation context
        # @return [String, nil] The identity key or generated composite key
        def get_identity_key_from_context(context)
          return nil unless context[:identity]

          context[:identity][:key] ||
            "#{context[:environment][:key]}_#{context[:identity][:identifier]}"
        end

        # Check if value is non-primitive (object or array)
        #
        # @param value [Object] The value to check
        # @return [Boolean] True if value is an object or array
        def non_primitive?(value)
          return false if value.nil?

          value.is_a?(Hash) || value.is_a?(Array)
        end
      end
    end
  end
end
