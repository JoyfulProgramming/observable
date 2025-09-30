# frozen_string_literal: true

module Observable
  class StructuredError < StandardError
    attr_reader :context, :type

    def initialize(message, type: self.class.name, context: {})
      @context = context.to_h
      @type = (type || self.class.name).to_s
      super(message)
    end

    def to_h
      {message: message}.merge(@context)
    end
  end
end
