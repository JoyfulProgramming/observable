require "test_helper"

class SpanRepoTest < Minitest::Test
  # #first
  def test_initializes_with_spans
    spans = [span_with(name: "test_span")]
    repo = Observable::Persistence::SpanRepo.new(spans: spans)

    assert_equal 1, repo.count
    assert_equal "test_span", repo.first.name
  end

  # #map
  def test_mapping_over_spans
    spans = [
      span_with(name: "span1"),
      span_with(name: "span2")
    ]
    repo = Observable::Persistence::SpanRepo.new(spans: spans)
    assert_equal ["span1", "span2"], repo.map(&:name)
  end

  # #select
  def test_selecting_spans
    spans = [
      span_with(name: "span1"),
      span_with(name: "span2")
    ]
    repo = Observable::Persistence::SpanRepo.new(spans: spans)
    assert_equal ["span1"], repo.select { |span| span.name == "span1" }.map(&:name)
  end

  # #in_code_namespace
  def test_in_code_namespace_filters_by_namespace
    spans = [
      span_with(name: "span1", attrs: {"code.namespace" => "UserService"}),
      span_with(name: "span2", attrs: {"code.namespace" => "OrderService"})
    ]
    repo = Observable::Persistence::SpanRepo.new(spans: spans)

    result = repo.in_code_namespace("UserService")

    assert_equal ["span1"], result.map(&:name)
  end

  def test_in_code_namespace_handles_missing_namespace
    spans = [
      span_with(name: "span1", attrs: {"code.namespace" => "UserService"}),
      span_with(name: "span2", attrs: {})
    ]
    repo = Observable::Persistence::SpanRepo.new(spans: spans)

    result = repo.in_code_namespace("UserService")

    assert_equal ["span1"], result.map(&:name)
  end

  def test_in_code_namespace_uses_sidekiq_job_class_fallback
    spans = [
      span_with(name: "span1", attrs: {"messaging.sidekiq.job_class" => "UserJob"}),
      span_with(name: "span2", attrs: {"code.namespace" => "UserService"})
    ]
    repo = Observable::Persistence::SpanRepo.new(spans: spans)

    result = repo.in_code_namespace("UserJob")

    assert_equal ["span1"], result.map(&:name)
  end

  # #in_root_trace
  def test_in_root_trace_returns_spans_with_multiple_spans_in_trace
    trace_id = "trace123"
    spans = [
      span_with(name: "span1", trace_id: trace_id),
      span_with(name: "span2", trace_id: trace_id),
      span_with(name: "span3", trace_id: "other_trace")
    ]
    repo = Observable::Persistence::SpanRepo.new(spans: spans)

    result = repo.in_root_trace

    assert_equal 2, result.count
    assert_equal ["span1", "span2"], result.map(&:name).sort
  end

  def test_in_root_trace_returns_empty_when_no_trace_has_multiple_spans
    spans = [
      span_with(name: "span1", trace_id: "trace1"),
      span_with(name: "span2", trace_id: "trace2")
    ]
    repo = Observable::Persistence::SpanRepo.new(spans: spans)

    result = repo.in_root_trace

    assert_equal 0, result.count
  end

  # #one_and_only!
  def test_one_and_only_returns_span_when_exactly_one_exists
    spans = [span_with(name: "single_span")]
    repo = Observable::Persistence::SpanRepo.new(spans: spans)

    result = repo.one_and_only!

    assert_equal "single_span", result.name
  end

  def test_one_and_only_raises_when_multiple_spans_exist
    spans = [
      span_with(name: "span1"),
      span_with(name: "span2")
    ]
    repo = described_class.new(spans: spans)

    error = assert_raises(ArgumentError) { repo.one_and_only! }
    assert_match(/Expected 1 span, but found 2/, error.message)
  end

  def test_one_and_only_raises_when_no_spans_exist
    repo = described_class.new(spans: [])

    error = assert_raises(ArgumentError) { repo.one_and_only! }
    assert_match(/Expected 1 span, but found 0/, error.message)
  end

  # #find_one!
  def test_find_one_returns_span_when_exactly_one_matches
    spans = [
      span_with(name: "span1", attrs: {"service" => "user"}),
      span_with(name: "span2", attrs: {"service" => "order"})
    ]
    repo = described_class.new(spans: spans)

    result = repo.find_one!(attrs: {"service" => "user"})

    assert_equal "span1", result.name
  end

  def test_find_one_works_with_block
    spans = [
      span_with(name: "span1", attrs: {"service" => "user"}),
      span_with(name: "span2", attrs: {"service" => "order"})
    ]
    repo = described_class.new(spans: spans)

    result = repo.find_one! { |span| span.name == "span1" }

    assert_equal "span1", result.name
  end

  def test_find_one_raises_when_no_spans_match
    spans = [span_with(name: "span1", attrs: {"service" => "user"})]
    repo = described_class.new(spans: spans)

    error = assert_raises(ArgumentError) { repo.find_one!(attrs: {"service" => "order"}) }
    assert_equal "No spans found", error.message
  end

  def test_find_one_raises_when_multiple_spans_match
    spans = [
      span_with(name: "span1", attrs: {"service" => "user"}),
      span_with(name: "span2", attrs: {"service" => "user"})
    ]
    repo = described_class.new(spans: spans)

    error = assert_raises(ArgumentError) { repo.find_one!(attrs: {"service" => "user"}) }
    assert_match(/Too many spans found/, error.message)
  end

  # #empty?
  def test_empty_returns_true_when_no_spans
    repo = described_class.new(spans: [])

    assert repo.empty?
  end

  def test_empty_returns_false_when_spans_exist
    spans = [span_with(name: "span1")]
    repo = described_class.new(spans: spans)

    refute repo.empty?
  end

  def test_empty_works_with_block
    spans = [
      span_with(name: "span1", attrs: {"service" => "user"}),
      span_with(name: "span2", attrs: {"service" => "order"})
    ]
    repo = Observable::Persistence::SpanRepo.new(spans: spans)

    assert repo.empty? { |span| span.attrs["service"] == "payment" }
    refute repo.empty? { |span| span.attrs["service"] == "user" }
  end

  # #raise_none_found
  def test_raise_none_found_raises_appropriate_error
    repo = Observable::Persistence::SpanRepo.new(spans: [])

    error = assert_raises(ArgumentError) { repo.raise_none_found }
    assert_equal "No spans found", error.message
  end

  # #raise_too_many_found
  def test_raise_too_many_found_raises_appropriate_error
    spans = [
      span_with(name: "span1"),
      span_with(name: "span2")
    ]
    repo = described_class.new(spans: spans)

    error = assert_raises(ArgumentError) { repo.raise_too_many_found { |span| true } }
    assert_match(/Too many spans found/, error.message)
  end

  # #find_by!
  def test_find_by_returns_first_span_with_matching_name
    spans = [
      span_with(name: "span1", attrs: {"service" => "user"}),
      span_with(name: "span2", attrs: {"service" => "order"}),
      span_with(name: "span1", attrs: {"service" => "payment"})
    ]
    repo = described_class.new(spans: spans)

    result = repo.find_by!(name: "span1")

    assert_equal "span1", result.name
    assert_equal "user", result.attrs["service"]
  end

  def test_find_by_raises_not_found_when_no_spans_match
    spans = [
      span_with(name: "span1", attrs: {"service" => "user"}),
      span_with(name: "span2", attrs: {"service" => "order"})
    ]
    repo = described_class.new(spans: spans)

    error = assert_raises(Observable::NotFound) { repo.find_by!(name: "nonexistent") }
    assert_match(/No spans found with name: nonexistent/, error.message)
  end

  # #to_block
  def test_to_block_creates_matching_block_for_attributes
    spans = [
      span_with(name: "span1", attrs: {"service" => "user", "version" => "1.0"}),
      span_with(name: "span2", attrs: {"service" => "order", "version" => "1.0"})
    ]
    repo = described_class.new(spans: spans)

    block = repo.to_block({"service" => "user"})
    matching_spans = spans.select(&block)

    assert_equal 1, matching_spans.count
    assert_equal "span1", matching_spans.first.name
  end

  def test_to_block_handles_string_and_symbol_keys
    spans = [
      span_with(name: "span1", attrs: {"service" => "user"}),
      span_with(name: "span2", attrs: {service: "user"})
    ]
    repo = described_class.new(spans: spans)

    block = repo.to_block({service: "user"})
    matching_spans = spans.select(&block)

    assert_equal 2, matching_spans.count
  end

  # #where
  def test_where_returns_spans_matching_simple_attribute
    spans = [
      span_with(name: "span1", attrs: {"error" => true}),
      span_with(name: "span2", attrs: {"error" => false}),
      span_with(name: "span3", attrs: {"error" => true})
    ]
    repo = described_class.new(spans: spans)

    result = repo.where(error: true)

    assert_equal 2, result.count
    assert_equal ["span1", "span3"], result.map(&:name).sort
  end

  def test_where_returns_spans_matching_string_attribute
    spans = [
      span_with(name: "span1", attrs: {"service" => "user"}),
      span_with(name: "span2", attrs: {"service" => "order"}),
      span_with(name: "span3", attrs: {"service" => "user"})
    ]
    repo = described_class.new(spans: spans)

    result = repo.where(service: "user")

    assert_equal 2, result.count
    assert_equal ["span1", "span3"], result.map(&:name).sort
  end

  def test_where_returns_empty_array_when_no_matches
    spans = [
      span_with(name: "span1", attrs: {"service" => "user"}),
      span_with(name: "span2", attrs: {"service" => "order"})
    ]
    repo = described_class.new(spans: spans)

    result = repo.where(service: "payment")

    assert_equal 0, result.count
  end

  def test_where_supports_nested_hash_syntax
    spans = [
      span_with(name: "span1", attrs: {"code" => {"return" => "hello"}}),
      span_with(name: "span2", attrs: {"code" => {"return" => "world"}}),
      span_with(name: "span3", attrs: {"code" => {"error" => "failed"}})
    ]
    repo = described_class.new(spans: spans)

    result = repo.where(code: {return: "hello"})

    assert_equal 1, result.count
    assert_equal "span1", result.first.name
  end

  def test_where_supports_dot_notation_for_nested_keys
    spans = [
      span_with(name: "span1", attrs: {"code" => {"return" => "hello"}}),
      span_with(name: "span2", attrs: {"code" => {"return" => "world"}}),
      span_with(name: "span3", attrs: {"code" => {"error" => "failed"}})
    ]
    repo = described_class.new(spans: spans)

    result = repo.where("code.return" => "hello")

    assert_equal 1, result.count
    assert_equal "span1", result.first.name
  end

  def test_where_supports_deeply_nested_dot_notation
    spans = [
      span_with(name: "span1", attrs: {"user" => {"profile" => {"name" => "John"}}}),
      span_with(name: "span2", attrs: {"user" => {"profile" => {"name" => "Jane"}}}),
      span_with(name: "span3", attrs: {"user" => {"settings" => {"theme" => "dark"}}})
    ]
    repo = described_class.new(spans: spans)

    result = repo.where("user.profile.name" => "John")

    assert_equal 1, result.count
    assert_equal "span1", result.first.name
  end

  def test_where_supports_multiple_criteria
    spans = [
      span_with(name: "span1", attrs: {"service" => "user", "error" => true}),
      span_with(name: "span2", attrs: {"service" => "user", "error" => false}),
      span_with(name: "span3", attrs: {"service" => "order", "error" => true})
    ]
    repo = described_class.new(spans: spans)

    result = repo.where(service: "user", error: true)

    assert_equal 1, result.count
    assert_equal "span1", result.first.name
  end

  def test_where_supports_mixed_nested_and_simple_criteria
    spans = [
      span_with(name: "span1", attrs: {"service" => "user", "code" => {"return" => "success"}}),
      span_with(name: "span2", attrs: {"service" => "user", "code" => {"return" => "error"}}),
      span_with(name: "span3", attrs: {"service" => "order", "code" => {"return" => "success"}})
    ]
    repo = described_class.new(spans: spans)

    result = repo.where(:service => "user", "code.return" => "success")

    assert_equal 1, result.count
    assert_equal "span1", result.first.name
  end

  def test_where_handles_missing_nested_keys_gracefully
    spans = [
      span_with(name: "span1", attrs: {"code" => {"return" => "hello"}}),
      span_with(name: "span2", attrs: {"code" => {}}),
      span_with(name: "span3", attrs: {})
    ]
    repo = described_class.new(spans: spans)

    result = repo.where("code.return" => "hello")

    assert_equal 1, result.count
    assert_equal "span1", result.first.name
  end

  def test_where_returns_new_span_repo_instance
    spans = [
      span_with(name: "span1", attrs: {"error" => true}),
      span_with(name: "span2", attrs: {"error" => false})
    ]
    repo = described_class.new(spans: spans)

    result = repo.where(error: true)

    assert_kind_of described_class, result
    refute_equal repo.object_id, result.object_id
  end

  # #ai
  def test_ai_returns_ansi_colored_formatted_string_grouped_by_trace_id
    trace_id = "trace123"
    spans = [
      span_with(name: "span1", trace_id: trace_id, attrs: {"service" => "user"}),
      span_with(name: "span2", trace_id: trace_id, attrs: {"service" => "order"}),
      span_with(name: "span3", trace_id: "other_trace", attrs: {"service" => "payment"})
    ]
    repo = described_class.new(spans: spans)

    output = repo.ai

    # Should contain ANSI color codes
    assert_match(/\e\[/, output, "Output should contain ANSI color codes")

    # Should show trace IDs as headers with colors
    assert_match(/#{trace_id}/, output)
    assert_match(/other_trace/, output)

    # Should show spans nested under their trace IDs
    assert_match(/span1/, output)
    assert_match(/span2/, output)
    assert_match(/span3/, output)

    # Should show attributes as key-value pairs
    assert_match(/service.*user/, output)
    assert_match(/service.*order/, output)
    assert_match(/service.*payment/, output)

    assert_kind_of String, output
  end

  private

  def described_class
    Observable::Persistence::SpanRepo
  end

  def span_with(name:, trace_id: "trace123", attrs: {})
    Observable::Persistence::Span.new(
      id: "span_#{name}",
      name: name,
      kind: :internal,
      trace_id: trace_id,
      attrs: attrs
    )
  end
end
