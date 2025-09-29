# frozen_string_literal: true

module MethodHelpers
  def method_with_no_args(instrumenter)
    instrumenter.instrument(binding) do
      # Some work
    end
  end

  def method_with_args(instrumenter, arg1, arg2, arg3)
    instrumenter.instrument(binding) do
      # Some work with args
    end
  end

  def method_with_hash_arg(instrumenter, hash_arg)
    instrumenter.instrument(binding) do
      # Some work with hash
    end
  end

  def method_with_custom_arg(instrumenter, custom_arg)
    instrumenter.instrument(binding) do
      # Some work with custom object
    end
  end

  def method_with_array_arg(instrumenter, array_arg)
    instrumenter.instrument(binding) do
      # Some work with array
    end
  end

  def method_with_complex_arg(instrumenter, complex_arg)
    instrumenter.instrument(binding) do
      # Some work with complex data
    end
  end

  def method_that_raises_exception(instrumenter, error_or_message)
    instrumenter.instrument(binding) do
      if error_or_message.is_a?(String)
        raise StandardError, error_or_message
      else
        raise error_or_message
      end
    end
  end

  def method_with_return_value(instrumenter, return_value:)
    instrumenter.instrument do
      return_value
    end
  end
end
