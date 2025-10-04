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

    def inspect
      "#<#{self.class.name}: #{message}, type=#{type}, context=#{@context}>"
    end

    def pretty_print
      "#<#{self.class.name}: message: #{message}, type: #{type}, context: #{@context}>"
    end

    def self.from_error(error)
      custom_converter_result = try_custom_converter(error)
      if custom_converter_result
        new(
          custom_converter_result[:message],
          type: custom_converter_result[:type],
          context: custom_converter_result[:context]
        )
      else
        new(
          safe_message(error),
          type: safe_type(error),
          context: safe_context(error)
        )
      end
    end

    def self.safe_message(error)
      if error.respond_to?(:message)
        error.message.to_s
      else
        ""
      end
    rescue
      ""
    end

    def self.safe_type(error)
      return "NilClass" if error.nil?

      if error.respond_to?(:type)
        type_value = error.type
        return type_value.to_s unless type_value.nil? || type_value.to_s.empty?
      end

      if error.respond_to?(:name)
        name_value = error.name
        return name_value.to_s unless name_value.nil? || name_value.to_s.empty?
      end

      error.class.name
    rescue
      error.class.name
    end

    def self.safe_context(error)
      if error.nil?
        {}
      elsif error.respond_to?(:to_h)
        error.to_h
      elsif error.respond_to?(:context)
        error.context
      else
        {}
      end
    rescue
      {}
    end

    def self.try_custom_converter(error)
      return nil if error.nil?

      converters = Configuration.config.custom_error_converters
      return nil if converters.empty?

      converter = converters[error.class.name]
      return nil unless converter

      result = begin
        converter.call(error)
      rescue
        nil
      end

      if result&.is_a?(Hash) &&
          result.key?(:message) &&
          result.key?(:type) &&
          result.key?(:context)
        result
      end
    end

    private_class_method :safe_message, :safe_type, :safe_context, :try_custom_converter
  end
end
