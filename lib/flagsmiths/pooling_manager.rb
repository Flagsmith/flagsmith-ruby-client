# frozen_string_literal: true

module Flagsmiths
  # Manager to asynchronously fetch the environment
  class EnvironmentDataPollingManager
    def initialize(main:, refresh_interval_seconds:)
      @main = main
      @refresh_interval_seconds = refresh_interval_seconds
    end

    def start
      # def update_environment
      #   clear_interval(@interval) if @interval
      #   @interval = setInterval(async () => {
      #     @main.updateEnvironment()
      #   },  * 1000)
      # }
      # todo: this call should be awaited for getIdentityFlags/getEnvironmentFlags when enableLocalEvaluation is true
      @main.update_environment
      update_environment
    end

    def stop
      return unless @interval

      # clear_interval(@interval)
    end
  end
end
