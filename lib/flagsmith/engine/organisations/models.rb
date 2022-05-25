# frozen_string_literal: true

module Flagsmith
  module Engine
    # OrganisationModel
    class Organisation
      attr_reader :id, :name, :feature_analitycs, :stop_serving_flags, :persist_trait_data

      def initialize(id:, name:, stop_serving_flags:, persist_trait_data:, feature_analitycs: nil)
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
          new(json.slice(:id, :name, :feature_analitycs, :stop_serving_flags, :persist_trait_data))
        end
      end
    end
  end
end
