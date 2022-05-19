# frozen_string_literal: true

module Flagsmiths
  module Engine
    # FeatureModel
    class Feature
      attr_reader :id, :name, :type

      def initialize(id:, name:, type:)
        @id = id
        @name = name
        @type = type
      end

      def ==(other)
        other.present? && id == other.id
      end

      class << self
        def build(json)
          new(
            id: json['id'],
            name: json['name'],
            type: json['type']
          )
        end
      end
    end

    module Features
      # MultivariateFeatureOptionModel
      class MultivariateOption
        attr_reader :value, :id

        def initialize(value:, id: nil)
          @value = value
          @id = id
        end

        class << self
          def build(json = {})
            new(
              value: json['value'],
              id: json['id']
            )
          end
        end
      end

      # MultivariateFeatureStateValueModel
      class MultivariateStateValue
        attr_reader :id, :multivariate_feature_option, :percentage_allocation, :mv_fs_value_uuid

        def inititalize(id:, multivariate_feature_option:, percentage_allocation:, mv_fs_value_uuid: SecureRandom.uuid)
          @id = id
          @percentage_allocation = percentage_allocation
          @multivariate_feature_option = multivariate_feature_option
          @mv_fs_value_uuid = mv_fs_value_uuid
        end

        def <=>(other)
          if id.present? && other.id.present?
            id - other.id
          else
            mv_fs_value_uuid <=> other.mv_fs_value_uuid
          end
        end

        class << self
          def build(json)
            new(
              id: json['id'], percentage_value: json['percentage_value'],
              multivariate_feature_option: MultivariateOption.build(json['multivariate_feature_option'])
            )
          end
        end
      end

      # FeatureStateModel
      class State
        attr_reader :feature, :enabled, :django_id, :uuid
        attr_accessor :multivariate_feature_state_values

        def initialize(params = {})
          @feature = params.fetch(:feature)
          @enabled = params.fetch(:enabled)
          @django_id = params.fetch(:django_id)
          @value = params.fetch(:value, nil)
          @uuid = params.fetch(:uuid, SecureRandom.uuid)
          @multivariate_feature_state_values = params.fetch(:multivariate_feature_state_values, [])
        end

        attr_writer :value

        def value(identity_id = nil)
          if identity_id.present? && multivariate_feature_state_values.length.positive?
            return multivariate_value(identity_id)
          end

          @value
        end

        alias feature_state_value value
        alias feature_state_uuid uuid

        def multivariate_value(identity_id)
          percentage_value = hashed_percentate_for_obj_ids(django_id || uuid, identity_id)

          start_percentage = 0
          multivariate_feature_state_values.sort.each do |my_value|
            limit = my_value.percentage_allocation + start_percentage
            if start_percentage <= percentage_value && percentage_value < limit
              return my_value.multivariate_feature_option.value
            end

            start_percentage = limit
          end
          @value
        end

        class << self
          def build(json)
            new(
              uuid: json['uuid'],
              enabled: json['enabled'],
              django_id: json['django_id'],
              feature_state_value: json['feature_state_value'],
              feature: Flagsmiths::Engine::Feature.build(json['feature'])
            ).tap do |model|
              model.multivariate_feature_state_values =
                build_multivariate_feature_state_values(json['multivariate_feature_state_values'])
            end
          end

          def build_multivariate_feature_state_values(multivariate_feature_state_values)
            return [] unless multivariate_feature_state_values&.any?

            multivariate_feature_state_values.map do |fsv|
              MultivariateStateValue.build(fsv)
            end
          end
        end
      end
    end
  end
end
