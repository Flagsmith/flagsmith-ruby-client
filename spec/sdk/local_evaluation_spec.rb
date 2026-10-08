# frozen_string_literal: true

require 'spec_helper'

require_relative 'shared_mocks.rb'

RSpec.describe Flagsmith do
  include_context 'shared mocks'

  describe '#get_identity_overrides_flags' do
    it 'should return identity overrides in local evaluation' do
      allow_any_instance_of(Flagsmith::Client).to receive(:api_client).and_return(mock_api_client)

      flagsmith = Flagsmith::Client.new(environment_key: mock_api_key, api_url: mock_api_url, enable_local_evaluation: true)
      expect(flagsmith.config.local_evaluation?).to be_truthy

      flag = flagsmith.get_identity_flags("overridden-id").get_flag("some_feature")

      expect(flag.enabled).to be_falsy
      expect(flag.value).to eq("some-overridden-value")
    end
  end

  describe '#get_multivariate_flags' do
    it 'should return a 100% multivariate variation in local evaluation' do
      allow_any_instance_of(Flagsmith::Client).to receive(:api_client).and_return(mock_api_client)

      flagsmith = Flagsmith::Client.new(environment_key: mock_api_key, api_url: mock_api_url, enable_local_evaluation: true)
      expect(flagsmith.config.local_evaluation?).to be_truthy

      flag = flagsmith.get_identity_flags("some-identifier").get_flag("test_mv")

      expect(flag.enabled).to be_falsy
      expect(flag.value).to eq("8888")
    end
  end

  describe 'paginating the environment document' do
    let(:environment_document) { JSON.parse(api_environment_document_response, symbolize_names: true) }
    let(:page_two_id) { 'identity_override:1:page-2' }
    let(:page_three_id) { 'identity_override:1:page-3' }

    def next_page_link(page_id)
      { 'link' => "</api/v1/environment-document/?page_id=#{URI.encode_www_form_component(page_id)}>; rel=\"next\"" }
    end

    def override_page(identifier)
      override = environment_document[:identity_overrides].first.merge(identifier: identifier)
      { identity_overrides: [override] }
    end

    it 'appends the identity overrides of every page' do
      allow_any_instance_of(Flagsmith::Client).to receive(:api_client).and_return(mock_api_client)
      allow(mock_api_client).to receive(:get).with('environment-document/')
        .and_return(OpenStruct.new(body: environment_document, headers: next_page_link(page_two_id)))
      allow(mock_api_client).to receive(:get).with('environment-document/', page_id: page_two_id)
        .and_return(OpenStruct.new(body: override_page('page-2-id'), headers: next_page_link(page_three_id)))
      allow(mock_api_client).to receive(:get).with('environment-document/', page_id: page_three_id)
        .and_return(OpenStruct.new(body: override_page('page-3-id'), headers: {}))

      flagsmith = Flagsmith::Client.new(environment_key: mock_api_key, api_url: mock_api_url, enable_local_evaluation: true)

      expect(flagsmith.identity_overrides_by_identifier.keys).to eq(%w[overridden-id page-2-id page-3-id])
      expect(flagsmith.get_identity_flags('page-3-id').get_flag('some_feature').value).to eq('some-overridden-value')
    end

    it 'makes a single request when the environment fits in one page' do
      allow_any_instance_of(Flagsmith::Client).to receive(:api_client).and_return(mock_api_client)

      Flagsmith::Client.new(environment_key: mock_api_key, api_url: mock_api_url, enable_local_evaluation: true)

      expect(mock_api_client).to have_received(:get).with('environment-document/').once
    end

    it 'warns when fetching takes longer than the refresh interval' do
      allow_any_instance_of(Flagsmith::Client).to receive(:api_client).and_return(mock_api_client)
      allow(Process).to receive(:clock_gettime).and_return(0.0, 75.2)
      logger = Logger.new(log_io = StringIO.new)

      flagsmith = Flagsmith::Client.new(
        environment_key: mock_api_key, api_url: mock_api_url,
        environment_refresh_interval_seconds: 60, logger: logger
      )
      flagsmith.update_environment

      expect(log_io.string).to include(
        'Fetching the environment document took 75.2s, longer than the environment refresh interval of 60.0s'
      )
    end
  end
end
