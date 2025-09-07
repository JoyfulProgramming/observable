"""
Observable Gem Refactoring Agent

A specialized Ruby refactoring system designed to improve production code quality
for the Observable gem using Claude AI.
"""

__version__ = "1.0.0"
__author__ = "Terragon Labs"
__description__ = "Ruby-focused refactoring agent for the Observable gem"

from .agent_system import RefactoringAgent
from .provider_config import provider_manager
from .gem_refactor_runner import (
    ObservableGemRefactorRunner,
    run_full_gem_refactor,
    run_performance_focused_refactor,
    run_quality_focused_refactor
)

__all__ = [
    "RefactoringAgent",
    "provider_manager", 
    "ObservableGemRefactorRunner",
    "run_full_gem_refactor",
    "run_performance_focused_refactor",
    "run_quality_focused_refactor"
]