#!/usr/bin/env python3
"""
Observable Gem Focused Refactoring Runner

Specialized runner for applying multiple refactoring strategies specifically
tailored to the Observable gem's architecture and Ruby patterns.
"""

import asyncio
import os
from pathlib import Path
from typing import List, Dict, Any, Optional
from dataclasses import dataclass
from datetime import datetime
import json

from rich.console import Console
from rich.progress import Progress, TaskID
from rich.table import Table
from rich import print as rprint

from agent_system import RefactoringAgent
from provider_config import provider_manager, ensure_provider_setup

console = Console()

@dataclass
class GemRefactorTask:
    """Refactoring task specifically for the Observable gem."""
    task_type: str
    priority: int
    description: str
    files_focus: List[str]  # Specific files to focus on
    success_criteria: List[str]  # How to measure success
    dependencies: List[str] = None  # Other tasks this depends on
    
class ObservableGemRefactorRunner:
    """
    Specialized refactoring runner for the Observable gem that applies
    Ruby best practices and OpenTelemetry patterns.
    """
    
    def __init__(self, workspace_dir: str = "."):
        self.workspace_dir = os.path.abspath(workspace_dir)
        self.results: List[Dict[str, Any]] = []
        
        # Ensure provider is setup
        if not ensure_provider_setup():
            raise RuntimeError("No Claude provider configured")
        
        # Initialize agent
        config = provider_manager.get_current_config()
        self.agent = RefactoringAgent(config.provider_type, config.api_key, config.model)
    
    def get_default_gem_refactor_plan(self) -> List[GemRefactorTask]:
        """Get the default refactoring plan for the Observable gem."""
        return [
            GemRefactorTask(
                task_type="architecture",
                priority=1,
                description="Analyze and improve gem architecture and module organization",
                files_focus=["lib/observable", "lib/observable.rb"],
                success_criteria=[
                    "Clear module boundaries",
                    "Reduced coupling between components",
                    "Proper separation of concerns"
                ]
            ),
            
            GemRefactorTask(
                task_type="performance", 
                priority=2,
                description="Optimize instrumentation performance and reduce overhead",
                files_focus=["lib/observable/instrumenter.rb"],
                success_criteria=[
                    "Reduced method call overhead",
                    "Optimized argument extraction",
                    "Efficient span creation",
                    "Memory usage improvements"
                ],
                dependencies=["architecture"]
            ),
            
            GemRefactorTask(
                task_type="code_smells",
                priority=3,
                description="Remove code smells and improve code quality",
                files_focus=["lib/observable/instrumenter.rb", "test/"],
                success_criteria=[
                    "Methods under 15 lines",
                    "Classes with single responsibility",
                    "No duplicate code patterns",
                    "Proper error handling"
                ]
            ),
            
            GemRefactorTask(
                task_type="idiomatic",
                priority=4,
                description="Make code more idiomatic Ruby and follow gem conventions",
                files_focus=["lib/", "observable.gemspec"],
                success_criteria=[
                    "Follows Ruby naming conventions",
                    "Uses appropriate Ruby patterns",
                    "Proper gem structure",
                    "Standard Ruby idioms"
                ],
                dependencies=["code_smells"]
            ),
            
            GemRefactorTask(
                task_type="error_handling",
                priority=5,
                description="Improve error handling and instrumentation resilience", 
                files_focus=["lib/observable/instrumenter.rb"],
                success_criteria=[
                    "Graceful degradation on errors",
                    "Proper exception handling",
                    "Clear error messages",
                    "No instrumentation failures affect application"
                ]
            ),
            
            GemRefactorTask(
                task_type="testing",
                priority=6,
                description="Enhance test coverage and test quality",
                files_focus=["test/", "test/unit/"],
                success_criteria=[
                    "100% test coverage for critical paths",
                    "Edge case testing",
                    "Performance benchmarks",
                    "Integration tests for OpenTelemetry"
                ],
                dependencies=["error_handling"]
            ),
            
            GemRefactorTask(
                task_type="understandability",
                priority=7,
                description="Improve code documentation and clarity",
                files_focus=["lib/observable/", "README.md"],
                success_criteria=[
                    "Clear method documentation",
                    "Usage examples",
                    "API documentation",
                    "Code comments for complex logic"
                ]
            ),
            
            GemRefactorTask(
                task_type="duplication",
                priority=8,
                description="Remove code duplication and extract common patterns",
                files_focus=["lib/", "test/"],
                success_criteria=[
                    "No duplicate code blocks",
                    "Shared utilities extracted",
                    "Common patterns abstracted",
                    "DRY principle applied"
                ],
                dependencies=["understandability"]
            )
        ]
    
    async def run_gem_refactor_plan(self, 
                                   tasks: Optional[List[GemRefactorTask]] = None,
                                   dry_run: bool = False) -> Dict[str, Any]:
        """
        Run a complete refactoring plan for the Observable gem.
        
        Args:
            tasks: Custom list of refactoring tasks (uses default if None)
            dry_run: If True, only analyze without making changes
            
        Returns:
            Summary of refactoring results
        """
        
        if tasks is None:
            tasks = self.get_default_gem_refactor_plan()
        
        # Sort tasks by priority
        sorted_tasks = sorted(tasks, key=lambda t: t.priority)
        
        rprint(f"🚀 [cyan]Starting Observable Gem Refactoring Plan[/cyan]")
        rprint(f"📁 Workspace: {self.workspace_dir}")
        rprint(f"📋 Tasks: {len(sorted_tasks)}")
        rprint(f"🔧 Dry Run: {'Yes' if dry_run else 'No'}")
        
        # Pre-refactoring analysis
        await self._run_pre_analysis()
        
        results = []
        successful_tasks = 0
        
        with Progress() as progress:
            main_task = progress.add_task("[cyan]Refactoring Progress...", total=len(sorted_tasks))
            
            for task in sorted_tasks:
                progress.update(main_task, description=f"[cyan]Running {task.task_type}...")
                
                rprint(f"\n📍 [bold]Task: {task.task_type.title()}[/bold]")
                rprint(f"   {task.description}")
                
                # Check dependencies
                if task.dependencies and not self._check_dependencies(task.dependencies, results):
                    rprint(f"⏭️ [yellow]Skipping {task.task_type} - dependencies not met[/yellow]")
                    progress.update(main_task, advance=1)
                    continue
                
                if dry_run:
                    # Dry run - just analyze
                    result = await self._analyze_task(task)
                else:
                    # Actually run the refactoring
                    result = await self.agent.execute_refactoring_task(
                        task.task_type, 
                        self.workspace_dir,
                        files_focus=task.files_focus,
                        success_criteria=task.success_criteria
                    )
                
                result["task_info"] = task
                result["timestamp"] = datetime.now().isoformat()
                results.append(result)
                
                if result["success"]:
                    successful_tasks += 1
                    rprint(f"✅ [green]{task.task_type} completed[/green]")
                    
                    # Verify success criteria if possible
                    await self._verify_success_criteria(task, result)
                else:
                    rprint(f"❌ [red]{task.task_type} failed: {result.get('error', 'Unknown error')}[/red]")
                
                progress.update(main_task, advance=1)
        
        # Post-refactoring analysis
        if not dry_run:
            await self._run_post_analysis()
        
        # Generate summary
        summary = self._generate_summary(results, successful_tasks, len(sorted_tasks))
        
        # Save detailed results
        await self._save_results(results, summary)
        
        return summary
    
    async def run_targeted_refactor(self, focus_areas: List[str]) -> Dict[str, Any]:
        """
        Run refactoring focused on specific areas of the gem.
        
        Args:
            focus_areas: List of areas to focus on (e.g., ['performance', 'testing'])
        """
        
        all_tasks = self.get_default_gem_refactor_plan()
        focused_tasks = [task for task in all_tasks if task.task_type in focus_areas]
        
        if not focused_tasks:
            rprint(f"❌ [red]No tasks found for focus areas: {focus_areas}[/red]")
            return {"success": False, "error": "No matching tasks"}
        
        return await self.run_gem_refactor_plan(focused_tasks)
    
    async def _run_pre_analysis(self):
        """Run pre-refactoring analysis to establish baseline."""
        rprint("\n🔍 [cyan]Running pre-refactoring analysis...[/cyan]")
        
        analysis_tasks = [
            ("gem_structure", "Analyzing gem structure and conventions"),
            ("code_metrics", "Collecting code metrics"),
            ("test_coverage", "Analyzing test coverage")
        ]
        
        for task_name, description in analysis_tasks:
            rprint(f"   {description}")
            
            if task_name == "gem_structure":
                result = await self.agent.tools["analyze_gem_structure"].execute(self.workspace_dir)
            elif task_name == "code_metrics":
                result = await self._collect_code_metrics()
            elif task_name == "test_coverage":
                result = await self._analyze_test_coverage()
            
            if result.get("success"):
                rprint(f"   ✅ {description} completed")
            else:
                rprint(f"   ⚠️ {description} had issues: {result.get('error', 'Unknown')}")
    
    async def _run_post_analysis(self):
        """Run post-refactoring analysis to measure improvements."""
        rprint("\n📊 [cyan]Running post-refactoring analysis...[/cyan]")
        
        # Re-run tests to ensure nothing broke
        rprint("   Running test suite...")
        test_result = await self.agent.tools["run_command"].execute(
            command="bundle exec rake test",
            workspace_dir=self.workspace_dir
        )
        
        if test_result["success"]:
            rprint("   ✅ All tests passing")
        else:
            rprint("   ❌ Test failures detected - review needed")
        
        # Run linting
        rprint("   Running StandardRB linting...")
        lint_result = await self.agent.tools["run_command"].execute(
            command="bundle exec standardrb",
            workspace_dir=self.workspace_dir
        )
        
        if lint_result["success"]:
            rprint("   ✅ Code style compliant")
        else:
            rprint("   ⚠️ Code style issues detected")
    
    async def _analyze_task(self, task: GemRefactorTask) -> Dict[str, Any]:
        """Analyze what would be done for a task (dry run)."""
        return {
            "success": True,
            "task_type": task.task_type,
            "actions": [f"Would analyze and refactor {task.task_type}"],
            "dry_run": True,
            "estimated_changes": len(task.files_focus)
        }
    
    def _check_dependencies(self, dependencies: List[str], completed_results: List[Dict]) -> bool:
        """Check if task dependencies have been completed successfully."""
        completed_tasks = {r["task_type"] for r in completed_results if r.get("success")}
        return all(dep in completed_tasks for dep in dependencies)
    
    async def _verify_success_criteria(self, task: GemRefactorTask, result: Dict[str, Any]):
        """Verify if the success criteria for a task have been met."""
        verified_criteria = []
        
        for criterion in task.success_criteria:
            # This is a simplified verification - in reality you'd implement
            # specific checks for each criterion
            verified_criteria.append({
                "criterion": criterion,
                "status": "needs_manual_verification"
            })
        
        result["success_criteria_verification"] = verified_criteria
    
    async def _collect_code_metrics(self) -> Dict[str, Any]:
        """Collect basic code metrics."""
        try:
            # Count lines of code
            result = await self.agent.tools["run_command"].execute(
                command="find lib -name '*.rb' | xargs wc -l | tail -1",
                workspace_dir=self.workspace_dir
            )
            
            return {
                "success": True,
                "metrics": {
                    "lines_of_code": result.get("output", "").strip() if result["success"] else "unknown"
                }
            }
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    async def _analyze_test_coverage(self) -> Dict[str, Any]:
        """Analyze test coverage."""
        try:
            # Run tests with coverage (if available)
            result = await self.agent.tools["run_command"].execute(
                command="bundle exec rake test",
                workspace_dir=self.workspace_dir
            )
            
            return {
                "success": result["success"],
                "test_output": result.get("output", "")
            }
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def _generate_summary(self, results: List[Dict], successful_tasks: int, total_tasks: int) -> Dict[str, Any]:
        """Generate a summary of the refactoring session."""
        
        total_actions = sum(len(r.get("actions", [])) for r in results)
        
        summary = {
            "timestamp": datetime.now().isoformat(),
            "workspace": self.workspace_dir,
            "total_tasks": total_tasks,
            "successful_tasks": successful_tasks,
            "failed_tasks": total_tasks - successful_tasks,
            "success_rate": (successful_tasks / total_tasks * 100) if total_tasks > 0 else 0,
            "total_actions": total_actions,
            "task_results": results
        }
        
        return summary
    
    async def _save_results(self, results: List[Dict], summary: Dict[str, Any]):
        """Save detailed results to files."""
        
        results_dir = Path(self.workspace_dir) / "refactoring_results"
        results_dir.mkdir(exist_ok=True)
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Save summary
        summary_file = results_dir / f"refactoring_summary_{timestamp}.json"
        with open(summary_file, "w") as f:
            json.dump(summary, f, indent=2, default=str)
        
        rprint(f"💾 Results saved to {summary_file}")
        
        # Print summary table
        self._print_summary_table(summary)
    
    def _print_summary_table(self, summary: Dict[str, Any]):
        """Print a rich summary table."""
        
        rprint("\n" + "="*60)
        rprint("📋 [bold cyan]OBSERVABLE GEM REFACTORING SUMMARY[/bold cyan]")
        rprint("="*60)
        
        # Overall stats
        stats_table = Table(title="📊 Refactoring Statistics")
        stats_table.add_column("Metric", style="cyan")
        stats_table.add_column("Value", style="green")
        
        stats_table.add_row("Total Tasks", str(summary["total_tasks"]))
        stats_table.add_row("Successful", f"✅ {summary['successful_tasks']}")
        stats_table.add_row("Failed", f"❌ {summary['failed_tasks']}")
        stats_table.add_row("Success Rate", f"{summary['success_rate']:.1f}%")
        stats_table.add_row("Total Actions", str(summary["total_actions"]))
        
        console.print(stats_table)
        
        # Task-by-task results
        if summary["failed_tasks"] > 0:
            rprint(f"\n❌ [bold red]Failed Tasks:[/bold red]")
            for result in summary["task_results"]:
                if not result.get("success"):
                    rprint(f"  • {result.get('task_type', 'unknown')}: {result.get('error', 'Unknown error')}")
        
        rprint(f"\n🎉 [bold green]Observable Gem Refactoring Complete![/bold green]")
        
        # Next steps
        rprint(f"\n📋 [bold]Recommended Next Steps:[/bold]")
        rprint("  1. Review the refactored code and test thoroughly")
        rprint("  2. Run the full test suite: `bundle exec rake test`")
        rprint("  3. Check code style: `bundle exec standardrb`")
        rprint("  4. Update documentation if needed")
        rprint("  5. Consider performance benchmarks")

# Convenience functions
async def run_full_gem_refactor(workspace_dir: str = ".") -> Dict[str, Any]:
    """Run the complete Observable gem refactoring plan."""
    runner = ObservableGemRefactorRunner(workspace_dir)
    return await runner.run_gem_refactor_plan()

async def run_performance_focused_refactor(workspace_dir: str = ".") -> Dict[str, Any]:
    """Run refactoring focused on performance improvements."""
    runner = ObservableGemRefactorRunner(workspace_dir)
    return await runner.run_targeted_refactor(["architecture", "performance", "code_smells"])

async def run_quality_focused_refactor(workspace_dir: str = ".") -> Dict[str, Any]:
    """Run refactoring focused on code quality improvements."""
    runner = ObservableGemRefactorRunner(workspace_dir)
    return await runner.run_targeted_refactor(["code_smells", "idiomatic", "understandability", "duplication"])

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1:
        if sys.argv[1] == "full":
            asyncio.run(run_full_gem_refactor())
        elif sys.argv[1] == "performance":
            asyncio.run(run_performance_focused_refactor())
        elif sys.argv[1] == "quality":
            asyncio.run(run_quality_focused_refactor())
        else:
            rprint(f"Unknown command: {sys.argv[1]}")
            rprint("Available commands: full, performance, quality")
    else:
        rprint("Usage: python gem_refactor_runner.py [full|performance|quality]")