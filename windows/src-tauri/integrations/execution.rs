// Execution session management
// Handles running processes, streaming output, and state

use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use uuid::Uuid;
use anyhow::Result;

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ExecutionSession {
    pub id: String,
    pub provider_id: String,
    pub project_id: String,
    pub status: ExecutionStatus,
    pub output: Vec<String>,
    pub error: Option<String>,
    pub pid: Option<u32>,
    pub started_at: String,
    pub ended_at: Option<String>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize, PartialEq)]
pub enum ExecutionStatus {
    Starting,
    Running,
    Idle,
    Success,
    Failed,
    Cancelled,
}

impl std::fmt::Display for ExecutionStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        match self {
            ExecutionStatus::Starting => write!(f, "Starting"),
            ExecutionStatus::Running => write!(f, "Running"),
            ExecutionStatus::Idle => write!(f, "Idle"),
            ExecutionStatus::Success => write!(f, "Success"),
            ExecutionStatus::Failed => write!(f, "Failed"),
            ExecutionStatus::Cancelled => write!(f, "Cancelled"),
        }
    }
}

/// Global execution session manager
pub struct ExecutionManager {
    sessions: Arc<Mutex<HashMap<String, ExecutionSession>>>,
}

impl ExecutionManager {
    pub fn new() -> Self {
        ExecutionManager {
            sessions: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    /// Create a new execution session
    pub fn create_session(
        provider_id: &str,
        project_id: &str,
    ) -> Result<ExecutionSession> {
        let session = ExecutionSession {
            id: Uuid::new_v4().to_string(),
            provider_id: provider_id.to_string(),
            project_id: project_id.to_string(),
            status: ExecutionStatus::Starting,
            output: vec![],
            error: None,
            pid: None,
            started_at: chrono::Utc::now().to_rfc3339(),
            ended_at: None,
        };

        Ok(session)
    }

    /// Update session status
    pub fn update_status(&self, session_id: &str, status: ExecutionStatus) -> Result<()> {
        let mut sessions = self.sessions.lock().unwrap();
        if let Some(session) = sessions.get_mut(session_id) {
            session.status = status;
        }
        Ok(())
    }

    /// Append output line to session
    pub fn append_output(&self, session_id: &str, line: String) -> Result<()> {
        let mut sessions = self.sessions.lock().unwrap();
        if let Some(session) = sessions.get_mut(session_id) {
            session.output.push(line);
        }
        Ok(())
    }

    /// Get session by ID
    pub fn get_session(&self, session_id: &str) -> Result<Option<ExecutionSession>> {
        let sessions = self.sessions.lock().unwrap();
        Ok(sessions.get(session_id).cloned())
    }

    /// List all sessions for a project
    pub fn list_sessions(&self, project_id: &str) -> Result<Vec<ExecutionSession>> {
        let sessions = self.sessions.lock().unwrap();
        let project_sessions: Vec<ExecutionSession> = sessions
            .values()
            .filter(|s| s.project_id == project_id)
            .cloned()
            .collect();
        Ok(project_sessions)
    }

    /// Complete a session
    pub fn complete_session(
        &self,
        session_id: &str,
        success: bool,
        error: Option<String>,
    ) -> Result<()> {
        let mut sessions = self.sessions.lock().unwrap();
        if let Some(session) = sessions.get_mut(session_id) {
            session.status = if success {
                ExecutionStatus::Success
            } else {
                ExecutionStatus::Failed
            };
            session.error = error;
            session.ended_at = Some(chrono::Utc::now().to_rfc3339());
        }
        Ok(())
    }

    /// Cancel a session
    pub fn cancel_session(&self, session_id: &str) -> Result<()> {
        let mut sessions = self.sessions.lock().unwrap();
        if let Some(session) = sessions.get_mut(session_id) {
            session.status = ExecutionStatus::Cancelled;
            session.ended_at = Some(chrono::Utc::now().to_rfc3339());
        }
        Ok(())
    }
}

impl Clone for ExecutionManager {
    fn clone(&self) -> Self {
        ExecutionManager {
            sessions: Arc::clone(&self.sessions),
        }
    }
}
