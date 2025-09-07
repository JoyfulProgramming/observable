"""
Provider Configuration Management

Manages configuration for different AI providers (Anthropic, OpenRouter, etc.)
for the Observable Gem Refactoring Agent.
"""

import json
import os
from pathlib import Path
from typing import Dict, Optional, Any
from dataclasses import dataclass
from rich import print as rprint

@dataclass
class ProviderConfig:
    """Configuration for an AI provider."""
    name: str
    provider_type: str  # 'anthropic', 'openrouter', etc.
    api_key: str
    model: str
    description: str
    base_url: Optional[str] = None

class ProviderManager:
    """Manages AI provider configurations."""
    
    def __init__(self, config_file: str = "~/.refactoring-agent-config.json"):
        self.config_file = Path(config_file).expanduser()
        self.configs: Dict[str, ProviderConfig] = {}
        self.current_provider: Optional[str] = None
        self._load_config()
    
    def _load_config(self):
        """Load configuration from file."""
        if self.config_file.exists():
            try:
                with open(self.config_file, 'r') as f:
                    data = json.load(f)
                    
                    # Load provider configurations
                    for name, config_data in data.get('providers', {}).items():
                        self.configs[name] = ProviderConfig(**config_data)
                    
                    # Load current provider
                    self.current_provider = data.get('current_provider')
                    
            except Exception as e:
                rprint(f"⚠️ [yellow]Warning: Could not load config file: {e}[/yellow]")
                self._create_default_config()
        else:
            self._create_default_config()
    
    def _create_default_config(self):
        """Create default configuration."""
        # Create default provider configurations (without API keys)
        self.configs = {
            "anthropic": ProviderConfig(
                name="anthropic",
                provider_type="anthropic",
                api_key="",
                model="claude-3-sonnet-20240229",
                description="Anthropic Claude via direct API"
            ),
            "openrouter": ProviderConfig(
                name="openrouter",
                provider_type="openrouter", 
                api_key="",
                model="anthropic/claude-3-sonnet",
                description="Anthropic Claude via OpenRouter",
                base_url="https://openrouter.ai/api/v1"
            )
        }
        
        # Try to get API key from environment
        anthropic_key = os.getenv('ANTHROPIC_API_KEY')
        if anthropic_key:
            self.configs["anthropic"].api_key = anthropic_key
            self.current_provider = "anthropic"
        
        openrouter_key = os.getenv('OPENROUTER_API_KEY')
        if openrouter_key:
            self.configs["openrouter"].api_key = openrouter_key
            if not self.current_provider:
                self.current_provider = "openrouter"
        
        self._save_config()
    
    def _save_config(self):
        """Save configuration to file."""
        try:
            # Create directory if it doesn't exist
            self.config_file.parent.mkdir(parents=True, exist_ok=True)
            
            # Prepare data for saving
            data = {
                "providers": {
                    name: {
                        "name": config.name,
                        "provider_type": config.provider_type,
                        "api_key": config.api_key,
                        "model": config.model,
                        "description": config.description,
                        "base_url": config.base_url
                    }
                    for name, config in self.configs.items()
                },
                "current_provider": self.current_provider
            }
            
            with open(self.config_file, 'w') as f:
                json.dump(data, f, indent=2)
                
        except Exception as e:
            rprint(f"⚠️ [yellow]Warning: Could not save config file: {e}[/yellow]")
    
    def setup_provider(self, provider_name: str, api_key: Optional[str] = None, model: Optional[str] = None) -> bool:
        """Setup or update a provider configuration."""
        
        # Get existing config or create new one
        if provider_name in self.configs:
            config = self.configs[provider_name]
        else:
            # Create new provider config based on provider type
            if provider_name == "anthropic":
                config = ProviderConfig(
                    name="anthropic",
                    provider_type="anthropic",
                    api_key="",
                    model="claude-3-sonnet-20240229",
                    description="Anthropic Claude via direct API"
                )
            elif provider_name == "openrouter":
                config = ProviderConfig(
                    name="openrouter",
                    provider_type="openrouter",
                    api_key="",
                    model="anthropic/claude-3-sonnet",
                    description="Anthropic Claude via OpenRouter",
                    base_url="https://openrouter.ai/api/v1"
                )
            else:
                rprint(f"❌ [red]Unknown provider: {provider_name}[/red]")
                return False
        
        # Update API key
        if api_key:
            config.api_key = api_key
        elif not config.api_key:
            # Try to get from environment
            env_key = f"{provider_name.upper()}_API_KEY"
            if provider_name == "openrouter":
                env_key = "OPENROUTER_API_KEY"
            
            env_api_key = os.getenv(env_key)
            if env_api_key:
                config.api_key = env_api_key
                rprint(f"✅ [green]Using {env_key} from environment[/green]")
            else:
                # Prompt for API key
                try:
                    import getpass
                    config.api_key = getpass.getpass(f"Enter API key for {provider_name}: ")
                except KeyboardInterrupt:
                    rprint("\n❌ [red]Setup cancelled[/red]")
                    return False
        
        # Update model if specified
        if model:
            config.model = model
        
        # Validate API key
        if not config.api_key:
            rprint(f"❌ [red]No API key provided for {provider_name}[/red]")
            return False
        
        # Save configuration
        self.configs[provider_name] = config
        
        # Set as current provider if none is set
        if not self.current_provider:
            self.current_provider = provider_name
        
        self._save_config()
        return True
    
    def set_provider(self, provider_name: str) -> bool:
        """Set the current active provider."""
        if provider_name in self.configs:
            config = self.configs[provider_name]
            if config.api_key:
                self.current_provider = provider_name
                self._save_config()
                return True
            else:
                rprint(f"❌ [red]Provider {provider_name} has no API key configured[/red]")
                return False
        else:
            rprint(f"❌ [red]Provider {provider_name} not found[/red]")
            return False
    
    def get_current_provider(self) -> Optional[str]:
        """Get the name of the current active provider."""
        return self.current_provider
    
    def get_current_config(self) -> Optional[ProviderConfig]:
        """Get the configuration of the current active provider."""
        if self.current_provider and self.current_provider in self.configs:
            return self.configs[self.current_provider]
        return None
    
    def list_providers(self) -> Dict[str, ProviderConfig]:
        """List all configured providers."""
        return self.configs.copy()
    
    def get_claude_code_options(self) -> Dict[str, Any]:
        """Get options for Claude Code SDK based on current provider."""
        config = self.get_current_config()
        if not config:
            return {}
        
        options = {
            "model": config.model
        }
        
        # Provider-specific options
        if config.provider_type == "anthropic":
            options["anthropic_api_key"] = config.api_key
        elif config.provider_type == "openrouter":
            options["openrouter_api_key"] = config.api_key
            if config.base_url:
                options["base_url"] = config.base_url
        
        return options

def ensure_provider_setup() -> bool:
    """Ensure that at least one provider is properly configured."""
    config = provider_manager.get_current_config()
    
    if not config:
        rprint("⚠️ [yellow]No provider configured.[/yellow]")
        rprint("Available providers: anthropic, openrouter")
        rprint("Use 'refactoring-agent setup <provider>' to configure a provider.")
        return False
    
    if not config.api_key:
        rprint(f"⚠️ [yellow]Provider {config.name} has no API key configured.[/yellow]")
        rprint(f"Use 'refactoring-agent setup {config.name}' to add an API key.")
        return False
    
    return True

# Global instance
provider_manager = ProviderManager()