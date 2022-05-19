# frozen_string_literal: true

require_relative '../../../../lib/flagsmith'

TEST_CASES = [
  ['EQUAL', 'bar', 'bar', true],
  ['EQUAL', 'bar', 'baz', false],
  ['EQUAL', 1, '1', true],
  ['EQUAL', 1, '2', false],
  ['EQUAL', true, 'true', true],
  ['EQUAL', false, 'false', true],
  ['EQUAL', false, 'true', false],
  ['EQUAL', true, 'false', false],
  ['EQUAL', 1.23, '1.23', true],
  ['EQUAL', 1.23, '4.56', false],
  ['GREATER_THAN', 2, '1', true],
  ['GREATER_THAN', 1, '1', false],
  ['GREATER_THAN', 0, '1', false],
  ['GREATER_THAN', 2.1, '2.0', true],
  ['GREATER_THAN', 2.1, '2.1', false],
  ['GREATER_THAN', 2.0, '2.1', false],
  ['GREATER_THAN_INCLUSIVE', 2, '1', true],
  ['GREATER_THAN_INCLUSIVE', 1, '1', true],
  ['GREATER_THAN_INCLUSIVE', 0, '1', false],
  ['GREATER_THAN_INCLUSIVE', 2.1, '2.0', true],
  ['GREATER_THAN_INCLUSIVE', 2.1, '2.1', true],
  ['GREATER_THAN_INCLUSIVE', 2.0, '2.1', false],
  ['LESS_THAN', 1, '2', true],
  ['LESS_THAN', 1, '1', false],
  ['LESS_THAN', 1, '0', false],
  ['LESS_THAN', 2.0, '2.1', true],
  ['LESS_THAN', 2.1, '2.1', false],
  ['LESS_THAN', 2.1, '2.0', false],
  ['LESS_THAN_INCLUSIVE', 1, '2', true],
  ['LESS_THAN_INCLUSIVE', 1, '1', true],
  ['LESS_THAN_INCLUSIVE', 1, '0', false],
  ['LESS_THAN_INCLUSIVE', 2.0, '2.1', true],
  ['LESS_THAN_INCLUSIVE', 2.1, '2.1', true],
  ['LESS_THAN_INCLUSIVE', 2.1, '2.0', false],
  ['NOT_EQUAL', 'bar', 'baz', true],
  ['NOT_EQUAL', 'bar', 'bar', false],
  ['NOT_EQUAL', 1, '2', true],
  ['NOT_EQUAL', 1, '1', false],
  ['NOT_EQUAL', true, 'false', true],
  ['NOT_EQUAL', false, 'true', true],
  ['NOT_EQUAL', false, 'false', false],
  ['NOT_EQUAL', true, 'true', false],
  ['CONTAINS', 'bar', 'b', true],
  ['CONTAINS', 'bar', 'bar', true],
  ['CONTAINS', 'bar', 'baz', false],
  ['NOT_CONTAINS', 'bar', 'b', false],
  ['NOT_CONTAINS', 'bar', 'bar', false],
  ['NOT_CONTAINS', 'bar', 'baz', true],
  ['REGEX', 'foo', /[a-z]+/, true],
  ['REGEX', 'FOO', /[a-z]+/, false],
  ['REGEX', '1.2.3', /\d/, true],

  ['EQUAL', '1.0.0', '1.0.0:semver', true],
  ['EQUAL', '1.0.0', '1.0.1:semver', false],
  ['NOT_EQUAL', '1.0.0', '1.0.0:semver', false],
  ['NOT_EQUAL', '1.0.0', '1.0.1:semver', true],
  ['GREATER_THAN', '1.0.1', '1.0.0:semver', true],
  ['GREATER_THAN', '1.0.0', '1.0.0-beta:semver', true],
  ['GREATER_THAN', '1.0.1', '1.2.0:semver', false],
  ['GREATER_THAN', '1.0.1', '1.0.1:semver', false],
  ['GREATER_THAN', '1.2.4', '1.2.3-pre.2+build.4:semver', true],
  ['LESS_THAN', '1.0.0', '1.0.1:semver', true],
  ['LESS_THAN', '1.0.0', '1.0.0:semver', false],
  ['LESS_THAN', '1.0.1', '1.0.0:semver', false],
  ['LESS_THAN', '1.0.0-rc.2', '1.0.0-rc.3:semver', true],
  ['GREATER_THAN_INCLUSIVE', '1.0.1', '1.0.0:semver', true],
  ['GREATER_THAN_INCLUSIVE', '1.0.1', '1.2.0:semver', false],
  ['GREATER_THAN_INCLUSIVE', '1.0.1', '1.0.1:semver', true],
  ['LESS_THAN_INCLUSIVE', '1.0.0', '1.0.1:semver', true],
  ['LESS_THAN_INCLUSIVE', '1.0.0', '1.0.0:semver', true],
  ['LESS_THAN_INCLUSIVE', '1.0.1', '1.0.0:semver', false]
].freeze

describe Flagsmiths::Engine::Segments::Condition do
  TEST_CASES.each do |(operator, trait_value, condition_value, expected_result)|
    it "#{operator}, #{condition_value} #match_trait_value #{trait_value}" do
      segment_condition = Flagsmiths::Engine::Segments::Condition.new(
        operator: operator, property: 'foo', value: condition_value
      )
      expect(segment_condition.match_trait_value?(trait_value)).to eq(expected_result)
    end
  end
end

describe Flagsmiths::Engine::Segment do
  it 'test_segment_schema_engine_model_object_to_dict(project)' do
    # Given
    segment = Flagsmiths::Engine::Segment.new(
      id: 1,
      name: 'Segment',
      rules: [
        Flagsmiths::Engine::Segments::Rule.new(
          type: 'ALL_RULE',
          conditions: [
            Flagsmiths::Engine::Segments::Condition.new(operator: 'EQUAL', property: 'foo', value: 'bar')
          ]
        )
      ],
      feature_states: [
        Flagsmiths::Engine::Features::State.new(
          django_id: 1,
          feature: Flagsmiths::Engine::Feature.new(
            id: 1,
            name: 'my_feature',
            type: 'STANDARD'
          ),
          enabled: true
        )
      ]
    )

    # When
    data = segment

    # Then
    expect(data.feature_states.length).to eq(1)
    expect(data.rules.length).to eq(1)
  end

  # it 'test_dict_to_segment_model' do
  #   # Given
  #   segment_dict = {
  #     "id": 1,
  #     "name": 'Segment',
  #     "rules": [
  #       {
  #         "rules": [],
  #         "conditions": [
  #           { "operator": 'EQUAL', "property_": 'foo', "value": 'bar' }
  #         ],
  #         "type": 'ALL'
  #       }
  #     ],
  #     "feature_states": [
  #       {
  #         "multivariate_feature_state_values": [],
  #         "id": 1,
  #         "enabled": true,
  #         "feature_state_value": nil,
  #         "feature": { "id": 1, "name": 'my_feature', "type": 'STANDARD' }
  #       }
  #     ]
  #   }
  #
  #   # When
  #   segment_model = segment_schema.load(segment_dict)
  #
  #   # Then
  #   assert isinstance(segment_model, Segment)
  #   assert segment_model.id == segment_dict['id']
  #   assert len(segment_model.rules) == 1
  #   assert len(segment_model.feature_states) == 1
  # end

  # it 'test_segment_condition_schema_load_when_property_is_none' do
  #   # Given
  #   schema = SegmentConditionSchema()
  #   data = { "operator": PERCENTAGE_SPLIT, "value": 10, "property_": None }
  #
  #   # When
  #   segment_condition_model = schema.load(data)
  #
  #   # Then
  #   assert segment_condition_model.value == data['value']
  #   assert segment_condition_model.operator == data['operator']
  #   assert segment_condition_model.property_ is None
  # end
end
