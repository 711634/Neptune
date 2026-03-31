// Project management commands
use crate::models::{ProjectContext, ProjectType, ProjectStatus, TaskGraph};
use crate::state::NeptuneState;
use anyhow::Result;
use tauri::State;
use std::collections::HashMap;

#[tauri::command]
pub fn cmd_create_project(
    name: String,
    description: String,
    project_type: String,
    state: State<NeptuneState>,
) -> Result<ProjectContext, String> {
    // Parse project type from string
    let proj_type = match project_type.as_str() {
        "web_app" => ProjectType::WebApp,
        "python_cli" => ProjectType::PythonCLI,
        "i_os_app" => ProjectType::iOSApp,
        "mac_os_app" => ProjectType::MacOSApp,
        "chrome_extension" => ProjectType::ChromeExtension,
        "data_analysis" => ProjectType::DataAnalysis,
        "rust_lib" => ProjectType::RustLib,
        _ => ProjectType::Unknown,
    };

    let project = ProjectContext {
        id: NeptuneState::generate_project_id(),
        name,
        description,
        goal: String::new(),
        project_type: proj_type,
        workspace_dir: String::new(),
        agents: HashMap::new(),
        task_graph: TaskGraph {
            tasks: HashMap::new(),
            dependencies: HashMap::new(),
        },
        skill_packs: vec![],
        transcripts: HashMap::new(),
        is_running: false,
        completed_at: None,
        build_artifacts: vec![],
        current_status: ProjectStatus::Created,
        created_at: chrono::Utc::now(),
        updated_at: chrono::Utc::now(),
    };

    state
        .save_project(&project)
        .map_err(|e| e.to_string())?;

    Ok(project)
}

#[tauri::command]
pub fn cmd_list_projects(state: State<NeptuneState>) -> Result<Vec<ProjectContext>, String> {
    state
        .list_projects()
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub fn cmd_get_project(id: String, state: State<NeptuneState>) -> Result<ProjectContext, String> {
    state
        .load_project(&id)
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub fn cmd_delete_project(id: String, state: State<NeptuneState>) -> Result<(), String> {
    state
        .delete_project(&id)
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub fn cmd_update_project(
    id: String,
    name: String,
    description: String,
    status: String,
    state: State<NeptuneState>,
) -> Result<ProjectContext, String> {
    let mut project = state
        .load_project(&id)
        .map_err(|e| e.to_string())?;

    project.name = name;
    project.description = description;

    // Parse status from string to ProjectStatus enum
    project.current_status = match status.as_str() {
        "created" => ProjectStatus::Created,
        "initializing" => ProjectStatus::Initializing,
        "planning" => ProjectStatus::Planning,
        "in_progress" => ProjectStatus::InProgress,
        "paused" => ProjectStatus::Paused,
        "completed" => ProjectStatus::Completed,
        "failed" => ProjectStatus::Failed,
        "archived" => ProjectStatus::Archived,
        _ => ProjectStatus::Created,
    };

    project.updated_at = chrono::Utc::now();

    state
        .save_project(&project)
        .map_err(|e| e.to_string())?;

    Ok(project)
}
