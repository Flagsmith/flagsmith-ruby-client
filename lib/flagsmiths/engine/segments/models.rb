# frozen_string_literal: true

require_relative 'constants'

module Flagsmiths
  module Engine
    # SegmentModel
    class Segment
      attr_reader :id, :name
      attr_accessor :rules, :feature_states

      def initialize(id:, name:, rules: nil, feature_states: nil)
        @id = id
        @name = name
        @rules = rules
        @feature_states = feature_states
      end

      class << self
        def build; end
      end
    end

    module Segments
      # SegmentConditionModel
      class Condition
        include Constants
        attr_reader :operator, :value, :property

        MATCHING_FUNCTIONS = {
          EQUAL => ->(other_value, self_value) { other_value == self_value },
          GREATER_THAN => ->(other_value, self_value) { other_value > self_value },
          GREATER_THAN_INCLUSIVE => ->(other_value, self_value) { other_value >= self_value },
          LESS_THAN => ->(other_value, self_value) { other_value < self_value },
          LESS_THAN_INCLUSIVE => ->(other_value, self_value) { other_value <= self_value },
          NOT_EQUAL => ->(other_value, self_value) { other_value != self_value },
          CONTAINS => ->(other_value, self_value) { other_value.include? self_value },

          NOT_CONTAINS => ->(other_value, self_value) { !other_value.include? self_value },
          REGEX => ->(other_value, self_value) { other_value.match? self_value }
        }.freeze

        def initialize(operator:, value:, property: nil)
          @operator = operator
          @value = value
          @property = property
        end

        def match_trait_value?(trait_value)
          if @value.is_a?(String) && @value.match?(/:semver$/)
            trait_value = Semantic::Version.new(trait_value.gsub(/:semver$/, ''))
          end

          type_as_trait_value = format_to_type_of(trait_value)
          formatted_value = type_as_trait_value ? type_as_trait_value.call(@value) : @value

          MATCHING_FUNCTIONS[operator]&.call(trait_value, formatted_value)
        end

        # rubocop:disable Metrics/AbcSize
        def format_to_type_of(input)
          {
            'String' => ->(v) { v.to_s },
            'Semantic::Version' => ->(v) { Semantic::Version.new(v.to_s.gsub(/:semver$/, '')) },
            'TrueClass' => ->(v) { ['True', 'true', 'TRUE', true, 1, '1'].include?(v) ? true : false },
            'FalseClass' => ->(v) { ['False', 'false', 'FALSE', false, 0, '0'].include?(v) ? false : true },
            'Integer' => ->(v) { v.to_i },
            'Float' => ->(v) { v.to_f }
          }[input.class.to_s]
        end
        # rubocop:enable Metrics/AbcSize
      end

      # SegmentRuleModel
      class Rule
        include Constants
        MATCHING_FUNCTIONS = {
          ANY_RULE => :any?,
          ALL_RULE => :all?,
          NONE_RULE => :none?
        }.freeze

        attr_accessor :type, :rules, :conditions

        def initialize(type: nil, rules: nil, conditions: nil)
          @type = type
          @rules = rules
          @conditions = conditions
        end

        def matching_function
          MATCHING_FUNCTIONS[type]
        end
      end
    end
  end
end
