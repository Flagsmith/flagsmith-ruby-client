# frozen_string_literal: true

require_relative 'intervals'

module Flagsmith
  # Manager to asynchronously fetch the environment
  class EnvironmentDataPollingManager
    include Flagsmith::SDK::Intervals

    def initialize(main, refresh_interval_seconds, polling_manager_failure_limit)
      @main = main
      @refresh_interval_seconds = refresh_interval_seconds
      @polling_manager_failure_limit = polling_manager_failure_limit
      @failures_since_last_update = 0
    end

    # rubocop:disable Metrics/MethodLength
    def start
      update_environment = lambda {
        stop
        @interval = set_interval(@refresh_interval_seconds) do
          @main.update_environment
          @failures_since_last_update = 0
        rescue StandardError => e
          @failures_since_last_update += 1
          @main.config.logger.warn "Failure to update the environment due to an error: #{e}"
          raise e if @failures_since_last_update > @polling_manager_failure_limit
        end
      }

      # TODO: this call should be awaited for getIdentityFlags/getEnvironmentFlags when enableLocalEvaluation is true
      update_environment.call
    end
    # rubocop:enable Metrics/MethodLength

    def stop
      return unless @interval

      clear_interval(@interval)
    end
  end
end
