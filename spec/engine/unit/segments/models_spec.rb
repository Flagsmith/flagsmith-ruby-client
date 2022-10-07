# frozen_string_literal: true

require 'spec_helper'

TEST_CASES = [
  # ['EQUAL', 'bar', 'bar', true],
  # ['EQUAL', 'bar', 'baz', false],
  # ['EQUAL', 1, '1', true],
  # ['EQUAL', 1, '2', false],
  # ['EQUAL', true, 'true', true],
  # ['EQUAL', false, 'false', true],
  # ['EQUAL', false, 'true', false],
  # ['EQUAL', true, 'false', false],
  # ['EQUAL', 1.23, '1.23', true],
  # ['EQUAL', 1.23, '4.56', false],
  # ['GREATER_THAN', 2, '1', true],
  # ['GREATER_THAN', 1, '1', false],
  # ['GREATER_THAN', 0, '1', false],
  # ['GREATER_THAN', 2.1, '2.0', true],
  # ['GREATER_THAN', 2.1, '2.1', false],
  # ['GREATER_THAN', 2.0, '2.1', false],
  # ['GREATER_THAN_INCLUSIVE', 2, '1', true],
  # ['GREATER_THAN_INCLUSIVE', 1, '1', true],
  # ['GREATER_THAN_INCLUSIVE', 0, '1', false],
  # ['GREATER_THAN_INCLUSIVE', 2.1, '2.0', true],
  # ['GREATER_THAN_INCLUSIVE', 2.1, '2.1', true],
  # ['GREATER_THAN_INCLUSIVE', 2.0, '2.1', false],
  # ['LESS_THAN', 1, '2', true],
  # ['LESS_THAN', 1, '1', false],
  # ['LESS_THAN', 1, '0', false],
  # ['LESS_THAN', 2.0, '2.1', true],
  # ['LESS_THAN', 2.1, '2.1', false],
  # ['LESS_THAN', 2.1, '2.0', false],
  # ['LESS_THAN_INCLUSIVE', 1, '2', true],
  # ['LESS_THAN_INCLUSIVE', 1, '1', true],
  # ['LESS_THAN_INCLUSIVE', 1, '0', false],
  # ['LESS_THAN_INCLUSIVE', 2.0, '2.1', true],
  # ['LESS_THAN_INCLUSIVE', 2.1, '2.1', true],
  # ['LESS_THAN_INCLUSIVE', 2.1, '2.0', false],
  # ['NOT_EQUAL', 'bar', 'baz', true],
  # ['NOT_EQUAL', 'bar', 'bar', false],
  # ['NOT_EQUAL', 1, '2', true],
  # ['NOT_EQUAL', 1, '1', false],
  # ['NOT_EQUAL', true, 'false', true],
  # ['NOT_EQUAL', false, 'true', true],
  # ['NOT_EQUAL', false, 'false', false],
  # ['NOT_EQUAL', true, 'true', false],
  # ['CONTAINS', 'bar', 'b', true],
  # ['CONTAINS', 'bar', 'bar', true],
  # ['CONTAINS', 'bar', 'baz', false],
  # ['NOT_CONTAINS', 'bar', 'b', false],
  # ['NOT_CONTAINS', 'bar', 'bar', false],
  # ['NOT_CONTAINS', 'bar', 'baz', true],
  # ['REGEX', 'foo', /[a-z]+/, true],
  # ['REGEX', 'FOO', /[a-z]+/, false],
  # ['REGEX', '1.2.3', /\d/, true],

  # ['EQUAL', '1.0.0', '1.0.0:semver', true],
  # ['EQUAL', '1.0.0', '1.0.1:semver', false],
  # ['NOT_EQUAL', '1.0.0', '1.0.0:semver', false],
  # ['NOT_EQUAL', '1.0.0', '1.0.1:semver', true],
  # ['GREATER_THAN', '1.0.1', '1.0.0:semver', true],
  # ['GREATER_THAN', '1.0.0', '1.0.0-beta:semver', true],
  # ['GREATER_THAN', '1.0.1', '1.2.0:semver', false],
  # ['GREATER_THAN', '1.0.1', '1.0.1:semver', false],
  # ['GREATER_THAN', '1.2.4', '1.2.3-pre.2+build.4:semver', true],
  # ['LESS_THAN', '1.0.0', '1.0.1:semver', true],
  # ['LESS_THAN', '1.0.0', '1.0.0:semver', false],
  # ['LESS_THAN', '1.0.1', '1.0.0:semver', false],
  # ['LESS_THAN', '1.0.0-rc.2', '1.0.0-rc.3:semver', true],
  # ['GREATER_THAN_INCLUSIVE', '1.0.1', '1.0.0:semver', true],
  # ['GREATER_THAN_INCLUSIVE', '1.0.1', '1.2.0:semver', false],
  # ['GREATER_THAN_INCLUSIVE', '1.0.1', '1.0.1:semver', true],
  # ['LESS_THAN_INCLUSIVE', '1.0.0', '1.0.1:semver', true],
  # ['LESS_THAN_INCLUSIVE', '1.0.0', '1.0.0:semver', true],
  # ['LESS_THAN_INCLUSIVE', '1.0.1', '1.0.0:semver', false],
  ['MODULO', 2, '2|0', true],
  ['MODULO', 3, '2|0', false],
  ['MODULO', 2.0, '2|0', true],
  ['MODULO', 'foo', '2|0', false],
  ['MODULO', 'foo', 'foo|bar', false],
].freeze

RSpec.describe Flagsmith::Engine::Segments::Condition do
  TEST_CASES.each do |(operator, trait_value, condition_value, expected_result)|
    it "#{operator}, #{condition_value} #match_trait_value #{trait_value}" do
      segment_condition = Flagsmith::Engine::Segments::Condition.new(
        operator: operator, property: 'foo', value: condition_value
      )
      expect(segment_condition.match_trait_value?(trait_value)).to eq(expected_result)
    end
  end
end
