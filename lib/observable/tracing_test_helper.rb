require_relative "persistence/trace_repo"
require_relative "persistence/span_repo"

module Observable
  module TracingTestHelper
    def traces
      Observable::Persistence::TraceRepo.new(spans: finished_spans)
    end

    def spans
      Observable::Persistence::SpanRepo.new(spans: finished_spans)
    end

    def setup_observable_data!
      @open_telemetry_exporter = setup_opentelemetry_for_tests
    end

    def teardown_observable_data!
      reset_observable_data!
      @open_telemetry_exporter = nil
    end

    def reset_observable_data!
      raise NoOpenTelemetryExporter if @open_telemetry_exporter.nil?

      @open_telemetry_exporter.reset
    end

    private

    def finished_spans
      raise NoOpenTelemetryExporter if @open_telemetry_exporter.nil?

      @open_telemetry_exporter.finished_spans
    end

    def setup_opentelemetry_for_tests
      require "opentelemetry/sdk"

      exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
      span_processor = OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter)

      # Configure the tracer provider with our span processor
      tracer_provider = OpenTelemetry::SDK::Trace::TracerProvider.new
      tracer_provider.add_span_processor(span_processor)
      OpenTelemetry.tracer_provider = tracer_provider

      exporter
    end
  end
end
