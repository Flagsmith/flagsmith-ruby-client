# frozen_string_literal: true

module Flagsmith
  module Engine
    module Features
      # Targeting reason constants for evaluation results
      module TargetingReasons
        TARGETING_REASON_DEFAULT = 'DEFAULT'
        TARGETING_REASON_TARGETING_MATCH = 'TARGETING_MATCH'
        TARGETING_REASON_SPLIT = 'SPLIT'
      end
    end
  end
end
