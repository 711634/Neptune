// Real Claude Desktop integration for Windows
// Detects and launches Claude Desktop

use anyhow::{Context, Result};
use std::process::Command;
use std::path::PathBuf;

pub struct ClaudeDesktopIntegration;

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ClaudeDesktopInfo {
    pub installed: bool,
    pub path: Option<String>,
    pub running: bool,
    pub version: Option<String>,
}

impl ClaudeDesktopIntegration {
    /// Find Claude Desktop installation
    pub fn find_claude_desktop_path() -> Result<String> {
        let username = std::env::var("USERNAME")
            .context("Failed to get Windows username")?;

        // Check common installation paths
        let paths = vec![
            format!("C:\\Users\\{}\\AppData\\Local\\Claude\\Claude.exe", username),
            "C:\\Program Files\\Claude\\Claude.exe".to_string(),
            "C:\\Program Files (x86)\\Claude\\Claude.exe".to_string(),
        ];

        for path in paths {
            if PathBuf::from(&path).exists() {
                return Ok(path);
            }
        }

        anyhow::bail!("Claude Desktop not found in common locations")
    }

    /// Check if Claude Desktop is installed
    pub fn is_installed() -> bool {
        Self::find_claude_desktop_path().is_ok()
    }

    /// Check if Claude Desktop is currently running
    pub fn is_running() -> bool {
        if let Ok(output) = Command::new("tasklist")
            .output()
        {
            if let Ok(tasklist) = String::from_utf8(output.stdout) {
                return tasklist.contains("Claude.exe") || tasklist.contains("claude.exe");
            }
        }
        false
    }

    /// Launch Claude Desktop
    pub fn launch() -> Result<()> {
        let path = Self::find_claude_desktop_path()?;

        Command::new(&path)
            .spawn()
            .context("Failed to launch Claude Desktop")?;

        Ok(())
    }

    /// Focus Claude Desktop if running
    pub fn focus() -> Result<()> {
        // Use PowerShell to activate window (non-privileged)
        let script = r#"
            $window = (Get-Process claude -ErrorAction SilentlyContinue | Select-Object -First 1)
            if ($null -ne $window) {
                Add-Type @"
                    using System;
                    using System.Runtime.InteropServices;
                    public class Window {
                        [DllImport("user32.dll")]
                        public static extern bool SetForegroundWindow(IntPtr hWnd);
                        [DllImport("user32.dll")]
                        public static extern bool IsIconic(IntPtr hWnd);
                        [DllImport("user32.dll")]
                        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
                    }
"@
                [Window]::SetForegroundWindow($window.MainWindowHandle)
                if ([Window]::IsIconic($window.MainWindowHandle)) {
                    [Window]::ShowWindow($window.MainWindowHandle, 9)
                }
            }
        "#;

        Command::new("powershell")
            .arg("-NoProfile")
            .arg("-Command")
            .arg(script)
            .spawn()?;

        Ok(())
    }

    /// Get Claude Desktop information
    pub fn get_info() -> ClaudeDesktopInfo {
        let path = Self::find_claude_desktop_path().ok();
        let running = Self::is_running();

        ClaudeDesktopInfo {
            installed: path.is_some(),
            path,
            running,
            version: None, // Version detection requires registry parsing
        }
    }

    /// Open a project with Claude Desktop
    pub fn open_project(project_path: &str) -> Result<()> {
        // Launch Claude Desktop and pass project path via command line
        let path = Self::find_claude_desktop_path()?;

        Command::new(&path)
            .arg("--open")
            .arg(project_path)
            .spawn()
            .context("Failed to open project in Claude Desktop")?;

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_claude_desktop_detection() {
        let info = ClaudeDesktopIntegration::get_info();
        println!("Claude Desktop info: {:?}", info);
    }
}
