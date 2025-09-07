# Start SimpleCov before loading any application code
require "simplecov"
SimpleCov.start do
  add_filter "/test/"
  add_filter "/spec/"
  add_filter "/bin/"
  add_filter "/.bundle/"
  
  # Track coverage for lib directory only
  track_files "lib/**/*.rb"
  
  # Minimum coverage threshold
  minimum_coverage 80
  
  # Generate both HTML and text reports
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::SimpleFormatter
  ])
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "observable"
require "minitest/autorun"
require "support/tracing_test_helper"

# Set up OpenTelemetry for testing
require "opentelemetry/sdk"

# Create and configure in-memory exporter for tests
OpenTelemetry::SDK.configure do |config|
  config.use_all
end
