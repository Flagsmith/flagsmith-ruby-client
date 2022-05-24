# frozen_string_literal: true

module Flagsmith
  module Engine
    # OrganisationModel
    class Organisation
      attr_reader :id, :name, :feature_analitycs, :stop_serving_flags, :persist_trait_data

      def initialize(id:, name:, feature_analitycs:, stop_serving_flags:, persist_trait_data:)
        @id = id
        @name = name
        @feature_analitycs = feature_analitycs
        @stop_serving_flags = stop_serving_flags
        @persist_trait_data = persist_trait_data
      end

      def unique_slug
        "#{id}-#{name}"
      end

      class << self
        def build(json)
          new(
            id: json['id'],
            name: json['name'],
            feature_analitycs: json['feature_analitycs'],
            stop_serving_flags: json['stop_serving_flags'],
            persist_trait_data: json['persist_trait_data']
          )
        end
      end
    end
  end
end
