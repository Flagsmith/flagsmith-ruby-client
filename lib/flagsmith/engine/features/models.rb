# frozen_string_literal: true

require_relative '../utils/hash_func'

module Flagsmith
  module Engine
    # FeatureStateModel
    class FeatureState
      include Flagsmith::Engine::Utils::HashFunc

      attr_reader :feature, :enabled, :django_id, :uuid, :feature_segment
      attr_accessor :multivariate_feature_state_values

      def initialize(params = {})
        @feature = params.fetch(:feature)
        @enabled = params.fetch(:enabled)
        @feature_segment = params.fetch(:feature_segment, nil)
        @django_id = params.fetch(:django_id, nil)
        @feature_state_value = params.fetch(:feature_state_value, nil)
        @uuid = params.fetch(:uuid, SecureRandom.uuid)
        @multivariate_feature_state_values = params.fetch(:multivariate_feature_state_values, [])
      end

      attr_writer :feature_state_value

      def get_value(identity_id = nil)
        return multivariate_value(identity_id) if identity_id && multivariate_feature_state_values.length.positive?

        @feature_state_value
      end

      alias set_value feature_state_value=
      alias feature_state_uuid uuid
      alias enabled? enabled

      def multivariate_value(identity_id)
        percentage_value = hashed_percentage_for_object_ids([django_id || uuid, identity_id])

        start_percentage = 0
        multivariate_feature_state_values.sort.each do |multi_fs_value|
          limit = multi_fs_value.percentage_allocation + start_percentage

          if start_percentage <= percentage_value && percentage_value < limit
            return multi_fs_value.multivariate_feature_option.value
          end

          start_percentage = limit
        end
        @feature_state_value
      end

      # Returns `true` if `self` is higher segment priority than `other`
      # (i.e. has lower value for feature_segment.priority)
      # NOTE:
      #     A segment will be considered higher priority only if:
      #     1. `other` does not have a feature segment
      #        (i.e: it is an environment feature state or it's a
      #        feature state with feature segment but from an old document
      #        that does not have `feature_segment.priority`)
      #        but `self` does.
      #     2. `other` have a feature segment with high priority
      def higher_segment_priority?(other)
        feature_segment.priority.to_i < (other&.feature_segment&.priority || Float::INFINITY)
      rescue TypeError, NoMethodError
        false
      end

      class << self
        def build(json)
          multivariate_feature_state_values = build_multivariate_values(json[:multivariate_feature_state_values])
          attributes = json.slice(:uuid, :enabled, :django_id, :feature_state_value)
                           .merge(feature: Flagsmith::Engine::Feature.build(json[:feature]))
                           .merge(multivariate_feature_state_values: multivariate_feature_state_values)
          if json.key?(:feature_segment) && !json[:feature_segment].nil?
            attributes = attributes.merge(
              feature_segment: Flagsmith::Engine::Features::Segment.new(json[:feature_segment])
            )
          end
          new(**attributes)
        end

        def build_multivariate_values(multivariate_feature_state_values)
          return [] unless multivariate_feature_state_values&.any?

          multivariate_feature_state_values.map do |fsv|
            Flagsmith::Engine::Features::MultivariateStateValue.build(fsv)
          end
        end
      end
    end

    # FeatureModel
    class Feature
      attr_reader :id, :name, :type

      def initialize(id:, name:, type:)
        @id = id
        @name = name
        @type = type
      end

      def ==(other)
        return false if other.nil?

        id == other.id
      end

      class << self
        def build(json)
          new(**json.slice(:id, :name, :type))
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
          def build(json)
            new(**json.slice(:id, :value))
          end
        end
      end

      # MultivariateFeatureStateValueModel
      class MultivariateStateValue
        attr_reader :id, :multivariate_feature_option, :percentage_allocation, :mv_fs_value_uuid

        def initialize(id:, multivariate_feature_option:, percentage_allocation:, mv_fs_value_uuid: SecureRandom.uuid)
          @id = id
          @percentage_allocation = percentage_allocation
          @multivariate_feature_option = multivariate_feature_option
          @mv_fs_value_uuid = mv_fs_value_uuid
        end

        def <=>(other)
          return false if other.nil?

          if !id.nil? && !other.id.nil?
            id - other.id
          else
            mv_fs_value_uuid <=> other.mv_fs_value_uuid
          end
        end

        class << self
          def build(json)
            new(
              **json.slice(:id, :percentage_allocation, :mv_fs_value_uuid)
                    .merge(multivariate_feature_option: MultivariateOption.build(json[:multivariate_feature_option]))
            )
          end
        end
      end

      # FeatureSegment
      class Segment
        attr_reader :priority

        def initialize(params = {})
          @priority = params[:priority].nil? ? nil : params[:priority].to_i
        end
      end
    end
  end
end
