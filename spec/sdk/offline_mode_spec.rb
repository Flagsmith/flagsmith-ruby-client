# frozen_string_literal: true

require 'spec_helper'


RSpec.describe Flagsmith::Client do
  it "gets environment flags with an environment document with an offline_handler" do
    offline_handler = \
    Flagsmith::OfflineHandlers::LocalFileHandler.new("spec/sdk/fixtures/environment.json")

    flagsmith = Flagsmith::Client.new(
      offline_mode: true,
      offline_handler: offline_handler,
    )

    response = flagsmith.get_environment_flags
    expect(response.count).to eq(2)
    expect(response.first[-1].feature_name).to eq("some_feature")
  end

  it "gets identity flags with an offline_handler" do
    offline_handler = \
    Flagsmith::OfflineHandlers::LocalFileHandler.new("spec/sdk/fixtures/environment.json")

    flagsmith = Flagsmith::Client.new(
      offline_mode: true,
      offline_handler: offline_handler,
    )

    response = flagsmith.get_identity_flags("some_identity")
    expect(response.first[-1].feature_name).to eq("some_feature")
  end

  it "raises an error if offline_mode is present but offline_handler is missing" do
    expect {
      flagsmith = Flagsmith::Client.new(offline_mode: true)
    }.to raise_error(
           Flagsmith::ClientError,
           "The offline_mode config param requires a matching offline_handler."
         )
  end

  it "raises an error if both the default_flag_handler and offline_handler are used" do
    default_flag_handler = lambda { |feature_name|
      Flagsmith::Flags::DefaultFlag.new(enabled: false, value: {}.to_json)
    }
    offline_handler = \
    Flagsmith::OfflineHandlers::LocalFileHandler.new("spec/sdk/fixtures/environment.json")
    expect {
      Flagsmith::Client.new(
        default_flag_handler: default_flag_handler,
        offline_handler: offline_handler,
      )
    }.to raise_error(
           Flagsmith::ClientError,
           "Cannot use offline_handler and default_flag_handler at the same time."
         )
  end
end

RSpec.describe Flagsmith::Flags::Collection do
  it "works with get_flag with an offline_handler" do
    offline_handler = \
    Flagsmith::OfflineHandlers::LocalFileHandler.new("spec/sdk/fixtures/environment.json")

    flags_collection = Flagsmith::Flags::Collection.new(offline_handler: offline_handler)
    flag = flags_collection.get_flag("some_feature")

    expect(flag.feature_name).to eq("some_feature")
    expect(flag.value).to eq("some-value")
  end
end
