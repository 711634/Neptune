// Real VS Code integration for Windows
// Opens projects, manages workspace links, detects Claude extension

use anyhow::{Context, Result};
use std::process::Command;
use winreg::RegKey;
use std::path::PathBuf;

pub struct VSCodeIntegration;

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct VSCodeWorkspace {
    pub folder: String,
    pub has_claude_extension: bool,
    pub has_workspace_file: bool,
}

impl VSCodeIntegration {
    /// Find VS Code installation
    pub fn find_vscode_path() -> Result<String> {
        // Try registry first
        let hklm = RegKey::predef(winreg::enums::HKEY_LOCAL_MACHINE);
        if let Ok(key) = hklm.open_subkey(
            "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\Code.exe",
        ) {
            if let Ok(path) = key.get_value::<String, &str>("") {
                return Ok(path);
            }
        }

        // Try common paths
        let common_paths = vec![
            "C:\\Program Files\\Microsoft VS Code\\Code.exe",
            "C:\\Program Files (x86)\\Microsoft VS Code\\Code.exe",
            "C:\\Program Files\\Microsoft VS Code Insiders\\Code Insiders.exe",
        ];

        for path in common_paths {
            if PathBuf::from(path).exists() {
                return Ok(path.to_string());
            }
        }

        anyhow::bail!("VS Code not found")
    }

    /// Check if VS Code is installed
    pub fn is_available() -> bool {
        Self::find_vscode_path().is_ok()
    }

    /// Open a project folder in VS Code
    pub fn open_project(project_path: &str) -> Result<()> {
        let code_path = Self::find_vscode_path()?;

        Command::new(&code_path)
            .arg(project_path)
            .spawn()
            .context("Failed to launch VS Code")?;

        Ok(())
    }

    /// Check if Claude extension is installed
    pub fn has_claude_extension(vscode_extensions_dir: &str) -> bool {
        let extensions_path = PathBuf::from(vscode_extensions_dir);
        if !extensions_path.exists() {
            return false;
        }

        // Look for any Claude-related extension folder
        if let Ok(entries) = std::fs::read_dir(&extensions_path) {
            for entry in entries.flatten() {
                if let Some(name) = entry.file_name().to_str() {
                    if name.contains("claude") || name.contains("anthropic") {
                        return true;
                    }
                }
            }
        }

        false
    }

    /// Link Neptune project as VS Code workspace
    pub fn create_workspace_link(project_path: &str, project_name: &str) -> Result<String> {
        let workspace_path = PathBuf::from(project_path)
            .join(format!("{}.code-workspace", project_name));

        let workspace_config = serde_json::json!({
            "folders": [
                {
                    "path": ".",
                }
            ],
            "settings": {
                "editor.formatOnSave": true,
                "editor.defaultFormatter": "esbenp.prettier-vscode",
                "[python]": {
                    "editor.defaultFormatter": "ms-python.python",
                    "editor.formatOnSave": true
                }
            },
            "extensions": {
                "recommendations": [
                    "anthropic.claude",
                ]
            }
        });

        let config_text = serde_json::to_string_pretty(&workspace_config)?;
        std::fs::write(&workspace_path, config_text)?;

        Ok(workspace_path.to_string_lossy().to_string())
    }

    /// Verify workspace is properly set up
    pub fn verify_workspace(project_path: &str) -> Result<VSCodeWorkspace> {
        let extensions_dir = std::env::var("USERPROFILE")
            .map(|home| format!("{}\\.vscode\\extensions", home))
            .unwrap_or_default();

        let has_workspace = PathBuf::from(project_path)
            .read_dir()
            .ok()
            .and_then(|mut entries| {
                entries.find(|entry| {
                    entry
                        .as_ref()
                        .ok()
                        .and_then(|e| e.file_name().into_string().ok())
                        .map(|name| name.ends_with(".code-workspace"))
                        .unwrap_or(false)
                })
            })
            .is_some();

        Ok(VSCodeWorkspace {
            folder: project_path.to_string(),
            has_claude_extension: Self::has_claude_extension(&extensions_dir),
            has_workspace_file: has_workspace,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_vscode_detection() {
        let is_available = VSCodeIntegration::is_available();
        println!("VS Code available: {}", is_available);
    }
}
