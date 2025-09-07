#!/usr/bin/env python3
"""
Observable Gem Refactoring Agent System

A Ruby-focused refactoring agent that uses Claude Code to improve production code quality
specifically tailored for the Observable gem and Ruby development patterns.

This system provides:
- Ruby-specific code analysis and refactoring
- Gem structure optimization
- Performance improvements
- Code quality enhancements
- Production readiness improvements
"""

import os
import json
import subprocess
import asyncio
from pathlib import Path
from typing import Dict, List, Optional, Any
import tempfile
import shutil

try:
    import anthropic
except ImportError:
    anthropic = None

try:
    import openai
except ImportError:
    openai = None

def validate_workspace_directory(workspace_dir: str) -> Dict[str, Any]:
    """Validate that a workspace directory exists and is accessible"""
    if not workspace_dir:
        return {
            "valid": True,
            "path": os.getcwd(),
            "message": "Using current working directory"
        }
    
    try:
        # Resolve to absolute path
        abs_path = os.path.abspath(workspace_dir.strip())
        
        # Check if directory exists
        if not os.path.exists(abs_path):
            return {
                "valid": False,
                "path": abs_path,
                "error": "Directory does not exist",
                "message": f"Directory {abs_path} does not exist"
            }
        
        # Check if it's actually a directory
        if not os.path.isdir(abs_path):
            return {
                "valid": False,
                "path": abs_path,
                "error": "Path is not a directory",
                "message": f"Path {abs_path} exists but is not a directory"
            }
        
        # Check if we can read the directory
        try:
            os.listdir(abs_path)
        except PermissionError:
            return {
                "valid": False,
                "path": abs_path,
                "error": "Permission denied",
                "message": f"Cannot access directory {abs_path} - permission denied"
            }
        
        # Check if we can write to the directory (for creating files)
        if not os.access(abs_path, os.W_OK):
            return {
                "valid": False,
                "path": abs_path,
                "error": "Directory not writable",
                "message": f"Directory {abs_path} is not writable"
            }
        
        return {
            "valid": True,
            "path": abs_path,
            "message": f"Valid workspace directory: {abs_path}"
        }
        
    except Exception as e:
        return {
            "valid": False,
            "path": workspace_dir,
            "error": str(e),
            "message": f"Error validating directory: {str(e)}"
        }

class AgentTool:
    """Base class for agent tools"""
    def __init__(self, name: str, description: str):
        self.name = name
        self.description = description
    
    async def execute(self, **kwargs) -> Dict[str, Any]:
        raise NotImplementedError

class FileReadTool(AgentTool):
    """Read file contents"""
    def __init__(self):
        super().__init__(
            "read_file",
            "Read the contents of a file"
        )
    
    async def execute(self, file_path: str, workspace_dir: str = None) -> Dict[str, Any]:
        try:
            if workspace_dir and os.path.isabs(file_path):
                # If file_path is absolute, use it directly (but validate it's within workspace)
                full_path = file_path
                if not full_path.startswith(os.path.abspath(workspace_dir)):
                    return {
                        "success": False,
                        "error": "Access denied: file is outside workspace directory",
                        "message": f"File {file_path} is outside the allowed workspace"
                    }
            elif workspace_dir:
                full_path = os.path.join(workspace_dir, file_path)
            else:
                full_path = file_path
            
            # Resolve any relative paths and ensure they exist
            full_path = os.path.abspath(full_path)
            
            if not os.path.exists(full_path):
                return {
                    "success": False,
                    "error": "File not found",
                    "message": f"File {file_path} does not exist at {full_path}"
                }
            
            if not os.path.isfile(full_path):
                return {
                    "success": False,
                    "error": "Path is not a file",
                    "message": f"Path {full_path} exists but is not a file"
                }
            
            with open(full_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            return {
                "success": True,
                "content": content,
                "file_path": full_path,
                "file_size": len(content),
                "message": f"Successfully read {file_path} ({len(content)} characters)"
            }
        except UnicodeDecodeError as e:
            return {
                "success": False,
                "error": f"File encoding error: {str(e)}",
                "message": f"Could not read {file_path} - file may be binary or use unsupported encoding"
            }
        except PermissionError as e:
            return {
                "success": False,
                "error": "Permission denied",
                "message": f"Permission denied reading {file_path}: {str(e)}"
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "message": f"Failed to read {file_path}: {str(e)}"
            }

class FileWriteTool(AgentTool):
    """Write or create files"""
    def __init__(self):
        super().__init__(
            "write_file",
            "Write content to a file (creates file if it doesn't exist)"
        )
    
    async def execute(self, file_path: str, content: str, workspace_dir: str = None) -> Dict[str, Any]:
        try:
            if workspace_dir and os.path.isabs(file_path):
                # If file_path is absolute, use it directly (but validate it's within workspace)
                full_path = file_path
                if not full_path.startswith(os.path.abspath(workspace_dir)):
                    return {
                        "success": False,
                        "error": "Access denied: file is outside workspace directory",
                        "message": f"File {file_path} is outside the allowed workspace"
                    }
            elif workspace_dir:
                full_path = os.path.join(workspace_dir, file_path)
            else:
                full_path = file_path
            
            # Resolve to absolute path
            full_path = os.path.abspath(full_path)
            
            # Create directories if they don't exist
            dir_path = os.path.dirname(full_path)
            if dir_path:
                os.makedirs(dir_path, exist_ok=True)
            
            # Check if file already exists and get some info
            file_existed = os.path.exists(full_path)
            original_size = 0
            if file_existed:
                original_size = os.path.getsize(full_path)
            
            # Write the file
            with open(full_path, 'w', encoding='utf-8') as f:
                f.write(content)
            
            new_size = len(content)
            
            return {
                "success": True,
                "file_path": full_path,
                "file_existed": file_existed,
                "original_size": original_size,
                "new_size": new_size,
                "bytes_written": new_size,
                "lines_written": content.count('\n') + 1,
                "message": f"Successfully {'updated' if file_existed else 'created'} {file_path} ({new_size} bytes, {content.count(chr(10)) + 1} lines)"
            }
        except PermissionError as e:
            return {
                "success": False,
                "error": "Permission denied",
                "message": f"Permission denied writing to {file_path}: {str(e)}"
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "message": f"Failed to write {file_path}: {str(e)}"
            }

class DirectoryListTool(AgentTool):
    """List directory contents"""
    def __init__(self):
        super().__init__(
            "list_directory",
            "List files and directories in a given path"
        )
    
    async def execute(self, dir_path: str = ".", workspace_dir: str = None) -> Dict[str, Any]:
        try:
            if workspace_dir:
                full_path = os.path.join(workspace_dir, dir_path)
            else:
                full_path = dir_path
            
            items = []
            for item in os.listdir(full_path):
                item_path = os.path.join(full_path, item)
                items.append({
                    "name": item,
                    "type": "directory" if os.path.isdir(item_path) else "file",
                    "size": os.path.getsize(item_path) if os.path.isfile(item_path) else None
                })
            
            return {
                "success": True,
                "items": items,
                "path": full_path,
                "message": f"Found {len(items)} items in {dir_path}"
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "message": f"Failed to list directory {dir_path}: {str(e)}"
            }

class RunCommandTool(AgentTool):
    """Execute terminal commands"""
    def __init__(self):
        super().__init__(
            "run_command",
            "Execute a terminal command and return the output"
        )
    
    async def execute(self, command: str, workspace_dir: str = None) -> Dict[str, Any]:
        try:
            # Change to workspace directory if specified
            original_cwd = os.getcwd()
            if workspace_dir and os.path.exists(workspace_dir):
                os.chdir(workspace_dir)
            
            # Run the command
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=60  # 60 second timeout for Ruby commands
            )
            
            # Restore original directory
            if workspace_dir:
                os.chdir(original_cwd)
            
            return {
                "success": result.returncode == 0,
                "output": result.stdout,
                "error": result.stderr,
                "return_code": result.returncode,
                "command": command,
                "message": f"Command executed: {command}"
            }
        except subprocess.TimeoutExpired:
            return {
                "success": False,
                "error": "Command timed out after 60 seconds",
                "message": f"Command timed out: {command}"
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "message": f"Failed to run command {command}: {str(e)}"
            }

class RubyCodeAnalysisTool(AgentTool):
    """Analyze Ruby code structure and gem patterns"""
    def __init__(self):
        super().__init__(
            "analyze_ruby_code",
            "Analyze Ruby code files for structure, dependencies, patterns, and gem-specific issues"
        )
    
    async def execute(self, file_path: str, workspace_dir: str = None) -> Dict[str, Any]:
        try:
            if workspace_dir:
                full_path = os.path.join(workspace_dir, file_path)
            else:
                full_path = file_path
            
            with open(full_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Ruby-specific analysis
            lines = content.split('\n')
            analysis = {
                "line_count": len(lines),
                "file_type": os.path.splitext(file_path)[1],
                "requires": [],
                "classes": [],
                "modules": [],
                "methods": [],
                "constants": [],
                "gem_dependencies": [],
                "potential_issues": []
            }
            
            # Extract Ruby patterns
            for i, line in enumerate(lines):
                line_stripped = line.strip()
                
                # Requires and dependencies
                if line_stripped.startswith('require ') or line_stripped.startswith('require_relative'):
                    analysis["requires"].append({"line": i+1, "content": line_stripped})
                
                # Classes
                if line_stripped.startswith('class '):
                    analysis["classes"].append({"line": i+1, "content": line_stripped})
                
                # Modules
                if line_stripped.startswith('module '):
                    analysis["modules"].append({"line": i+1, "content": line_stripped})
                
                # Methods
                if line_stripped.startswith('def '):
                    analysis["methods"].append({"line": i+1, "content": line_stripped})
                
                # Constants (simple heuristic)
                if line_stripped and line_stripped[0].isupper() and '=' in line_stripped:
                    analysis["constants"].append({"line": i+1, "content": line_stripped})
                
                # Gem dependencies in gemspec
                if 'add_dependency' in line_stripped or 'add_development_dependency' in line_stripped:
                    analysis["gem_dependencies"].append({"line": i+1, "content": line_stripped})
            
            # Identify potential issues
            if len(analysis["classes"]) > 5:
                analysis["potential_issues"].append("Multiple classes in single file - consider splitting")
            
            if len([line for line in lines if line.strip() and not line.startswith('#')]) > 200:
                analysis["potential_issues"].append("Large file - consider refactoring")
            
            # Look for common Ruby anti-patterns
            content_lower = content.lower()
            if 'rescue exception' in content_lower:
                analysis["potential_issues"].append("Catching Exception is too broad")
            
            if content.count('def ') > 20:
                analysis["potential_issues"].append("Many methods - consider extracting to modules")
            
            return {
                "success": True,
                "analysis": analysis,
                "file_path": full_path,
                "message": f"Successfully analyzed Ruby file {file_path}"
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "message": f"Failed to analyze {file_path}: {str(e)}"
            }

class GemStructureAnalysisTool(AgentTool):
    """Analyze gem structure and conventions"""
    def __init__(self):
        super().__init__(
            "analyze_gem_structure",
            "Analyze gem directory structure and check conventions"
        )
    
    async def execute(self, workspace_dir: str = None) -> Dict[str, Any]:
        try:
            if workspace_dir:
                gem_root = workspace_dir
            else:
                gem_root = os.getcwd()
            
            gem_root = os.path.abspath(gem_root)
            
            structure_analysis = {
                "gem_root": gem_root,
                "has_gemspec": False,
                "has_lib_dir": False,
                "has_test_dir": False,
                "has_spec_dir": False,
                "has_readme": False,
                "has_changelog": False,
                "has_license": False,
                "lib_structure": [],
                "test_structure": [],
                "gem_files": [],
                "missing_conventions": [],
                "recommendations": []
            }
            
            # Check for standard gem files
            for item in os.listdir(gem_root):
                item_path = os.path.join(gem_root, item)
                
                if item.endswith('.gemspec'):
                    structure_analysis["has_gemspec"] = True
                    structure_analysis["gem_files"].append(item)
                
                elif item.lower() == 'lib' and os.path.isdir(item_path):
                    structure_analysis["has_lib_dir"] = True
                    # Analyze lib structure
                    for root, dirs, files in os.walk(item_path):
                        for file in files:
                            if file.endswith('.rb'):
                                rel_path = os.path.relpath(os.path.join(root, file), gem_root)
                                structure_analysis["lib_structure"].append(rel_path)
                
                elif item.lower() in ['test', 'tests'] and os.path.isdir(item_path):
                    structure_analysis["has_test_dir"] = True
                    # Analyze test structure
                    for root, dirs, files in os.walk(item_path):
                        for file in files:
                            if file.endswith('.rb'):
                                rel_path = os.path.relpath(os.path.join(root, file), gem_root)
                                structure_analysis["test_structure"].append(rel_path)
                
                elif item.lower() == 'spec' and os.path.isdir(item_path):
                    structure_analysis["has_spec_dir"] = True
                
                elif item.lower() in ['readme.md', 'readme.txt', 'readme']:
                    structure_analysis["has_readme"] = True
                
                elif item.lower() in ['changelog.md', 'changelog', 'history.md']:
                    structure_analysis["has_changelog"] = True
                
                elif item.lower() in ['license', 'license.txt', 'mit-license']:
                    structure_analysis["has_license"] = True
            
            # Check for missing conventions
            if not structure_analysis["has_gemspec"]:
                structure_analysis["missing_conventions"].append("Missing .gemspec file")
            
            if not structure_analysis["has_lib_dir"]:
                structure_analysis["missing_conventions"].append("Missing lib/ directory")
            
            if not (structure_analysis["has_test_dir"] or structure_analysis["has_spec_dir"]):
                structure_analysis["missing_conventions"].append("Missing test/ or spec/ directory")
            
            if not structure_analysis["has_readme"]:
                structure_analysis["missing_conventions"].append("Missing README file")
            
            if not structure_analysis["has_license"]:
                structure_analysis["missing_conventions"].append("Missing LICENSE file")
            
            # Generate recommendations
            if len(structure_analysis["lib_structure"]) > 10:
                structure_analysis["recommendations"].append("Consider organizing lib files into subdirectories")
            
            if not structure_analysis["has_changelog"]:
                structure_analysis["recommendations"].append("Consider adding a CHANGELOG.md file")
            
            return {
                "success": True,
                "analysis": structure_analysis,
                "message": f"Successfully analyzed gem structure for {gem_root}"
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "message": f"Failed to analyze gem structure: {str(e)}"
            }

class RefactoringAgent:
    """Ruby-focused refactoring agent for the Observable gem"""
    
    def __init__(self, provider: str, api_key: str, model: str):
        self.provider = provider
        self.api_key = api_key
        self.model = model
        self.tools = {
            "read_file": FileReadTool(),
            "write_file": FileWriteTool(),
            "list_directory": DirectoryListTool(),
            "run_command": RunCommandTool(),
            "analyze_ruby_code": RubyCodeAnalysisTool(),
            "analyze_gem_structure": GemStructureAnalysisTool()
        }
        
        # Initialize API client
        if provider == "anthropic":
            self.client = anthropic.Anthropic(api_key=api_key)
        elif provider in ["openrouter", "moonshot"]:
            self.client = openai.OpenAI(
                base_url="https://openrouter.ai/api/v1",
                api_key=api_key,
            )
        else:
            raise ValueError(f"Unsupported provider: {provider}")
    
    async def execute_refactoring_task(self, task_type: str, workspace_dir: str = None, **kwargs) -> Dict[str, Any]:
        """Execute a specific refactoring task"""
        try:
            # Validate workspace directory first
            workspace_validation = validate_workspace_directory(workspace_dir)
            if not workspace_validation["valid"]:
                return {
                    "success": False,
                    "error": workspace_validation["error"],
                    "actions": [],
                    "primaryAction": "error",
                    "workspace_error": workspace_validation["message"]
                }
            
            # Use the validated workspace path
            validated_workspace = workspace_validation["path"]
            
            # Get task-specific instructions
            instruction = self._get_refactoring_instruction(task_type, **kwargs)
            
            # System prompt for Ruby/gem refactoring
            system_prompt = f"""You are a Ruby refactoring specialist focused on improving the Observable gem codebase.

AVAILABLE TOOLS:
1. **read_file(file_path)** - Read file contents
2. **write_file(file_path, content)** - Create or update files
3. **list_directory(dir_path)** - List directory contents  
4. **run_command(command)** - Execute terminal commands (bundle, rake, standardrb, etc.)
5. **analyze_ruby_code(file_path)** - Analyze Ruby code structure and patterns
6. **analyze_gem_structure()** - Analyze gem directory structure and conventions

WORKING DIRECTORY: {validated_workspace}

RUBY/GEM EXPERTISE:
- Follow Ruby community conventions and idioms
- Respect gem structure and patterns
- Maintain backward compatibility
- Focus on readability and maintainability
- Apply Ruby best practices for performance and memory usage
- Consider OpenTelemetry patterns and instrumentation
- Maintain proper testing structure

REFACTORING PRINCIPLES:
- Make incremental, safe changes
- Preserve existing functionality
- Improve code clarity and maintainability
- Optimize for Ruby performance patterns
- Follow Standard Ruby linting rules
- Maintain proper error handling
- Keep consistent with existing code style

TASK FORMAT:
For each action you take, use:

ACTION: tool_name
PARAMS: {{"param": "value"}}
REASONING: Brief explanation of why you're taking this action

**CRITICAL: You must use tools to complete refactoring tasks. Always start by analyzing the codebase structure.**

Your mission: {instruction}

Start by analyzing the gem structure and then examining the relevant files."""

            messages = [{"role": "user", "content": instruction}]
            actions_taken = []
            max_iterations = 15  # Allow more iterations for complex refactoring
            
            for iteration in range(max_iterations):
                # Get response from AI
                if self.provider == "anthropic":
                    response = self.client.messages.create(
                        model=self.model,
                        max_tokens=4000,
                        system=system_prompt,
                        messages=messages
                    )
                    ai_response = response.content[0].text
                else:
                    # OpenRouter
                    response = self.client.chat.completions.create(
                        model=self.model,
                        messages=[{"role": "system", "content": system_prompt}] + messages,
                        max_tokens=4000
                    )
                    ai_response = response.choices[0].message.content
                
                # Parse AI response for actions
                action_result = await self._parse_and_execute_action(ai_response, validated_workspace)
                
                if action_result:
                    actions_taken.append(action_result["action"])
                    # Add the action result to conversation
                    messages.append({"role": "assistant", "content": ai_response})
                    
                    # Format tool result for better AI understanding
                    tool_result = action_result['result']
                    result_message = f"Tool '{action_result['action']}' executed.\n"
                    result_message += f"Reasoning: {action_result.get('reasoning', 'Not provided')}\n"
                    result_message += f"Result: {json.dumps(tool_result, indent=2)}\n"
                    
                    if not tool_result.get('success', True):
                        result_message += "\n**ERROR**: The tool execution failed. Please analyze the error and try a different approach."
                    
                    result_message += "\nContinue with the next action to complete your refactoring mission."
                    
                    messages.append({"role": "user", "content": result_message})
                    
                    # Check if refactoring seems complete
                    completion_indicators = ["refactoring complete", "task complete", "mission accomplished", "all changes applied"]
                    if any(indicator in ai_response.lower() for indicator in completion_indicators):
                        break
                else:
                    # No action found - encourage the agent to take action
                    messages.append({"role": "assistant", "content": ai_response})
                    if iteration < max_iterations - 1:
                        encouragement = """
No action detected. For refactoring tasks you must:
- Use tools to analyze and modify code
- Start each action with: ACTION: tool_name
- Follow with: PARAMS: {"param": "value"}  
- Add: REASONING: explanation

Continue with your next refactoring action."""
                        messages.append({"role": "user", "content": encouragement})
                    break
            
            return {
                "success": True,
                "result": ai_response,
                "actions": actions_taken,
                "primaryAction": actions_taken[0] if actions_taken else "analysis",
                "task_type": task_type,
                "iterations": iteration + 1
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "actions": actions_taken if 'actions_taken' in locals() else [],
                "primaryAction": "error",
                "task_type": task_type
            }
    
    def _get_refactoring_instruction(self, task_type: str, **kwargs) -> str:
        """Get specific refactoring instructions based on task type"""
        
        instructions = {
            "performance": """
            Improve the performance of the Observable gem codebase by:
            1. Analyzing method calls and identifying bottlenecks
            2. Optimizing argument extraction and serialization
            3. Reducing memory allocations and object creation
            4. Improving OpenTelemetry span creation efficiency
            5. Optimizing configuration access patterns
            6. Consider lazy loading and memoization where appropriate
            7. Profile memory usage and suggest improvements
            Run performance tests after changes to verify improvements.
            """,
            
            "duplication": """
            Remove code duplication in the Observable gem by:
            1. Identifying repeated code patterns across files
            2. Extracting common functionality into shared modules or methods
            3. Consolidating similar configuration patterns
            4. Creating reusable abstractions for instrumentation logic
            5. Eliminating duplicate error handling patterns
            6. Standardizing serialization and filtering approaches
            Ensure tests still pass after refactoring.
            """,
            
            "understandability": """
            Improve code readability and understandability by:
            1. Adding clear method and class documentation
            2. Improving variable and method names for clarity
            3. Breaking down complex methods into smaller, focused ones
            4. Adding meaningful comments for complex logic
            5. Organizing code structure logically
            6. Ensuring consistent code style and formatting
            7. Making the public API more intuitive
            Run StandardRB to ensure code style consistency.
            """,
            
            "idiomatic": """
            Make the Observable gem code more idiomatic Ruby by:
            1. Following Ruby naming conventions and patterns
            2. Using appropriate Ruby idioms and standard library methods
            3. Implementing proper Ruby module and class structures
            4. Using Ruby's metaprogramming features appropriately
            5. Following gem development best practices
            6. Ensuring proper use of Ruby's object model
            7. Implementing Ruby-style configuration patterns
            Maintain compatibility with existing public API.
            """,
            
            "code_smells": """
            Remove code smells from the Observable gem by:
            1. Identifying and fixing long methods (>15 lines)
            2. Breaking down large classes into focused components
            3. Eliminating inappropriate intimacy between classes
            4. Removing dead code and unused methods
            5. Fixing feature envy (methods using other classes' data)
            6. Eliminating primitive obsession
            7. Removing magic numbers and strings
            Ensure all existing functionality remains intact.
            """,
            
            "error_handling": """
            Improve error handling throughout the Observable gem by:
            1. Adding proper exception handling for edge cases
            2. Creating custom exception classes where appropriate
            3. Ensuring graceful degradation when instrumentation fails
            4. Adding better error messages and debugging information
            5. Implementing proper logging for error conditions
            6. Ensuring OpenTelemetry spans handle errors correctly
            7. Adding validation for configuration parameters
            Test error conditions thoroughly after changes.
            """,
            
            "testing": """
            Improve the testing structure and coverage by:
            1. Analyzing current test coverage and identifying gaps
            2. Adding tests for edge cases and error conditions
            3. Improving test organization and structure
            4. Creating better test helpers and utilities
            5. Adding performance benchmarks
            6. Ensuring tests are reliable and fast
            7. Adding integration tests for OpenTelemetry functionality
            All tests must pass after refactoring.
            """,
            
            "architecture": """
            Improve the overall architecture of the Observable gem by:
            1. Analyzing current component relationships
            2. Reducing coupling between modules
            3. Improving abstraction boundaries
            4. Creating cleaner interfaces between components
            5. Organizing code into logical layers
            6. Improving the plugin/extension architecture
            7. Making the system more modular and testable
            Maintain backward compatibility with existing API.
            """
        }
        
        if task_type in instructions:
            return instructions[task_type]
        else:
            # Custom task
            custom_instruction = kwargs.get('instruction', 'Perform general code quality improvements')
            return f"""
            Perform the following refactoring task on the Observable gem:
            
            {custom_instruction}
            
            Focus on maintaining the gem's functionality while improving code quality,
            performance, and maintainability. Follow Ruby best practices and gem conventions.
            """
    
    async def _parse_and_execute_action(self, ai_response: str, workspace_dir: str = None) -> Optional[Dict[str, Any]]:
        """Parse AI response for actions and execute them"""
        lines = ai_response.split('\n')
        
        action_found = False
        tool_name = None
        params = {}
        reasoning = ""
        
        for i, line in enumerate(lines):
            line = line.strip()
            
            if line.startswith('ACTION:'):
                tool_name = line.replace('ACTION:', '').strip()
                action_found = True
                
            elif line.startswith('PARAMS:') and action_found:
                try:
                    params_str = line.replace('PARAMS:', '').strip()
                    params = json.loads(params_str)
                except json.JSONDecodeError as e:
                    print(f"JSON decode error for params: {e}")
                    params = {}
                
            elif line.startswith('REASONING:') and action_found:
                reasoning = line.replace('REASONING:', '').strip()
        
        # If we found an action, execute it
        if action_found and tool_name:
            # Add workspace_dir to params
            if workspace_dir:
                params['workspace_dir'] = workspace_dir
            
            # Execute the tool
            if tool_name in self.tools:
                print(f"Executing tool: {tool_name} with params: {params}")
                result = await self.tools[tool_name].execute(**params)
                return {
                    "action": tool_name,
                    "params": params,
                    "result": result,
                    "reasoning": reasoning
                }
            else:
                print(f"Unknown tool: {tool_name}. Available tools: {list(self.tools.keys())}")
                return {
                    "action": tool_name,
                    "params": params,
                    "result": {
                        "success": False,
                        "error": f"Unknown tool: {tool_name}",
                        "available_tools": list(self.tools.keys())
                    },
                    "reasoning": reasoning
                }
        
        return None