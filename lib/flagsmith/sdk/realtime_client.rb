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

    def listen(main, remaining_attempts: Float::INFINITY, retry_interval: 0.5) # rubocop:disable Metrics/MethodLength
      @last_updated_at = 0
      @main = main
      @running = true
      @thread = Thread.new do
        while @running && remaining_attempts.positive?
          remaining_attempts -= 1
          @config.logger.warn 'Beginning to pull down realtime endpoint'
          begin
            sleep retry_interval
            stream_events
          rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
            @config.logger.warn "Connection failed: #{e.message}. Retrying in #{retry_interval} seconds..."
          rescue StandardError => e
            @config.logger.error "Error: #{e.message}. Retrying in #{retry_interval} seconds..."
          end
        end
      ensure
        @running = false
      end
    end

    private

    # Open connection to SSE endpoint and handle the events as they arrive,
    # rather than once the server closes the connection.
    def stream_events
      buffer = +''
      Faraday.new(url: endpoint).get do |req|
        req.options.timeout = nil # Keep connection alive indefinitely
        req.options.open_timeout = 10
        req.options.on_data = proc do |chunk, _received_bytes, _env|
          buffer << chunk
          process_line(buffer.slice!(/.*\n/)) while buffer.include?("\n")
        end
      end
    end

    def process_line(line)
      # SSE protocol: Skip non-event lines
      return if line.strip.empty? || line.start_with?(':')

      # Parse SSE fields
      return unless line.start_with?('data: ')

      data = JSON.parse(line[6..].strip)
      updated_at = data['updated_at']
      return unless updated_at > @last_updated_at

      @config.logger.info "Realtime updating environment from #{@last_updated_at} to #{updated_at}"
      @main.update_environment
      @last_updated_at = updated_at
    end
  end
end
