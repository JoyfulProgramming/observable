require "test_helper"

class TracingTestHelperTest < Minitest::Test
  def test_when_no_open_telemetry_exporter_set_up_raises_error
    assert_raises(Observable::NoOpenTelemetryExporter) do
      spans
    end
  end

  def test_spans_returns_spans_after_instrumentation
    setup_observable_data!

    Observable.instrumenter.instrument do
      "test value"
    end

    assert_equal 1, spans.count
    assert_equal "TracingTestHelperTest#test_spans_returns_spans_after_instrumentation", spans.first.name
  end

  def test_spans_returns_multiple_spans_after_multiple_instrumentations
    setup_observable_data!

    Observable.instrumenter.instrument { "first" }
    Observable.instrumenter.instrument { "second" }

    assert_equal 2, spans.count
    assert_equal "TracingTestHelperTest#test_spans_returns_multiple_spans_after_multiple_instrumentations", spans.first.name
  end

  def test_traces_returns_traces_after_instrumentation
    setup_observable_data!

    Observable.instrumenter.instrument do
      "test value"
    end

    assert_equal 1, traces.count
    assert_equal "TracingTestHelperTest#test_traces_returns_traces_after_instrumentation", traces.first.spans.first.name
  end

  def test_traces_returns_multiple_traces_after_multiple_instrumentations
    setup_observable_data!

    Observable.instrumenter.instrument { "first" }
    Observable.instrumenter.instrument { "second" }

    assert_equal 2, traces.count
  end

  def test_setup_resets_data_if_teardown_is_forgotten
    setup_observable_data!
    Observable.instrumenter.instrument { "test value" }
    assert_equal 1, spans.count

    setup_observable_data!
    Observable.instrumenter.instrument { "test value" }
    assert_equal 1, spans.count
  end
end
