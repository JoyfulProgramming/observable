#!/usr/bin/env ruby

require_relative "lib/observable"

# Configure the instrumenter
Observable::Configuration.configure do |config|
  config.app_namespace = "example_app"
  config.track_return_values = true
  config.max_serialization_depth = 3
  config.pii_filters = [/password/, /token/, /secret/]
end

class ExampleService
  def initialize
    @instrumenter = Observable::Instrumenter.new
  end

  def process_order(order_id, customer_email, amount)
    @instrumenter.instrument(binding) do
      # Simulate some processing
      puts "Processing order #{order_id} for #{customer_email}, amount: #{amount}"

      # Return a result hash
      {
        order_id: order_id,
        status: "processed",
        processed_at: Time.now.to_i,
        amount: amount
      }
    end
  end

  def self.static_method(data)
    instrumenter = Observable::Instrumenter.new
    instrumenter.instrument(binding) do
      puts "Processing data: #{data.inspect}"
      data.transform_values(&:upcase) if data.is_a?(Hash)
    end
  end
end

# Example usage
puts "=== Observable Example ==="
puts

service = ExampleService.new
result = service.process_order("ORD-123", "customer@example.com", 99.99)
puts "Result: #{result}"

puts

static_result = ExampleService.static_method({name: "john", city: "nyc"})
puts "Static result: #{static_result}"

puts "\n=== Check OpenTelemetry spans were created ==="
# In a real application, these spans would be exported to your observability platform
