require "test_helper"

class InstrumenterTest < Minitest::Test
  include TracingTestHelper

  def test_instrumenter_class_exists
    assert Observable::Instrumenter
  end

  def test_instrument_method_executes_block
    instrumenter = Observable::Instrumenter.new
    result = nil

    instrumenter.instrument do
      result = "executed"
    end

    assert_equal "executed", result
  end

  def test_instrument_captures_calling_method_name
    instrumenter = Observable::Instrumenter.new

    calling_method_name = nil
    instrumenter.instrument do
      calling_method_name = instrumenter.last_captured_method_name
    end

    assert_equal "test_instrument_captures_calling_method_name", calling_method_name
  end

  def test_instrument_captures_calling_class_namespace
    instrumenter = Observable::Instrumenter.new

    calling_namespace = nil
    instrumenter.instrument do
      calling_namespace = instrumenter.last_captured_namespace
    end

    assert_equal "InstrumenterTest", calling_namespace
  end

  def test_instrument_creates_opentelemetry_span
    open_telemetry_exporter.reset
    instrumenter = Observable::Instrumenter.new

    instrumenter.instrument do
      # Some work
    end

    assert_equal 1, spans.count
    span = spans.first
    assert_equal "InstrumenterTest#test_instrument_creates_opentelemetry_span", span.name
  end

  def test_instrument_captures_method_arguments
    open_telemetry_exporter.reset
    instrumenter = Observable::Instrumenter.new

    test_method_with_args(instrumenter, "hello", 42)

    span = spans.first
    assert_equal "InstrumenterTest#test_method_with_args", span.name
    # Test that actual arguments are captured with numeric indices
    assert_equal "hello", span.attrs["code.arguments.0"]
    assert_equal 42, span.attrs["code.arguments.1"]
  end

  def test_instrument_tracks_return_values
    open_telemetry_exporter.reset
    instrumenter = Observable::Instrumenter.new

    instrumenter.instrument do
      "returned value"
    end

    span = spans.first
    assert_equal "returned value", span.attrs["code.return"]
  end

  def test_instrument_records_exceptions
    open_telemetry_exporter.reset
    instrumenter = Observable::Instrumenter.new

    assert_raises(StandardError) do
      method_that_raises_exception(instrumenter, "error message")
    end

    span = spans.first
    assert_equal "InstrumenterTest#method_that_raises_exception", span.name
    assert_equal true, span.attrs["error"]
    assert_equal "StandardError", span.attrs["error.type"]
    assert_equal "error message", span.attrs["error.message"]
  end

  def test_configuration_works
    # Test custom configuration
    Observable::Configuration.configure do |config|
      config.app_namespace = "test_app"
      config.max_serialization_depth = 5
    end

    instrumenter = Observable::Instrumenter.new
    assert_equal "test_app", instrumenter.config.app_namespace
    assert_equal 5, instrumenter.config.max_serialization_depth

    # Reset to defaults
    Observable::Configuration.configure do |config|
      config.app_namespace = nil
      config.max_serialization_depth = 4
    end
  end

  private

  def test_method_with_args(instrumenter, arg1, arg2)
    instrumenter.instrument(binding) do
      # Some work with args
    end
  end

  def method_that_raises_exception(instrumenter, message)
    instrumenter.instrument(binding) do
      raise StandardError, message
    end
  end
end
