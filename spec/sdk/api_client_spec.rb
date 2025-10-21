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
  end
end
