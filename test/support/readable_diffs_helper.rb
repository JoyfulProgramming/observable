# frozen_string_literal: true

require "super_diff"

module ReadableDiffsHelper
  def assert_equal(expected, actual, message = nil)
    if expected != actual
      diff = SuperDiff.diff(expected, actual)

      message = message ? "#{message}\n#{diff}" : diff
      raise Minitest::Assertion, SuperDiff::EqualityMatchers::Main.call(expected:, actual:)
    end
    super
  end

  def assert_match(pattern, actual, message = nil)
    if !pattern&.match?(actual)
      diff = SuperDiff.diff(pattern, actual)

      message = message ? "#{message}\nExpected pattern to match actual value:\n#{diff}" : "Expected pattern to match actual value:\n#{diff}"
      raise Minitest::Assertion, message
    end
  end

  def refute_match(pattern, actual, message = nil)
    if pattern&.match?(actual)
      diff = SuperDiff.diff("not to match #{pattern}", actual)

      message = message ? "#{message}\nExpected pattern not to match actual value:\n#{diff}" : "Expected pattern not to match actual value:\n#{diff}"
      raise Minitest::Assertion, message
    end
  end
end
