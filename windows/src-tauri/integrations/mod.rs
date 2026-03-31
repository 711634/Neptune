// Real Windows CLI and IDE integrations
// Not just detection - actual execution and workspace linking

#[cfg(target_os = "windows")]
pub mod claude_code;
#[cfg(target_os = "windows")]
pub mod vscode;
#[cfg(target_os = "windows")]
pub mod claude_desktop;
#[cfg(target_os = "windows")]
pub mod codex;
pub mod execution;
pub mod streaming;

#[cfg(target_os = "windows")]
pub use claude_code::ClaudeCodeIntegration;
#[cfg(target_os = "windows")]
pub use vscode::VSCodeIntegration;
#[cfg(target_os = "windows")]
pub use claude_desktop::ClaudeDesktopIntegration;
#[cfg(target_os = "windows")]
pub use codex::CodexIntegration;
pub use execution::ExecutionSession;
pub use streaming::{StreamingSession, ProcessStream};

use anyhow::Result;
use std::path::PathBuf;

/// Session for a provider execution
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ProviderSession {
    pub id: String,
    pub provider_id: String,
    pub status: SessionStatus,
    pub created_at: String,
    pub project_path: Option<String>,
    pub output: Vec<String>,
    pub pid: Option<u32>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize, PartialEq)]
pub enum SessionStatus {
    Starting,
    Running,
    Idle,
    Error,
    Completed,
}

impl std::fmt::Display for SessionStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        match self {
            SessionStatus::Starting => write!(f, "Starting"),
            SessionStatus::Running => write!(f, "Running"),
            SessionStatus::Idle => write!(f, "Idle"),
            SessionStatus::Error => write!(f, "Error"),
            SessionStatus::Completed => write!(f, "Completed"),
        }
    }
}
