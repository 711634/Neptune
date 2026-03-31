// Codex integration for Windows
// Detects Codex/Claude models availability for local workflows

use anyhow::{Context, Result};
use std::process::Command;

pub struct CodexIntegration;

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct CodexSession {
    pub id: String,
    pub model: String,
    pub available: bool,
    pub status: String,
}

impl CodexIntegration {
    /// Detect if Codex/Claude models are available
    /// This checks if Claude Code CLI can access the Claude API
    pub fn is_available() -> bool {
        // Try to get Claude status via CLI
        if let Ok(output) = Command::new("claude")
            .arg("--version")
            .output()
        {
            return output.status.success();
        }
        false
    }

    /// Check model availability
    pub fn check_models() -> Result<Vec<String>> {
        let output = Command::new("claude")
            .arg("models")
            .arg("list")
            .output()
            .context("Failed to list available models")?;

        if !output.status.success() {
            anyhow::bail!("Failed to check available models");
        }

        let stdout = String::from_utf8(output.stdout)?;
        let models: Vec<String> = stdout
            .lines()
            .filter(|line| !line.is_empty() && !line.starts_with('#'))
            .map(|line| line.trim().to_string())
            .collect();

        Ok(models)
    }

    /// Create a Codex/Claude session for local execution
    pub fn create_session(model: &str, project_path: &str) -> Result<CodexSession> {
        use uuid::Uuid;

        // Verify model is available
        let models = Self::check_models()?;
        if !models.iter().any(|m| m.contains(model)) {
            anyhow::bail!("Model {} not available", model);
        }

        Ok(CodexSession {
            id: Uuid::new_v4().to_string(),
            model: model.to_string(),
            available: true,
            status: "Idle".to_string(),
        })
    }

    /// Execute code through Codex
    pub fn execute_code(model: &str, code: &str, project_path: &str) -> Result<String> {
        let output = Command::new("claude")
            .arg("exec")
            .arg("--model")
            .arg(model)
            .arg("--project")
            .arg(project_path)
            .arg(code)
            .output()
            .context("Failed to execute code through Codex")?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            anyhow::bail!("Codex execution failed: {}", stderr);
        }

        let result = String::from_utf8(output.stdout)?;
        Ok(result)
    }

    /// Get Codex/Claude status
    pub fn get_status() -> Result<String> {
        let output = Command::new("claude")
            .arg("status")
            .output()
            .context("Failed to get Claude status")?;

        if !output.status.success() {
            anyhow::bail!("Claude not available");
        }

        let status = String::from_utf8(output.stdout)?;
        Ok(status)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_codex_availability() {
        let available = CodexIntegration::is_available();
        println!("Codex available: {}", available);
    }
}
