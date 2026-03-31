// VS Code adapter for Windows
// Detects VS Code installation, supports workspace linking

use super::Provider;
use crate::models::ProviderStatus;
use std::path::Path;
use winreg::RegKey;

pub struct VSCodeProvider {
    installed: bool,
    path: Option<String>,
}

impl VSCodeProvider {
    pub fn new() -> Self {
        let (installed, path) = Self::detect_vscode();
        Self { installed, path }
    }

    fn detect_vscode() -> (bool, Option<String>) {
        // Try registry first (Windows)
        if let Ok(hklm) = RegKey::predef(winreg::enums::HKEY_LOCAL_MACHINE).open_subkey(
            "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\Code.exe",
        ) {
            if let Ok(path) = hklm.get_value::<String, _>("") {
                return (true, Some(path));
            }
        }

        // Try common installation paths
        let common_paths = [
            "C:\\Program Files\\Microsoft VS Code\\Code.exe",
            "C:\\Program Files (x86)\\Microsoft VS Code\\Code.exe",
            "C:\\Program Files\\Microsoft VS Code Insiders\\Code Insiders.exe",
        ];

        for path_str in &common_paths {
            if Path::new(path_str).exists() {
                return (true, Some(path_str.to_string()));
            }
        }

        (false, None)
    }

    fn check_running(&self) -> bool {
        // Check if Code.exe is in running processes
        if let Ok(output) = std::process::Command::new("tasklist")
            .output()
        {
            if let Ok(tasklist) = String::from_utf8(output.stdout) {
                return tasklist.contains("Code.exe") || tasklist.contains("code.exe");
            }
        }
        false
    }
}

impl Provider for VSCodeProvider {
    fn id(&self) -> &str {
        "vscode"
    }

    fn name(&self) -> &str {
        "VS Code + Claude"
    }

    fn detect(&self) -> bool {
        Self::detect_vscode().0
    }

    fn get_status(&self) -> ProviderStatus {
        ProviderStatus {
            id: self.id().to_string(),
            name: self.name().to_string(),
            installed: self.installed,
            running: self.check_running(),
            capabilities: vec![
                "detect".to_string(),
                "open_workspace".to_string(),
                "link_project".to_string(),
            ],
        }
    }
}
