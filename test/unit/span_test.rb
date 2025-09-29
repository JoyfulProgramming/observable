require "test_helper"

class SpanTest < Minitest::Test
  def test_initializes_with_required_attributes
    span = Observable::Persistence::Span.new(
      id: "span123",
      name: "test_operation",
      kind: :internal,
      trace_id: "trace456",
      attrs: {"service.name" => "test_service"}
    )

    assert_equal "span123", span.id
    assert_equal "test_operation", span.name
    assert_equal :internal, span.kind
    assert_equal "trace456", span.trace_id
    assert_equal({"service.name" => "test_service"}, span.attrs)
  end

  def test_initializes_with_empty_attributes
    span = Observable::Persistence::Span.new(
      id: "span123",
      name: "test_operation",
      kind: :internal,
      trace_id: "trace456",
      attrs: {}
    )

    assert_equal({}, span.attrs)
  end

  def test_hex_trace_id_returns_trace_id
    span = create_span(trace_id: "trace789")
    assert_equal "trace789", span.hex_trace_id
  end

  def test_hex_span_id_returns_id
    span = create_span(id: "span789")
    assert_equal "span789", span.hex_span_id
  end

  def test_code_namespace_returns_code_namespace_attribute
    span = create_span(attrs: {"code.namespace" => "MyApp::Service"})
    assert_equal "MyApp::Service", span.code_namespace
  end

  def test_code_namespace_returns_messaging_sidekiq_job_class_when_code_namespace_missing
    span = create_span(attrs: {"messaging.sidekiq.job_class" => "MyJob"})
    assert_equal "MyJob", span.code_namespace
  end

  def test_code_namespace_returns_empty_string_when_neither_attribute_present
    span = create_span(attrs: {"other.attr" => "value"})
    assert_equal "", span.code_namespace
  end

  def test_producer_returns_true_for_producer_kind
    span = create_span(kind: :producer)
    assert span.producer?
  end

  def test_producer_returns_false_for_non_producer_kind
    span = create_span(kind: :consumer)
    refute span.producer?
  end

  def test_consumer_returns_true_for_consumer_kind
    span = create_span(kind: :consumer)
    assert span.consumer?
  end

  def test_consumer_returns_false_for_non_consumer_kind
    span = create_span(kind: :internal)
    refute span.consumer?
  end

  def test_from_spandata_creates_span_from_spandata_object
    spandata = create_spandata_mock(
      hex_span_id: "span123",
      hex_trace_id: "trace456",
      name: "test_operation",
      kind: :internal,
      attributes: {"service.name" => "test_service"}
    )

    span = Observable::Persistence::Span.from_spandata(spandata)

    assert_equal "span123", span.id
    assert_equal "trace456", span.trace_id
    assert_equal "test_operation", span.name
    assert_equal :internal, span.kind
    assert_equal({"service.name" => "test_service"}, span.attrs)
  end

  def test_from_span_or_spandata_returns_span_when_given_span
    original_span = create_span(id: "original123")
    result = Observable::Persistence::Span.from_span_or_spandata(original_span)
    assert_same original_span, result
  end

  def test_from_span_or_spandata_creates_span_when_given_spandata
    spandata = create_spandata_mock(
      hex_span_id: "span123",
      hex_trace_id: "trace456",
      name: "test_operation",
      kind: :internal,
      attributes: {"service.name" => "test_service"}
    )

    result = Observable::Persistence::Span.from_span_or_spandata(spandata)

    assert_instance_of Observable::Persistence::Span, result
    assert_equal "span123", result.id
    assert_equal "trace456", result.trace_id
    assert_equal "test_operation", result.name
    assert_equal :internal, result.kind
    assert_equal({"service.name" => "test_service"}, result.attrs)
  end

  def test_inspect_returns_string_representation
    span = create_span(
      id: "span123",
      name: "test_operation",
      kind: :internal,
      trace_id: "trace456",
      attrs: {"service.name" => "test_service"}
    )

    expected_string = [
      "  #{cyan}#{bold}test_operation#{reset}",
      "  id: #{white}span123#{reset}",
      "    #{yellow}service.name#{reset}: #{green}\"test_service\"#{reset}"
    ]
    assert_equal expected_string, span.inspect.split("\n")
  end

  def test_ai_returns_colored_output_with_name_and_id
    span = create_span(name: "test_operation", id: "span123")
    output = span.ai

    assert_includes output, "test_operation"
    assert_includes output, "span123"
    assert_includes output, "id:"
  end

  def test_ai_includes_attributes_when_present
    span = create_span(
      name: "test_operation",
      attrs: {"service.name" => "test_service", "http.method" => "GET"}
    )
    output = span.ai

    assert_includes output, "service.name"
    assert_includes output, "test_service"
    assert_includes output, "http.method"
    assert_includes output, "GET"
  end

  def test_ai_handles_empty_attributes
    span = create_span(name: "test_operation", attrs: {})
    output = span.ai

    assert_includes output, "test_operation"
    refute_includes output, "service.name"
  end

  def test_ai_ends_with_empty_line
    span = create_span(name: "test_operation")
    output = span.ai

    assert output.end_with?("\n")
  end

  private

  def create_span(overrides = {})
    defaults = {
      id: "span123",
      name: "test_operation",
      kind: :internal,
      trace_id: "trace456",
      attrs: {}
    }
    Observable::Persistence::Span.new(defaults.merge(overrides))
  end

  def create_spandata_mock(attributes)
    mock = Object.new
    attributes.each do |key, value|
      mock.define_singleton_method(key) { value }
    end
    # Add is_a? method to the mock
    mock.define_singleton_method(:is_a?) do |klass|
      klass != Observable::Persistence::Span
    end
    mock
  end

  def cyan
    Observable::Persistence::Span::CYAN
  end

  def bold
    Observable::Persistence::Span::BOLD
  end

  def reset
    Observable::Persistence::Span::RESET
  end

  def white
    Observable::Persistence::Span::WHITE
  end

  def yellow
    Observable::Persistence::Span::YELLOW
  end

  def green
    Observable::Persistence::Span::GREEN
  end
end
