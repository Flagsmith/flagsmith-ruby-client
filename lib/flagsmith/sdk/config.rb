# frozen_string_literal: true

module Flagsmith
  # Config options shared around Engine
  class Config
    DEFAULT_API_URL = 'https://edge.api.flagsmith.com/api/v1/'
    DEFAULT_REALTIME_API_URL = 'https://realtime.flagsmith.com/'

    OPTIONS = %i[
      environment_key api_url custom_headers request_timeout_seconds enable_local_evaluation
      environment_refresh_interval_seconds retries enable_analytics default_flag_handler
      offline_mode offline_handler polling_manager_failure_limit
      realtime_api_url enable_realtime_updates logger
    ].freeze

    # Available Configs
    #
    # == Options:
    #
    #   +environment_key+                      - The environment key obtained from Flagsmith
    #                                            interface
    #   +api_url+                              - Override the URL of the Flagsmith API to communicate with
    #   +customer_headers+                     - Additional headers to add to requests made
    #                                            to the Flagsmith API
    #   +request_timeout_seconds+              - Number of seconds to wait for a request to
    #                                            complete before terminating the request
    #                                            Defaults to 10 seconds
    #   +enable_local_evaluation+              - Enables local evaluation of flags
    #   +environment_refresh_interval_seconds+ - If using local evaluation,
    #                                            specify the interval period between
    #                                            refreshes of local environment data
    #   +retries+                              - a faraday retry option to use
    #                                            on all http requests to the Flagsmith API
    #   +enable_analytics+                     - if enabled, sends additional requests to the Flagsmith
    #                                            API to power flag analytics charts
    #   +default_flag_handler+                 - ruby block which will be used in the case where
    #                                            flags cannot be retrieved from the API or
    #                                            a non-existent feature is requested.
    #                                            The searched feature#name will be passed to the block as an argument.
    #   +offline_mode+                         - if enabled, uses a locally provided file and
    #                                            bypasses requests to the api.
    #   +offline_handler+                      - A file object that contains a JSON serialization of
    #                                            the entire environment, project, flags, etc.
    #   +polling_manager_failure_limit+        - An integer to control how long to suppress errors in
    #                                            the polling manager for local evaluation mode.
    #   +realtime_api_url+                     - Override the realtime api URL to communicate with a
    #                                            non-standard realtime endpoint.
    #   +enable_realtime_updates+              - A boolean to enable realtime updates.
    #   +logger+                               - Pass your logger, default is Logger.new($stdout)
    #
    attr_reader(*OPTIONS)

    def initialize(options)
      build_config(options)

      freeze
    end

    def local_evaluation?
      @enable_local_evaluation
    end

    def enable_analytics?
      @enable_analytics
    end

    def offline_mode?
      @offline_mode
    end

    def realtime_mode?
      @enable_realtime_updates
    end

    def environment_flags_url
      'flags/'
    end

    def identities_url
      'identities/'
    end

    def environment_url
      'environment-document/'
    end

    private

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def build_config(options)
      opts = options.is_a?(String) ? { environment_key: options } : options

      @environment_key = opts.fetch(:environment_key, Flagsmith::Config.environment_key)
      @api_url = opts.fetch(:api_url, Flagsmith::Config::DEFAULT_API_URL)
      @custom_headers = opts.fetch(:custom_headers, {})
      @request_timeout_seconds = opts.fetch(:request_timeout_seconds, 10)
      @retries = opts[:retries]
      @enable_local_evaluation = opts.fetch(:enable_local_evaluation, false)
      @environment_refresh_interval_seconds = opts.fetch(:environment_refresh_interval_seconds, 60)
      @enable_analytics = opts.fetch(:enable_analytics, false)
      @default_flag_handler = opts[:default_flag_handler]
      @offline_mode = opts.fetch(:offline_mode, false)
      @offline_handler = opts[:offline_handler]
      @polling_manager_failure_limit = opts.fetch(:polling_manager_failure_limit, 10)
      @realtime_api_url = opts.fetch(:realtime_api_url, Flagsmith::Config::DEFAULT_REALTIME_API_URL)
      @realtime_api_url << '/' unless @realtime_api_url.end_with? '/'
      @enable_realtime_updates = opts.fetch(:enable_realtime_updates, false)
      @logger = options.fetch(:logger, Logger.new($stdout).tap { |l| l.level = :debug })
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    class << self
      def environment_key
        ENV.fetch('FLAGSMITH_ENVIRONMENT_KEY', nil)
      end
    end
  end
end
