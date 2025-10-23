#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require_relative 'lib/flagsmith'

flagsmith = Flagsmith::Client.new(
  environment_key: ''
)

begin
  flags = flagsmith.get_environment_flags

  beta_users_flag = flags['beta_users']

  if beta_users_flag
    puts "Flag found!"
  else
    puts "error getting flag environment"
  end

  puts "-" * 50
  puts "All flags"
  flags.all_flags.each do |flag|
    puts "  - #{flag.feature_name}: enabled=#{flag.enabled?}, value=#{flag.value.inspect}"
  end

rescue StandardError => e
  puts "Error: #{e.message}"
  puts e.backtrace.join("\n")
end
