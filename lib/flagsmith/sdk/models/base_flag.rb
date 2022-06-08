# frozen_string_literal: true

module Flagsmith
    class BaseFlag
        include Comparable

        attr_reader :enabled, :value, :default
        
        def initialize(enabled:, value:, default: false)
            @enabled = enabled
            @value = value
            @default = default
        end
        
        alias is_default default