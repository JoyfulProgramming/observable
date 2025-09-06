# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the Observable gem - a Ruby library that provides OpenTelemetry instrumentation for method calls with configurable serialization, PII filtering, and argument tracking. It automatically captures method invocation details, arguments, return values, and exceptions as OpenTelemetry spans.

## Core Architecture

### Main Components

- **Observable::Instrumenter** (`lib/observable/instrumenter.rb`) - The core instrumentation engine that wraps method calls with OpenTelemetry spans
- **Observable::Configuration** (`lib/observable/instrumenter.rb`) - Uses Dry::Configurable for flexible configuration management
- **ArgumentExtractor** (`lib/observable/instrumenter.rb`) - Extracts method arguments from Ruby bindings using introspection
- **CallerInformation** (`lib/observable/instrumenter.rb`) - Value object containing method metadata (name, namespace, filepath, line number, arguments)

### Key Features

- **Automatic method instrumentation** - Wrap any method call with `instrumenter.instrument(binding) { ... }`
- **Argument tracking** - Captures method parameters with PII filtering capabilities
- **Return value serialization** - Configurable tracking of method return values
- **Exception handling** - Automatically captures and records exceptions in spans
- **Class/instance method detection** - Distinguishes between static (`.`) and instance (`#`) methods
- **Configurable serialization** - Supports custom formatters and max depth limits

## Development Commands

### Running Tests
```bash
bundle exec rake test
```

### Running Individual Tests
```bash
ruby -Itest test/unit/instrumenter_test.rb
```

### Linting
```bash
bundle exec standardrb
```

### Dependencies
```bash
bundle install
```

### Interactive Console
```bash
bin/console
```

### Build Gem
```bash
bundle exec rake build
```

### Release Process
```bash
# Update version in lib/observable/version.rb
bundle exec rake release
```

## Configuration System

The gem uses Dry::Configurable with these key settings:

- `transport` - Transport mechanism (default: `:otel`)
- `app_namespace` - Application namespace for spans
- `attribute_namespace` - Attribute namespace prefix
- `tracer_names` - OpenTelemetry tracer configuration
- `formatters` - Object serialization methods (default: `:to_h`)
- `pii_filters` - Regex patterns to filter sensitive data
- `max_serialization_depth` - Prevents infinite recursion (default: 4)
- `track_return_values` - Enable/disable return value capture (default: true)

## Usage Pattern

The primary usage pattern involves:

1. Create an instrumenter instance: `Observable::Instrumenter.new`
2. Wrap method calls: `instrumenter.instrument(binding) { method_logic }`
3. The instrumenter automatically:
   - Extracts method name, class, and arguments from `binding`
   - Creates OpenTelemetry spans with standardized naming (`Class#method` or `Class.method`)
   - Serializes arguments and return values with PII filtering
   - Handles exceptions and sets appropriate span status

## Testing Structure

- **Unit tests** in `test/unit/` - Test individual components
- **Support helpers** in `test/support/` - Test utilities and mocks
- Uses Minitest framework
- Custom tracing test helpers for OpenTelemetry span verification

## Dependencies

**Runtime:**
- `opentelemetry-sdk` ~> 1.5 - OpenTelemetry instrumentation
- `dry-configurable` >= 0.13.0, < 2.0 - Configuration management
- `dry-struct` ~> 1.4 - Value objects

**Development:**
- `minitest` ~> 5.14 - Testing framework
- `standard` ~> 1.40 - Ruby linting and formatting
- `rake` ~> 13.0 - Build automation

## Code Style

- Uses Standard Ruby for linting and formatting
- Ruby version: 3.4+ (configured in `.ruby-version` and `.standard.yml`)
- Frozen string literals enforced
- Follows Ruby community conventions for method naming and structure