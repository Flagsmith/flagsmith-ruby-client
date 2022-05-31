# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Flagsmith::Engine::Feature do
  it '#compare' do
    fm1 = Flagsmith::Engine::Feature.new(id: 1, name: 'a', type: 'test')
    fm2 = Flagsmith::Engine::Feature.new(id: 1, name: 'a', type: 'test')

    expect(fm1).to eq(fm2)
  end

  it 'feature state generates default #uuid' do
    fs = Flagsmith::Engine::FeatureState.new(feature: {}, enabled: true, django_id: 1)
    expect(fs.feature_state_uuid).to_not be_nil
  end

  it 'multivariate feature state generates default #mv_fs_value_uuid' do
    option = Flagsmith::Engine::Features::MultivariateOption.new(value: 'value')
    feature_state_value = Flagsmith::Engine::Features::MultivariateStateValue.new(
      multivariate_feature_option: option, percentage_allocation: 10, id: 1
    )

    expect(feature_state_value.mv_fs_value_uuid).to_not be_nil
  end

  it '#get_value returns no multivariate values' do
    value = 'foo'
    feature_state =  Flagsmith::Engine::FeatureState.new(feature: {}, enabled: true, django_id: 1)

    feature_state.set_value(value)

    expect(feature_state.get_value).to eq(value)
    expect(feature_state.get_value(1)).to eq(value)
  end

  context '#get_value returns' do
    mv_feature_control_value = 'control'
    mv_feature_value_1 = 'foo'
    mv_feature_value_2 = 'bar'

    [
      [70, mv_feature_value_1],
      [30, mv_feature_value_2],
      [10, mv_feature_control_value]
    ].each do |test_case|
      feature = Flagsmith::Engine::Feature.new(id: 1, name: 'mv_feature', type: 'STANDARD')

      mv_feature_option_1 = Flagsmith::Engine::Features::MultivariateOption.new(value: mv_feature_value_1, id: 1)
      mv_feature_option_2 = Flagsmith::Engine::Features::MultivariateOption.new(value: mv_feature_value_2, id: 2)

      mv_feature_state_value_1 = Flagsmith::Engine::Features::MultivariateStateValue.new(
        multivariate_feature_option: mv_feature_option_1, percentage_allocation: test_case[0], id: 1
      )
      mv_feature_state_value_2 = Flagsmith::Engine::Features::MultivariateStateValue.new(
        multivariate_feature_option: mv_feature_option_2, percentage_allocation: test_case[0], id: 2
      )

      mv_feature_state = Flagsmith::Engine::FeatureState.new(feature: feature, enabled: true, django_id: 1)
      mv_feature_state.multivariate_feature_state_values = [
          mv_feature_state_value_1,
          mv_feature_state_value_2
      ]

      mv_feature_state.set_value(mv_feature_control_value)

      it 'multivariate values untill #percentage_allocation is less than 17' do
        expect(mv_feature_state.get_value("test")).to eq(test_case[1])
      end
    end
  end
end
