// Windows provider adapters
// Detect and integrate with local tools: Claude Code, VS Code, Claude Desktop

#[cfg(target_os = "windows")]
mod claude_code;
#[cfg(target_os = "windows")]
mod vscode;
#[cfg(target_os = "windows")]
mod claude_desktop;

#[cfg(target_os = "windows")]
pub use claude_code::ClaudeCodeProvider;
#[cfg(target_os = "windows")]
pub use vscode::VSCodeProvider;
#[cfg(target_os = "windows")]
pub use claude_desktop::ClaudeDesktopProvider;

use crate::models::ProviderStatus;
use std::sync::Arc;

pub struct ProviderRegistry {
    pub providers: Vec<Arc<dyn Provider>>,
}

pub trait Provider: Send + Sync {
    fn id(&self) -> &str;
    fn name(&self) -> &str;
    fn detect(&self) -> bool;
    fn get_status(&self) -> ProviderStatus;
}

pub fn init_providers() -> ProviderRegistry {
    let mut providers: Vec<Arc<dyn Provider>> = Vec::new();

    #[cfg(target_os = "windows")]
    {
        providers.push(Arc::new(ClaudeCodeProvider::new()));
        providers.push(Arc::new(VSCodeProvider::new()));
        providers.push(Arc::new(ClaudeDesktopProvider::new()));
    }

    ProviderRegistry { providers }
}

pub fn detect_all(registry: &ProviderRegistry) -> Vec<ProviderStatus> {
    registry
        .providers
        .iter()
        .map(|p| p.get_status())
        .collect()
}
