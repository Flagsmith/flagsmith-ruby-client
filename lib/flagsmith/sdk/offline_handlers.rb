# frozen_string_literal: true

module Flagsmith
  module OfflineHandlers
    # Provides the offline_handler to the Flagsmith::Client.
    class LocalFileHandler
      attr_reader :environment

      def initialize(environment_document_path)
        environment_file = File.open(environment_document_path)

        data = JSON.parse(environment_file.read, symbolize_names: true)
        @environment = Flagsmith::Engine::Environment.build(data)
      end
    end
  end
end
