# frozen_string_literal: true

require 'logger'
require 'faraday'
require 'json'

module Flagsmith
  # Ruby client for realtime access to flagsmith.com
  class RealtimeClient
    attr_accessor :running

    def initialize(config)
      @config = config
      @thread = nil
      @running = false
      @main = nil
    end

    def endpoint
      "#{@config.realtime_api_url}sse/environments/#{@main.environment.api_key}/stream"
    end

    def listen(main, remaining_attempts: Float::INFINITY, retry_interval: 0.5) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength
      last_updated_at = 0
      @main = main
      @running = true
      @thread = Thread.new do
        while @running && remaining_attempts.positive?
          remaining_attempts -= 1
          @config.logger.warn 'Beginning to pull down realtime endpoint'
          begin
            sleep retry_interval
            # Open connection to SSE endpoint
            Faraday.new(url: endpoint).get do |req|
              req.options.timeout = nil # Keep connection alive indefinitely
              req.options.open_timeout = 10
            end.body.each_line do |line| # rubocop:disable Style/MultilineBlockChain
              # SSE protocol: Skip non-event lines
              next if line.strip.empty? || line.start_with?(':')

              # Parse SSE fields
              next unless line.start_with?('data: ')

              data = JSON.parse(line[6..].strip)
              updated_at = data['updated_at']
              next unless updated_at > last_updated_at

              @config.logger.info "Realtime updating environment from #{last_updated_at} to #{updated_at}"
              @main.update_environment
              last_updated_at = updated_at
            end
          rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
            @config.logger.warn "Connection failed: #{e.message}. Retrying in #{retry_interval} seconds..."
          rescue StandardError => e
            @config.logger.error "Error: #{e.message}. Retrying in #{retry_interval} seconds..."
          end
        end
      end

      @running = false
    end
  end
end
