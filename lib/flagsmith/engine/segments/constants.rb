# frozen_string_literal: true

module Flagsmith
  module Engine
    module Segments
      module Constants
        # Segment Rules
        ALL_RULE = 'ALL'
        ANY_RULE = 'ANY'
        NONE_RULE = 'NONE'

        RULE_TYPES = [ALL_RULE, ANY_RULE, NONE_RULE].freeze

        # Segment Condition Operators
        EQUAL = 'EQUAL'
        GREATER_THAN = 'GREATER_THAN'
        LESS_THAN = 'LESS_THAN'
        LESS_THAN_INCLUSIVE = 'LESS_THAN_INCLUSIVE'
        CONTAINS = 'CONTAINS'
        GREATER_THAN_INCLUSIVE = 'GREATER_THAN_INCLUSIVE'
        NOT_CONTAINS = 'NOT_CONTAINS'
        NOT_EQUAL = 'NOT_EQUAL'
        REGEX = 'REGEX'
        PERCENTAGE_SPLIT = 'PERCENTAGE_SPLIT'

        CONDITION_OPERATORS = [
          EQUAL,
          GREATER_THAN,
          LESS_THAN,
          LESS_THAN_INCLUSIVE,
          CONTAINS,
          GREATER_THAN_INCLUSIVE,
          NOT_CONTAINS,
          NOT_EQUAL,
          REGEX,
          PERCENTAGE_SPLIT
        ].freeze
      end
    end
  end
end
