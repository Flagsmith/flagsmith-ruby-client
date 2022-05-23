# frozen_string_literal: true

require 'faraday'
require 'faraday_middleware'

require_relative 'flagsmiths/sdk/analytics_processor'
require_relative 'flagsmiths/sdk/api_client'
require_relative 'flagsmiths/sdk/config'
require_relative 'flagsmiths/sdk/errors'
require_relative 'flagsmiths/sdk/helpers'
require_relative 'flagsmiths/sdk/pooling_manager'
require_relative 'flagsmiths/sdk/models/flag'
require_relative 'flagsmiths/sdk/models/flags/collection'
require_relative 'flagsmiths/sdk/instance_methods'

require_relative 'flagsmiths/engine/core'

# Ruby client for flagsmith.com
class Flagsmith
  extend Forwardable
  include Flagsmiths::SDK::Helpers
  include Flagsmiths::SDK::InstanceMethods
  include Flagsmiths::Engine::Core
  # A Flagsmith client.
  #
  # Provides an interface for interacting with the Flagsmith http API.
  # Basic Usage::
  #
  # flagsmith = Flagsmith.new(environment_key: '<your API key>')
  # environment_flags = flagsmith.get_environment_flags
  # feature_enabled = environment_flags.is_feature_enabled('foo')
  # identity_flags = flagsmith.get_identity_flags('identifier', 'foo': 'bar')
  # feature_enabled_for_identity = identity_flags.is_feature_enabled('foo')

  # Available Configs.
  #
  # :environment_key, :api_url, :custom_headers, :request_timeout_seconds, :enable_local_evaluation,
  # :environment_refresh_interval_seconds, :retries, :enable_analytics, :default_flag_handler
  # You can see full description in the Flagsmiths::Config

  attr_reader :config, :environment

  delegate Flagsmiths::Config::OPTIONS => :@config

  def initialize(config)
    @config = Flagsmiths::Config.new(config)

    api_client
    analytics_processor
    environment_data_polling_manager
  end

  def api_client
    @api_client ||= Flagsmiths::ApiClient.new(@config)
  end

  def analytics_processor
    return nil unless @config.enable_analytics?

    @analytics_processor ||=
      Flagsmiths::AnalyticsProcessor.new(
        api_client: api_client,
        timeout: request_timeout_seconds
      )
  end

  def environment_data_polling_manager
    return nil unless @config.local_evaluation?

    @environment_data_polling_manager ||= Flagsmiths::EnvironmentDataPollingManager.new(
      self, environment_refresh_interval_seconds
    ).tap(&:start)
    update_environment
  end

  # Updates the environment state for local flag evaluation.
  # You only need to call this if you wish to bypass environment_refresh_interval_seconds.
  def update_environment
    @environment = environment_from_api
  end

  def environment_from_api
    api_client.get(@config.environment_url).body
    environment_data = api_client.get(@config.environment_url).body
    Flagsmiths::Engine::Environment.build(environment_data)
  end
end
