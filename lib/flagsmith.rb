# frozen_string_literal: true

require 'semantic'
require 'faraday'
require 'faraday_middleware'
require 'securerandom'
require 'pry'

# require_relative 'flagsmiths/analytics'
# require_relative 'flagsmiths/errors'
# require_relative 'flagsmiths/models/flag'
# require_relative 'flagsmiths/models/flags/collection'
# require_relative 'flagsmiths/pooling_manager'
# require_relative 'flagsmiths/api_client'
# require_relative 'flagsmiths/config'
# require_relative 'flagsmiths/helpers'

Dir.glob('./lib/flagsmiths/client/**/*.rb').sort.each { |file| require file }
Dir.glob('./lib/flagsmiths/engine/**/*.rb').sort.each { |file| require file }

require_relative 'flagsmith_engine'

# Ruby client for flagsmith.com
class Flagsmith
  extend Forwardable
  include FlagsmithEngine
  include Flagsmiths::Helpers
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
  #

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

  # Get all the default for flags for the current environment.
  # @returns Flags object holding all the flags for the current environment.
  def environment_flags
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

  def identity_flags(identifier, **traits)
    return get_identity_flags_from_document(identifier, traits) if environment

    get_identity_flags_from_api(identifier, traits)
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

  def environment_flags_from_document
    Flagsmiths::Flags::Collection.from_feature_state_models(
      get_environment_feature_states(environment),
      analytics_processor: analytics_processor,
      default_flag_handler: default_flag_handler
    )
  end

  alias get_environment_flags environment_flags
  alias get_identity_flags identity_flags
  # alias get_value feature_value

  private

  def get_identity_flags_from_document(identifier, traits = {})
    identity_model = build_identity_model(
      identifier,
      traits.map { |key, value| { key => value } }
    )

    Flasmiths::Flags::Collection.from_feature_state_models(
      get_identity_feature_states(environment, identity_model),
      analytics_processor: analytics_processor,
      default_flag_handler: default_flag_handler
    )
  end

  def environment_flags_from_api
    rescue_with_default_handler do
      api_flags = api_client.get(@config.environment_flags_url).body
      api_flags = api_flags.select { |flag| flag['feature_segment'].nil? }
      Flagsmiths::Flags::Collection.from_api(
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
      Flagsmiths::Flags::Collection.from_api(
        json_response['flags'],
        analytics_processor: analytics_processor,
        default_flag_handler: default_flag_handler
      )
    end
  end

  def rescue_with_default_handler
    yield
  rescue StandardError
    if default_flag_handler
      return Flagsmiths::Flags::Collection.new(
        {},
        default_flag_handler: default_flag_handler
      )
    end
    raise
  end

  def build_identity_model(identifier, traits = {})
    unless environment
      raise Flagsmiths::ClientError,
            'Unable to build identity model when no local environment present.'
    end
    trait_models = traits.map { |trait| Flagsmiths::TraitModel.new(trait.key, trait.value) }
    Flagsmiths::IdentityModel('0', trait_models, [], environment_key, identifier)
  end
end
