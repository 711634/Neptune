// Provider detection and status commands
use crate::providers::ProviderRegistry;
use crate::models::ProviderStatus;
use tauri::State;

#[tauri::command]
pub fn cmd_detect_providers(registry: State<ProviderRegistry>) -> Vec<ProviderStatus> {
    registry
        .providers
        .iter()
        .map(|p| p.get_status())
        .collect()
}

#[tauri::command]
pub fn cmd_get_provider_status(
    provider_id: String,
    registry: State<ProviderRegistry>,
) -> Result<ProviderStatus, String> {
    registry
        .providers
        .iter()
        .find(|p| p.id() == provider_id)
        .map(|p| p.get_status())
        .ok_or_else(|| format!("Provider {} not found", provider_id))
}
