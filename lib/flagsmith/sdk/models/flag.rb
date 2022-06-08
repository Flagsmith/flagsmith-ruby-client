# frozen_string_literal: true

require_relative './base_flag'

module Flagsmith
  # Flag object
  class Flag < BaseFlag

    attr_reader :feature_name, :feature_id

    def initialize(feature_name:, enabled:, value:, feature_id:)
      super(enabled: enabled, value: value, default: false)
      @feature_name = feature_name
      @feature_id = feature_id
    end

    def <=>(other)
      feature_name <=> other.feature_name
    end

    def [](key)
      to_h[key]
    end

    def to_h
      {
        feature_id: feature_id,
        feature_name: feature_name,
        value: value,
        enabled: enabled,
        default: default
      }
    end

    class << self
      def from_feature_state_model(feature_state_model, identity_id)
        new(
          enabled: feature_state_model.enabled,
          value: feature_state_model.get_value(identity_id),
          feature_name: feature_state_model.feature.name,
          feature_id: feature_state_model.feature.id
        )
      end

      def from_api(json_flag_data)
        new(
          enabled: json_flag_data[:enabled],
          value: json_flag_data[:feature_state_value] || json_flag_data[:value],
          feature_name: json_flag_data.dig(:feature, :name),
          feature_id: json_flag_data.dig(:feature, :id)
        )
      end
    end
  end
end
