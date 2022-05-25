# frozen_string_literal: true

module Flagsmith
  module Engine
    # IdentityModel
    class Identity
      attr_reader :identifier, :environment_api_key, :created_date, :identity_features,
                  :identity_traits, :identity_uuid, :django_id

      def initialize(params)
        @identity_uuid = params.fetch(:identity_uuid, SecureRandom.uuid)
        @created_date = params[:created_date].is_a?(String) ? Date.parse(params[:created_date]) : params[:created_date]
        @identity_traits = params.fetch(:identity_traits, [])
        @identity_features = params.fetch(:identity_features, Flagsmith::Engine::Identities::FeaturesList.new)
        @environment_api_key = params.fetch(:environment_api_key)
        @identifier = params.fetch(:identifier)
        @django_id = params.fetch(:django_id, nil)
      end

      def composite_key
        Identity.generate_composite_key(@environment_api_key, @identifier)
      end

      def update_traits(traits)
        existing_traits = {}
        @identity_traits.each { |trait| existing_traits[trait.key] = trait }

        traits.each do |trait|
          if trait.value.nil?
            existing_traits.delete(trait.key)
          else
            existing_traits[trait.key] = trait
          end
        end

        @identity_traits = existing_traits.values
      end

      class << self
        def generate_composite_key(env_key, identifier)
          "#{env_key}_#{identifier}"
        end

        def build(json)
          identity_features = Flagsmith::Engine::Identities::FeaturesList.build(json[:identity_features])
          identity_traits = json.fetch(:identity_traits, [])
                                .map { |t| Flagsmith::Engine::Identities::Trait.build(t) }

          Identity.new(
            json.slice(:identifier, :identity_uuid, :environment_api_key, :created_date, :django_id)
                .merge(identity_features: identity_features, identity_traits: identity_traits)
          )
        end
      end
    end

    module Identities
      # TraitModel
      class Trait
        attr_reader :trait_value, :trait_key

        def initialize(trait_key:, trait_value:)
          @trait_key = trait_key
          @trait_value = trait_value
        end

        alias key trait_key
        alias value trait_value

        class << self
          def build(json)
            new(json.slice(:trait_key, :trait_value))
          end
        end
      end

      class NotInuiqueFeatureState < StandardError; end

      # IdentityFeaturesList
      class FeaturesList
        include Enumerable

        def initialize(list = [])
          @list = []
          list.each { |item| @list << item }
        end

        def <<(item)
          @list.each do |v|
            next unless v.django_id == item.django_id

            raise NotInuiqueFeatureState, "Feature state for this feature already exists, django_id: #{django_id}"
          end
          @list << item
        end

        def each(&block)
          @list.each { |item| block&.call(item) || item }
        end

        class << self
          def build(identity_features)
            return new unless identity_features&.any?

            new(
              identity_features.map { |f| Flagsmith::Engine::Features::State.build(f) }
            )
          end
        end
      end
    end
  end
end
