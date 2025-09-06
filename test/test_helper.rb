$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "observable"
require "minitest/autorun"

# Set up OpenTelemetry for testing
require "opentelemetry/sdk"

# Create and configure in-memory exporter for tests
OpenTelemetry::SDK.configure do |config|
  config.use_all
end
