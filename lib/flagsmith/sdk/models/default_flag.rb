# frozen_string_literal: true

require_relative 'base_flag'

module Flagsmith
    class DefaultFlag < BaseFlag

        def initialize(enabled:, value:)
            super(enabled: enabled, value: value, default: true)
