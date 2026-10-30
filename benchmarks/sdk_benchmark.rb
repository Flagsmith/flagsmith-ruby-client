# frozen_string_literal: true

require 'flagsmith'

# Benchmarks a locally evaluating SDK client against environment documents tiered by size.
class SdkBenchmark
  ENVIRONMENTS = %w[small medium large].freeze
  BENCHMARKS = {
    'getEnvironmentFlags' => :get_environment_flags,
    'getIdentityFlagsWithIdentityOverrides' => :get_identity_flags_with_identity_overrides,
    'getIdentityFlagsNoTraits' => :get_identity_flags_no_traits,
    'getIdentityFlagsWithTraits' => :get_identity_flags_with_traits,
    'getIdentitySegmentsWithTraits' => :get_identity_segments_with_traits
  }.freeze

  IDENTITY_OVERRIDES_IDENTIFIER = 'identity-override-1'
  IDENTIFIER = 'user-1'
  TRAITS = {
    plan: 'plan-7',
    age: 30,
    country: 'GB',
    version: '2.5.1',
    email: 'jane@example.com',
    user_id: 12,
    beta: true,
    score: 95,
    tier: 'pro',
    device: 'iPhone 15'
  }.freeze

  # Build a locally evaluating client serving the environment document from memory.
  def initialize(sdk_benchmarks_dir, environment)
    environment_document = File.read(File.join(sdk_benchmarks_dir, 'environments', "#{environment}.json"))
    Faraday.default_adapter = serve_environment_document(environment_document)
    @client = Flagsmith::Client.new(
      environment_key: JSON.parse(environment_document).fetch('api_key'),
      api_url: 'http://flagsmith.benchmark/api/v1/',
      enable_local_evaluation: true,
      environment_refresh_interval_seconds: 86_400, # Refreshed by benchmarks only
      logger: Logger.new(File::NULL)
    )
  end

  def close
    @client.environment_data_polling_manager.stop
  end

  # rubocop:disable Naming/AccessorMethodName

  # Get a feature value from the environment flags.
  def get_environment_flags
    @client.get_environment_flags.feature_value('feature_1')
  end

  # Check a feature for an identity with identity overrides.
  def get_identity_flags_with_identity_overrides
    @client.get_identity_flags(IDENTITY_OVERRIDES_IDENTIFIER).feature_enabled?('feature_8')
  end

  # Get a feature value for an identity without traits.
  def get_identity_flags_no_traits
    @client.get_identity_flags(IDENTIFIER).feature_value('feature_1')
  end

  # Get a feature value for an identity with traits.
  def get_identity_flags_with_traits
    @client.get_identity_flags(IDENTIFIER, **TRAITS).feature_value('feature_1')
  end

  # List the segments of an identity with traits.
  def get_identity_segments_with_traits
    @client.get_identity_segments(IDENTIFIER, TRAITS)
  end

  # rubocop:enable Naming/AccessorMethodName

  private

  def serve_environment_document(environment_document)
    Class.new(Faraday::Adapter) do
      define_method(:call) do |env|
        super(env)
        save_response(env, 200, environment_document, { 'Content-Type' => 'application/json' })
        @app.call(env)
      end
    end
  end
end
