// Neptune Windows MVP - Tauri Backend
// Local autonomous agent orchestration for Windows

#![cfg_attr(
    all(not(debug_assertions), target_os = "windows"),
    windows_subsystem = "windows"
)]

mod commands;
mod models;
mod providers;
mod state;
mod integrations;

use tauri::Manager;
use std::sync::Arc;

fn main() {
    tauri::Builder::default()
        .setup(|app| {
            // Initialize state manager
            let state = state::NeptuneState::new()?;
            app.manage(state);

            // Initialize provider adapters
            let providers = providers::init_providers();
            app.manage(providers);

            // Initialize session store for streaming output
            let session_store = commands::SessionStore::new();
            app.manage(session_store);

            Ok(())
        })
        // Register IPC commands
        .invoke_handler(tauri::generate_handler![
            // Project & Agent management
            commands::cmd_create_project,
            commands::cmd_list_projects,
            commands::cmd_get_project,
            commands::cmd_delete_project,
            commands::cmd_update_project,
            commands::cmd_create_agent,
            commands::cmd_get_agent,
            commands::cmd_update_agent_status,
            commands::cmd_append_agent_output,
            // Provider detection
            commands::cmd_detect_providers,
            commands::cmd_get_provider_status,
            // Settings
            commands::cmd_load_settings,
            commands::cmd_save_settings,
            // Real execution commands
            commands::cmd_launch_claude_code,
            commands::cmd_execute_claude_command,
            commands::cmd_list_claude_sessions,
            commands::cmd_open_in_vscode,
            commands::cmd_create_vscode_workspace,
            commands::cmd_check_vscode_setup,
            commands::cmd_launch_claude_desktop,
            commands::cmd_focus_claude_desktop,
            commands::cmd_open_project_claude_desktop,
            commands::cmd_get_claude_desktop_info,
            commands::cmd_check_codex_availability,
            commands::cmd_list_codex_models,
            commands::cmd_get_claude_status,
            commands::cmd_check_claude_code_available,
            commands::cmd_check_vscode_available,
            commands::cmd_check_claude_desktop_available,
            // Session streaming and output management
            commands::cmd_list_active_sessions,
            commands::cmd_get_session_output,
            commands::cmd_get_session_status,
            commands::cmd_stop_session,
            commands::cmd_clear_session_output,
        ])
        .plugin(tauri_plugin_shell::init())
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
