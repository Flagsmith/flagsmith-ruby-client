# frozen_string_literal: true

require 'spec_helper'

# require File.join(APP_ROOT, 'lib/flagsmiths/engine/core')

def load_test_cases(filepath)
  data = JSON.parse(File.open(filepath).read, symbolize_names: false)
  environment = Flagsmiths::Engine::Environment.build(data['environment'])

  data['identities_and_responses'].map do |test_case|
    identity = Flagsmiths::Engine::Identity.build(test_case['identity'])
    {
      'environment' => environment,
      'identity' => identity,
      'response' => test_case['response']
    }
  end
end

RSpec.describe Flagsmiths::Engine::Core do
  load_test_cases(
    File.join(APP_ROOT, 'spec/engine-test-data/data/environment_n9fbf9h3v4fFgH3U3ngWhb.json')
  ).each do |test_case|
    engine = Class.new { extend Flagsmiths::Engine::Core }
    json_flags = test_case.dig('response', 'flags').sort_by { |json| json.dig('feature', 'name') }
    feature_states = engine.get_identity_feature_states(test_case['environment'], test_case['identity']).sort_by { |fs| fs.feature.name }

    it { expect(feature_states.length).to eq(json_flags.length) }

    json_flags.each.with_index do |json_flag, index|
      describe "feature state with ID #{json_flag.dig('feature', 'id')}" do
        subject { feature_states[index] }

        it { expect(subject.enabled?).to eq(json_flag['enabled']) }
        it { expect(subject.value(test_case['identity'].django_id)).to eq(json_flag['feature_state_value']) }
      end
    end
  end
end
