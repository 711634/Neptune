// Real-time output streaming from CLI processes
// Sends output to frontend via Tauri events

use std::process::{Command, Stdio, Child};
use std::io::{BufRead, BufReader};
use std::sync::{Arc, Mutex};
use std::thread;
use uuid::Uuid;
use anyhow::{Context, Result};

#[derive(Debug, Clone)]
pub struct StreamingSession {
    pub id: String,
    pub provider: String,
    pub project_id: String,
    pub status: String,
    pub pid: Option<u32>,
    #[cfg_attr(feature = "serde", serde(skip))]
    pub output: Arc<Mutex<Vec<String>>>,
    pub started_at: String,
    pub error: Option<String>,
}

pub struct ProcessStream {
    pub session_id: String,
    pub handle: Option<Child>,
    pub output: Arc<Mutex<Vec<String>>>,
}

impl ProcessStream {
    /// Start streaming a process and capture output
    pub fn start_process(
        provider: &str,
        project_id: &str,
        executable: &str,
        args: &[&str],
        cwd: &str,
    ) -> Result<StreamingSession> {
        let session_id = Uuid::new_v4().to_string();
        let output = Arc::new(Mutex::new(Vec::new()));
        let output_clone = Arc::clone(&output);

        let mut cmd = Command::new(executable);
        cmd.current_dir(cwd)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());

        for arg in args {
            cmd.arg(arg);
        }

        let mut child = cmd.spawn()
            .context(format!("Failed to spawn {} process", provider))?;

        let pid = child.id();

        // Take stdout
        if let Some(stdout) = child.stdout.take() {
            let output_write = Arc::clone(&output_clone);

            // Spawn thread to read stdout
            thread::spawn(move || {
                let reader = BufReader::new(stdout);
                for line in reader.lines() {
                    if let Ok(line) = line {
                        // Add to output buffer
                        if let Ok(mut out) = output_write.lock() {
                            out.push(line);
                        }
                    }
                }
            });
        }

        // Take stderr and merge with stdout
        if let Some(stderr) = child.stderr.take() {
            let output_write = Arc::clone(&output_clone);

            thread::spawn(move || {
                let reader = BufReader::new(stderr);
                for line in reader.lines() {
                    if let Ok(line) = line {
                        let error_line = format!("[ERROR] {}", line);
                        if let Ok(mut out) = output_write.lock() {
                            out.push(error_line);
                        }
                    }
                }
            });
        }

        Ok(StreamingSession {
            id: session_id,
            provider: provider.to_string(),
            project_id: project_id.to_string(),
            status: "Running".to_string(),
            pid: Some(pid),
            output: output_clone,
            started_at: chrono::Utc::now().to_rfc3339(),
            error: None,
        })
    }

    /// Get current output from session
    pub fn get_output(output: &Arc<Mutex<Vec<String>>>) -> Vec<String> {
        output.lock()
            .map(|o| o.clone())
            .unwrap_or_default()
    }

    /// Stop the process
    pub fn stop_process(child: &mut Child) -> Result<()> {
        child.kill()?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_output_capture() {
        let output = Arc::new(Mutex::new(vec!["test line".to_string()]));
        let lines = ProcessStream::get_output(&output);
        assert_eq!(lines.len(), 1);
        assert_eq!(lines[0], "test line");
    }
}
