require "test_helper"

class InstrumenterTest < Minitest::Test
  make_my_diffs_pretty!
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
    instrumenter = Observable::Instrumenter.new

    instrumenter.instrument do
      # Some work
    end

    assert_equal 1, spans.count
    span = spans.first
    assert_equal "InstrumenterTest#test_instrument_creates_opentelemetry_span", span.name
  end

  def test_instrument_captures_method_arguments
    instrumenter = Observable::Instrumenter.new

    test_method_with_args(instrumenter, "hello", 42)

    span = spans.first

    assert_equal ({
      "code.function" => "InstrumenterTest#test_method_with_args",
      "code.namespace" => "InstrumenterTest",
      "app.namespace" => "app",
      "code.arguments.0" => "hello",
      "code.arguments.1" => 42,
      "error" => false,
      "code.return" => "nil"
    }), span.attrs.except("code.lineno", "code.filepath")
  end

  def test_instrument_tracks_return_values
    instrumenter = Observable::Instrumenter.new

    instrumenter.instrument do
      "returned value"
    end

    span = spans.first

    assert_equal ({
      "code.function" => "InstrumenterTest#test_instrument_tracks_return_values",
      "code.namespace" => "InstrumenterTest",
      "app.namespace" => "app",
      "code.return" => "returned value",
      "error" => false
    }), span.attrs.except("code.lineno", "code.filepath")
  end

  def test_instrument_records_exceptions
    instrumenter = Observable::Instrumenter.new

    assert_raises(StandardError) do
      method_that_raises_exception(instrumenter, "error message")
    end

    span = spans.first
    assert_equal ({
      "code.function" => "InstrumenterTest#method_that_raises_exception",
      "code.namespace" => "InstrumenterTest",
      "code.arguments.0" => "error message",
      "app.namespace" => "app",
      "error" => true,
      "error.type" => "StandardError",
      "error.message" => "error message"
    }), span.attrs.except("code.lineno", "code.filepath")
  end

  def test_configuration_works
    test_config = Observable::Configuration.config.dup
    test_config.app_namespace = "test_app"
    test_config.serialization_depth = 5

    instrumenter = Observable::Instrumenter.new(config: test_config)
    assert_equal "test_app", instrumenter.config.app_namespace
    assert_equal 5, instrumenter.config.serialization_depth
  end

  def test_class_specific_serialization_depth_for_hash
    test_config = Observable::Configuration.config.dup
    test_config.serialization_depth = {:default => 2, "Hash" => 3}
    instrumenter = Observable::Instrumenter.new(config: test_config)

    # Create a deep nested hash that goes 4 levels deep
    deep_hash = {
      level1: {
        level2: {
          level3: {
            level4: "should be captured due to Hash depth=3"
          }
        }
      }
    }

    test_method_with_hash_arg(instrumenter, deep_hash)

    span = spans.first

    assert_equal ({
      "code.function" => "InstrumenterTest#test_method_with_hash_arg",
      "code.namespace" => "InstrumenterTest",
      "app.namespace" => "app",
      "code.arguments.0.level1.level2.level3.level4" => "should be captured due to Hash depth=3",
      "error" => false,
      "code.return" => "nil"
    }), span.attrs.except("code.lineno", "code.filepath")
  end

  def test_class_specific_serialization_depth_for_custom_class
    test_config = Observable::Configuration.config.dup
    test_config.serialization_depth = {:default => 2, "TestCustomClass" => 1}
    instrumenter = Observable::Instrumenter.new(config: test_config)

    custom_obj = TestCustomClass.new(name: "test", data: {nested: {deep: "value"}})
    test_method_with_custom_arg(instrumenter, custom_obj)

    span = spans.first

    assert_equal ({
      "code.function" => "InstrumenterTest#test_method_with_custom_arg",
      "code.namespace" => "InstrumenterTest",
      "app.namespace" => "app",
      "code.arguments.0.class" => "TestCustomClass",
      "code.arguments.0.name" => "test",
      "error" => false,
      "code.return" => "nil"
    }), span.attrs.except("code.lineno", "code.filepath")
  end

  def test_default_depth_when_class_not_specified
    test_config = Observable::Configuration.config.dup
    test_config.serialization_depth = {:default => 2, "Hash" => 1}
    instrumenter = Observable::Instrumenter.new(config: test_config)

    deep_array = [
      {
        level1: {
          level2: "value"
        }
      }
    ]

    test_method_with_array_arg(instrumenter, deep_array)

    span = spans.first

    assert_equal ({
      "code.function" => "InstrumenterTest#test_method_with_array_arg",
      "code.namespace" => "InstrumenterTest",
      "app.namespace" => "app",
      "error" => false,
      "code.return" => "nil"
    }), span.attrs.except("code.lineno", "code.filepath")
  end

  def test_mixed_depth_limits_in_nested_structure
    test_config = Observable::Configuration.config.dup
    test_config.serialization_depth = {:default => 1, "Hash" => 3, "TestCustomClass" => 2}
    instrumenter = Observable::Instrumenter.new(config: test_config)

    complex_data = {
      user: TestCustomClass.new(name: "john", data: {profile: {age: 30}}),
      metadata: {
        created: {
          timestamp: "2023-01-01"
        }
      }
    }

    test_method_with_complex_arg(instrumenter, complex_data)

    span = spans.first

    assert_equal ({
      "code.function" => "InstrumenterTest#test_method_with_complex_arg",
      "code.namespace" => "InstrumenterTest",
      "app.namespace" => "app",
      "code.arguments.0.user.class" => "TestCustomClass",
      "code.arguments.0.user.name" => "john",
      "code.arguments.0.user.data.profile.age" => 30,
      "code.arguments.0.metadata.created.timestamp" => "2023-01-01",
      "error" => false,
      "code.return" => "nil"
    }), span.attrs.except("code.lineno", "code.filepath")
  end

  def test_backward_compatibility_with_single_depth_config
    test_config = Observable::Configuration.config.dup
    test_config.serialization_depth = 3  # Old style single value
    instrumenter = Observable::Instrumenter.new(config: test_config)

    deep_hash = {l1: {l2: {l3: {l4: "deep"}}}}
    test_method_with_hash_arg(instrumenter, deep_hash)

    span = spans.first

    assert_equal ({
      "code.function" => "InstrumenterTest#test_method_with_hash_arg",
      "code.namespace" => "InstrumenterTest",
      "app.namespace" => "app",
      "code.arguments.0.l1.l2.l3.l4" => "deep",
      "error" => false,
      "code.return" => "nil"
    }), span.attrs.except("code.lineno", "code.filepath")
  end

  def setup
    open_telemetry_exporter.reset
    super
  end

  private

  def test_method_with_args(instrumenter, arg1, arg2)
    instrumenter.instrument(binding) do
      # Some work with args
    end
  end

  def test_method_with_hash_arg(instrumenter, hash_arg)
    instrumenter.instrument(binding) do
      # Some work with hash
    end
  end

  def test_method_with_custom_arg(instrumenter, custom_arg)
    instrumenter.instrument(binding) do
      # Some work with custom object
    end
  end

  def test_method_with_array_arg(instrumenter, array_arg)
    instrumenter.instrument(binding) do
      # Some work with array
    end
  end

  def test_method_with_complex_arg(instrumenter, complex_arg)
    instrumenter.instrument(binding) do
      # Some work with complex data
    end
  end

  def method_that_raises_exception(instrumenter, message)
    instrumenter.instrument(binding) do
      raise StandardError, message
    end
  end
end

class TestCustomClass
  attr_reader :name, :data

  def initialize(name:, data:)
    @name = name
    @data = data
  end

  def to_h
    {
      name: @name,
      data: @data
    }
  end
end
