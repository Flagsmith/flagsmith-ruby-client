require 'bundler/setup'
require 'hanami/setup'
require 'hanami/model'
require_relative '../apps/web/application'

Hanami.configure do
  mount Web::Application, at: '/'

  model do
    adapter :sql, ENV.fetch('DATABASE_URL')
  end

  environment :development do
    # See: https://guides.hanamirb.org/projects/logging
    logger level: :debug
  end
end
