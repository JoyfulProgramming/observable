# Observable

Automatic OpenTelemetry instrumentation for Ruby methods with configurable serialization, PII filtering, and argument tracking.

## Getting Started

```bash
bundle add observable
```

Or

```ruby
# Gemfile
gem 'observable'
```

Basic usage:

```ruby
require 'observable'

class UserService
  def initialize
    @instrumenter = Observable::Instrumenter.new
  end

  def create_user(name, email)
    @instrumenter.instrument(binding) do
      User.create(name: name, email: email)
    end
  end
end
```

OpenTelemetry spans are automatically created with method names, arguments, return values, and exceptions.

## Configuration

Configure globally or per-instrumenter:

```ruby
# Global configuration
Observable::Configuration.configure do |config|
  config.app_namespace = "my_app"
  config.track_return_values = true
  config.max_serialization_depth = 4
  config.pii_filters = [/password/i, /secret/i]
end

# Per-instrumenter configuration
config = Observable::Configuration.new
config.track_return_values = false
instrumenter = Observable::Instrumenter.new(config: config)
```

### Default Configuration

- `transport`: `:otel` - Uses OpenTelemetry SDK
- `track_return_values`: `true` - Captures method return values
- `max_serialization_depth`: `4` - Prevents infinite recursion
- `formatters`: `{default: :to_h}` - Object serialization method
- `pii_filters`: `[]` - Regex patterns to filter sensitive data

## OpenTelemetry Integration

This library seamlessly integrates with OpenTelemetry, the industry-standard observability framework. Spans are automatically created with standardized naming (`Class#method` or `Class.method`) and include rich metadata about method invocations, making your Ruby applications immediately observable without manual instrumentation.

## Custom Formatters

Control how domain objects are serialized in spans by configuring custom formatters.

```ruby
Observable::Configuration.configure do |config|
  config.formatters = {
    default: :to_h,
    'YourCustomClass' => :to_formatted_h
  }
end
```

## Example

A domain object `Customer` has an `Invoice`.

Objective - only send the invoice ID to the trace to save data.

Imagine domain objects are `Dry::Struct` value objects:

```ruby
class Customer < Dry::Struct
  attribute :id, Dry.Types::String
  attribute :name, Dry.Types::String
  attribute :Invoice, Invoice
end

class Invoice < Dry::Struct
  attribute :id, Dry.Types::String
  attribute :status, Dry.Types::String
  attribute :line_items, Dry.Types::Array
end
```

Two steps:

1. Define custom formatting method - `#to_formatted_h`
  
```diff
 class Customer < Dry::Struct
   attribute :id, Dry.Types::String
   attribute :name, Dry.Types::String
   attribute :Invoice, Invoice

+  def to_formatted_h
+    {
+      id: id,
+      name: name,
+      invoice: {
+       id: invoice.id
+      }
+    }
+  end
 end
```

2. Configure observable:

```ruby
Observable::Configuration.configure do |config|
  config.formatters = {
    default: :to_h,
    'Customer' => :to_formatted_h
  }
end
```


The instrumenter tries class-specific formatters first, then falls back to the default formatter, then `to_s`.

## Benefits vs. Hand-Rolling Your Own

• **Zero-touch instrumentation** - Wrap any method call without modifying existing code or manually creating spans
• **Production-ready safety** - Built-in PII filtering, serialization depth limits, and exception handling prevent common observability pitfalls
• **Standardized telemetry** - Consistent span naming, attribute structure, and OpenTelemetry compliance across your entire application

## License

MIT License. See LICENSE file for details.