// Real execution commands - actually run CLIs and IDEs
#[cfg(target_os = "windows")]
use crate::integrations::{
    claude_code::ClaudeCodeIntegration,
    vscode::VSCodeIntegration,
    claude_desktop::ClaudeDesktopIntegration,
    codex::CodexIntegration,
};
use crate::integrations::ExecutionSession;
use crate::state::NeptuneState;
use tauri::State;
use anyhow::Result;

/// Launch Claude Code CLI for a project
#[tauri::command]
#[cfg(target_os = "windows")]
pub fn cmd_launch_claude_code(
    project_id: String,
    project_path: String,
    state: State<NeptuneState>,
) -> Result<String, String> {
    if !ClaudeCodeIntegration::is_available() {
        return Err("Claude Code CLI not found in PATH".to_string());
    }

    match ClaudeCodeIntegration::launch_session(&project_path) {
        Ok(session) => {
            // Save session to project state
            Ok(format!("Claude Code launched for {}: {}", project_id, session.id))
        }
        Err(e) => Err(format!("Failed to launch Claude Code: {}", e)),
    }
}

#[tauri::command]
#[cfg(not(target_os = "windows"))]
pub fn cmd_launch_claude_code(
    _project_id: String,
    _project_path: String,
    _state: State<NeptuneState>,
) -> Result<String, String> {
    Err("Neptune Windows features not available on this platform".to_string())
}

/// Execute a command with Claude Code
#[tauri::command]
#[cfg(target_os = "windows")]
pub fn cmd_execute_claude_command(
    project_path: String,
    command: String,
) -> Result<Vec<String>, String> {
    match ClaudeCodeIntegration::execute_command(&project_path, &command) {
        Ok(output) => Ok(output),
        Err(e) => Err(format!("Command execution failed: {}", e)),
    }
}

#[tauri::command]
#[cfg(not(target_os = "windows"))]
pub fn cmd_execute_claude_command(
    _project_path: String,
    _command: String,
) -> Result<Vec<String>, String> {
    Err("Neptune Windows features not available on this platform".to_string())
}

/// Get available Claude sessions
#[tauri::command]
#[cfg(target_os = "windows")]
pub fn cmd_list_claude_sessions() -> Result<Vec<String>, String> {
    match ClaudeCodeIntegration::list_sessions() {
        Ok(sessions) => Ok(sessions),
        Err(e) => Err(format!("Failed to list sessions: {}", e)),
    }
}

#[tauri::command]
#[cfg(not(target_os = "windows"))]
pub fn cmd_list_claude_sessions() -> Result<Vec<String>, String> {
    Err("Neptune Windows features not available on this platform".to_string())
}

/// Open a project in VS Code
#[tauri::command]
#[cfg(target_os = "windows")]
pub fn cmd_open_in_vscode(
    project_id: String,
    project_path: String,
) -> Result<String, String> {
    if !VSCodeIntegration::is_available() {
        return Err("VS Code not installed".to_string());
    }

    match VSCodeIntegration::open_project(&project_path) {
        Ok(_) => {
            // Create workspace link
            let _ = VSCodeIntegration::create_workspace_link(&project_path, &project_id);
            Ok(format!("Project {} opened in VS Code", project_id))
        }
        Err(e) => Err(format!("Failed to open project in VS Code: {}", e)),
    }
}

#[tauri::command]
#[cfg(not(target_os = "windows"))]
pub fn cmd_open_in_vscode(
    _project_id: String,
    _project_path: String,
) -> Result<String, String> {
    Err("Neptune Windows features not available on this platform".to_string())
}

/// Create VS Code workspace for a project
#[tauri::command]
#[cfg(target_os = "windows")]
pub fn cmd_create_vscode_workspace(
    project_id: String,
    project_path: String,
) -> Result<String, String> {
    match VSCodeIntegration::create_workspace_link(&project_path, &project_id) {
        Ok(workspace_path) => Ok(workspace_path),
        Err(e) => Err(format!("Failed to create workspace: {}", e)),
    }
}

#[tauri::command]
#[cfg(not(target_os = "windows"))]
pub fn cmd_create_vscode_workspace(
    _project_id: String,
    _project_path: String,
) -> Result<String, String> {
    Err("Neptune Windows features not available on this platform".to_string())
}

/// Check VS Code setup status
#[tauri::command]
#[cfg(target_os = "windows")]
pub fn cmd_check_vscode_setup(project_path: String) -> Result<serde_json::Value, String> {
    match VSCodeIntegration::verify_workspace(&project_path) {
        Ok(workspace) => {
            Ok(serde_json::json!({
                "folder": workspace.folder,
                "has_claude_extension": workspace.has_claude_extension,
                "has_workspace_file": workspace.has_workspace_file,
                "ready": workspace.has_workspace_file && workspace.has_claude_extension,
            }))
        }
        Err(e) => Err(format!("Failed to check workspace: {}", e)),
    }
}

#[tauri::command]
#[cfg(not(target_os = "windows"))]
pub fn cmd_check_vscode_setup(_project_path: String) -> Result<serde_json::Value, String> {
    Err("Neptune Windows features not available on this platform".to_string())
}

/// Launch Claude Desktop
#[tauri::command]
#[cfg(target_os = "windows")]
pub fn cmd_launch_claude_desktop() -> Result<String, String> {
    match ClaudeDesktopIntegration::launch() {
        Ok(_) => Ok("Claude Desktop launched".to_string()),
        Err(e) => Err(format!("Failed to launch Claude Desktop: {}", e)),
    }
}

#[tauri::command]
#[cfg(not(target_os = "windows"))]
pub fn cmd_launch_claude_desktop() -> Result<String, String> {
    Err("Neptune Windows features not available on this platform".to_string())
}

/// Focus Claude Desktop if running
#[tauri::command]
#[cfg(target_os = "windows")]
pub fn cmd_focus_claude_desktop() -> Result<String, String> {
    match ClaudeDesktopIntegration::focus() {
        Ok(_) => Ok("Claude Desktop focused".to_string()),
        Err(e) => Err(format!("Failed to focus Claude Desktop: {}", e)),
    }
}

#[tauri::command]
#[cfg(not(target_os = "windows"))]
pub fn cmd_focus_claude_desktop() -> Result<String, String> {
    Err("Neptune Windows features not available on this platform".to_string())
}

/// Open project with Claude Desktop
#[tauri::command]
#[cfg(target_os = "windows")]
pub fn cmd_open_project_claude_desktop(project_path: String) -> Result<String, String> {
    match ClaudeDesktopIntegration::open_project(&project_path) {
        Ok(_) => Ok("Project opened in Claude Desktop".to_string()),
        Err(e) => Err(format!("Failed to open project in Claude Desktop: {}", e)),
    }
}

#[tauri::command]
#[cfg(not(target_os = "windows"))]
pub fn cmd_open_project_claude_desktop(_project_path: String) -> Result<String, String> {
    Err("Neptune Windows features not available on this platform".to_string())
}

/// Get Claude Desktop info
#[tauri::command]
#[cfg(target_os = "windows")]
pub fn cmd_get_claude_desktop_info() -> Result<serde_json::Value, String> {
    let info = ClaudeDesktopIntegration::get_info();
    Ok(serde_json::to_value(info).unwrap())
}

#[tauri::command]
#[cfg(not(target_os = "windows"))]
pub fn cmd_get_claude_desktop_info() -> Result<serde_json::Value, String> {
    Err("Neptune Windows features not available on this platform".to_string())
}

/// Check Codex availability
#[tauri::command]
#[cfg(target_os = "windows")]
pub fn cmd_check_codex_availability() -> Result<bool, String> {
    Ok(CodexIntegration::is_available())
}

#[tauri::command]
#[cfg(not(target_os = "windows"))]
pub fn cmd_check_codex_availability() -> Result<bool, String> {
    Ok(false)
}

/// List available models through Codex
#[tauri::command]
#[cfg(target_os = "windows")]
pub fn cmd_list_codex_models() -> Result<Vec<String>, String> {
    match CodexIntegration::check_models() {
        Ok(models) => Ok(models),
        Err(e) => Err(format!("Failed to list models: {}", e)),
    }
}

#[tauri::command]
#[cfg(not(target_os = "windows"))]
pub fn cmd_list_codex_models() -> Result<Vec<String>, String> {
    Ok(vec![])
}

/// Get Claude/Codex status
#[tauri::command]
#[cfg(target_os = "windows")]
pub fn cmd_get_claude_status() -> Result<String, String> {
    match CodexIntegration::get_status() {
        Ok(status) => Ok(status),
        Err(e) => Err(format!("Failed to get Claude status: {}", e)),
    }
}

#[tauri::command]
#[cfg(not(target_os = "windows"))]
pub fn cmd_get_claude_status() -> Result<String, String> {
    Ok("Unknown".to_string())
}

/// Check if Claude Code is available
#[tauri::command]
#[cfg(target_os = "windows")]
pub fn cmd_check_claude_code_available() -> Result<bool, String> {
    Ok(ClaudeCodeIntegration::is_available())
}

#[tauri::command]
#[cfg(not(target_os = "windows"))]
pub fn cmd_check_claude_code_available() -> Result<bool, String> {
    Ok(false)
}

/// Check if VS Code is available
#[tauri::command]
#[cfg(target_os = "windows")]
pub fn cmd_check_vscode_available() -> Result<bool, String> {
    Ok(VSCodeIntegration::is_available())
}

#[tauri::command]
#[cfg(not(target_os = "windows"))]
pub fn cmd_check_vscode_available() -> Result<bool, String> {
    Ok(false)
}

/// Check if Claude Desktop is available
#[tauri::command]
#[cfg(target_os = "windows")]
pub fn cmd_check_claude_desktop_available() -> Result<bool, String> {
    Ok(ClaudeDesktopIntegration::is_installed())
}

#[tauri::command]
#[cfg(not(target_os = "windows"))]
pub fn cmd_check_claude_desktop_available() -> Result<bool, String> {
    Ok(false)
}
