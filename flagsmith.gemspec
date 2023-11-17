# frozen_string_literal: true

require File.expand_path('lib/flagsmith/version', __dir__)

Gem::Specification.new do |spec|
  spec.required_ruby_version = '>= 2.4.0'
  spec.name = 'flagsmith'
  spec.version = Flagsmith::VERSION
  spec.authors = ['Tom Stuart', 'Brian Moelk']
  spec.email = ['tom@solidstategroup.com', 'bmoelk@gmail.com']
  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end

  spec.summary = 'Flagsmith - Ship features with confidence'
  spec.description = 'Ruby Client for Flagsmith. Ship features with confidence using feature flags and remote config. Host yourself or use our hosted version at https://flagsmith.com'
  spec.homepage = 'https://flagsmith.com'

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'gem-release'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'

  spec.add_dependency 'faraday', "~> 2.7", ">= 2.7.11"
  spec.add_dependency 'faraday-retry'
  spec.add_dependency 'semantic'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
