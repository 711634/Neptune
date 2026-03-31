// Real Claude Code CLI integration for Windows
// Executes `claude` commands and streams output

use anyhow::{Context, Result};
use std::process::{Command, Stdio};
use std::io::{BufRead, BufReader};
use std::path::PathBuf;
use uuid::Uuid;

pub struct ClaudeCodeIntegration;

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ClaudeCodeSession {
    pub id: String,
    pub status: String,
    pub output: Vec<String>,
    pub pid: Option<u32>,
    pub project_path: Option<String>,
}

impl ClaudeCodeIntegration {
    /// Find Claude executable in PATH
    pub fn find_claude_path() -> Result<String> {
        let output = Command::new("where")
            .arg("claude")
            .output()
            .context("Failed to locate claude executable")?;

        if !output.status.success() {
            anyhow::bail!("Claude CLI not found in PATH");
        }

        let path = String::from_utf8(output.stdout)?
            .trim()
            .to_string();

        Ok(path)
    }

    /// Check if Claude is available
    pub fn is_available() -> bool {
        Command::new("where")
            .arg("claude")
            .output()
            .map(|output| output.status.success())
            .unwrap_or(false)
    }

    /// Launch Claude Code session for a project
    pub fn launch_session(project_path: &str) -> Result<ClaudeCodeSession> {
        let claude_path = Self::find_claude_path()?;

        let mut cmd = Command::new(&claude_path);
        cmd.current_dir(project_path)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());

        let mut child = cmd.spawn()
            .context("Failed to spawn claude process")?;

        let pid = child.id();
        let session = ClaudeCodeSession {
            id: Uuid::new_v4().to_string(),
            status: "Running".to_string(),
            output: vec![],
            pid: Some(pid),
            project_path: Some(project_path.to_string()),
        };

        // Start output reading in background
        if let Some(stdout) = child.stdout.take() {
            let session_id = session.id.clone();
            std::thread::spawn(move || {
                let reader = BufReader::new(stdout);
                for line in reader.lines() {
                    if let Ok(line) = line {
                        // In real implementation, emit event to frontend
                        eprintln!("[claude:{}] {}", session_id, line);
                    }
                }
            });
        }

        Ok(session)
    }

    /// Execute a command with Claude
    pub fn execute_command(project_path: &str, command: &str) -> Result<Vec<String>> {
        let claude_path = Self::find_claude_path()?;

        let output = Command::new(&claude_path)
            .current_dir(project_path)
            .args(&[command])
            .output()
            .context("Failed to execute claude command")?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            anyhow::bail!("Claude command failed: {}", stderr);
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        let lines: Vec<String> = stdout
            .lines()
            .map(|l| l.to_string())
            .collect();

        Ok(lines)
    }

    /// Get list of Claude sessions
    pub fn list_sessions() -> Result<Vec<String>> {
        let output = Self::execute_command(".", "session list")?;
        Ok(output)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_claude_detection() {
        let is_available = ClaudeCodeIntegration::is_available();
        println!("Claude Code available: {}", is_available);
    }
}
