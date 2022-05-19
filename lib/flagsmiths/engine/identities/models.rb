# frozen_string_literal: true

module Flagsmiths
  module Engine
    # IdentityModel
    class Identity
      attr_reader :identifier, :environmet_api_key, :created_date, :identity_features,
                  :identity_traits, :identity_uuid, :django_id

      def initialize(params)
        @identity_uuid = params.fetch(:identity_uuid, SecureRandom.uuid)
        @created_date = Date.parse(params[:created_date]) || Time.now
        @identity_traits = params.fetch(:identity_traits, [])
        @identity_features = params.fetch(:identity_features, Flagsmiths::Engine::Identities::FeaturesList.new)
        @environmet_api_key = params.fetch(:environmet_api_key)
        @identifier = params.fetch(:identifier)
        @django_id = params.fetch(:django_id, nil)
      end

      def composite_key
        Identity.generate_composite_key(@environmet_api_key, @identifier)
      end

      def update_traits(traits)
        existing_traits = {}
        @identity_traits.each { |trait| existing_traits[trait.key] = trait }

        traits.each do |trait|
          if trait.value.present?
            existing_traits[trait.key] = trait
          else
            existing_traits.delete(trait.key)
          end
        end

        @identity_traits = existing_traits.values
      end

      class << self
        def generate_composite_key(env_key, identifier)
          "#{env_key}_#{identifier}"
        end

        def build(json)
          identity_features = Flagsmiths::Engine::Identities::FeaturesList.build(json['identity_features'])
          identity_traits = json['identity_traits']&.map { |t| Flagsmiths::Engine::Identities::Trait.build(t) }

          Identity.new(
            identifier: json['identifier'], identity_uuid: json['identity_uuid'],
            environment_api_key: json['environment_api_key'], django_id: json['django_id'],
            created_date: json['created_date'],
            identity_features: identity_features, identity_traits: identity_traits || []
          )
        end
      end

      module Identities
        # TraitModel
        class Trait
          attr_reader :key, :value

          def initialize(key:, value:)
            @key = key
            @value = value
          end

          alias trait_key key
          alias trait_value value
        end

        class NotInuiqueFeatureState < StandardError; end

        # IdentityFeaturesList
        class FeaturesList
          include Enumerable

          def inititalize(list = [])
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

          class << self
            def build(identity_features)
              return [] unless identity_features.present?

              new(
                identity_features.map { |f| Flagsmiths::Engine::Features::State.build(f) }
              )
            end
          end
        end
      end
    end
  end
end
