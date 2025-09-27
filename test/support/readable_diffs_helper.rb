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
end
