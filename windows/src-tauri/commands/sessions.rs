// Session management commands - real-time output streaming
use crate::integrations::streaming::StreamingSession;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use tauri::State;

// Global session store
pub struct SessionStore {
    sessions: Arc<Mutex<HashMap<String, StreamingSession>>>,
}

impl SessionStore {
    pub fn new() -> Self {
        SessionStore {
            sessions: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    pub fn add_session(&self, session: StreamingSession) {
        if let Ok(mut sessions) = self.sessions.lock() {
            sessions.insert(session.id.clone(), session);
        }
    }

    pub fn get_session(&self, id: &str) -> Option<StreamingSession> {
        self.sessions.lock()
            .ok()
            .and_then(|sessions| sessions.get(id).cloned())
    }

    pub fn list_sessions(&self) -> Vec<StreamingSession> {
        self.sessions.lock()
            .map(|sessions| sessions.values().cloned().collect())
            .unwrap_or_default()
    }

    pub fn remove_session(&self, id: &str) {
        if let Ok(mut sessions) = self.sessions.lock() {
            sessions.remove(id);
        }
    }
}

impl Clone for SessionStore {
    fn clone(&self) -> Self {
        SessionStore {
            sessions: Arc::clone(&self.sessions),
        }
    }
}

/// Get output from an active session
#[tauri::command]
pub fn cmd_get_session_output(
    session_id: String,
    store: State<SessionStore>,
) -> Result<Vec<String>, String> {
    match store.get_session(&session_id) {
        Some(session) => {
            let output = session.output.lock()
                .map(|o| o.clone())
                .unwrap_or_default();
            Ok(output)
        }
        None => Err(format!("Session {} not found", session_id)),
    }
}

/// Get session status
#[tauri::command]
pub fn cmd_get_session_status(
    session_id: String,
    store: State<SessionStore>,
) -> Result<String, String> {
    match store.get_session(&session_id) {
        Some(session) => Ok(session.status),
        None => Err(format!("Session {} not found", session_id)),
    }
}

/// List all active sessions
#[tauri::command]
pub fn cmd_list_active_sessions(
    store: State<SessionStore>,
) -> Result<Vec<serde_json::Value>, String> {
    let sessions = store.list_sessions();
    Ok(sessions.iter().map(|s| {
        serde_json::json!({
            "id": s.id,
            "provider": s.provider,
            "project_id": s.project_id,
            "status": s.status,
            "pid": s.pid,
            "started_at": s.started_at,
            "output_lines": s.output.lock().map(|o| o.len()).unwrap_or(0),
        })
    }).collect())
}

/// Stop a session
#[tauri::command]
pub fn cmd_stop_session(
    session_id: String,
    store: State<SessionStore>,
) -> Result<(), String> {
    if let Some(mut session) = store.get_session(&session_id) {
        session.status = "Stopped".to_string();
        store.add_session(session);
        Ok(())
    } else {
        Err(format!("Session {} not found", session_id))
    }
}

/// Clear session output (after saving to disk)
#[tauri::command]
pub fn cmd_clear_session_output(
    session_id: String,
    store: State<SessionStore>,
) -> Result<(), String> {
    if let Some(mut session) = store.get_session(&session_id) {
        if let Ok(mut output) = session.output.lock() {
            output.clear();
        }
        Ok(())
    } else {
        Err(format!("Session {} not found", session_id))
    }
}
