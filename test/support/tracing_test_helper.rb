require_relative "persistence/trace_repo"
require_relative "persistence/span_repo"

module TracingTestHelper
  def traces
    Observable::Persistence::TraceRepo.new(spans: finished_spans)
  end

  def spans
    Observable::Persistence::SpanRepo.new(spans: finished_spans)
  end

  def finished_spans
    open_telemetry_exporter.finished_spans
  end

  def open_telemetry_exporter
    @open_telemetry_exporter ||= setup_opentelemetry_for_tests
  end

  private

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
