# frozen_string_literal: true

module Flagsmith
  module SDK
    # Available Flagsmith Functions
    module InstanceMethods
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

      private

      def environment_flags_from_document
        Flagsmith::Flags::Collection.from_feature_state_models(
          get_environment_feature_states(environment),
          analytics_processor: analytics_processor,
          default_flag_handler: default_flag_handler
        )
      end

      def get_identity_flags_from_document(identifier, traits = {})
        identity_model = build_identity_model(identifier, traits)

        Flagsmith::Flags::Collection.from_feature_state_models(
          get_identity_feature_states(environment, identity_model),
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
end