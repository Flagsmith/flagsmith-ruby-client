# frozen_string_literal: true

require 'spec_helper'

require_relative 'shared_mocks.rb'

RSpec.describe Flagsmith::AnalyticsProcessor do
  include_context "shared mocks"

  before(:each) do
    allow(mock_config).to receive(:enable_analytics?).and_return(true)
    allow(mock_config).to receive(:request_timeout_seconds).and_return(3)
    allow(mock_api_client).to receive(:post).with('analytics/flags/', any_args)
  end

  subject do Flagsmith::AnalyticsProcessor.new(
    api_client: flagsmith.api_client, timeout: flagsmith.config.request_timeout_seconds
    )
  end

  it 'test_analytics_processor_track_feature_updates_analytics_data' do
    subject.track_feature(1)
    expect(subject.analytics_data[1]).to eq(1)

    subject.track_feature(1)
    expect(subject.analytics_data[1]).to eq(2)
  end

  it 'test_analytics_processor_flush_clears_analytics_data' do
    subject.track_feature(1)
    subject.flush
    expect(subject.analytics_data).to eql({})
  end

  it 'test_analytics_processor_flush_post_request_data_match_ananlytics_data' do
    subject.track_feature(1)
    subject.track_feature(2)
    expect(flagsmith.api_client).to receive(:post).exactly(1).times do |uri_path, body|
      expect(uri_path).to eq('analytics/flags/')
      expect(body).to eq({ 1 => 1, 2 => 1 }.to_json)
    end
    subject.flush
  end
end
