// Settings management commands
use crate::models::AppSettings;
use crate::state::NeptuneState;
use serde_json::json;
use tauri::State;

#[tauri::command]
pub fn cmd_load_settings(state: State<NeptuneState>) -> Result<AppSettings, String> {
    state
        .load_settings()
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub fn cmd_save_settings(
    settings: AppSettings,
    state: State<NeptuneState>,
) -> Result<(), String> {
    state
        .save_settings(&settings)
        .map_err(|e| e.to_string())
}
