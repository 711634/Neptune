// State management for Neptune on Windows
// File-based persistence in C:\Users\{user}\AppData\Local\Neptune\

use crate::models::*;
use anyhow::{Result, Context};
use serde_json;
use std::fs;
use std::path::{Path, PathBuf};
use uuid::Uuid;
use chrono::Utc;

pub struct NeptuneState {
    pub base_dir: PathBuf,
    pub projects_dir: PathBuf,
    pub skills_dir: PathBuf,
    pub logs_dir: PathBuf,
}

impl NeptuneState {
    pub fn new() -> Result<Self> {
        let base_dir = Self::get_base_dir();
        let projects_dir = base_dir.join("projects");
        let skills_dir = base_dir.join("skills");
        let logs_dir = base_dir.join("logs");

        // Create directories if they don't exist
        fs::create_dir_all(&projects_dir)?;
        fs::create_dir_all(&skills_dir)?;
        fs::create_dir_all(&logs_dir)?;

        Ok(Self {
            base_dir,
            projects_dir,
            skills_dir,
            logs_dir,
        })
    }

    /// Get the Neptune base directory
    /// On Windows: C:\Users\{username}\AppData\Local\Neptune\
    fn get_base_dir() -> PathBuf {
        if let Ok(local_appdata) = std::env::var("LOCALAPPDATA") {
            Path::new(&local_appdata).join("Neptune")
        } else {
            // Fallback if LOCALAPPDATA not available
            let home = std::env::var("USERPROFILE").unwrap_or_else(|_| "C:\\Users\\User".to_string());
            Path::new(&home).join("AppData\\Local\\Neptune")
        }
    }

    // MARK: - Project Persistence

    pub fn save_project(&self, project: &ProjectContext) -> Result<()> {
        let project_dir = self.projects_dir.join(&project.id);
        fs::create_dir_all(&project_dir)?;

        let project_file = project_dir.join("project.json");
        let json = serde_json::to_string_pretty(project)?;
        fs::write(project_file, json)?;

        Ok(())
    }

    pub fn load_project(&self, id: &str) -> Result<ProjectContext> {
        let project_file = self.projects_dir.join(id).join("project.json");
        let contents = fs::read_to_string(project_file)
            .context("Failed to read project file")?;
        let project = serde_json::from_str(&contents)
            .context("Failed to parse project JSON")?;
        Ok(project)
    }

    pub fn list_projects(&self) -> Result<Vec<ProjectContext>> {
        let mut projects = Vec::new();

        if !self.projects_dir.exists() {
            return Ok(projects);
        }

        for entry in fs::read_dir(&self.projects_dir)? {
            let entry = entry?;
            let path = entry.path();

            if path.is_dir() {
                if let Ok(project) = self.load_project(path.file_name().unwrap().to_str().unwrap()) {
                    projects.push(project);
                }
            }
        }

        // Sort by created_at descending
        projects.sort_by(|a, b| b.created_at.cmp(&a.created_at));
        Ok(projects)
    }

    pub fn delete_project(&self, id: &str) -> Result<()> {
        let project_dir = self.projects_dir.join(id);
        if project_dir.exists() {
            fs::remove_dir_all(project_dir)?;
        }
        Ok(())
    }

    // MARK: - Agent State

    pub fn save_agent(&self, project_id: &str, agent: &Agent) -> Result<()> {
        let agent_dir = self.projects_dir
            .join(project_id)
            .join("agents")
            .join(&agent.id);

        fs::create_dir_all(&agent_dir)?;

        let state_file = agent_dir.join("state.json");
        let json = serde_json::to_string_pretty(agent)?;
        fs::write(state_file, json)?;

        Ok(())
    }

    pub fn load_agent(&self, project_id: &str, agent_id: &str) -> Result<Agent> {
        let state_file = self.projects_dir
            .join(project_id)
            .join("agents")
            .join(agent_id)
            .join("state.json");

        let contents = fs::read_to_string(state_file)?;
        let agent = serde_json::from_str(&contents)?;
        Ok(agent)
    }

    pub fn append_transcript(&self, project_id: &str, agent_id: &str, lines: &[String]) -> Result<()> {
        let transcript_file = self.projects_dir
            .join(project_id)
            .join("agents")
            .join(agent_id)
            .join("transcript.log");

        fs::create_dir_all(transcript_file.parent().unwrap())?;

        let mut content = String::new();
        if transcript_file.exists() {
            content = fs::read_to_string(&transcript_file)?;
        }

        for line in lines {
            content.push_str(line);
            content.push('\n');
        }

        fs::write(transcript_file, content)?;
        Ok(())
    }

    // MARK: - Settings

    pub fn save_settings(&self, settings: &AppSettings) -> Result<()> {
        let settings_file = self.base_dir.join("settings.json");
        let json = serde_json::to_string_pretty(settings)?;
        fs::write(settings_file, json)?;
        Ok(())
    }

    pub fn load_settings(&self) -> Result<AppSettings> {
        let settings_file = self.base_dir.join("settings.json");

        if settings_file.exists() {
            let contents = fs::read_to_string(settings_file)?;
            let settings = serde_json::from_str(&contents)?;
            Ok(settings)
        } else {
            Ok(AppSettings::default())
        }
    }

    // MARK: - Utilities

    pub fn generate_project_id() -> String {
        Uuid::new_v4().to_string()
    }

    pub fn get_logs_dir(&self) -> &Path {
        &self.logs_dir
    }

    pub fn get_base_dir_path(&self) -> &Path {
        &self.base_dir
    }
}
