# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Flagsmith::Engine::Organisation do
  context '#build then unique_slug' do
    let!(:model) do
      Flagsmith::Engine::Organisation.build(
        persist_trait_data: true,
        name: 'Flagsmith',
        feature_analytics: false,
        stop_serving_flags: false,
        id: 13
      )
    end

    it { expect(model.unique_slug).to eq('13-Flagsmith') }
  end
end
