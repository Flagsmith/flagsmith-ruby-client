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
end
