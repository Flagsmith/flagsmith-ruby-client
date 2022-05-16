# frozen_string_literal: true

module Flagsmith
  module Engine
    # EnvironmentModel
    class Environment
      attr_reader :id, :api_key
      attr_accessor :project, :feature_states, :amplitude_config, :segment_config,
                    :mixpanel_config, :heap_config

      def initialize(id:, api_key:, project:, feature_states: [])
        @id = id
        @api_key = api_key
        @project = project
        @feature_states = feature_states
      end

      class << self
        def build(json)
          project = Flagsmith::Engine::Project.build(json[:project])
          feature_states = json[:feature_states].map do |fs|
            Flagsmith::Engine::FeatureState.build(fs)
          end

          new(**json.slice(:id, :api_key).merge(project: project, feature_states: feature_states))
        end
      end
    end

    module Environments
      # EnvironmentApiKeyModel
      class ApiKey
        attr_reader :id, :key, :created_at, :name, :client_api_key
        attr_accessor :expires_at, :active

        def initialize(params = {})
          @id = params.fetch(:id)
          @key = params.fetch(:key)
          @name = params.fetch(:name)
          @client_api_key = params.fetch(:client_api_key)
          @created_at = params.fetch(:created_at, Time.now)
          @expires_at = params.fetch(:expires_at, nil)
          @active = params.fetch(:active, true)
        end

        def valid?
          active && (!expires_at || expires_at > Time.now)
        end

        class << self
          def build(json)
            attributes = json.slice(:id, :key, :name, :client_api_key, :active)
            attributes = attributes.merge(expires_at: Date.parse(json[:created_at])) unless json[:created_at].nil?
            attributes = attributes.merge(expires_at: Date.parse(json[:expires_at])) unless json[:expires_at].nil?
            new(**attributes)
          end
        end
      end
    end
  end
end
