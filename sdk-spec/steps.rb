# frozen_string_literal: true

# Steps for the Flagsmith SDK behavioural spec: https://github.com/Flagsmith/sdk-spec
#
# Each method implements the Gherkin step in the comment above it.

require 'flagsmith'

def as_spec_flags(flags)
  flags.all_flags.map do |flag|
    { feature: flag.feature_name, enabled: flag.enabled, value: flag.value }
  end
end

# Create the SDK client
def create_client(environment_key, api_url)
  Flagsmith::Client.new(environment_key: environment_key, api_url: api_url)
end

# Create the SDK client with local evaluation
def create_client_with_local_evaluation(environment_key, api_url)
  Flagsmith::Client.new(environment_key: environment_key, api_url: api_url, enable_local_evaluation: true)
end

# When the application gets the environment flags
def get_environment_flags(flagsmith)
  as_spec_flags(flagsmith.get_environment_flags)
end

# When the application gets the flags for identity "{identifier}" with traits:
def get_identity_flags(flagsmith, identifier, traits)
  as_spec_flags(flagsmith.get_identity_flags(identifier, **traits))
end
