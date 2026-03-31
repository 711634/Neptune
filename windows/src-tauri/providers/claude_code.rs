// Claude Code CLI adapter for Windows
// Detects claude executable in PATH, supports direct execution

use super::Provider;
use crate::models::ProviderStatus;

pub struct ClaudeCodeProvider {
    installed: bool,
    path: Option<String>,
}

impl ClaudeCodeProvider {
    pub fn new() -> Self {
        let installed = Self::detect_claude();
        let path = Self::find_claude_path();

        Self { installed, path }
    }

    fn detect_claude() -> bool {
        // Try to find claude in PATH
        if let Ok(output) = std::process::Command::new("where")
            .arg("claude")
            .output()
        {
            output.status.success()
        } else {
            false
        }
    }

    fn find_claude_path() -> Option<String> {
        if let Ok(output) = std::process::Command::new("where")
            .arg("claude")
            .output()
        {
            if output.status.success() {
                let path = String::from_utf8(output.stdout).ok()?;
                return Some(path.trim().to_string());
            }
        }
        None
    }

    fn check_running(&self) -> bool {
        // Claude Code runs as a service/daemon, typically always available if installed
        self.installed
    }
}

impl Provider for ClaudeCodeProvider {
    fn id(&self) -> &str {
        "claude_code"
    }

    fn name(&self) -> &str {
        "Claude Code CLI"
    }

    fn detect(&self) -> bool {
        Self::detect_claude()
    }

    fn get_status(&self) -> ProviderStatus {
        ProviderStatus {
            id: self.id().to_string(),
            name: self.name().to_string(),
            installed: self.installed,
            running: self.check_running(),
            capabilities: vec![
                "detect".to_string(),
                "execute_tasks".to_string(),
                "list_sessions".to_string(),
            ],
        }
    }
}
