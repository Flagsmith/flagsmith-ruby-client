# frozen_string_literal: true

# Flags engine methods
module FlagsmithEngine
  def get_identity_feature_states_dict(environment:, identity:, override_traits: [])
    # Get feature states from the environment
    feature_states = {}
    environment.feature_states.each do |fs|
      feature_sates[fs.feature.id] = fs
    end

    # Override with any feature states defined by matching segments
    identity_segments = get_identity_segments(environment, identity, override_traits)
    identity_segments.each do |matching_segment|
      matching_segment.feature_states.each do |feature_state|
        # NOTE: that feature states are stored on the segment in descending priority
        # order so we only care that the last one is added
        # TODO: can we optimise this?
        feature_states[feature_state.feature.id] = feature_state
      end
    end

    # Override with any feature states defined directly the identity
    identity.identity_features || [].each do |fs|
      feature_states[fs.feature.id] = fs if feature_states[fs.feature.id]
    end
    feature_states
  end

  def get_identity_feature_state(environment:, identity:, feature_name: string, override_traits: [])
    feature_states = get_identity_feature_states_dict(environment, identity, override_traits)

    matching_feature = feature_states.select { |f| f.feature.name == feature_name }

    raise FeatureStateNotFound, 'Feature State Not Found' if matching_feature.length.zero?

    matching_feature[0]
  end

  def get_identity_feature_states(environment:, identity:, override_traits: [])
    feature_states = get_identity_feature_states_dict(environment, identity, override_traits)

    return feature_states.select(&:enabled) if environment.project.hide_disabled_flags

    feature_states
  end

  def get_environment_feature_state(environment:, feature_name:)
    features_states = environment.feature_states.select { |f| f.feature.name == feature_name }

    raise FeatureStateNotFound, 'Feature State Not Found' if features_states.length.zero?

    features_states[0]
  end

  def get_environment_feature_states(environment:)
    return environment.feature_states.select(&:enabled) if environment.project.hide_disabled_flags

    environment.feature_states
  end
end
