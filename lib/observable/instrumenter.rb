require "opentelemetry/sdk"
require "dry/configurable"

module Observable
  class Configuration
    extend Dry::Configurable

    setting :tracer_name, default: "observable"
    setting :transport, default: :otel
    setting :app_namespace, default: "app"
    setting :attribute_namespace, default: "app"
    setting :formatter, default: {default: :to_h}
    setting :pii_filters, default: []
    setting :serialization_depth, default: {default: 2}
    setting :track_return_values, default: true
  end

  class Instrumenter
    attr_reader :last_captured_method_name, :last_captured_namespace, :config

    def initialize(tracer: nil, config: nil)
      @config = config || Configuration.config
      @tracer = tracer || OpenTelemetry.tracer_provider.tracer(@config.tracer_name)
    end

    def instrument(caller_binding = nil, &block)
      @caller_binding = caller_binding
      caller_info = extract_caller_information
      create_instrumented_span(caller_info, &block)
    end

    private

    # Extracts all information about the calling method in one place
    def extract_caller_information
      caller_location = find_caller_location
      namespace = extract_actual_class_name
      is_class_method = determine_if_class_method

      CallerInformation.new(
        method_name: caller_location.label,
        namespace: namespace,
        filepath: caller_location.path,
        line_number: caller_location.lineno,
        arguments: extract_arguments_from_caller(caller_location),
        is_class_method: is_class_method
      )
    end

    def find_caller_location
      locations = caller_locations(1, 10)
      raise InstrumentationError, "Unable to determine caller location" if locations.nil? || locations.empty?

      instrumenter_file = __FILE__
      caller_location = locations.find { |loc| loc.path != instrumenter_file }

      caller_location || locations.first
    rescue => e
      raise InstrumentationError, "Error finding caller location: #{e.message}"
    end

    def extract_namespace_from_path(file_path)
      return "UnknownClass" if file_path.nil? || file_path.empty?

      file_name = File.basename(file_path, ".*")
      return "UnknownClass" if file_name.empty?

      file_name.split("_").map(&:capitalize).join
    rescue
      "UnknownClass"
    end

    def extract_actual_class_name
      if @caller_binding
        begin
          caller_self = @caller_binding.eval("self")
          if caller_self.is_a?(Class)
            caller_self.name
          else
            caller_self.class.name
          end
        rescue
          extract_namespace_from_path(@caller_binding.eval("__FILE__"))
        end
      else
        caller_location = find_caller_location
        extract_namespace_from_path(caller_location.path)
      end
    rescue
      "UnknownClass"
    end

    def determine_if_class_method
      return false unless @caller_binding

      begin
        caller_self = @caller_binding.eval("self")
        caller_self.is_a?(Class)
      rescue
        false
      end
    end

    def create_instrumented_span(caller_info, &block)
      separator = caller_info.is_class_method ? "." : "#"

      if caller_info.method_name.include?("#") || caller_info.method_name.include?(".")
        span_name = caller_info.method_name
        method_name_only = caller_info.method_name.split(/[#.]/).last
      else
        span_name = "#{caller_info.namespace}#{separator}#{caller_info.method_name}"
        method_name_only = caller_info.method_name
      end

      @last_captured_method_name = method_name_only
      @last_captured_namespace = caller_info.namespace
      @tracer.in_span(span_name) do |span|
        set_span_attributes(span, caller_info)

        begin
          result = block.call
          span.set_attribute("error", false)
          serialize_return_value(span, result)
          result
        rescue => e
          span.set_attribute("error", true)
          span.set_attribute("error.type", e.class.name)
          span.set_attribute("error.message", e.message)
          span.status = OpenTelemetry::Trace::Status.error(e.message)
          raise
        end
      end
    end

    def set_span_attributes(span, caller_info)
      span.set_attribute("code.function", caller_info.method_name)
      span.set_attribute("code.namespace", caller_info.namespace)
      span.set_attribute("code.filepath", caller_info.filepath)
      span.set_attribute("code.lineno", caller_info.line_number)

      if @config.app_namespace
        span.set_attribute("app.namespace", @config.app_namespace)
      end

      caller_info.arguments.each do |param_index, param_data|
        if param_data.is_a?(Hash) && param_data.key?(:value) && param_data.key?(:param_name)
          serialize_argument(span, "code.arguments.#{param_index}", param_data[:value], param_data[:param_name])
        else
          serialize_argument(span, "code.arguments.#{param_index}", param_data, param_index)
        end
      end
    end

    def serialize_argument(span, attribute_prefix, value, param_name = nil, depth = 0)
      if param_name && should_filter_pii?(param_name)
        span.set_attribute(attribute_prefix, "[FILTERED]")
        return
      end

      case value
      when String, Numeric, TrueClass, FalseClass, NilClass
        span.set_attribute(attribute_prefix, value)
      when Hash
        serialize_hash(span, attribute_prefix, value, depth)
      when Array
        serialize_array(span, attribute_prefix, value, depth)
      else
        serialize_object(span, attribute_prefix, value, depth)
      end
    end

    def serialize_return_value(span, value)
      return unless @config.track_return_values

      case value
      when NilClass
        span.set_attribute("code.return", "nil")
      when String, Numeric, TrueClass, FalseClass
        span.set_attribute("code.return", value)
      when Hash
        serialize_hash(span, "code.return", value, 2)
      when Array
        serialize_array(span, "code.return", value, 2)
      else
        serialize_object(span, "code.return", value, 2)
      end
    end

    def serialize_hash(span, prefix, hash, depth = 0)
      return if depth >= @config.max_serialization_depth

      hash.each do |key, value|
        key_str = key.to_s
        next if should_filter_pii?(key_str)
        serialize_argument(span, "#{prefix}.#{key_str}", value, nil, depth + 1)
      end
    end

    def serialize_array(span, prefix, array, depth = 0)
      return if depth > @config.max_serialization_depth

      items_to_process = [array.length, 10].min
      array.first(items_to_process).each_with_index do |item, index|
        serialize_argument(span, "#{prefix}.#{index}", item, nil, depth + 1)
      end
    end

    def serialize_object(span, prefix, obj, depth = 0)
      span.set_attribute("#{prefix}.class", obj.class.name)

      formatter = find_formatter_for_class(obj.class.name)

      if formatter && obj.respond_to?(formatter)
        result = obj.send(formatter)
        if result.is_a?(Hash)
          serialize_hash(span, prefix, result, depth)
          return
        end
      end

      default_formatter = @config.formatters[:default]
      if default_formatter && obj.respond_to?(default_formatter)
        result = obj.send(default_formatter)
        if result.is_a?(Hash)
          serialize_hash(span, prefix, result, depth)
          return
        end
      end

      span.set_attribute(prefix, obj.to_s)
    end

    def find_formatter_for_class(class_name)
      @config.formatters[class_name]
    end

    def should_filter_pii?(param_name)
      return false if @config.pii_filters.empty?

      param_name_str = param_name.to_s.downcase
      @config.pii_filters.any? { |pattern| pattern.match?(param_name_str) }
    end

    def extract_arguments_from_caller(caller_location)
      ArgumentExtractor.new(caller_location, @caller_binding).extract
    end

    CallerInformation = Struct.new(:method_name, :namespace, :filepath, :line_number, :arguments, :is_class_method, keyword_init: true)

    class ArgumentExtractor
      def initialize(caller_location, caller_binding = nil)
        @caller_location = caller_location
        @caller_binding = caller_binding
        @method_name = caller_location.label
      end

      def extract
        return {} unless @caller_binding
        extract_from_binding
      end

      private

      def extract_from_binding
        @caller_binding.local_variables
        args = {}

        extract_local_variables_with_numeric_indexing(args)

        args
      rescue
        {}
      end

      def extract_local_variables_with_numeric_indexing(args)
        local_vars = @caller_binding.local_variables
        positional_index = 0

        local_vars.each do |var_name|
          var_name_str = var_name.to_s

          next if var_name_str.start_with?("_") || var_name == :instrumenter

          value = @caller_binding.local_variable_get(var_name)

          args[positional_index.to_s] = {
            value: value,
            param_name: var_name_str
          }
          positional_index += 1
        end
      end
    end

    class InstrumentationError < StandardError; end
  end
end
