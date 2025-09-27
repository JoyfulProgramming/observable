# frozen_string_literal: true

require_relative "observable/version"
require_relative "observable/configuration"
require_relative "observable/instrumenter"

module Observable
  class Error < StandardError; end

  def self.instrumenter(config: nil)
    Instrumenter.new(config: config)
  end
end
