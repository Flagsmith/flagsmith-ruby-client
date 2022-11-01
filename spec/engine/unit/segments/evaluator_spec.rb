# frozen_string_literal: true

require 'spec_helper'

# list of test cases containing: operator, property, value, traits (list of dicts), expected_result
TEST_CASES = [
    ['IS_SET', 'foo', nil, {}, false],
    ['IS_SET', 'foo', nil, {'foo': 'bar'}, true],
    ['IS_NOT_SET', 'foo', nil, {}, true],
    ['IS_NOT_SET', 'foo', nil, {'foo': 'bar'}, false],
]

RSpec.describe Flagsmith::Engine::Segments::Evaluator do
  subject { Class.new { extend Flagsmith::Engine::Segments::Evaluator } }

  TEST_CASES.each do |(operator, property, value, traits, expected_result)|
    it "traits: #{traits} #traits_match_segment_condition(#{operator}, #{property}, #{value || 'No value'}) should be #{expected_result}" do
      condition = Flagsmith::Engine::Segments::Condition.new(
        operator: operator, property: property, value: value
      )
      trait_models = traits.map { 
        |k,v| Flagsmith::Engine::Identities::Trait.new(trait_key: k, trait_value: v) 
      }

      expect(subject.traits_match_segment_condition(
        trait_models, condition, 1, 1)).to eq(expected_result)
    end
  end
end
