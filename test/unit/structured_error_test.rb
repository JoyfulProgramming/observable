require "test_helper"

class StructuredErrorTest < Minitest::Test
  def test_initializes_with_message_type_and_context
    error = Observable::StructuredError.new(
      "Something went wrong",
      type: "ValidationError",
      context: {user_id: 123, field: "email"}
    )

    assert_equal "Something went wrong", error.message
    assert_equal "ValidationError", error.type
    assert_equal({user_id: 123, field: "email"}, error.context)
  end

  def test_with_object_that_responds_to_to_h_calls_to_h_for_context
    context_obj = Object.new
    def context_obj.to_h
      {key: "value"}
    end

    error = Observable::StructuredError.new(
      "Error message",
      type: "TestError",
      context: context_obj
    )

    assert_equal({key: "value"}, error.context)
  end

  def test_to_h_returns_message_merged_with_context
    error = Observable::StructuredError.new(
      "Database connection failed",
      type: "DatabaseError",
      context: {host: "localhost", port: 5432, timeout: 30}
    )

    expected_hash = {
      message: "Database connection failed",
      host: "localhost",
      port: 5432,
      timeout: 30
    }

    assert_equal expected_hash, error.to_h
  end

  def test_to_h_handles_empty_context
    error = Observable::StructuredError.new(
      "Simple error",
      type: "SimpleError",
      context: {}
    )

    expected_hash = {message: "Simple error"}

    assert_equal expected_hash, error.to_h
  end

  def test_to_h_handles_nil_context
    error = Observable::StructuredError.new(
      "Error with nil context",
      type: "NilContextError",
      context: nil
    )

    expected_hash = {message: "Error with nil context"}

    assert_equal expected_hash, error.to_h
  end

  def test_inherits_from_standard_error
    error = Observable::StructuredError.new(
      "Test error",
      type: "TestType",
      context: {}
    )

    assert_kind_of StandardError, error
    assert_kind_of Observable::StructuredError, error
  end

  def test_can_be_raised_and_caught
    error = Observable::StructuredError.new(
      "Raised error",
      type: "RaisedError",
      context: {raised: true}
    )

    assert_raises(Observable::StructuredError) do
      raise error
    end
  end

  def test_context_with_complex_data_structures
    complex_context = {
      user: {id: 1, name: "John"},
      metadata: {timestamp: Time.now, tags: ["urgent", "bug"]},
      nested: {deep: {value: "test"}}
    }

    error = Observable::StructuredError.new(
      "Complex error",
      type: "ComplexError",
      context: complex_context
    )

    assert_equal complex_context, error.context
    assert_equal "Complex error", error.to_h[:message]
    assert_equal 1, error.to_h[:user][:id]
    assert_equal "John", error.to_h[:user][:name]
    assert_equal ["urgent", "bug"], error.to_h[:metadata][:tags]
  end

  def test_context_keys_override_message_key_if_conflict
    error = Observable::StructuredError.new(
      "Original message",
      type: "ConflictError",
      context: {message: "Overridden message", other: "data"}
    )

    # The context should override the message key
    assert_equal "Overridden message", error.to_h[:message]
    assert_equal "data", error.to_h[:other]
  end

  def test_type_defaults_to_structured_error_class_when_missing
    error = Observable::StructuredError.new(
      "Message",
      type: nil
    )

    assert_equal "Observable::StructuredError", error.type
  end

  def test_type_defaults_to_structured_error_class_when_not_provided
    error = Observable::StructuredError.new(
      "Message"
    )

    assert_equal "Observable::StructuredError", error.type
  end

  def test_type_is_preserved_when_provided
    error = Observable::StructuredError.new(
      "Message",
      type: "CustomError"
    )

    assert_equal "CustomError", error.type
  end

  def test_type_can_be_omitted_from_signature
    error = Observable::StructuredError.new(
      "Message"
    )

    assert_equal "Observable::StructuredError", error.type
  end

  def test_type_can_be_a_class
    error = Observable::StructuredError.new(
      "Message",
      type: StandardError
    )

    assert_equal "StandardError", error.type
  end

  def test_inspect_follows_ruby_error_format
    error = Observable::StructuredError.new(
      "message",
      type: "CustomError",
      context: {foo: "bar"}
    )

    assert_equal %(#<Observable::StructuredError: message, type=CustomError, context={foo: "bar"}>), error.inspect
  end

  def test_to_s_returns_message_only
    error = Observable::StructuredError.new(
      "message",
      type: "CustomError",
      context: {foo: "bar"}
    )

    assert_equal "message", error.to_s
  end

  def test_pretty_print_formats_error_with_indentation
    error = Observable::StructuredError.new(
      "message",
      type: "CustomError",
      context: {foo: "bar"}
    )

    expected = %(#<Observable::StructuredError: message: message, type: CustomError, context: {foo: "bar"}>)

    assert_equal expected, error.pretty_print
  end

  # from_error factory method tests

  def test_from_error_creates_structured_error_from_standard_error
    original_error = StandardError.new("Database connection failed")

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_kind_of Observable::StructuredError, structured_error
    assert_equal "Database connection failed", structured_error.message
    assert_equal "StandardError", structured_error.type
    assert_equal({}, structured_error.context)
  end

  def test_from_error_uses_error_class_name_as_type_when_no_type_method
    original_error = ArgumentError.new("Invalid argument")

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_equal "ArgumentError", structured_error.type
    assert_equal "Invalid argument", structured_error.message
  end

  def test_from_error_uses_type_method_when_available
    original_error = Object.new
    def original_error.message
      "Custom error message"
    end

    def original_error.type
      "CustomErrorType"
    end

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_equal "CustomErrorType", structured_error.type
    assert_equal "Custom error message", structured_error.message
  end

  def test_from_error_uses_context_method_when_available
    original_error = Object.new
    def original_error.message
      "Error with context"
    end

    def original_error.context
      {user_id: 123, action: "login"}
    end

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_equal({user_id: 123, action: "login"}, structured_error.context)
    assert_equal "Error with context", structured_error.message
  end

  def test_from_error_handles_error_without_context_method
    original_error = StandardError.new("Simple error")

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_equal({}, structured_error.context)
    assert_equal "Simple error", structured_error.message
  end

  def test_from_error_uses_name_method_when_available
    original_error = Object.new
    def original_error.message
      "Named error"
    end

    def original_error.name
      "ValidationError"
    end

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_equal "ValidationError", structured_error.type
    assert_equal "Named error", structured_error.message
  end

  def test_from_error_prioritizes_type_method_over_name_method
    original_error = Object.new
    def original_error.message
      "Priority test error"
    end

    def original_error.type
      "TypeMethodResult"
    end

    def original_error.name
      "NameMethodResult"
    end

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_equal "TypeMethodResult", structured_error.type
  end

  def test_from_error_handles_nil_error
    structured_error = Observable::StructuredError.from_error(nil)

    assert_equal "", structured_error.message
    assert_equal "NilClass", structured_error.type
    assert_equal({}, structured_error.context)
  end

  def test_from_error_handles_error_with_nil_type_method
    original_error = Object.new
    def original_error.message
      "Error with nil type"
    end

    def original_error.type
      nil
    end

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_equal "Object", structured_error.type
    assert_equal "Error with nil type", structured_error.message
  end

  def test_from_error_handles_error_with_nil_name_method
    original_error = Object.new
    def original_error.message
      "Error with nil name"
    end

    def original_error.name
      nil
    end

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_equal "Object", structured_error.type
    assert_equal "Error with nil name", structured_error.message
  end

  def test_from_error_handles_error_with_nil_context_method
    original_error = Object.new
    def original_error.message
      "Error with nil context"
    end

    def original_error.context
      nil
    end

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_equal({}, structured_error.context)
    assert_equal "Error with nil context", structured_error.message
  end

  def test_from_error_handles_error_with_empty_string_type
    original_error = Object.new
    def original_error.message
      "Error with empty type"
    end

    def original_error.type
      ""
    end

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_equal "Object", structured_error.type
    assert_equal "Error with empty type", structured_error.message
  end

  def test_from_error_handles_error_with_complex_context
    original_error = Object.new
    def original_error.message
      "Complex context error"
    end

    def original_error.context
      {
        user: {id: 1, name: "John"},
        metadata: {timestamp: Time.now, tags: ["urgent"]},
        nested: {deep: {value: "test"}}
      }
    end

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_equal "Complex context error", structured_error.message
    assert_equal 1, structured_error.context[:user][:id]
    assert_equal "John", structured_error.context[:user][:name]
    assert_equal ["urgent"], structured_error.context[:metadata][:tags]
  end

  def test_from_error_handles_error_with_context_that_responds_to_to_h
    context_obj = Object.new
    def context_obj.to_h
      {converted: "value", nested: {data: "test"}}
    end

    original_error = Object.new
    def original_error.message
      "Error with to_h context"
    end
    original_error.define_singleton_method(:context) { context_obj }

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_equal({converted: "value", nested: {data: "test"}}, structured_error.context)
  end

  def test_from_error_handles_custom_error_class
    custom_error_class = Class.new(StandardError) do
      def type
        "CustomErrorClass"
      end

      def context
        {custom: "data", class_name: self.class.name}
      end
    end

    original_error = custom_error_class.new("Custom error message")

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_equal "Custom error message", structured_error.message
    assert_equal "CustomErrorClass", structured_error.type
    assert_equal({custom: "data", class_name: custom_error_class.name}, structured_error.context)
  end

  def test_from_error_handles_error_with_symbol_type
    original_error = Object.new
    def original_error.message
      "Symbol type error"
    end

    def original_error.type
      :symbol_type
    end

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_equal "symbol_type", structured_error.type
    assert_equal "Symbol type error", structured_error.message
  end

  def test_from_error_handles_error_with_symbol_name
    original_error = Object.new
    def original_error.message
      "Symbol name error"
    end

    def original_error.name
      :symbol_name
    end

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_equal "symbol_name", structured_error.type
    assert_equal "Symbol name error", structured_error.message
  end

  def test_from_error_handles_error_with_numeric_type
    original_error = Object.new
    def original_error.message
      "Numeric type error"
    end

    def original_error.type
      42
    end

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_equal "42", structured_error.type
    assert_equal "Numeric type error", structured_error.message
  end

  def test_from_error_handles_error_without_message_method
    original_error = Object.new
    def original_error.type
      "NoMessageError"
    end

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_equal "", structured_error.message
    assert_equal "NoMessageError", structured_error.type
  end

  def test_from_error_handles_error_with_exception_that_raises_in_type_method
    original_error = Object.new
    def original_error.message
      "Error with failing type method"
    end

    def original_error.type
      raise "Type method failed"
    end

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_equal "Object", structured_error.type
    assert_equal "Error with failing type method", structured_error.message
  end

  def test_from_error_handles_error_with_exception_that_raises_in_context_method
    original_error = Object.new
    def original_error.message
      "Error with failing context method"
    end

    def original_error.context
      raise "Context method failed"
    end

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_equal({}, structured_error.context)
    assert_equal "Error with failing context method", structured_error.message
  end

  def test_from_error_handles_error_with_exception_that_raises_in_name_method
    original_error = Object.new
    def original_error.message
      "Error with failing name method"
    end

    def original_error.name
      raise "Name method failed"
    end

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_equal "Object", structured_error.type
    assert_equal "Error with failing name method", structured_error.message
  end

  # Custom error converter configuration tests
  class CustomErrorClass < StandardError
    def type
      "CustomType"
    end

    def context
      {custom: "data"}
    end
  end

  def test_from_error_handles_multiple_custom_converters
    converter = lambda do |error|
      {
        message: "Message Prefix: #{error.message}",
        type: "Type Prefix: #{error.type}",
        context: error.context.merge(foo: "bar")
      }
    end

    Observable.configure do |config|
      config.custom_error_converters = {
        "StructuredErrorTest::CustomErrorClass" => converter
      }
    end

    login_error = CustomErrorClass.new("Invalid credentials")
    structured_login_error = Observable::StructuredError.from_error(login_error)

    assert_equal "Message Prefix: Invalid credentials", structured_login_error.message
    assert_equal "Type Prefix: CustomType", structured_login_error.type
    assert_equal({custom: "data", foo: "bar"}, structured_login_error.context)
  end

  def test_from_error_falls_back_to_default_behavior_when_no_converter_configured
    Observable.configure do |config|
      config.custom_error_converters = {}
    end

    original_error = CustomErrorClass.new("No converter")

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_equal "No converter", structured_error.message
    assert_equal "CustomType", structured_error.type
    assert_equal({custom: "data"}, structured_error.context)
  end

  def test_from_error_handles_converter_that_returns_invalid_structure
    invalid_converter = lambda do |error|
      {
        invalid: "structure"
      }
    end

    Observable.configure do |config|
      config.custom_error_converters = {
        "InstrumenterTest::CustomErrorClass" => invalid_converter
      }
    end

    original_error = CustomErrorClass.new("Test message")

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_equal "Test message", structured_error.message
    assert_equal "CustomType", structured_error.type
    assert_equal({custom: "data"}, structured_error.context)
  end

  def test_from_error_handles_converter_that_raises_exception
    custom_error_class = Class.new(StandardError)

    failing_converter = lambda do |error|
      raise "Converter failed"
    end

    Observable.configure do |config|
      config.custom_error_converters = {custom_error_class => failing_converter}
    end

    original_error = custom_error_class.new("Test message")

    structured_error = Observable::StructuredError.from_error(original_error)

    assert_equal "Test message", structured_error.message
    assert_equal "Observable::StructuredError", structured_error.type
    assert_equal({}, structured_error.context)
  end
end
