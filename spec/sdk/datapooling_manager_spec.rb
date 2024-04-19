# frozen_string_literal: true
require 'spec_helper'

require_relative 'shared_mocks.rb'

RSpec.describe Flagsmith::EnvironmentDataPollingManager do
  include_context "shared mocks"

  let(:api_environment_response) { File.read('spec/sdk/fixtures/environment.json') }
  let(:environment_response) { OpenStruct.new(body: JSON.parse(api_environment_response, symbolize_names: true)) }
  let(:refresh_interval_seconds) { 0.01 }
  let(:delay_time) { 0.045 }

  before(:each) do
    allow(Thread).to receive(:new).and_call_original
    allow(Thread).to receive(:kill).and_call_original
    allow(mock_api_client).to receive(:get).with('environment-document/').and_return(environment_response)
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


class FakeFlagsmith
  attr_accessor :raise_error, :config

  def initialize config
    @config = config
  end

  def update_environment
    if @raise_error
      raise StandardError, "Some networking issue"
    else
      # Perform update logic
    end
  end
end

RSpec.describe Flagsmith::EnvironmentDataPollingManager do
  include_context "shared mocks"

  let(:refresh_interval_seconds) { 0.01 }
  let(:delay_time) { 0.045 }
  let(:update_failures_limit) { 5 }
  let(:fake_flagsmith) { FakeFlagsmith.new mock_config }

  before :each do
    allow(mock_config).to receive(:logger).and_return(Logger.new($stdout))
  end

  subject { Flagsmith::EnvironmentDataPollingManager.new(fake_flagsmith, refresh_interval_seconds, update_failures_limit) }

  it "operates under an error prone environment" do
    fake_flagsmith.raise_error = true

    # Four invocations are processed without the error bubbling up.
    times = (delay_time / refresh_interval_seconds).to_i
    subject.start
    sleep delay_time
    # Show that the failures are recorded without raising.
    expect(subject.failures_since_last_update).to eq(4)

    # Now set flagsmith to respond as normal.
    fake_flagsmith.raise_error = false
    sleep delay_time

    # Now the exception count is back to zero.
    expect(subject.failures_since_last_update).to eq(0)
    subject.stop
  end
end
