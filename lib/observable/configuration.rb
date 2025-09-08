require "dry/configurable"

module Observable
  class Configuration
    extend Dry::Configurable

    setting :tracer_name, default: "observable"
    setting :transport, default: :otel
    setting :app_namespace, default: "app"
    setting :attribute_namespace, default: "app"
    setting :formatters, default: {default: :to_h}
    setting :pii_filters, default: []
    setting :serialization_depth, default: {default: 2}
    setting :track_return_values, default: true
  end
end
