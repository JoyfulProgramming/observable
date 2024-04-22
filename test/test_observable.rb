# frozen_string_literal: true

require "test_helper"

class TestObservable < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Observable::VERSION
  end

  def test_it_does_something_useful
    assert false
  end
end
