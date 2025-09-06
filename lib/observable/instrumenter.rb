require "opentelemetry/sdk"
require "dry/configurable"

module Observable
  # Configuration using Dry::Configurable
  class Configuration
    extend Dry::Configurable

    setting :transport, default: :otel
    setting :app_namespace, default: nil
    setting :attribute_namespace, default: nil
    setting :tracer_names, default: {default: "terragon_instrumenter"}
    setting :formatters, default: {default: :to_h}
    setting :pii_filters, default: []
    setting :max_serialization_depth, default: 4
    setting :track_return_values, default: true
  end

  class Instrumenter
    attr_reader :last_captured_method_name, :last_captured_namespace, :config

    def initialize(tracer: nil, config: nil)
      @config = config || Configuration.config
      @tracer = tracer || OpenTelemetry.tracer_provider.tracer("terragon_instrumenter")
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

      # Find the first location that's not in the instrumenter file
      instrumenter_file = __FILE__
      caller_location = locations.find { |loc| loc.path != instrumenter_file }

      # If we can't find a caller outside the instrumenter, use the first location
      caller_location || locations.first
    rescue => e
      raise InstrumentationError, "Error finding caller location: #{e.message}"
    end

    def extract_namespace_from_path(file_path)
      return "UnknownClass" if file_path.nil? || file_path.empty?

      file_name = File.basename(file_path, ".*")
      return "UnknownClass" if file_name.empty?

      # Convert snake_case to PascalCase for class naming convention
      file_name.split("_").map(&:capitalize).join
    rescue
      "UnknownClass" # In production, log this error
    end

    def extract_actual_class_name
      if @caller_binding
        # Try to get the class name from the caller's binding
        begin
          # Look for 'self' in the binding to get the class
          caller_self = @caller_binding.eval("self")
          # Handle both class-level methods (caller_self is a Class) and instance methods
          if caller_self.is_a?(Class)
            caller_self.name
          else
            caller_self.class.name
          end
        rescue
          # Fallback to file-based extraction if binding introspection fails
          extract_namespace_from_path(@caller_binding.eval("__FILE__"))
        end
      else
        # No binding provided, extract from caller location
        caller_location = find_caller_location
        extract_namespace_from_path(caller_location.path)
      end
    rescue
      "UnknownClass" # Final fallback
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
      # Create span name with full class name and appropriate separator
      separator = caller_info.is_class_method ? "." : "#"

      # Check if the method_name already includes the class name to avoid duplication
      if caller_info.method_name.include?("#") || caller_info.method_name.include?(".")
        span_name = caller_info.method_name
        # Extract just the method name for test access (everything after the last # or .)
        method_name_only = caller_info.method_name.split(/[#.]/).last
      else
        span_name = "#{caller_info.namespace}#{separator}#{caller_info.method_name}"
        method_name_only = caller_info.method_name
      end

      # Store information for test access
      @last_captured_method_name = method_name_only
      @last_captured_namespace = caller_info.namespace
      @tracer.in_span(span_name) do |span|
        set_span_attributes(span, caller_info)

        begin
          result = block.call
          # Set success status
          span.set_attribute("error", false)

          serialize_return_value(span, result)

          result
        rescue => e
          # Record exception information
          span.set_attribute("error", true)
          span.set_attribute("error.type", e.class.name)
          span.set_attribute("error.message", e.message)

          # Set span status to error (OpenTelemetry convention)
          span.status = OpenTelemetry::Trace::Status.error(e.message)

          # Re-raise the exception to preserve original behavior
          raise
        end
      end
    end

    def set_span_attributes(span, caller_info)
      span.set_attribute("code.function", caller_info.method_name)
      span.set_attribute("code.namespace", caller_info.namespace)
      span.set_attribute("code.filepath", caller_info.filepath)
      span.set_attribute("code.lineno", caller_info.line_number)

      # Add app namespace if configured
      if @config.app_namespace
        span.set_attribute("app.namespace", @config.app_namespace)
      end

      # Serialize and set argument attributes with PII filtering
      caller_info.arguments.each do |param_index, param_data|
        if param_data.is_a?(Hash) && param_data.key?(:value) && param_data.key?(:param_name)
          # New format with value and param_name
          serialize_argument(span, "code.arguments.#{param_index}", param_data[:value], param_data[:param_name])
        else
          # Fallback for old format
          serialize_argument(span, "code.arguments.#{param_index}", param_data, param_index)
        end
      end
    end

    # Serialize argument values into span attributes
    def serialize_argument(span, attribute_prefix, value, param_name = nil, depth = 0)
      # Check for PII filtering first
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

    # Serialize return values into span attributes
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
      return if depth >= @config.max_serialization_depth # Prevent deep nesting

      hash.each do |key, value|
        key_str = key.to_s
        next if should_filter_pii?(key_str)
        serialize_argument(span, "#{prefix}.#{key_str}", value, nil, depth + 1)
      end
    end

    def serialize_array(span, prefix, array, depth = 0)
      return if depth > @config.max_serialization_depth # Prevent deep nesting

      # Limit to first 10 items
      items_to_process = [array.length, 10].min
      array.first(items_to_process).each_with_index do |item, index|
        serialize_argument(span, "#{prefix}.#{index}", item, nil, depth + 1)
      end
    end

    def serialize_object(span, prefix, obj, depth = 0)
      # Always include the class information
      span.set_attribute("#{prefix}.class", obj.class.name)

      # Try to use configured formatter first
      formatter = find_formatter_for_class(obj.class.name)

      if formatter && obj.respond_to?(formatter)
        result = obj.send(formatter)
        if result.is_a?(Hash)
          serialize_hash(span, prefix, result, depth)
          return
        end
      end

      # Try default formatter
      default_formatter = @config.formatters[:default]
      if default_formatter && obj.respond_to?(default_formatter)
        result = obj.send(default_formatter)
        if result.is_a?(Hash)
          serialize_hash(span, prefix, result, depth)
          return
        end
      end

      # Fall back to string representation
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

    # Extract arguments using binding or fallback to heuristics
    def extract_arguments_from_caller(caller_location)
      ArgumentExtractor.new(caller_location, @caller_binding).extract
    end

    # Value object to hold caller information
    CallerInformation = Struct.new(:method_name, :namespace, :filepath, :line_number, :arguments, :is_class_method, keyword_init: true)

    # Real implementation for argument extraction using binding or fallback
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
        # Extract parameter names and values from the binding
        @caller_binding.local_variables
        args = {}

        # Extract all local variables and use numeric indexing for positional args
        extract_local_variables_with_numeric_indexing(args)

        args
      rescue
        # If binding introspection fails, return empty hash
        # In production, this should be logged as a warning
        {}
      end

      def extract_local_variables_with_numeric_indexing(args)
        local_vars = @caller_binding.local_variables
        positional_index = 0

        local_vars.each do |var_name|
          var_name_str = var_name.to_s

          # Skip internal variables that start with underscore or common temporaries
          next if var_name_str.start_with?("_") || var_name == :instrumenter

          value = @caller_binding.local_variable_get(var_name)

          # Store both numeric index and original parameter name for PII filtering
          args[positional_index.to_s] = {
            value: value,
            param_name: var_name_str
          }
          positional_index += 1
        end
      end
    end

    # Custom error class for instrumentation failures
    class InstrumentationError < StandardError; end
  end
end
