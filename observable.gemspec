# frozen_string_literal: true

require_relative "lib/observable/version"

Gem::Specification.new do |spec|
  spec.name = "observable"
  spec.version = Observable::VERSION
  spec.authors = ["John Gallagher"]
  spec.email = ["john@synapticmishap.co.uk"]

  spec.summary = "OpenTelemetry instrumentation library for Ruby methods"
  spec.description = "A Ruby gem that provides automated OpenTelemetry instrumentation for method calls with configurable serialization, PII filtering, and argument tracking"
  spec.homepage = "https://github.com/JoyfulProgramming/observable"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/JoyfulProgramming/observable"
  spec.metadata["changelog_uri"] = "https://github.com/JoyfulProgramming/observable/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "opentelemetry-sdk", "~> 1.5"
  spec.add_dependency "dry-configurable", ">= 0.13.0", "< 2.0"
  spec.add_dependency "dry-struct", "~> 1.4"

  # Development dependencies
  spec.add_development_dependency "minitest", "~> 5.14"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "standard", "~> 1.40"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
