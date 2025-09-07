#!/usr/bin/env python3
"""
Observable Gem Refactoring Agent CLI

Command-line interface for running Ruby-focused refactoring tasks
on the Observable gem codebase.
"""

import asyncio
import os
import sys
from pathlib import Path
from typing import List, Optional
import typer
from rich.console import Console
from rich.table import Table
from rich import print as rprint

from agent_system import RefactoringAgent
from provider_config import provider_manager, ensure_provider_setup

app = typer.Typer(help="Observable Gem Refactoring Agent - Improve your Ruby gem's production code quality")
console = Console()

@app.command("setup")
def setup_provider(
    provider: str = typer.Argument(help="Provider to setup (anthropic, openrouter)"),
    api_key: str = typer.Option(None, "--api-key", "-k", help="API key for the provider"),
    model: str = typer.Option(None, "--model", "-m", help="Model to use")
):
    """Setup a Claude provider for the refactoring agent."""
    try:
        success = provider_manager.setup_provider(provider, api_key, model)
        if success:
            rprint(f"✅ [green]Successfully configured {provider} provider[/green]")
        else:
            rprint(f"❌ [red]Failed to configure {provider} provider[/red]")
            sys.exit(1)
    except Exception as e:
        rprint(f"❌ [red]Error setting up provider: {e}[/red]")
        sys.exit(1)

@app.command("list-providers")
def list_providers():
    """List all configured providers."""
    providers = provider_manager.list_providers()
    current = provider_manager.get_current_provider()
    
    table = Table(title="🔧 Configured Providers")
    table.add_column("Provider", style="cyan")
    table.add_column("Model", style="green")
    table.add_column("Status", style="yellow")
    table.add_column("Current", style="red")
    
    for provider_name, config in providers.items():
        status = "✅ Ready" if config.api_key else "❌ No API Key"
        is_current = "🔥 Yes" if provider_name == current else ""
        table.add_row(provider_name, config.model, status, is_current)
    
    console.print(table)

@app.command("use")
def use_provider(provider: str = typer.Argument(help="Provider name to use")):
    """Switch to a different provider."""
    if provider_manager.set_provider(provider):
        rprint(f"✅ [green]Switched to {provider} provider[/green]")
    else:
        rprint(f"❌ [red]Provider {provider} not found or not configured[/red]")
        sys.exit(1)

@app.command("refactor")
def refactor_code(
    task_type: str = typer.Argument(help="Type of refactoring: performance, duplication, understandability, idiomatic, code_smells, error_handling, testing, architecture"),
    workspace: str = typer.Option(".", "--workspace", "-w", help="Workspace directory (default: current directory)"),
    provider: Optional[str] = typer.Option(None, "--provider", "-p", help="Provider to use for this task"),
    model: Optional[str] = typer.Option(None, "--model", "-m", help="Model to use for this task")
):
    """Run a specific refactoring task on the Observable gem."""
    
    # Validate task type
    valid_tasks = [
        "performance", "duplication", "understandability", "idiomatic", 
        "code_smells", "error_handling", "testing", "architecture"
    ]
    
    if task_type not in valid_tasks:
        rprint(f"❌ [red]Invalid task type: {task_type}[/red]")
        rprint(f"Valid types: {', '.join(valid_tasks)}")
        sys.exit(1)
    
    # Setup provider if specified
    if provider:
        provider_manager.set_provider(provider)
    
    if not ensure_provider_setup():
        rprint("❌ [red]No provider configured. Use 'setup' command first.[/red]")
        sys.exit(1)
    
    # Run refactoring task
    try:
        asyncio.run(_run_refactor_task(task_type, workspace, model))
    except KeyboardInterrupt:
        rprint("\n🛑 [yellow]Refactoring interrupted by user[/yellow]")
        sys.exit(1)
    except Exception as e:
        rprint(f"❌ [red]Error during refactoring: {e}[/red]")
        sys.exit(1)

@app.command("analyze")
def analyze_gem(
    workspace: str = typer.Option(".", "--workspace", "-w", help="Workspace directory (default: current directory)"),
    file: Optional[str] = typer.Option(None, "--file", "-f", help="Specific file to analyze"),
    provider: Optional[str] = typer.Option(None, "--provider", "-p", help="Provider to use for this task")
):
    """Analyze the Observable gem structure and code quality."""
    
    if provider:
        provider_manager.set_provider(provider)
    
    if not ensure_provider_setup():
        rprint("❌ [red]No provider configured. Use 'setup' command first.[/red]")
        sys.exit(1)
    
    try:
        asyncio.run(_run_analysis_task(workspace, file))
    except KeyboardInterrupt:
        rprint("\n🛑 [yellow]Analysis interrupted by user[/yellow]")
        sys.exit(1)
    except Exception as e:
        rprint(f"❌ [red]Error during analysis: {e}[/red]")
        sys.exit(1)

@app.command("custom")
def custom_refactor(
    instruction: str = typer.Argument(help="Custom refactoring instruction"),
    workspace: str = typer.Option(".", "--workspace", "-w", help="Workspace directory (default: current directory)"),
    provider: Optional[str] = typer.Option(None, "--provider", "-p", help="Provider to use for this task")
):
    """Run a custom refactoring task with your own instructions."""
    
    if provider:
        provider_manager.set_provider(provider)
    
    if not ensure_provider_setup():
        rprint("❌ [red]No provider configured. Use 'setup' command first.[/red]")
        sys.exit(1)
    
    try:
        asyncio.run(_run_custom_refactor_task(instruction, workspace))
    except KeyboardInterrupt:
        rprint("\n🛑 [yellow]Refactoring interrupted by user[/yellow]")
        sys.exit(1)
    except Exception as e:
        rprint(f"❌ [red]Error during refactoring: {e}[/red]")
        sys.exit(1)

@app.command("batch")
def batch_refactor(
    tasks: str = typer.Argument(help="Comma-separated list of refactoring tasks"),
    workspace: str = typer.Option(".", "--workspace", "-w", help="Workspace directory (default: current directory)"),
    provider: Optional[str] = typer.Option(None, "--provider", "-p", help="Provider to use for this task")
):
    """Run multiple refactoring tasks in sequence."""
    
    task_list = [task.strip() for task in tasks.split(",")]
    valid_tasks = [
        "performance", "duplication", "understandability", "idiomatic", 
        "code_smells", "error_handling", "testing", "architecture"
    ]
    
    # Validate all tasks
    invalid_tasks = [task for task in task_list if task not in valid_tasks]
    if invalid_tasks:
        rprint(f"❌ [red]Invalid task types: {', '.join(invalid_tasks)}[/red]")
        rprint(f"Valid types: {', '.join(valid_tasks)}")
        sys.exit(1)
    
    if provider:
        provider_manager.set_provider(provider)
    
    if not ensure_provider_setup():
        rprint("❌ [red]No provider configured. Use 'setup' command first.[/red]")
        sys.exit(1)
    
    try:
        asyncio.run(_run_batch_refactor_tasks(task_list, workspace))
    except KeyboardInterrupt:
        rprint("\n🛑 [yellow]Batch refactoring interrupted by user[/yellow]")
        sys.exit(1)
    except Exception as e:
        rprint(f"❌ [red]Error during batch refactoring: {e}[/red]")
        sys.exit(1)

async def _run_refactor_task(task_type: str, workspace: str, model: Optional[str] = None):
    """Run a single refactoring task."""
    config = provider_manager.get_current_config()
    if not config:
        rprint("❌ [red]No active provider configuration[/red]")
        return
    
    # Use specified model or default from config
    use_model = model or config.model
    
    rprint(f"🚀 [cyan]Starting {task_type} refactoring...[/cyan]")
    rprint(f"📁 Workspace: {os.path.abspath(workspace)}")
    rprint(f"🔧 Provider: {config.name} ({use_model})")
    
    agent = RefactoringAgent(config.provider_type, config.api_key, use_model)
    result = await agent.execute_refactoring_task(task_type, workspace)
    
    if result["success"]:
        rprint(f"✅ [green]{task_type.title()} refactoring completed successfully![/green]")
        rprint(f"📊 Actions taken: {len(result['actions'])}")
        rprint(f"🔄 Iterations: {result['iterations']}")
        
        # Display actions taken
        if result["actions"]:
            rprint("\n📋 [bold]Actions performed:[/bold]")
            for i, action in enumerate(result["actions"], 1):
                rprint(f"  {i}. {action}")
    else:
        rprint(f"❌ [red]{task_type.title()} refactoring failed: {result.get('error', 'Unknown error')}[/red]")

async def _run_analysis_task(workspace: str, file: Optional[str] = None):
    """Run analysis task."""
    config = provider_manager.get_current_config()
    if not config:
        rprint("❌ [red]No active provider configuration[/red]")
        return
    
    rprint(f"🔍 [cyan]Starting gem analysis...[/cyan]")
    rprint(f"📁 Workspace: {os.path.abspath(workspace)}")
    
    agent = RefactoringAgent(config.provider_type, config.api_key, config.model)
    
    if file:
        # Analyze specific file
        instruction = f"Analyze the Ruby file '{file}' for code quality, structure, and potential improvements. Provide detailed recommendations for refactoring."
    else:
        # Analyze entire gem
        instruction = "Analyze the Observable gem structure and codebase. Identify areas for improvement, code quality issues, and provide refactoring recommendations."
    
    result = await agent.execute_refactoring_task("analysis", workspace, instruction=instruction)
    
    if result["success"]:
        rprint("✅ [green]Analysis completed successfully![/green]")
        rprint(f"📊 Actions taken: {len(result['actions'])}")
    else:
        rprint(f"❌ [red]Analysis failed: {result.get('error', 'Unknown error')}[/red]")

async def _run_custom_refactor_task(instruction: str, workspace: str):
    """Run a custom refactoring task."""
    config = provider_manager.get_current_config()
    if not config:
        rprint("❌ [red]No active provider configuration[/red]")
        return
    
    rprint(f"🎯 [cyan]Starting custom refactoring...[/cyan]")
    rprint(f"📝 Task: {instruction}")
    rprint(f"📁 Workspace: {os.path.abspath(workspace)}")
    
    agent = RefactoringAgent(config.provider_type, config.api_key, config.model)
    result = await agent.execute_refactoring_task("custom", workspace, instruction=instruction)
    
    if result["success"]:
        rprint("✅ [green]Custom refactoring completed successfully![/green]")
        rprint(f"📊 Actions taken: {len(result['actions'])}")
    else:
        rprint(f"❌ [red]Custom refactoring failed: {result.get('error', 'Unknown error')}[/red]")

async def _run_batch_refactor_tasks(task_list: List[str], workspace: str):
    """Run multiple refactoring tasks in sequence."""
    config = provider_manager.get_current_config()
    if not config:
        rprint("❌ [red]No active provider configuration[/red]")
        return
    
    rprint(f"🎯 [cyan]Starting batch refactoring...[/cyan]")
    rprint(f"📋 Tasks: {', '.join(task_list)}")
    rprint(f"📁 Workspace: {os.path.abspath(workspace)}")
    
    agent = RefactoringAgent(config.provider_type, config.api_key, config.model)
    
    total_actions = 0
    successful_tasks = 0
    
    for i, task_type in enumerate(task_list, 1):
        rprint(f"\n📍 [bold]Task {i}/{len(task_list)}: {task_type}[/bold]")
        
        result = await agent.execute_refactoring_task(task_type, workspace)
        
        if result["success"]:
            rprint(f"✅ [green]{task_type} completed[/green]")
            total_actions += len(result["actions"])
            successful_tasks += 1
        else:
            rprint(f"❌ [red]{task_type} failed: {result.get('error', 'Unknown error')}[/red]")
    
    # Summary
    rprint(f"\n📊 [bold]Batch Refactoring Summary:[/bold]")
    rprint(f"✅ Successful tasks: {successful_tasks}/{len(task_list)}")
    rprint(f"📋 Total actions: {total_actions}")
    
    if successful_tasks == len(task_list):
        rprint("🎉 [green]All refactoring tasks completed successfully![/green]")
    else:
        rprint("⚠️ [yellow]Some tasks failed. Check the output above for details.[/yellow]")

@app.command("help-tasks")
def help_tasks():
    """Show detailed information about available refactoring tasks."""
    
    task_descriptions = {
        "performance": "🚀 Optimize code for better performance - reduce bottlenecks, improve memory usage, optimize OpenTelemetry operations",
        "duplication": "🔄 Remove code duplication - extract common patterns, create shared modules, eliminate repeated logic",
        "understandability": "📖 Improve code readability - better names, documentation, structure, and clarity",
        "idiomatic": "💎 Make code more idiomatic Ruby - follow Ruby conventions, use standard patterns, improve APIs",
        "code_smells": "🧹 Remove code smells - fix long methods, large classes, inappropriate coupling, dead code",
        "error_handling": "⚠️ Improve error handling - add proper exceptions, better error messages, graceful degradation",
        "testing": "🧪 Enhance testing - improve coverage, add edge cases, better test structure and organization",
        "architecture": "🏗️ Improve architecture - reduce coupling, better abstractions, cleaner interfaces, modularity"
    }
    
    rprint("[bold cyan]📋 Available Refactoring Tasks[/bold cyan]\n")
    
    for task, description in task_descriptions.items():
        rprint(f"[yellow]{task:15}[/yellow] {description}")
    
    rprint(f"\n[dim]Usage: refactoring-agent refactor <task_type> [options][/dim]")
    rprint(f"[dim]Example: refactoring-agent refactor performance --workspace ./my-gem[/dim]")

if __name__ == "__main__":
    app()