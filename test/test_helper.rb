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
