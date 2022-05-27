$flagsmith = Flagsmith::Client.new(
  enable_local_evaluation: true,
  environment_refresh_interval_seconds: 60,
  default_flag_handler: lambda { |feature_name|
    Flagsmith::Flag.new(
      feature_name: feature_name, enabled: false, value: {}.to_json, feature_id: nil
    )
  }
)
