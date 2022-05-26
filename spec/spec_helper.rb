# frozen_string_literal: true

require 'bundler/setup'
Bundler.setup

APP_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..'))
# $LOAD_PATH << File.join(APP_ROOT, 'lib/flagsmith')

require 'flagsmith'

require 'ostruct'
require 'json'
require 'pry'

Dir[File.join(APP_ROOT, 'spec/support/**/*.rb')].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include Engine::Builders, type: :model
end
