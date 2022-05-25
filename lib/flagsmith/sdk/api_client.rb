# frozen_string_literal: true

require 'logger'

module Flagsmith
  # Ruby client for flagsmith.com
  class ApiClient
    extend Forwardable

    HTTP_METHODS_ALLOW_LIST = %i[get post].freeze

    delegate HTTP_METHODS_ALLOW_LIST => :@conn

    def initialize(config)
      @conn = Faraday.new(url: config.api_url) do |f|
        build_headers(f, config)
        f.response :json, parser_options: { symbolize_names: true }
        f.adapter Faraday.default_adapter

        f.options.timeout = config.request_timeout_seconds
        configure_logger(f, config)
        configure_retries(f, config)
      end

      freeze
    end

    private

    def build_headers(faraday, config)
      faraday.headers['Accept'] = 'application/json'
      faraday.headers['Content-Type'] = 'application/json'
      faraday.headers['X-Environment-Key'] = config.environment_key
      faraday.headers.merge(config.custom_headers)
    end

    def configure_logger(faraday, config)
      faraday.response :logger, config.logger
    end

    def configure_retries(faraday, config)
      return unless config.retries

      faraday.request :retry, { max: config.retries }
    end
  end
end
