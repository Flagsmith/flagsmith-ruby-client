# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.required_ruby_version = '>= 2.4.0'
  spec.name = 'flagsmith'
  spec.version = '2.0.0'
  spec.authors = ['Tom Stuart', 'Brian Moelk']
  spec.email = ['tom@solidstategroup.com', 'bmoelk@gmail.com']
  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }

  spec.summary = 'Flagsmith - Ship features with confidence'
  spec.description = 'Ruby Client for Flagsmith. Ship features with confidence using feature flags and remote config. Host yourself or use our hosted version at https://flagsmith.com'
  spec.homepage = 'https://flagsmith.com'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'gem-release'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'pry'
  spec.add_dependency 'faraday'
  spec.add_dependency 'faraday_middleware'
  spec.add_dependency 'semantic'
end
