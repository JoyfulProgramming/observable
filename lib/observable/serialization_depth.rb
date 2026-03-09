# frozen_string_literal: true

module Observable
  class SerializationDepth
    DEFAULT_DEPTH = 2

    def initialize(config)
      @config = config
    end

    def for_class(class_name)
      if @config.is_a?(Integer)
        @config
      else
        @config[class_name] || @config[:default] || @config["default"] || DEFAULT_DEPTH
      end
    end
  end
end
