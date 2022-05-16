# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_context 'shared mocks', shared_context: :metadata do
  let(:mock_api_client) { double(Flagsmith::ApiClient) }
  let(:mock_config) { double(Flagsmith::Config) }
  let(:mock_api_key) { 'ASDFIEVNQWEPARJ' }
  let(:mock_api_url) { 'http://mock.flagsmith.com/api/' }

  let(:user_id) { 'user@email.none' }

  let(:api_flags_response) { File.read('spec/sdk/fixtures/flags.json') }
  let(:api_identities_response) { File.read('spec/sdk/fixtures/identities.json') }

  let(:flags_response) { OpenStruct.new(body: JSON.parse(api_flags_response, symbolize_names: true)) }
  let(:identities_response) { OpenStruct.new(body: JSON.parse(api_identities_response, symbolize_names: true)) }

  before do
    allow(mock_config).to receive(:new).with(api_url: mock_api_url, environment_key: mock_api_key)
                                       .and_return(mock_config)
    allow(mock_config).to receive(:enable_analytics?).and_return(false)
    allow(mock_config).to receive(:local_evaluation?).and_return(false)
    allow(mock_config).to receive(:default_flag_handler).and_return(nil)
    allow(mock_config).to receive(:identities_url).and_return('identities/')
    allow(mock_config).to receive(:environment_flags_url).and_return('flags/')
    allow(mock_api_client).to receive(:new).with(mock_config)
                                           .and_return(mock_api_client)
    allow(mock_api_client).to receive(:get).with('flags/').and_return(flags_response)
    allow(mock_api_client).to receive(:post).with(
      'identities/', { identifier: user_id, traits: [] }.to_json
    ).and_return(identities_response)

    allow(flagsmith).to receive(:api_client).and_return(mock_api_client)
  end

  let!(:flagsmith) { Flagsmith::Client.new(environment_key: mock_api_key, api_url: mock_api_url) }
end
