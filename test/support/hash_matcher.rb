# frozen_string_literal: true

module HashMatcher
  def assert_matches(expected, actual, message = nil)
    mutated_expected = expected.map do |key, value|
      if value.is_a?(Regexp) && actual[key].is_a?(String)
        [key, value.match?(actual[key]) ? actual[key] : value]
      elsif value.is_a?(Regexp) && !actual[key].is_a?(String)
        raise TypeError, "Cannot match #{key} with #{value.inspect} - needed a String got #{actual[key].class}"
      elsif value.is_a?(Range) && actual[key].is_a?(Numeric)
        [key, value.include?(actual[key]) ? actual[key] : value]
      elsif value.is_a?(Range) && !actual[key].is_a?(Numeric)
        raise TypeError, "Cannot match #{key} with #{value.inspect} - needed a Numeric got #{actual[key].class}"
      else
        [key, value]
      end
    end.to_h
    assert_equal mutated_expected, actual, message
  end
end
