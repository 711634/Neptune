import { useState, useEffect } from 'react'
import { invoke } from '@tauri-apps/api/core'
import Dashboard from './pages/Dashboard'
import Projects from './pages/Projects'
import Providers from './pages/Providers'
import Sessions from './pages/Sessions'
import Settings from './pages/Settings'

export default function App() {
  const [currentPage, setCurrentPage] = useState<'dashboard' | 'projects' | 'providers' | 'sessions' | 'settings'>('dashboard')
  const [providers, setProviders] = useState<any[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadProviders()
  }, [])

  const loadProviders = async () => {
    try {
      const result = await invoke('cmd_detect_providers')
      setProviders(result as any[])
    } catch (error) {
      console.error('Failed to detect providers:', error)
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen bg-slate-950">
        <div className="text-center">
          <div className="mb-4 text-2xl font-bold text-neptune-400">Neptune</div>
          <div className="text-slate-400">Initializing...</div>
        </div>
      </div>
    )
  }

  return (
    <div className="flex h-screen bg-slate-950 text-white">
      {/* Sidebar */}
      <nav className="w-64 bg-slate-900 border-r border-slate-800 flex flex-col">
        <div className="p-6 border-b border-slate-800">
          <h1 className="text-2xl font-bold text-neptune-400">Neptune</h1>
          <p className="text-xs text-slate-500 mt-1">Local AI IDE</p>
        </div>

        <div className="flex-1 py-6">
          <button
            onClick={() => setCurrentPage('dashboard')}
            className={`w-full text-left px-6 py-3 flex items-center gap-3 transition-colors ${
              currentPage === 'dashboard'
                ? 'bg-neptune-600 text-white'
                : 'hover:bg-slate-800 text-slate-300'
            }`}
          >
            <span className="text-lg">📊</span>
            <span>Dashboard</span>
          </button>
          <button
            onClick={() => setCurrentPage('projects')}
            className={`w-full text-left px-6 py-3 flex items-center gap-3 transition-colors ${
              currentPage === 'projects'
                ? 'bg-neptune-600 text-white'
                : 'hover:bg-slate-800 text-slate-300'
            }`}
          >
            <span className="text-lg">📁</span>
            <span>Projects</span>
          </button>
          <button
            onClick={() => setCurrentPage('providers')}
            className={`w-full text-left px-6 py-3 flex items-center gap-3 transition-colors ${
              currentPage === 'providers'
                ? 'bg-neptune-600 text-white'
                : 'hover:bg-slate-800 text-slate-300'
            }`}
          >
            <span className="text-lg">🔧</span>
            <span>Tools</span>
          </button>
          <button
            onClick={() => setCurrentPage('sessions')}
            className={`w-full text-left px-6 py-3 flex items-center gap-3 transition-colors ${
              currentPage === 'sessions'
                ? 'bg-neptune-600 text-white'
                : 'hover:bg-slate-800 text-slate-300'
            }`}
          >
            <span className="text-lg">⚡</span>
            <span>Sessions</span>
          </button>
          <button
            onClick={() => setCurrentPage('settings')}
            className={`w-full text-left px-6 py-3 flex items-center gap-3 transition-colors ${
              currentPage === 'settings'
                ? 'bg-neptune-600 text-white'
                : 'hover:bg-slate-800 text-slate-300'
            }`}
          >
            <span className="text-lg">⚙️</span>
            <span>Settings</span>
          </button>
        </div>

        {/* Provider Status */}
        <div className="p-4 border-t border-slate-800">
          <div className="text-xs font-semibold text-slate-400 mb-3 uppercase">Providers</div>
          <div className="space-y-2">
            {providers.map((p) => (
              <div
                key={p.id}
                className="flex items-center gap-2 text-xs text-slate-300 bg-slate-800 px-3 py-2 rounded"
              >
                <span className={p.installed ? 'text-green-400' : 'text-red-400'}>●</span>
                <span>{p.name}</span>
              </div>
            ))}
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <main className="flex-1 overflow-auto">
        {currentPage === 'dashboard' && <Dashboard />}
        {currentPage === 'projects' && <Projects />}
        {currentPage === 'providers' && <Providers />}
        {currentPage === 'sessions' && <Sessions />}
        {currentPage === 'settings' && <Settings />}
      </main>
    </div>
  )
}
