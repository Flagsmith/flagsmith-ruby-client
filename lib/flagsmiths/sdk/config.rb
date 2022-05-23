# frozen_string_literal: true

module Flagsmiths
  # Config options shared around Engine
  class Config
    DEFAULT_API_URL = 'https://api.flagsmith.com/api/v1/'
    OPTIONS = %i[
      environment_key api_url custom_headers request_timeout_seconds enable_local_evaluation
      environment_refresh_interval_seconds retries enable_analytics default_flag_handler logger
    ].freeze

    # Available Configs
    #
    # == Options:
    #
    #   +environment_key+                      - The environment key obtained from Flagsmith
    #                                            interface
    #   +api_url+                              - Override the URL of the Flagsmith API to communicate with
    #   +customer_headrrs+                     - Additional headers to add to requests made
    #                                            to the Flagsmith API
    #   +request_timeout_seconds+              - Number of seconds to wait for a request to
    #                                            complete before terminating the request
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
    #                                            a non existent feature is requested
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

      @environment_key = opts.fetch(:environment_key, Flagsmiths::Config.environment_key)
      @api_url = opts.fetch(:api_url, Flagsmiths::Config::DEFAULT_API_URL)
      @custom_headers = opts.fetch(:custom_headers, {})
      @request_timeout_seconds = opts[:request_timeout_seconds]
      @retries = opts[:retries]
      @enable_local_evaluation = opts.fetch(:enable_local_evaluation, false)
      @environment_refresh_interval_seconds = opts.fetch(:environment_refresh_interval_seconds, 60)
      @enable_analytics = opts.fetch(:enable_analytics, false)
      @default_flag_handler = opts[:default_flag_handler]
      @logger = options.fetch(:logger, Logger.new($stdout).tap { |l| l.level = :debug })
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    class << self
      def environment_key
        ENV['FLAGSMITH_ENVIRONMENT_KEY']
      end
    end
  end
end
