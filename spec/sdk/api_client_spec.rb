# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Flagsmith::ApiClient do
  let(:config) do
    Flagsmith::Config.new(
      environment_key: 'test-key',
      api_url: 'https://edge.api.flagsmith.com/api/v1/'
    )
  end

  describe 'headers' do
    it 'sets User-Agent header with SDK version' do
      api_client = described_class.new(config)
      connection = api_client.instance_variable_get(:@conn)

      expected_user_agent = "flagsmith-ruby-sdk/#{Flagsmith::VERSION}"
      expect(connection.headers['User-Agent']).to eq(expected_user_agent)
    end

    it 'applies custom_headers alongside the default headers' do
      custom_config = Flagsmith::Config.new(
        environment_key: 'test-key',
        api_url: 'https://edge.api.flagsmith.com/api/v1/',
        custom_headers: { 'Authorization' => 'Bearer proxy-token', 'X-Proxy-Token' => 'abc' }
      )
      connection = described_class.new(custom_config).instance_variable_get(:@conn)

      expect(connection.headers['Authorization']).to eq('Bearer proxy-token')
      expect(connection.headers['X-Proxy-Token']).to eq('abc')
      expect(connection.headers['X-Environment-Key']).to eq('test-key')
    end
  end
end
