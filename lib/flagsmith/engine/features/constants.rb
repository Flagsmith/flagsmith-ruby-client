# frozen_string_literal: true

module Flagsmith
  module Engine
    module Features
      # Targeting reason constants for evaluation results
      module TargetingReasons
        TARGETING_REASON_DEFAULT = 'DEFAULT'
        TARGETING_REASON_STATIC = 'STATIC'
        TARGETING_REASON_TARGETING_MATCH = 'TARGETING_MATCH'
        TARGETING_REASON_SPLIT = 'SPLIT'
        TARGETING_REASON_CIRCULAR_DEPENDENCY = 'ERROR; code=CIRCULAR_DEPENDENCY'
      end
    end
  end
end
