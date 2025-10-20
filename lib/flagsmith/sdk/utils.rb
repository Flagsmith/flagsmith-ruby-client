# frozen_string_literal: true

module Flagsmith
  module SDK
    # Utility functions
    module Utils
      FLAGSMITH_USER_AGENT = 'flagsmith-ruby-sdk'
      FLAGSMITH_UNKNOWN_VERSION = 'unknown'

      module_function

      # Returns the user agent string for HTTP requests
      # @return [String] user agent in format "flagsmith-ruby-sdk/version"
      def user_agent
        "#{FLAGSMITH_USER_AGENT}/#{version}"
      end

      # Returns the SDK version
      # @return [String] version string or 'unknown' if not available
      def version
        return Flagsmith::VERSION if defined?(Flagsmith::VERSION)

        FLAGSMITH_UNKNOWN_VERSION
      rescue StandardError
        FLAGSMITH_UNKNOWN_VERSION
      end
    end
  end
end
