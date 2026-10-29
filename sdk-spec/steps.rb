# frozen_string_literal: true

# Steps for the Flagsmith SDK behavioural spec: https://github.com/Flagsmith/sdk-spec
#
# Each method implements the Gherkin step in the comment above it.

require 'flagsmith'

def as_spec_flag(flag)
  { feature: flag.feature_name, enabled: flag.enabled, value: flag.value }
end

def as_spec_flags(flags)
  flags.all_flags.map { |flag| as_spec_flag(flag) }
end

# Create the SDK client
def create_client(environment_key, api_url)
  Flagsmith::Client.new(environment_key: environment_key, api_url: api_url)
end

# Create the SDK client with events enabled
def create_client_with_events(environment_key, api_url, events_api_url)
  Flagsmith::Client.new(
    environment_key: environment_key, api_url: api_url, enable_events: true, events_api_url: events_api_url
  )
end

# When the application gets the environment flags
def get_environment_flags(flagsmith)
  as_spec_flags(flagsmith.get_environment_flags)
end

# When the application gets the flags for identity "{identifier}" with traits:
def get_identity_flags(flagsmith, identifier, traits)
  as_spec_flags(flagsmith.get_identity_flags(identifier, **traits))
end

# When the application gets the experiment flag "{feature}" for identity "{identifier}" with traits:
def get_experiment_flag(flagsmith, feature, identifier, traits)
  [as_spec_flag(flagsmith.get_experiment_flag(feature, identifier, **traits))]
end

# When the application tracks event "{event}" for identity "{identifier}" with value {value} and metadata:
def track_event(flagsmith, event, identifier, value, metadata)
  flagsmith.track_event(event, identifier: identifier, value: value, metadata: metadata)
end

# When the application tracks an exposure of feature "{feature}" for identity "{identifier}" with value {value} and metadata:
def track_exposure_event(flagsmith, feature, identifier, value, metadata)
  flagsmith.track_exposure_event(feature, identifier: identifier, value: value, metadata: metadata)
end
