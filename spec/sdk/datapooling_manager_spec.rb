# frozen_string_literal: true

require 'spec_helper'

require_relative 'shared_mocks.rb'

RSpec.describe Flagsmith::EnvironmentDataPollingManager do
  include_context "shared mocks"

  let(:api_environment_response) { File.read('spec/sdk/fixtures/environment.json') }
  let(:environemnt_response) { OpenStruct.new(body: JSON.parse(api_environment_response, symbolize_names: true)) }
  let(:refresh_interval_seconds) { 0.01 }
  let(:delay_time) { 0.045 }

  before(:each) do
    allow(Thread).to receive(:new).and_call_original
    allow(Thread).to receive(:kill).and_call_original
    allow(mock_api_client).to receive(:get).with('environment-document/').and_return(environemnt_response)
    allow(double(Flagsmith::Config)).to receive(:environment_url).and_return("environment-document/")
  end

  subject { Flagsmith::EnvironmentDataPollingManager.new(flagsmith, refresh_interval_seconds, 10) }

  it 'test_polling_manager_calls_update_environment_on_start' do
    times = (delay_time / refresh_interval_seconds).to_i
    expect(flagsmith).to receive(:update_environment).exactly(times).times
    subject.start
    sleep delay_time
    subject.stop
  end
end
