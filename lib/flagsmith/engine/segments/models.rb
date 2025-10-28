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
          GREATER_THAN => ->(other_value, self_value) { (other_value || false) && other_value > self_value },
          GREATER_THAN_INCLUSIVE => ->(other_value, self_value) { (other_value || false) && other_value >= self_value },
          LESS_THAN => ->(other_value, self_value) { (other_value || false) && other_value < self_value },
          LESS_THAN_INCLUSIVE => ->(other_value, self_value) { (other_value || false) && other_value <= self_value },
          NOT_EQUAL => ->(other_value, self_value) { other_value != self_value },
          CONTAINS => ->(other_value, self_value) { (other_value || false) && other_value.include?(self_value) },

          NOT_CONTAINS => ->(other_value, self_value) { (other_value || false) && !other_value.include?(self_value) },
          REGEX => ->(other_value, self_value) { (other_value || false) && other_value.to_s.match?(self_value) }
        }.freeze

        def initialize(operator:, value:, property: nil)
          @operator = operator
          @value = value
          @property = property
        end

        def match_trait_value?(trait_value)
          if @value.is_a?(String) && @value.match?(/:semver$/)
            begin
              trait_value = Semantic::Version.new(trait_value.to_s.gsub(/:semver$/, ''))
            rescue ArgumentError, Semantic::Version::ValidationFailed => _e
              return false
            end
          end

          return match_in_value(trait_value) if @operator == IN
          return match_modulo_value(trait_value) if @operator == MODULO
          return MATCHING_FUNCTIONS[REGEX]&.call(trait_value, @value) if @operator == REGEX

          type_as_trait_value = format_to_type_of(trait_value)
          formatted_value = type_as_trait_value ? type_as_trait_value.call(@value) : @value

          MATCHING_FUNCTIONS[operator]&.call(trait_value, formatted_value)
        end

        # rubocop:disable Metrics/AbcSize
        def format_to_type_of(input)
          {
            'String' => ->(v) { v.to_s },
            'Semantic::Version' => ->(v) { Semantic::Version.new(v.to_s.gsub(/:semver$/, '')) },
            # Double check this is the desired behavior between SDKs
            'TrueClass' => ->(v) { ['True', 'true', 'TRUE', true, 1, '1'].include?(v) },
            'FalseClass' => ->(v) { !['False', 'false', 'FALSE', false].include?(v) },
            'Integer' => lambda { |v|
              i = v.to_i
              i.to_s == v.to_s ? i : v
            },
            'Float' => lambda { |v|
              f = v.to_f
              f.to_s == v.to_s ? f : v
            }
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
          return false if trait_value.nil? || trait_value.is_a?(TrueClass) || trait_value.is_a?(FalseClass)

<<<<<<< HEAD
          # Floats/doubles are not supported by the engine due to ambiguous serialization across supported platforms. (segments/models_spec.rb)
          return false unless trait_value.is_a?(String) || trait_value.is_a?(Integer)

          if @value.is_a?(Array)
            return @value.include?(trait_value.to_s)
          end
=======
          return @value.include?(trait_value.to_s) if @value.is_a?(Array)
>>>>>>> 6a6a129d14a0f15bbf3252a2c6b539681dfa7e85

          if @value.is_a?(String)
            begin
              parsed = JSON.parse(@value)
              return parsed.include?(trait_value.to_s) if parsed.is_a?(Array)
            rescue JSON::ParserError
            end
          end

          @value.to_s.split(',').include?(trait_value.to_s)
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
