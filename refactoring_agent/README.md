# Observable Gem Refactoring Agent

A specialized Ruby refactoring system designed to improve production code quality for the Observable gem. This agent uses Claude AI to analyze and refactor Ruby code with a focus on gem-specific patterns, OpenTelemetry instrumentation, and Ruby best practices.

## Overview

The Observable Gem Refactoring Agent is built on the OpenTerra agent system but specifically tailored for Ruby development and the Observable gem's architecture. It provides intelligent code analysis and automated refactoring capabilities to improve:

- **Performance** - Optimize instrumentation overhead and memory usage
- **Code Quality** - Remove code smells and improve maintainability  
- **Ruby Idioms** - Make code more idiomatic and follow gem conventions
- **Architecture** - Improve component organization and reduce coupling
- **Error Handling** - Enhance resilience and graceful degradation
- **Testing** - Improve test coverage and quality
- **Documentation** - Enhance code clarity and API docs

## Features

### 🚀 Ruby-Focused Refactoring
- Specialized analysis for Ruby code patterns and gem structure
- OpenTelemetry instrumentation optimization
- Ruby performance improvements (memory usage, method calls)
- Gem convention adherence checking

### 🎯 Targeted Refactoring Types
- **Performance**: Optimize bottlenecks and reduce overhead
- **Duplication**: Remove duplicate code and extract patterns
- **Understandability**: Improve readability and documentation
- **Idiomatic**: Make code more Ruby-like and conventional
- **Code Smells**: Remove anti-patterns and improve structure
- **Error Handling**: Enhance error resilience and messages
- **Testing**: Improve coverage and test quality
- **Architecture**: Better component organization and interfaces

### 🔧 Advanced Capabilities
- Batch refactoring with dependency management
- Dry-run mode for safe analysis
- Pre/post-refactoring validation
- Success criteria verification
- Comprehensive reporting and metrics

### 🎨 Rich CLI Interface
- Beautiful progress tracking with Rich console output
- Multiple provider support (Anthropic, OpenRouter)
- Configurable models and settings
- Interactive setup and configuration

## Installation

### Prerequisites
- Python 3.8+ 
- Ruby 3.0+ (for the Observable gem)
- Git

### Quick Setup

1. **Clone or copy the refactoring agent files**:
```bash
cd your-observable-gem-directory
# The refactoring_agent directory should be in your gem's root
```

2. **Install Python dependencies**:
```bash
cd refactoring_agent
pip install -r requirements.txt
```

3. **Setup a Claude provider** (choose one):

**Option A: Anthropic Direct**
```bash
# Set environment variable
export ANTHROPIC_API_KEY="your-api-key-here"

# Or setup interactively
python cli.py setup anthropic
```

**Option B: OpenRouter**
```bash
# Set environment variable  
export OPENROUTER_API_KEY="your-api-key-here"

# Or setup interactively
python cli.py setup openrouter
```

4. **Verify setup**:
```bash
python cli.py list-providers
```

## Usage

### Basic Commands

#### Setup and Configuration
```bash
# Setup a provider
python cli.py setup anthropic --api-key sk-...

# List configured providers
python cli.py list-providers

# Switch providers
python cli.py use openrouter
```

#### Single Refactoring Tasks
```bash
# Run performance optimization
python cli.py refactor performance

# Improve code readability
python cli.py refactor understandability

# Remove code smells
python cli.py refactor code_smells

# Make code more idiomatic Ruby
python cli.py refactor idiomatic
```

#### Batch Refactoring
```bash
# Run multiple refactoring types
python cli.py batch "performance,code_smells,idiomatic"

# Quality-focused refactoring
python cli.py batch "code_smells,understandability,duplication"
```

#### Analysis and Custom Tasks
```bash
# Analyze gem structure
python cli.py analyze

# Analyze specific file
python cli.py analyze --file lib/observable/instrumenter.rb

# Custom refactoring task
python cli.py custom "Optimize the ArgumentExtractor class for better performance"
```

### Advanced Usage

#### Observable Gem Specialized Runner
For comprehensive refactoring specifically designed for the Observable gem:

```bash
# Full refactoring plan (all 8 refactoring types)
python gem_refactor_runner.py full

# Performance-focused refactoring
python gem_refactor_runner.py performance  

# Code quality-focused refactoring
python gem_refactor_runner.py quality
```

#### Dry Run Mode
```bash
# Analyze without making changes
python -c "
import asyncio
from gem_refactor_runner import ObservableGemRefactorRunner
runner = ObservableGemRefactorRunner('.')
asyncio.run(runner.run_gem_refactor_plan(dry_run=True))
"
```

## Available Refactoring Types

| Type | Description | Focus Areas |
|------|-------------|-------------|
| **performance** | 🚀 Optimize for speed and memory | Method calls, argument extraction, span creation |
| **duplication** | 🔄 Remove duplicate code | Shared patterns, common utilities, DRY principle |
| **understandability** | 📖 Improve readability | Documentation, naming, structure clarity |
| **idiomatic** | 💎 More Ruby-like code | Conventions, standard patterns, gem structure |
| **code_smells** | 🧹 Remove anti-patterns | Long methods, large classes, coupling issues |
| **error_handling** | ⚠️ Better error resilience | Exceptions, graceful degradation, error messages |
| **testing** | 🧪 Improve test quality | Coverage, edge cases, test organization |
| **architecture** | 🏗️ Better code organization | Modularity, interfaces, component boundaries |

## Configuration

### Provider Settings
Configuration is stored in `~/.refactoring-agent-config.json`:

```json
{
  "providers": {
    "anthropic": {
      "name": "anthropic",
      "provider_type": "anthropic", 
      "api_key": "sk-...",
      "model": "claude-3-sonnet-20240229",
      "description": "Anthropic Claude via direct API"
    },
    "openrouter": {
      "name": "openrouter",
      "provider_type": "openrouter",
      "api_key": "sk-or-...", 
      "model": "anthropic/claude-3-sonnet",
      "description": "Anthropic Claude via OpenRouter",
      "base_url": "https://openrouter.ai/api/v1"
    }
  },
  "current_provider": "anthropic"
}
```

### Environment Variables
```bash
# Anthropic
export ANTHROPIC_API_KEY="your-key-here"

# OpenRouter  
export OPENROUTER_API_KEY="your-key-here"
```

## Observable Gem Integration

This refactoring agent is specifically designed for the Observable gem's architecture:

### Key Focus Areas
- **Instrumenter optimization** - Core instrumentation performance
- **Configuration system** - Dry::Configurable patterns  
- **Argument extraction** - Ruby binding introspection efficiency
- **OpenTelemetry integration** - Span creation and management
- **Error handling** - Instrumentation failure resilience
- **Testing patterns** - Minitest and tracing test helpers

### Gem-Specific Analysis
- Validates gem structure and conventions
- Checks for proper Ruby version compatibility  
- Analyzes OpenTelemetry integration patterns
- Reviews dependency management
- Ensures Standard Ruby compliance

## Example Workflows

### 1. Complete Gem Refactoring
```bash
# Setup
python cli.py setup anthropic

# Run comprehensive refactoring
python gem_refactor_runner.py full

# Review results in refactoring_results/
ls refactoring_results/
```

### 2. Performance-Focused Sprint
```bash
# Focus on performance improvements
python cli.py batch "architecture,performance,code_smells"

# Run tests to validate
bundle exec rake test

# Check performance impact
bundle exec ruby -Itest test/benchmark/instrumenter_benchmark.rb
```

### 3. Code Quality Improvement
```bash
# Improve readability and maintainability
python cli.py batch "code_smells,understandability,duplication"

# Validate with linter
bundle exec standardrb

# Review changes
git diff
```

### 4. Pre-Release Preparation
```bash
# Comprehensive quality check
python gem_refactor_runner.py quality

# Ensure everything works
bundle exec rake test
bundle exec standardrb
gem build observable.gemspec
```

## Results and Reporting

### Output Locations
- **Console output** - Real-time progress and results
- **refactoring_results/** - Detailed JSON results with timestamps
- **Git changes** - All modifications tracked in version control

### Report Contents
- Task-by-task success/failure status
- Number of files modified per task
- Success criteria verification
- Before/after code metrics
- Test results and lint status

### Example Result Summary
```
📋 OBSERVABLE GEM REFACTORING SUMMARY
====================================
Total Tasks: 8
Successful: 7 ✅  
Failed: 1 ❌
Success Rate: 87.5%
Total Actions: 23

Next Steps:
1. Review refactored code and test thoroughly
2. Run full test suite: bundle exec rake test  
3. Check code style: bundle exec standardrb
4. Update documentation if needed
5. Consider performance benchmarks
```

## Troubleshooting

### Common Issues

**"No provider configured"**
```bash
python cli.py setup anthropic --api-key your-key
```

**"Task timed out"**
- Large files may need longer timeout
- Consider breaking into smaller refactoring tasks
- Check internet connection for API calls

**"Tests failing after refactoring"**
- Review the specific changes made  
- Check git diff for unintended modifications
- Run individual test files to isolate issues

**"API rate limits"**
- The system includes automatic rate limiting
- Consider using a different provider temporarily
- OpenRouter often has higher rate limits

### Debug Mode
```bash
# Enable verbose logging
export PYTHONPATH=.
python -m rich.logging cli.py refactor performance --workspace .
```

### Reset Configuration
```bash
rm ~/.refactoring-agent-config.json
python cli.py setup anthropic
```

## Advanced Customization

### Custom Refactoring Tasks
You can extend the system with custom refactoring instructions:

```python
from gem_refactor_runner import ObservableGemRefactorRunner, GemRefactorTask

# Create custom task
custom_task = GemRefactorTask(
    task_type="custom_optimization",
    priority=1,
    description="Optimize specific OpenTelemetry patterns",
    files_focus=["lib/observable/instrumenter.rb"],
    success_criteria=["Reduced span creation overhead"]
)

# Run custom task
runner = ObservableGemRefactorRunner()
await runner.run_gem_refactor_plan([custom_task])
```

### Provider Extensions
Add support for additional AI providers by extending `provider_config.py`.

## Contributing

This refactoring agent is specifically tailored for the Observable gem. For improvements:

1. **Test thoroughly** - Changes should not break existing functionality
2. **Follow Ruby patterns** - Maintain consistency with gem conventions
3. **Benchmark performance** - Measure impact of refactoring changes
4. **Document changes** - Update both code and markdown documentation

## License

This refactoring agent is provided as a development tool for the Observable gem project. Use in accordance with your project's licensing terms.

---

**🚀 Ready to improve your Observable gem's production code quality!**

Get started with:
```bash
python cli.py setup anthropic
python gem_refactor_runner.py full
```