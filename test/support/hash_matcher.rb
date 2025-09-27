# frozen_string_literal: true

module HashMatcher
  def assert_hashes_match(expected, actual, message = nil, match_keys: nil)
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
    filtered_actual = actual.select { |key, _| matches_pattern?(match_keys, key) }
    assert_equal mutated_expected, filtered_actual, message
  end

  def matches_pattern?(pattern, value)
    if pattern.nil?
      true
    elsif pattern.is_a?(Array)
      pattern.include?(value)
    elsif pattern.is_a?(Regexp)
      pattern.match?(value)
    elsif pattern.is_a?(Range)
      pattern.include?(value)
    else
      pattern == value
    end
  end
end
