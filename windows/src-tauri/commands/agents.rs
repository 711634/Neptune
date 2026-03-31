// Agent management commands
use crate::models::{Agent, AgentRole, AgentStatus};
use crate::state::NeptuneState;
use anyhow::Result;
use tauri::State;

#[tauri::command]
pub fn cmd_create_agent(
    project_id: String,
    name: String,
    role: String,
    state: State<NeptuneState>,
) -> Result<Agent, String> {
    // Parse role from string to AgentRole enum
    let agent_role = match role.as_str() {
        "planning" => AgentRole::Planning,
        "research" => AgentRole::Research,
        "coding" => AgentRole::Coding,
        "review" => AgentRole::Review,
        "shipping" => AgentRole::Shipping,
        _ => AgentRole::Coding,
    };

    let agent = Agent {
        id: NeptuneState::generate_project_id(),
        name,
        role: agent_role,
        status: AgentStatus::Idle,
        created_at: chrono::Utc::now(),
        updated_at: chrono::Utc::now(),
        assigned_tasks: vec![],
        completed_tasks: vec![],
        current_output: String::new(),
    };

    state
        .save_agent(&project_id, &agent)
        .map_err(|e| e.to_string())?;

    Ok(agent)
}

#[tauri::command]
pub fn cmd_get_agent(
    project_id: String,
    agent_id: String,
    state: State<NeptuneState>,
) -> Result<Agent, String> {
    state
        .load_agent(&project_id, &agent_id)
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub fn cmd_update_agent_status(
    project_id: String,
    agent_id: String,
    status: String,
    state: State<NeptuneState>,
) -> Result<Agent, String> {
    let mut agent = state
        .load_agent(&project_id, &agent_id)
        .map_err(|e| e.to_string())?;

    // Parse status from string to AgentStatus enum
    agent.status = match status.as_str() {
        "idle" => AgentStatus::Idle,
        "waking" => AgentStatus::Waking,
        "thinking" => AgentStatus::Thinking,
        "planning" => AgentStatus::Planning,
        "researching" => AgentStatus::Researching,
        "coding" => AgentStatus::Coding,
        "reviewing" => AgentStatus::Reviewing,
        "shipping" => AgentStatus::Shipping,
        "success" => AgentStatus::Success,
        "failed" => AgentStatus::Failed,
        "blocked" => AgentStatus::Blocked,
        "sleeping" => AgentStatus::Sleeping,
        _ => AgentStatus::Idle,
    };

    agent.updated_at = chrono::Utc::now();

    state
        .save_agent(&project_id, &agent)
        .map_err(|e| e.to_string())?;

    Ok(agent)
}

#[tauri::command]
pub fn cmd_append_agent_output(
    project_id: String,
    agent_id: String,
    lines: Vec<String>,
    state: State<NeptuneState>,
) -> Result<(), String> {
    state
        .append_transcript(&project_id, &agent_id, &lines)
        .map_err(|e| e.to_string())
}
