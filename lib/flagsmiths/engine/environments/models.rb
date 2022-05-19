# frozen_string_literal: true

module Flagsmiths
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
          project = Flagsmiths::Engine::Project.build(json['project'])
          feature_states = json['feature_states'].map do |fs|
            Flagsmiths::Engine::Features::State.build(fs)
          end

          new(
            id: json['id'], api_key: json['api_key'],
            project: project, feature_states: feature_states
          )
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
          @created_at = params.fetch(:created_at)
          @expires_at = params.fetch(:expires_at)
          @active = params.fetch(:active, true)
        end

        def valid?
          active && (!expires_at || expires_at > Time.now)
        end

        class << self
          def build(json)
            new(
              id: json['id'],
              key: json['key'],
              name: json['name'],
              client_api_key: json['client_api_key'],
              created_at: Date.parse(json['created_at'])
            )
          end
        end
      end
    end
  end
end
