# frozen_string_literal: true

require 'logger'

module Flagsmiths
  # Ruby client for flagsmith.com
  class ApiClient
    extend Forwardable

    HTTP_METHODS_ALLOW_LIST = %i[get post].freeze

    delegate HTTP_METHODS_ALLOW_LIST => :@conn

    def initialize(config)
      @config = config
      @conn = Faraday.new(url: @config.api_url) do |f|
        build_headers(f)
        f.response :json
        f.adapter Faraday.default_adapter

        f.options.timeout = @config.request_timeout_seconds
        configure_logger(f)
        configure_retries(f)
      end

      freeze
    end

    # def get_flags(user_id = nil)
    #   if user_id.nil?
    #     res = get('flags/')
    #     Flagsmiths::Flags::Collection.from_api(
    #       res.body.select { |flag| flag['feature_segment'].nil? }, user_id
    #     )
    #   else
    #     res = get("identities/?identifier=#{user_id}")
    #     Flagsmiths::Flags::Collection.from_api(res.body['flags'], user_id)
    #   end
    # end

    private

    def build_headers(faraday)
      faraday.headers['Accept'] = 'application/json'
      faraday.headers['Content-Type'] = 'application/json'
      faraday.headers['X-Environment-Key'] = @config.environment_key
      faraday.headers.merge(@config.custom_headers)
    end

    def configure_logger(faraday)
      faraday.response :logger, @config.logger, body: true, bodies: { request: true, response: true }
    end

    def configure_retries(faraday)
      return unless @config.retries

      faraday.request :retry
      faraday.options.retries = @config.retries
    end
  end
end
