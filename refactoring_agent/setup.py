#!/usr/bin/env python3
"""
Observable Gem Refactoring Agent Setup Script

Automated setup for the Ruby-focused refactoring system.
This script handles dependency installation, provider configuration,
and validation of the Observable gem environment.
"""

import os
import sys
import subprocess
import json
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import platform

try:
    from rich.console import Console
    from rich.progress import Progress
    from rich.prompt import Prompt, Confirm
    from rich.panel import Panel
    from rich import print as rprint
except ImportError:
    # Fallback if rich isn't installed yet
    def rprint(text):
        print(text)
    
    class Console:
        def print(self, text):
            print(text)
    
    class Prompt:
        @staticmethod
        def ask(prompt, default=None):
            if default:
                response = input(f"{prompt} [{default}]: ")
                return response or default
            return input(f"{prompt}: ")
    
    class Confirm:
        @staticmethod  
        def ask(prompt):
            while True:
                response = input(f"{prompt} (y/N): ").lower()
                if response in ['y', 'yes']:
                    return True
                elif response in ['n', 'no', '']:
                    return False

console = Console()

class RefactoringAgentSetup:
    """Setup manager for the Observable Gem Refactoring Agent."""
    
    def __init__(self):
        self.base_dir = Path(__file__).parent
        self.gem_root = self.base_dir.parent
        self.requirements_file = self.base_dir / "requirements.txt"
        self.config_file = Path.home() / ".refactoring-agent-config.json"
        
    def run_full_setup(self) -> bool:
        """Run the complete setup process."""
        try:
            rprint(Panel(
                "🚀 [bold cyan]Observable Gem Refactoring Agent Setup[/bold cyan]\n\n"
                "This will set up the Ruby-focused refactoring system for production code quality improvements.",
                title="Welcome",
                expand=False
            ))
            
            # Step 1: Check environment
            rprint("\n[bold]Step 1: Environment Validation[/bold]")
            if not self._check_environment():
                return False
            
            # Step 2: Install dependencies
            rprint("\n[bold]Step 2: Python Dependencies[/bold]")  
            if not self._install_dependencies():
                return False
            
            # Step 3: Setup providers
            rprint("\n[bold]Step 3: AI Provider Configuration[/bold]")
            if not self._setup_providers():
                return False
            
            # Step 4: Validate gem structure
            rprint("\n[bold]Step 4: Observable Gem Validation[/bold]")
            if not self._validate_gem_structure():
                return False
            
            # Step 5: Run initial test
            rprint("\n[bold]Step 5: System Validation[/bold]")
            if not self._test_system():
                return False
            
            # Success!
            self._show_success_message()
            return True
            
        except KeyboardInterrupt:
            rprint("\n🛑 [yellow]Setup interrupted by user[/yellow]")
            return False
        except Exception as e:
            rprint(f"\n❌ [red]Setup failed with error: {e}[/red]")
            return False
    
    def _check_environment(self) -> bool:
        """Check if the environment meets requirements."""
        checks = [
            ("Python version", self._check_python_version),
            ("Git availability", self._check_git),
            ("Ruby availability", self._check_ruby),
            ("Gem structure", self._check_basic_gem_structure)
        ]
        
        all_passed = True
        
        for check_name, check_func in checks:
            rprint(f"   Checking {check_name}...", end=" ")
            success, message = check_func()
            
            if success:
                rprint("✅")
            else:
                rprint(f"❌ {message}")
                all_passed = False
        
        return all_passed
    
    def _check_python_version(self) -> Tuple[bool, str]:
        """Check Python version."""
        version = sys.version_info
        if version.major == 3 and version.minor >= 8:
            return True, f"Python {version.major}.{version.minor}.{version.micro}"
        return False, f"Python {version.major}.{version.minor} found, need 3.8+"
    
    def _check_git(self) -> Tuple[bool, str]:
        """Check if git is available."""
        try:
            result = subprocess.run(["git", "--version"], capture_output=True, text=True)
            if result.returncode == 0:
                return True, "Git available"
            return False, "Git not found"
        except FileNotFoundError:
            return False, "Git not installed"
    
    def _check_ruby(self) -> Tuple[bool, str]:
        """Check if Ruby is available."""
        try:
            result = subprocess.run(["ruby", "--version"], capture_output=True, text=True)
            if result.returncode == 0:
                version_info = result.stdout.strip()
                return True, version_info
            return False, "Ruby not found"
        except FileNotFoundError:
            return False, "Ruby not installed"
    
    def _check_basic_gem_structure(self) -> Tuple[bool, str]:
        """Check if we're in a gem directory."""
        if (self.gem_root / "lib").exists():
            return True, "Gem lib/ directory found"
        return False, "Not in a Ruby gem directory (lib/ not found)"
    
    def _install_dependencies(self) -> bool:
        """Install Python dependencies."""
        if not self.requirements_file.exists():
            rprint("   ❌ requirements.txt not found")
            return False
        
        rprint("   Installing Python dependencies...")
        
        try:
            # Check if we should use a virtual environment
            if not os.getenv('VIRTUAL_ENV') and Confirm.ask("   Create virtual environment?"):
                venv_path = self.base_dir / "venv"
                rprint(f"   Creating virtual environment at {venv_path}")
                subprocess.run([sys.executable, "-m", "venv", str(venv_path)], check=True)
                
                # Provide instructions for activation
                if platform.system() == "Windows":
                    activate_cmd = f"{venv_path}\\Scripts\\activate.bat"
                else:
                    activate_cmd = f"source {venv_path}/bin/activate"
                
                rprint(f"   ⚠️ Please activate the virtual environment and re-run setup:")
                rprint(f"   {activate_cmd}")
                rprint(f"   python setup.py")
                return False
            
            # Install requirements
            result = subprocess.run([
                sys.executable, "-m", "pip", "install", "-r", str(self.requirements_file)
            ], capture_output=True, text=True)
            
            if result.returncode == 0:
                rprint("   ✅ Dependencies installed successfully")
                return True
            else:
                rprint(f"   ❌ Failed to install dependencies: {result.stderr}")
                return False
                
        except subprocess.CalledProcessError as e:
            rprint(f"   ❌ Error installing dependencies: {e}")
            return False
    
    def _setup_providers(self) -> bool:
        """Setup AI providers."""
        rprint("   AI providers enable the refactoring agent to analyze and modify code.")
        rprint("   You need at least one provider configured.")
        
        providers_to_setup = []
        
        # Check for existing environment variables
        anthropic_key = os.getenv('ANTHROPIC_API_KEY')
        openrouter_key = os.getenv('OPENROUTER_API_KEY')
        
        if anthropic_key:
            rprint("   ✅ Found ANTHROPIC_API_KEY in environment")
            providers_to_setup.append(('anthropic', anthropic_key))
        
        if openrouter_key:
            rprint("   ✅ Found OPENROUTER_API_KEY in environment")
            providers_to_setup.append(('openrouter', openrouter_key))
        
        # If no keys found, ask user to configure
        if not providers_to_setup:
            rprint("   No API keys found in environment variables.")
            
            if Confirm.ask("   Setup Anthropic Claude (direct API)?"):
                key = Prompt.ask("   Enter your Anthropic API key")
                if key:
                    providers_to_setup.append(('anthropic', key))
            
            if Confirm.ask("   Setup OpenRouter (alternative provider)?"):
                key = Prompt.ask("   Enter your OpenRouter API key")
                if key:
                    providers_to_setup.append(('openrouter', key))
        
        if not providers_to_setup:
            rprint("   ❌ No providers configured. You need at least one API key.")
            rprint("   You can:")
            rprint("   1. Set ANTHROPIC_API_KEY environment variable")
            rprint("   2. Set OPENROUTER_API_KEY environment variable")  
            rprint("   3. Re-run setup and provide keys interactively")
            return False
        
        # Save provider configurations
        return self._save_provider_config(providers_to_setup)
    
    def _save_provider_config(self, providers: List[Tuple[str, str]]) -> bool:
        """Save provider configuration to file."""
        try:
            config = {
                "providers": {},
                "current_provider": None
            }
            
            for provider_name, api_key in providers:
                if provider_name == "anthropic":
                    config["providers"]["anthropic"] = {
                        "name": "anthropic",
                        "provider_type": "anthropic",
                        "api_key": api_key,
                        "model": "claude-3-sonnet-20240229", 
                        "description": "Anthropic Claude via direct API",
                        "base_url": None
                    }
                elif provider_name == "openrouter":
                    config["providers"]["openrouter"] = {
                        "name": "openrouter",
                        "provider_type": "openrouter",
                        "api_key": api_key,
                        "model": "anthropic/claude-3-sonnet",
                        "description": "Anthropic Claude via OpenRouter",
                        "base_url": "https://openrouter.ai/api/v1"
                    }
                
                # Set first provider as current
                if not config["current_provider"]:
                    config["current_provider"] = provider_name
            
            with open(self.config_file, 'w') as f:
                json.dump(config, f, indent=2)
            
            rprint(f"   ✅ Provider configuration saved to {self.config_file}")
            return True
            
        except Exception as e:
            rprint(f"   ❌ Failed to save provider config: {e}")
            return False
    
    def _validate_gem_structure(self) -> bool:
        """Validate the Observable gem structure."""
        required_files = [
            "lib/observable.rb",
            "observable.gemspec"
        ]
        
        required_dirs = [
            "lib/observable",
            "test"
        ]
        
        missing_files = []
        missing_dirs = []
        
        # Check files
        for file_path in required_files:
            if not (self.gem_root / file_path).exists():
                missing_files.append(file_path)
        
        # Check directories
        for dir_path in required_dirs:
            if not (self.gem_root / dir_path).exists():
                missing_dirs.append(dir_path)
        
        if missing_files or missing_dirs:
            rprint("   ❌ Observable gem structure validation failed:")
            for file in missing_files:
                rprint(f"      Missing file: {file}")
            for dir in missing_dirs:
                rprint(f"      Missing directory: {dir}")
            
            if not Confirm.ask("   Continue anyway? (may affect refactoring quality)"):
                return False
        
        # Check if this looks like the Observable gem specifically
        instrumenter_file = self.gem_root / "lib/observable/instrumenter.rb"
        if instrumenter_file.exists():
            rprint("   ✅ Observable gem structure validated")
            return True
        else:
            rprint("   ⚠️ This doesn't appear to be the Observable gem")
            rprint("   The refactoring agent is optimized for Observable gem patterns")
            return Confirm.ask("   Continue with general Ruby gem refactoring?")
    
    def _test_system(self) -> bool:
        """Test that the system is working."""
        rprint("   Testing refactoring agent system...")
        
        try:
            # Try to import the main modules
            sys.path.insert(0, str(self.base_dir))
            
            from provider_config import provider_manager, ensure_provider_setup
            from agent_system import RefactoringAgent
            
            # Test provider setup
            if not ensure_provider_setup():
                rprint("   ❌ Provider setup validation failed")
                return False
            
            rprint("   ✅ All system components validated")
            return True
            
        except ImportError as e:
            rprint(f"   ❌ Import error: {e}")
            rprint("   Try installing dependencies again")
            return False
        except Exception as e:
            rprint(f"   ❌ System test failed: {e}")
            return False
    
    def _show_success_message(self):
        """Show success message and next steps."""
        rprint(Panel(
            "🎉 [bold green]Setup Complete![/bold green]\n\n"
            "Your Observable Gem Refactoring Agent is ready to use.\n\n"
            "[bold]Quick Start:[/bold]\n"
            "• python cli.py list-providers\n"
            "• python cli.py refactor performance\n"
            "• python gem_refactor_runner.py full\n\n"
            "[bold]Documentation:[/bold]\n"
            "• Read README.md for detailed usage\n"
            "• Run 'python cli.py help-tasks' for task info\n\n"
            "[bold]Next Steps:[/bold]\n"
            "1. Review your gem's current code quality\n"
            "2. Choose appropriate refactoring tasks\n" 
            "3. Run tests after refactoring\n"
            "4. Review and commit changes",
            title="🚀 Ready to Refactor",
            expand=False
        ))

def main():
    """Main setup function."""
    setup = RefactoringAgentSetup()
    
    if len(sys.argv) > 1:
        command = sys.argv[1]
        
        if command == "--check-only":
            # Just run environment checks
            rprint("🔍 Running environment checks only...")
            success = setup._check_environment()
            sys.exit(0 if success else 1)
        elif command == "--deps-only":
            # Just install dependencies
            rprint("📦 Installing dependencies only...")
            success = setup._install_dependencies()
            sys.exit(0 if success else 1)
        elif command == "--help":
            rprint("Observable Gem Refactoring Agent Setup")
            rprint("\nUsage:")
            rprint("  python setup.py           - Full setup")
            rprint("  python setup.py --check-only   - Environment checks only")
            rprint("  python setup.py --deps-only    - Install dependencies only")
            rprint("  python setup.py --help         - Show this help")
            sys.exit(0)
    
    # Run full setup
    success = setup.run_full_setup()
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()