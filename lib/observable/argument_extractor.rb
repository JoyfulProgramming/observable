# frozen_string_literal: true

module Observable
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
      args = {}
      extract_local_variables_with_numeric_indexing(args)
      args
    rescue StandardError
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
end
