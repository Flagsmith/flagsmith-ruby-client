# frozen_string_literal: true

require_relative 'intervals'

module Flagsmith
  # Manager to asynchronously fetch the environment
  class EnvironmentDataPollingManager
    include Flagsmith::SDK::Intervals

    def initialize(main, refresh_interval_seconds)
      @main = main
      @refresh_interval_seconds = refresh_interval_seconds
    end

    def start
      update_environment = lambda {
        clear_interval(@interval) if @interval
        @interval = set_interval(@refresh_interval_seconds) { @main.update_environment }
      }

      # TODO: this call should be awaited for getIdentityFlags/getEnvironmentFlags when enableLocalEvaluation is true
      update_environment.call
    end

    def stop
      return unless @interval

      clear_interval(@interval)
    end
  end
end
