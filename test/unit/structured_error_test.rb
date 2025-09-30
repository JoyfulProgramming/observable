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
end
