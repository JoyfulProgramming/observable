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
  def create_user(name, email)
    Observable.instrument(binding) do
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
  config.tracer_name = "my_app"
  config.transport = :otel
  config.app_namespace = "my_app"
  config.attribute_namespace = "my_app"
  config.track_return_values = true
  config.serialization_depth = {default: 2, "MyClass" => 3}
  config.formatters = {default: :to_h, "MyClass" => :to_formatted_h}
  config.pii_filters = [/password/i, /secret/i]
end

# Per-instrumenter configuration
config = Observable::Configuration.new
config.track_return_values = false
instrumenter = Observable::Instrumenter.new(config: config)
```

### Configuration Options

- `tracer_name`: `"observable"` - Name for the OpenTelemetry tracer
- `transport`: `:otel` - Uses OpenTelemetry SDK
- `app_namespace`: `"app"` - Namespace for application-specific attributes
- `attribute_namespace`: `"app"` - Namespace for span attributes
- `track_return_values`: `true` - Captures method return values in spans
- `serialization_depth`: `{default: 2}` - Per-class serialization depth limits (Hash or Integer for backward compatibility)
- `formatters`: `{default: :to_h}` - Object serialization methods by class name
- `pii_filters`: `[]` - Regex patterns to filter sensitive data from spans

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
  config.serialization_depth = {
    default: 2,
    'YourCustomClass' => 3
  }
end
```

## Example

A domain object `Customer` has an `Invoice`.

### Objective 

Send data from related domain objects when a method is called.

### Background

Imagine domain objects are `Dry::Struct` value objects:

```ruby
class Customer < Dry::Struct
  attribute :id, Dry.Types::String
  attribute :name, Dry.Types::String
  attribute :status, Dry.Type::Symbol
  attribute :Invoice, Invoice
end

class Invoice < Dry::Struct
  attribute :id, Dry.Types::String
  attribute :status, Dry.Types::String
  attribute :line_items, Dry.Types::Array
end
```

### Solution

1. Define custom formatting method - `#to_formatted_h`
  
```diff
 class Customer < Dry::Struct
   attribute :id, Dry.Types::String
   attribute :name, Dry.Types::String
   attribute :status, Dry.Type::Symbol
   attribute :Invoice, Invoice

+  def to_formatted_h
+    {
+      id: id,
+      name: name,
+      status: status,
+      invoice: {
+       id: invoice.id
+      }
+    }
+  end
 end
```

2. Configure

```ruby
Observable::Configuration.configure do |config|
  config.formatters = {
    default: :to_h,
    'Customer' => :to_formatted_h
  }
end
```

3. Instrument

Let's say we have a use case object that marks the customer as active: `MarkCustomerAsActive#call`.

How can we observe the behaviour of this use case?

Instrument it like so:

```diff
 class MarkCustomerAsActive
   def call(customer)
+    Observable.instrument(binding) do
       customer.activate!
       # ... more code ...
       customer # return customer object
+    end
   end
 end
```

4. Use

Deploy. Then behold the beauty of domain object attributes in your logs:

| attribute | value |
|------|-------|
| `code.args.0.class_name` | `Customer` |
| `code.args.0.id` | `1234567` |
| `code.args.0.name` | `Joe Bloggs` |
| `code.args.0.status` | `inactive` |
| `code.args.0.invoice.id` | `567890` |
| `code.return.class_name` | `Customer` |
| `code.return.id` | `1234567` |
| `code.return.name` | `Joe Bloggs` |
| `code.return.status` | `active` |
| `code.return.invoice.id` | `567890` |


## Benefits

Why use this library? Why not write Otel attributes manually?

* **Two line instrumentation** - Wrap any method call without modifying existing code or manually creating spans
* **Production-ready safety** - Built-in PII filtering, serialization depth limits, and exception handling prevent common observability pitfalls
* **Standardized telemetry** - Consistent span naming, attribute structure, and OpenTelemetry compliance across your entire application
* **Domain objects** - Support for your own custom domain objects to express business terms in your observability data, bringing you closer to the people who pay your salary.

## License

MIT License. See LICENSE file for details.
