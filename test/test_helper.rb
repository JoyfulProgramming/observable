require "support/simplecov"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "observable"
require "minitest/autorun"
require "support/tracing_test_helper"
require "support/readable_diffs_helper"
require "support/hash_matcher"
require "support/opentelemetry"

class Minitest::Test
  include ReadableDiffsHelper
  include HashMatcher
  include TracingTestHelper
end
