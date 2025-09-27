# frozen_string_literal: true

require "simplecov"

SimpleCov.start do
  add_filter "/test/"
  add_filter "/spec/"
  add_filter "/bin/"
  add_filter "/.bundle/"
  track_files "lib/**/*.rb"

  minimum_coverage 70

  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::SimpleFormatter
  ])
end
