# frozen_string_literal: true

require 'faraday'
require 'faraday/retry'

# Hash#slice was added in ruby version 2.5
# This is the patch to use slice in earler versions
require 'flagsmith/hash_slice'

require 'flagsmith/sdk/analytics_processor'
require 'flagsmith/sdk/api_client'
require 'flagsmith/sdk/config'
require 'flagsmith/sdk/errors'
require 'flagsmith/sdk/intervals'
require 'flagsmith/sdk/pooling_manager'
require 'flagsmith/sdk/models/flags'
require 'flagsmith/sdk/models/segments'

require 'flagsmith/engine/core'

# no-doc
module Flagsmith
  # Ruby client for flagsmith.com
  class Client # rubocop:disable Metrics/ClassLength
    extend Forwardable
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
    # identity_flags = flagsmith.get_identity_flags('identifier', {'foo': 'bar'})
    # feature_enabled_for_identity = identity_flags.is_feature_enabled('foo')
    # feature_value_for_identity = identity_flags.get_feature_value('foo')
    #
    # identity_segments = flagsmith.get_identity_segments('identifier', {'foo': 'bar'})

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
      engine
    end

    def api_client
      @api_client ||= Flagsmith::ApiClient.new(@config)
    end

    def engine
      @engine ||= Flagsmith::Engine::Engine.new
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

    # Get all the default for flags for the current environment.
    # @returns Flags object holding all the flags for the current environment.
    def get_environment_flags # rubocop:disable Naming/AccessorMethodName
      return environment_flags_from_document if @config.local_evaluation?

      environment_flags_from_api
    end

    # Get all the flags for the current environment for a given identity. Will also
    # upsert all traits to the Flagsmith API for future evaluations. Providing a
    # trait with a value of None will remove the trait from the identity if it exists.
    #
    # identifier a unique identifier for the identity in the current
    # environment, e.g. email address, username, uuid
    # traits { key => value } is a dictionary of traits to add / update on the identity in
    # Flagsmith, e.g. { "num_orders": 10 }
    # returns Flags object holding all the flags for the given identity.
    def get_identity_flags(identifier, **traits)
      return get_identity_flags_from_document(identifier, traits) if environment

      get_identity_flags_from_api(identifier, traits)
    end

    def feature_enabled?(feature_name, default: false)
      flag = get_environment_flags[feature_name]
      return default if flag.nil?

      flag.enabled?
    end

    def feature_enabled_for_identity?(feature_name, user_id, default: false)
      flag = get_identity_flags(user_id)[feature_name]
      return default if flag.nil?

      flag.enabled?
    end

    def get_value(feature_name, default: nil)
      flag = get_environment_flags[feature_name]
      return default if flag.nil?

      flag.value
    end

    def get_value_for_identity(feature_name, user_id = nil, default: nil)
      flag = get_identity_flags(user_id)[feature_name]
      return default if flag.nil?

      flag.value
    end

    def get_identity_segments(identifier, traits = {})
      unless environment
        raise Flagsmith::ClientError,
              'Local evaluation required to obtain identity segments.'
      end

      identity_model = build_identity_model(identifier, traits)
      segment_models = engine.get_identity_segments(environment, identity_model)
      segment_models.map { |sm| Flagsmith::Segments::Segment.new(id: sm.id, name: sm.name) }.compact
    end

    private

    def environment_flags_from_document
      Flagsmith::Flags::Collection.from_feature_state_models(
        engine.get_environment_feature_states(environment),
        analytics_processor: analytics_processor,
        default_flag_handler: default_flag_handler
      )
    end

    def get_identity_flags_from_document(identifier, traits = {})
      identity_model = build_identity_model(identifier, traits)

      Flagsmith::Flags::Collection.from_feature_state_models(
        engine.get_identity_feature_states(environment, identity_model),
        analytics_processor: analytics_processor,
        default_flag_handler: default_flag_handler
      )
    end

    def environment_flags_from_api
      rescue_with_default_handler do
        api_flags = api_client.get(@config.environment_flags_url).body
        api_flags = api_flags.select { |flag| flag[:feature_segment].nil? }
        Flagsmith::Flags::Collection.from_api(
          api_flags,
          analytics_processor: analytics_processor,
          default_flag_handler: default_flag_handler
        )
      end
    end

    def get_identity_flags_from_api(identifier, traits = {})
      rescue_with_default_handler do
        data = generate_identities_data(identifier, traits)
        json_response = api_client.post(@config.identities_url, data.to_json).body

        Flagsmith::Flags::Collection.from_api(
          json_response[:flags],
          analytics_processor: analytics_processor,
          default_flag_handler: default_flag_handler
        )
      end
    end

    def rescue_with_default_handler
      yield
    rescue StandardError
      if default_flag_handler
        return Flagsmith::Flags::Collection.new(
          {},
          default_flag_handler: default_flag_handler
        )
      end
      raise
    end

    def build_identity_model(identifier, traits = {})
      unless environment
        raise Flagsmith::ClientError,
              'Unable to build identity model when no local environment present.'
      end

      trait_models = traits.map do |key, value|
        Flagsmith::Engine::Identities::Trait.new(trait_key: key, trait_value: value)
      end
      Flagsmith::Engine::Identity.new(
        identity_traits: trait_models, environment_api_key: environment_key, identifier: identifier
      )
    end

    def generate_identities_data(identifier, traits = {})
      {
        identifier: identifier,
        traits: traits.map { |key, value| { trait_key: key, trait_value: value } }
      }
    end
  end
end
