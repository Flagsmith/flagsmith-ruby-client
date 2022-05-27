# frozen_string_literal: true

require 'faraday'
require 'faraday/retry'
require 'faraday_middleware'

# Hash#slice was added in ruby version 2.5
# This is the patch to use slice in earler versions
require 'flagsmith/hash_slice'

require 'flagsmith/sdk/analytics_processor'
require 'flagsmith/sdk/api_client'
require 'flagsmith/sdk/config'
require 'flagsmith/sdk/errors'
require 'flagsmith/sdk/intervals'
require 'flagsmith/sdk/pooling_manager'
require 'flagsmith/sdk/models/flag'
require 'flagsmith/sdk/models/flags/collection'
require 'flagsmith/sdk/instance_methods'

require 'flagsmith/engine/core'

# no-doc
module Flagsmith
  # Ruby client for flagsmith.com
  class Client
    extend Forwardable
    include Flagsmith::SDK::InstanceMethods
    include Flagsmith::Engine::Core
    # A Flagsmith client.
    #
    # Provides an interface for interacting with the Flagsmith http API.
    # Basic Usage::
    #
    # flagsmith = Flagsmith::Client.new(environment_key: '<your API key>')
    #
    # environment_flags = flagsmith.get_environment_flags
    # feature_enabled = environment_flags.is_feature_enabled('foo')
    # feature_value = identity_flags.get_feature_value('foo')
    #
    # identity_flags = flagsmith.get_identity_flags('identifier', 'foo': 'bar')
    # feature_enabled_for_identity = identity_flags.is_feature_enabled('foo')
    # feature_value_for_identity = identity_flags.get_feature_value('foo')

    # Available Configs.
    #
    # :environment_key, :api_url, :custom_headers, :request_timeout_seconds, :enable_local_evaluation,
    # :environment_refresh_interval_seconds, :retries, :enable_analytics, :default_flag_handler
    # You can see full description in the Flagsmith::Config

    attr_reader :config, :environment

    delegate Flagsmith::Config::OPTIONS => :@config

    def initialize(config)
      @_mutex = Mutex.new
      @config = Flagsmith::Config.new(config)

      api_client
      analytics_processor
      environment_data_polling_manager
    end

    def api_client
      @api_client ||= Flagsmith::ApiClient.new(@config)
    end

    def analytics_processor
      return nil unless @config.enable_analytics?

      @analytics_processor ||=
        Flagsmith::AnalyticsProcessor.new(
          api_client: api_client,
          timeout: request_timeout_seconds
        )
    end

    def environment_data_polling_manager
      return nil unless @config.local_evaluation?

      update_environment

      @environment_data_polling_manager ||= Flagsmith::EnvironmentDataPollingManager.new(
        self, environment_refresh_interval_seconds
      ).tap(&:start)
    end

    # Updates the environment state for local flag evaluation.
    # You only need to call this if you wish to bypass environment_refresh_interval_seconds.
    def update_environment
      @_mutex.synchronize { @environment = environment_from_api }
    end

    def environment_from_api
      environment_data = api_client.get(@config.environment_url).body
      Flagsmith::Engine::Environment.build(environment_data)
    end
  end
end
