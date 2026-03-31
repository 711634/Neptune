// Claude Desktop adapter for Windows
// Detects Claude Desktop installation, supports launching

use super::Provider;
use crate::models::ProviderStatus;
use std::path::Path;

pub struct ClaudeDesktopProvider {
    installed: bool,
}

impl ClaudeDesktopProvider {
    pub fn new() -> Self {
        let installed = Self::detect_claude_desktop();
        Self { installed }
    }

    fn detect_claude_desktop() -> bool {
        // Check common installation paths on Windows
        let common_paths = [
            "C:\\Users\\{user}\\AppData\\Local\\Claude\\Claude.exe",
            "C:\\Program Files\\Claude\\Claude.exe",
            "C:\\Program Files (x86)\\Claude\\Claude.exe",
        ];

        // Expand {user} placeholder
        if let Ok(username) = std::env::var("USERNAME") {
            for path_template in &common_paths {
                let path_str = path_template.replace("{user}", &username);
                if Path::new(&path_str).exists() {
                    return true;
                }
            }
        }

        false
    }

    fn check_running(&self) -> bool {
        if let Ok(output) = std::process::Command::new("tasklist")
            .output()
        {
            if let Ok(tasklist) = String::from_utf8(output.stdout) {
                return tasklist.contains("Claude.exe") || tasklist.contains("claude.exe");
            }
        }
        false
    }
}

impl Provider for ClaudeDesktopProvider {
    fn id(&self) -> &str {
        "claude_desktop"
    }

    fn name(&self) -> &str {
        "Claude Desktop"
    }

    fn detect(&self) -> bool {
        Self::detect_claude_desktop()
    }

    fn get_status(&self) -> ProviderStatus {
        ProviderStatus {
            id: self.id().to_string(),
            name: self.name().to_string(),
            installed: self.installed,
            running: self.check_running(),
            capabilities: vec![
                "detect".to_string(),
                "launch".to_string(),
                "focus".to_string(),
            ],
        }
    }
}
