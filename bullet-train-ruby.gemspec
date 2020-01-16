Gem::Specification.new do |spec|
  spec.name = "bullet-train-client"
  spec.version = "1.0.0"
  spec.authors = ["Tom Stuart"]
  spec.email = ["tom@solidstategroup.com"]
  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }

  spec.summary = "Bullet Train - Ship features with confidence"
  spec.description = "Ruby Client for Bullet-Train. Ship features with confidence using feature flags and remote config. Host yourself or use our hosted version at https://bullet-train.io"
  spec.homepage = "https://bullet-train.io"

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_dependency 'faraday'
end
