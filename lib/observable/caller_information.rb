# frozen_string_literal: true

module Observable
  CallerInformation = Struct.new(:method_name, :namespace, :filepath, :line_number, :arguments, :is_class_method, keyword_init: true)
end
