require "test_helper"

class InstrumenterTest < Minitest::Test
  include MethodHelpers

  def test_instrument_records_details_of_method_call
    returned_value = method_with_return_value(
      Observable.instrumenter,
      return_value: "returned value"
    )

    assert_equal "returned value", returned_value
    assert_equal 1, spans.count
    assert_equal "MethodHelpers#method_with_return_value", spans.first.name
    assert_hashes_match ({
      "app.namespace" => "app",
      "code.filepath" => %r{.*/test/support/method_helpers.rb},
      "code.lineno" => 51,
      "code.function" => "MethodHelpers#method_with_return_value",
      "code.namespace" => "MethodHelpers",
      "code.return" => "returned value",
      "error" => false
    }), spans.one_and_only!.attrs
  end

  def test_instrument_captures_method_arguments
    method_with_args(
      Observable.instrumenter,
      "hello",
      42,
      nil
    )

    assert_hashes_match ({
      "code.arguments.0" => "hello",
      "code.arguments.1" => 42,
      "code.arguments.2" => "nil"
    }), spans.one_and_only!.attrs, match_keys: %r{code.arguments}
  end

  def test_instrument_records_exceptions
    assert_raises(StandardError) do
      method_that_raises_exception(
        Observable.instrumenter,
        "error message"
      )
    end

    assert_hashes_match ({
      "code.function" => "MethodHelpers#method_that_raises_exception",
      "code.namespace" => "InstrumenterTest",
      "code.filepath" => %r{.*/test/support/method_helpers.rb},
      "code.lineno" => 43,
      "code.arguments.0" => "error message",
      "error" => true,
      "error.type" => "StandardError",
      "error.message" => "error message",
      "error.stacktrace" => /.*/
    }), first_span_attrs!, match_keys: /error|code/
  end

  def test_instrumenter_records_details_of_structured_errors
    assert_raises(Observable::StructuredError) do
      method_that_raises_exception(
        Observable.instrumenter,
        Observable::StructuredError.new("error message", type: "Error::Class", context: {foo: "bar"})
      )
    end

    assert_hashes_match ({
      "error" => true,
      "error.type" => "Error::Class",
      "error.message" => "error message",
      "error.stacktrace" => /.*/,
      "error.context.foo" => "bar"
    }), first_span_attrs!, match_keys: /error/
  end

  def test_namespace_is_configurable
    assume_instrumenter_with_config(app_namespace: "test_app") do |instrumenter|
      method_with_no_args(instrumenter)
    end

    assert_hashes_match ({
      "app.namespace" => "test_app"
    }), first_span_attrs!, match_keys: "app.namespace"
  end

  def test_serializing_hash_with_no_serialization_depth_defaults_to_depth_of_2
    assume_instrumenter_with_config(serialization_depth: {}) do |instrumenter|
      method_with_hash_arg(instrumenter, four_deep_hash)

      assert_hashes_match ({
        "code.arguments.0.level_1.value" => "level 1 value",
        "code.arguments.0.level_1.level_2.value" => "level 2 value"
      }), first_span_attrs!, match_keys: %r{code.arguments.0}
    end
  end

  def test_serializing_hash_with_depth_of_1_limits_the_depth_of_the_hash
    assume_instrumenter_with_config(serialization_depth: {"Hash" => 1}) do |instrumenter|
      method_with_hash_arg(instrumenter, four_deep_hash)

      assert_hashes_match ({
        "code.arguments.0.level_1.value" => "level 1 value"
      }), first_span_attrs!, match_keys: %r{code.arguments.0}
    end
  end

  def test_serializing_hash_with_depth_of_2_limits_the_depth_of_the_hash
    assume_instrumenter_with_config(serialization_depth: {"Hash" => 2}) do |instrumenter|
      method_with_hash_arg(instrumenter, four_deep_hash)

      assert_hashes_match ({
        "code.arguments.0.level_1.value" => "level 1 value",
        "code.arguments.0.level_1.level_2.value" => "level 2 value"
      }), first_span_attrs!, match_keys: %r{code.arguments.0}
    end
  end

  def test_serialization_depth_is_configurable_for_custom_class
    custom_obj = TestCustomClass.new(name: "test", data: {nested: {deep: "value"}})

    assume_instrumenter_with_config(serialization_depth: {"TestCustomClass" => 1}) do |instrumenter|
      method_with_custom_arg(instrumenter, custom_obj)

      assert_hashes_match ({
        "code.arguments.0.name" => "test",
        "code.arguments.0.class" => "TestCustomClass"
      }), first_span_attrs!, match_keys: %r{code.arguments.0}
    end

    reset_observable_data!

    assume_instrumenter_with_config(serialization_depth: {"TestCustomClass" => 2}) do |instrumenter|
      method_with_custom_arg(instrumenter, custom_obj)

      assert_hashes_match ({
        "code.arguments.0.name" => "test",
        "code.arguments.0.class" => "TestCustomClass",
        "code.arguments.0.data.nested.deep" => "value"
      }), first_span_attrs!, match_keys: %r{code.arguments.0}
    end
  end

  def test_serialization_depth_is_configurable_for_mixed_structure
    complex_data = {
      user: TestCustomClass.new(name: "john", data: {profile: {age: 30}}),
      metadata: {
        created: {
          timestamp: "2023-01-01"
        }
      }
    }
    assume_instrumenter_with_config(serialization_depth: {"Hash" => 3, "TestCustomClass" => 2}) do |instrumenter|
      method_with_complex_arg(instrumenter, complex_data)

      assert_hashes_match ({
        "code.arguments.0.user.class" => "TestCustomClass",
        "code.arguments.0.user.name" => "john",
        "code.arguments.0.user.data.profile.age" => 30,
        "code.arguments.0.metadata.created.timestamp" => "2023-01-01"
      }), first_span_attrs!, match_keys: %r{code.arguments.0}
    end
  end

  def setup
    super
    setup_observable_data!
  end

  def teardown
    super
    teardown_observable_data!
  end

  private

  def first_span_attrs!
    spans.one_and_only!.attrs
  end

  def assume_instrumenter_with_config(app_namespace: nil, serialization_depth: nil)
    test_config = Observable::Configuration.config.dup
    test_config.app_namespace = app_namespace if app_namespace
    test_config.serialization_depth = serialization_depth if serialization_depth
    instrumenter = Observable.instrumenter(config: test_config)
    yield instrumenter
    instrumenter
  end

  def four_deep_hash
    {
      level_1: {
        value: "level 1 value",
        level_2: {
          value: "level 2 value",
          level_3: {
            value: "level 3 value",
            level_4: {
              value: "level 4 value"
            }
          }
        }
      }
    }
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
