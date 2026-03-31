import { useState, useEffect, useRef } from 'react'
import { invoke } from '@tauri-apps/api/core'

interface Session {
  id: string
  provider: string
  project_id: string
  status: string
  pid?: number
  started_at: string
  output_lines: number
}

export default function Sessions() {
  const [sessions, setSessions] = useState<Session[]>([])
  const [selectedSession, setSelectedSession] = useState<string | null>(null)
  const [output, setOutput] = useState<string[]>([])
  const [loading, setLoading] = useState(true)
  const outputRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    loadSessions()
    const interval = setInterval(loadSessions, 2000) // Poll every 2 seconds
    return () => clearInterval(interval)
  }, [])

  // Auto-scroll to bottom
  useEffect(() => {
    if (outputRef.current) {
      outputRef.current.scrollTop = outputRef.current.scrollHeight
    }
  }, [output])

  const loadSessions = async () => {
    try {
      const result = await invoke('cmd_list_active_sessions')
      setSessions(result as Session[])

      // If a session is selected, load its output
      if (selectedSession) {
        await loadSessionOutput(selectedSession)
      }
    } catch (error) {
      console.error('Failed to load sessions:', error)
    } finally {
      setLoading(false)
    }
  }

  const loadSessionOutput = async (sessionId: string) => {
    try {
      const result = await invoke('cmd_get_session_output', {
        sessionId,
      })
      setOutput(result as string[])
    } catch (error) {
      console.error('Failed to load output:', error)
      setOutput(['Error loading output'])
    }
  }

  const handleSelectSession = async (sessionId: string) => {
    setSelectedSession(sessionId)
    await loadSessionOutput(sessionId)
  }

  const handleStopSession = async (sessionId: string) => {
    try {
      await invoke('cmd_stop_session', { sessionId })
      await loadSessions()
    } catch (error) {
      console.error('Failed to stop session:', error)
    }
  }

  if (loading && sessions.length === 0) {
    return <div className="p-8 text-slate-400">Loading sessions...</div>
  }

  return (
    <div className="p-8 h-full flex flex-col">
      <h2 className="text-3xl font-bold mb-6">Active Sessions</h2>

      <div className="flex gap-6 flex-1 min-h-0">
        {/* Session List */}
        <div className="w-64 bg-slate-800 rounded-lg border border-slate-700 overflow-hidden flex flex-col">
          <div className="p-4 border-b border-slate-700 font-semibold">
            Sessions ({sessions.length})
          </div>
          <div className="flex-1 overflow-y-auto">
            {sessions.length === 0 ? (
              <div className="p-4 text-slate-400 text-sm">No active sessions</div>
            ) : (
              sessions.map((session) => (
                <div
                  key={session.id}
                  onClick={() => handleSelectSession(session.id)}
                  className={`p-3 border-b border-slate-700 cursor-pointer transition-colors ${
                    selectedSession === session.id
                      ? 'bg-neptune-600'
                      : 'hover:bg-slate-700'
                  }`}
                >
                  <div className="font-semibold text-sm">{session.provider}</div>
                  <div className="text-xs text-slate-400 mt-1">
                    {session.status === 'Running' ? '🟢' : '🔴'} {session.status}
                  </div>
                  <div className="text-xs text-slate-500 mt-2">
                    Lines: {session.output_lines}
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Output Display */}
        <div className="flex-1 bg-slate-800 rounded-lg border border-slate-700 flex flex-col min-w-0">
          {selectedSession ? (
            <>
              <div className="p-4 border-b border-slate-700 flex items-center justify-between">
                <div className="font-semibold">
                  Session: {sessions.find((s) => s.id === selectedSession)?.provider}
                </div>
                <button
                  onClick={() => handleStopSession(selectedSession)}
                  className="bg-red-600 hover:bg-red-700 text-white px-3 py-1 rounded text-sm font-semibold"
                >
                  Stop Session
                </button>
              </div>
              <div
                ref={outputRef}
                className="flex-1 overflow-y-auto p-4 font-mono text-sm text-slate-300 bg-slate-900 space-y-1"
              >
                {output.length === 0 ? (
                  <div className="text-slate-500">Waiting for output...</div>
                ) : (
                  output.map((line, idx) => (
                    <div
                      key={idx}
                      className={
                        line.startsWith('[ERROR]') ? 'text-red-400' : 'text-slate-300'
                      }
                    >
                      {line}
                    </div>
                  ))
                )}
              </div>
            </>
          ) : (
            <div className="flex items-center justify-center h-full text-slate-400">
              Select a session to view output
            </div>
          )}
        </div>
      </div>

      {/* Stats */}
      {sessions.length > 0 && (
        <div className="mt-6 grid grid-cols-4 gap-4">
          <div className="bg-slate-800 rounded p-4 border border-slate-700">
            <div className="text-slate-400 text-sm">Active Sessions</div>
            <div className="text-2xl font-bold text-neptune-400">
              {sessions.filter((s) => s.status === 'Running').length}
            </div>
          </div>
          <div className="bg-slate-800 rounded p-4 border border-slate-700">
            <div className="text-slate-400 text-sm">Total Sessions</div>
            <div className="text-2xl font-bold text-neptune-400">{sessions.length}</div>
          </div>
          <div className="bg-slate-800 rounded p-4 border border-slate-700">
            <div className="text-slate-400 text-sm">Total Output Lines</div>
            <div className="text-2xl font-bold text-neptune-400">
              {sessions.reduce((sum, s) => sum + s.output_lines, 0)}
            </div>
          </div>
          <div className="bg-slate-800 rounded p-4 border border-slate-700">
            <div className="text-slate-400 text-sm">Last Update</div>
            <div className="text-sm text-neptune-400">
              {new Date().toLocaleTimeString()}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
