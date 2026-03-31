import { useState, useEffect } from 'react'
import { invoke } from '@tauri-apps/api/core'

export default function Dashboard() {
  const [projects, setProjects] = useState<any[]>([])
  const [stats, setStats] = useState({ total: 0, active: 0 })
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadProjects()
  }, [])

  const loadProjects = async () => {
    try {
      const result = await invoke('cmd_list_projects')
      const projectList = result as any[]
      setProjects(projectList)
      setStats({
        total: projectList.length,
        active: projectList.filter((p) => p.status === 'InProgress').length,
      })
    } catch (error) {
      console.error('Failed to load projects:', error)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="p-8">
      <h2 className="text-3xl font-bold mb-8">Dashboard</h2>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-6 mb-8">
        <div className="bg-slate-800 rounded-lg p-6 border border-slate-700">
          <div className="text-slate-400 text-sm font-semibold uppercase mb-2">Total Projects</div>
          <div className="text-4xl font-bold text-neptune-400">{stats.total}</div>
        </div>
        <div className="bg-slate-800 rounded-lg p-6 border border-slate-700">
          <div className="text-slate-400 text-sm font-semibold uppercase mb-2">Active</div>
          <div className="text-4xl font-bold text-green-400">{stats.active}</div>
        </div>
        <div className="bg-slate-800 rounded-lg p-6 border border-slate-700">
          <div className="text-slate-400 text-sm font-semibold uppercase mb-2">Status</div>
          <div className="text-xl text-slate-300">Ready</div>
        </div>
      </div>

      {/* Recent Projects */}
      <div className="bg-slate-800 rounded-lg border border-slate-700 overflow-hidden">
        <div className="p-6 border-b border-slate-700">
          <h3 className="text-xl font-bold">Recent Projects</h3>
        </div>
        {loading ? (
          <div className="p-6 text-slate-400">Loading...</div>
        ) : projects.length === 0 ? (
          <div className="p-6 text-slate-400">No projects yet. Create one to get started.</div>
        ) : (
          <div className="divide-y divide-slate-700">
            {projects.slice(0, 5).map((p) => (
              <div key={p.id} className="p-4 hover:bg-slate-700 transition-colors cursor-pointer">
                <div className="font-semibold text-white">{p.name}</div>
                <div className="text-sm text-slate-400 mt-1">{p.description}</div>
                <div className="text-xs text-slate-500 mt-2">
                  {p.projectType} • {p.status}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
