require "support/simplecov"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "observable"
require "minitest/autorun"
require "observable/tracing_test_helper"
require "support/readable_diffs_helper"
require "support/hash_matcher"
require "support/opentelemetry"
require "stringio"

class Minitest::Test
  include ReadableDiffsHelper
  include HashMatcher
  include Observable::TracingTestHelper

  def capture_output(&block)
    original_stdout = $stdout
    $stdout = StringIO.new
    block.call
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
