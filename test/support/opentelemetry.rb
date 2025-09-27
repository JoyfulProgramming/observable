# frozen_string_literal: true

require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"

OpenTelemetry::SDK.configure do |config|
  config.use_all
end
