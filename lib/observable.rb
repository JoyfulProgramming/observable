# frozen_string_literal: true

require_relative "observable/version"
require_relative "observable/configuration"
require_relative "observable/instrumenter"
require_relative "observable/persistence/span"
require_relative "observable/persistence/span_repo"
require_relative "observable/persistence/trace"
require_relative "observable/persistence/trace_repo"

module Observable
  class Error < StandardError; end

  class NoOpenTelemetryExporter < Error
    def message
      "No OpenTelemetry exporter set up. Call `Observable::TracingTestHelper#use_in_memory_otel_exporter!` to set up the exporter."
    end
  end

  class NotFound < Error; end

  def self.instrumenter(config: nil)
    Instrumenter.new(config: config)
  end
end
