// Data models shared between frontend and backend
// Parallel to macOS Swift models, serializable to JSON

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use chrono::{DateTime, Utc};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProjectContext {
    pub id: String,
    pub name: String,
    pub description: String,
    pub goal: String,
    pub project_type: ProjectType,
    pub workspace_dir: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,

    pub agents: HashMap<String, Agent>,
    pub task_graph: TaskGraph,
    pub skill_packs: Vec<String>,
    pub transcripts: HashMap<String, Vec<String>>,

    pub is_running: bool,
    pub completed_at: Option<DateTime<Utc>>,
    pub build_artifacts: Vec<String>,
    pub current_status: ProjectStatus,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ProjectType {
    WebApp,
    PythonCLI,
    iOSApp,
    MacOSApp,
    ChromeExtension,
    DataAnalysis,
    RustLib,
    Unknown,
}

impl ProjectType {
    pub fn display_name(&self) -> &str {
        match self {
            ProjectType::WebApp => "Web App (React/Next.js)",
            ProjectType::PythonCLI => "Python CLI",
            ProjectType::iOSApp => "iOS App",
            ProjectType::MacOSApp => "macOS App",
            ProjectType::ChromeExtension => "Chrome Extension",
            ProjectType::DataAnalysis => "Data Analysis Tool",
            ProjectType::RustLib => "Rust Library",
            ProjectType::Unknown => "Unknown",
        }
    }

    pub fn detect(workspace_dir: &str) -> Self {
        // Check for characteristic files
        let paths = [
            ("package.json", ProjectType::WebApp),
            ("tsconfig.json", ProjectType::WebApp),
            ("requirements.txt", ProjectType::PythonCLI),
            ("pyproject.toml", ProjectType::PythonCLI),
            ("Cargo.toml", ProjectType::RustLib),
            ("manifest.json", ProjectType::ChromeExtension),
        ];

        for (file, proj_type) in &paths {
            let path = std::path::Path::new(workspace_dir).join(file);
            if path.exists() {
                return proj_type.clone();
            }
        }

        ProjectType::Unknown
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ProjectStatus {
    Created,
    Initializing,
    Planning,
    InProgress,
    Paused,
    Completed,
    Failed,
    Archived,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Agent {
    pub id: String,
    pub name: String,
    pub role: AgentRole,
    pub status: AgentStatus,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub assigned_tasks: Vec<String>,
    pub completed_tasks: Vec<String>,
    pub current_output: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Copy)]
#[serde(rename_all = "snake_case")]
pub enum AgentRole {
    Planning,
    Research,
    Coding,
    Review,
    Shipping,
}

impl AgentRole {
    pub fn display_name(&self) -> &str {
        match self {
            AgentRole::Planning => "PLANNING",
            AgentRole::Research => "RESEARCH",
            AgentRole::Coding => "CODING",
            AgentRole::Review => "REVIEW",
            AgentRole::Shipping => "SHIPPING",
        }
    }

    pub fn emoji(&self) -> &str {
        match self {
            AgentRole::Planning => "🧠",
            AgentRole::Research => "🔍",
            AgentRole::Coding => "💻",
            AgentRole::Review => "👀",
            AgentRole::Shipping => "🚀",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, Copy)]
#[serde(rename_all = "snake_case")]
pub enum AgentStatus {
    Idle,
    Waking,
    Thinking,
    Planning,
    Researching,
    Coding,
    Reviewing,
    Shipping,
    Success,
    Failed,
    Blocked,
    Sleeping,
}

impl AgentStatus {
    pub fn color(&self) -> &str {
        match self {
            AgentStatus::Idle => "#6B7280",
            AgentStatus::Waking => "#F59E0B",
            AgentStatus::Thinking => "#F59E0B",
            AgentStatus::Planning => "#8B5CF6",
            AgentStatus::Researching => "#3B82F6",
            AgentStatus::Coding => "#10B981",
            AgentStatus::Reviewing => "#F59E0B",
            AgentStatus::Shipping => "#EC4899",
            AgentStatus::Success => "#10B981",
            AgentStatus::Failed => "#EF4444",
            AgentStatus::Blocked => "#8B5CF6",
            AgentStatus::Sleeping => "#3B82F6",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskGraph {
    pub tasks: HashMap<String, Task>,
    pub dependencies: HashMap<String, Vec<String>>, // task_id -> [dependent_ids]
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Task {
    pub id: String,
    pub name: String,
    pub description: String,
    pub assigned_agent: Option<String>,
    pub status: TaskStatus,
    pub created_at: DateTime<Utc>,
    pub completed_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Copy)]
#[serde(rename_all = "snake_case")]
pub enum TaskStatus {
    Pending,
    Ready,
    InProgress,
    Completed,
    Failed,
    Blocked,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Skill {
    pub id: String,
    pub name: String,
    pub role: AgentRole,
    pub prompt: String,
    pub examples: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppSettings {
    pub claude_path: String,
    pub workspace_dir: String,
    pub low_power_mode: bool,
    pub aggressive_efficiency: bool,
    pub launch_at_startup: bool,
    pub max_concurrent_agents: u32,
    pub preferred_provider: String,
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            claude_path: "claude".to_string(),
            workspace_dir: std::env::var("USERPROFILE")
                .unwrap_or_else(|_| "C:\\Users\\User".to_string()),
            low_power_mode: false,
            aggressive_efficiency: false,
            launch_at_startup: false,
            max_concurrent_agents: 3,
            preferred_provider: "claude_code".to_string(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProviderStatus {
    pub id: String,
    pub name: String,
    pub installed: bool,
    pub running: bool,
    pub capabilities: Vec<String>,
}
