# frozen_string_literal: true

require_relative 'constants'

module Flagsmith
  module Engine
    # SegmentModel
    class Segment
      attr_reader :id, :name
      attr_accessor :rules, :feature_states

      def initialize(id:, name:, rules: [], feature_states: [])
        @id = id
        @name = name
        @rules = rules
        @feature_states = feature_states
      end

      class << self
        def build(json)
          feature_states = json.fetch(:feature_states, []).map { |fs| Flagsmith::Engine::FeatureState.build(fs) }
          rules = json.fetch(:rules, []).map { |rule| Flagsmith::Engine::Segments::Rule.build(rule) }

          new(
            **json.slice(:id, :name)
                  .merge(feature_states: feature_states, rules: rules)
          )
        end
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
          CONTAINS => ->(other_value, self_value) { other_value&.include? self_value },

          NOT_CONTAINS => ->(other_value, self_value) { !other_value&.include? self_value },
          REGEX => ->(other_value, self_value) { other_value&.match? self_value }
        }.freeze

        def initialize(operator:, value:, property: nil)
          @operator = operator
          @value = value
          @property = property
        end

        def match_trait_value?(trait_value)
          # handle some exceptions
          trait_value = Semantic::Version.new(trait_value.gsub(/:semver$/, '')) if @value.is_a?(String) && @value.match?(/:semver$/)

          return match_in_value(trait_value) if @operator == IN
          return match_modulo_value(trait_value) if @operator == MODULO

          type_as_trait_value = format_to_type_of(trait_value)
          formatted_value = type_as_trait_value ? type_as_trait_value.call(@value) : @value

          MATCHING_FUNCTIONS[operator]&.call(trait_value, formatted_value)
        end

        # rubocop:disable Metrics/AbcSize
        def format_to_type_of(input)
          {
            'String' => ->(v) { v.to_s },
            'Semantic::Version' => ->(v) { Semantic::Version.new(v.to_s.gsub(/:semver$/, '')) },
            'TrueClass' => ->(v) { ['True', 'true', 'TRUE', true, 1, '1'].include?(v) },
            'FalseClass' => ->(v) { !['False', 'false', 'FALSE', false, 0, '0'].include?(v) },
            'Integer' => ->(v) { v.to_i },
            'Float' => ->(v) { v.to_f }
          }[input.class.to_s]
        end
        # rubocop:enable Metrics/AbcSize

        def match_modulo_value(trait_value)
          divisor, remainder = @value.split('|')
          trait_value.is_a?(Numeric) && trait_value % divisor.to_f == remainder.to_f # rubocop:disable Lint/FloatComparison
        rescue StandardError
          false
        end

        def match_in_value(trait_value)
          return @value.split(',').include?(trait_value.to_s) if trait_value.is_a?(String) || trait_value.is_a?(Integer)

          false
        end

        class << self
          def build(json)
            new(**json.slice(:operator, :value).merge(property: json[:property_]))
          end
        end
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

        def initialize(type: nil, rules: [], conditions: [])
          @type = type
          @rules = rules
          @conditions = conditions
        end

        def matching_function
          MATCHING_FUNCTIONS[type]
        end

        class << self
          def build(json)
            rules = json.fetch(:rules, []).map { |r| Flagsmith::Engine::Segments::Rule.build(r) }
            conditions = json.fetch(:conditions, []).map { |c| Flagsmith::Engine::Segments::Condition.build(c) }
            new(
              type: json[:type], rules: rules, conditions: conditions
            )
          end
        end
      end
    end
  end
end
