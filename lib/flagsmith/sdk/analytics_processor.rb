# frozen_string_literal: true

module Flagsmith
  # Used to control how often we send data(in seconds)
  class AnalyticsProcessor
    ENDPOINT = 'analytics/flags/'
    TIMER = 10
    attr_reader :last_flushed, :timeout, :analytics_data

    # AnalyticsProcessor is used to track how often individual Flags are evaluated within
    # the Flagsmith SDK. Docs: https://docs.flagsmith.com/advanced-use/flag-analytics.
    #
    # data[:environment_key] environment key obtained from the Flagsmith UI
    # data[:base_api_url] base api url to override when using self hosted version
    # data[:timeout] used to tell requests to stop waiting for a response after a
    #                given number of seconds
    def initialize(data)
      @last_flushed = Time.now
      @analytics_data = {}
      @api_client = data.fetch(:api_client)
      @timeout = data.fetch(:timeout, 3)
    end

    # Sends all the collected data to the api asynchronously and resets the timer
    def flush
      return if @analytics_data.empty?

      @api_client.post(ENDPOINT, @analytics_data.to_json)

      @analytics_data = {}
      @last_flushed = Time.now
    end

    def track_feature(feature_name)
      @analytics_data[feature_name] = @analytics_data.fetch(feature_name, 0) + 1
      flush if (Time.now - @last_flushed) > TIMER * 1000
    end
  end
end
