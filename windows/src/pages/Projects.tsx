import { useState, useEffect } from 'react'
import { invoke } from '@tauri-apps/api/core'

export default function Projects() {
  const [projects, setProjects] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [showNewProjectForm, setShowNewProjectForm] = useState(false)
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    projectType: 'WebApp',
  })

  useEffect(() => {
    loadProjects()
  }, [])

  const loadProjects = async () => {
    try {
      const result = await invoke('cmd_list_projects')
      setProjects(result as any[])
    } catch (error) {
      console.error('Failed to load projects:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleCreateProject = async () => {
    if (!formData.name.trim()) {
      alert('Project name is required')
      return
    }

    try {
      await invoke('cmd_create_project', {
        name: formData.name,
        description: formData.description,
        projectType: formData.projectType,
      })
      setFormData({ name: '', description: '', projectType: 'WebApp' })
      setShowNewProjectForm(false)
      await loadProjects()
    } catch (error) {
      console.error('Failed to create project:', error)
      alert('Failed to create project')
    }
  }

  return (
    <div className="p-8">
      <div className="flex items-center justify-between mb-8">
        <h2 className="text-3xl font-bold">Projects</h2>
        <button
          onClick={() => setShowNewProjectForm(!showNewProjectForm)}
          className="bg-neptune-600 hover:bg-neptune-700 text-white px-6 py-2 rounded-lg font-semibold transition-colors"
        >
          + New Project
        </button>
      </div>

      {/* New Project Form */}
      {showNewProjectForm && (
        <div className="bg-slate-800 rounded-lg border border-slate-700 p-6 mb-8">
          <h3 className="text-lg font-bold mb-4">Create New Project</h3>
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium mb-2">Project Name</label>
              <input
                type="text"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                className="w-full bg-slate-900 border border-slate-700 rounded px-4 py-2 text-white focus:outline-none focus:border-neptune-500"
                placeholder="Enter project name"
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-2">Description</label>
              <textarea
                value={formData.description}
                onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                className="w-full bg-slate-900 border border-slate-700 rounded px-4 py-2 text-white focus:outline-none focus:border-neptune-500"
                placeholder="Enter project description"
                rows={3}
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-2">Project Type</label>
              <select
                value={formData.projectType}
                onChange={(e) => setFormData({ ...formData, projectType: e.target.value })}
                className="w-full bg-slate-900 border border-slate-700 rounded px-4 py-2 text-white focus:outline-none focus:border-neptune-500"
              >
                <option>WebApp</option>
                <option>PythonCLI</option>
                <option>iOSApp</option>
                <option>MacOSApp</option>
                <option>ChromeExtension</option>
                <option>DataAnalysis</option>
                <option>RustLib</option>
              </select>
            </div>
            <div className="flex gap-3 pt-4">
              <button
                onClick={handleCreateProject}
                className="bg-neptune-600 hover:bg-neptune-700 text-white px-6 py-2 rounded font-semibold transition-colors"
              >
                Create
              </button>
              <button
                onClick={() => setShowNewProjectForm(false)}
                className="bg-slate-700 hover:bg-slate-600 text-white px-6 py-2 rounded font-semibold transition-colors"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Projects Grid */}
      {loading ? (
        <div className="text-slate-400">Loading projects...</div>
      ) : projects.length === 0 ? (
        <div className="text-center py-12">
          <div className="text-slate-400 text-lg mb-4">No projects yet</div>
          <button
            onClick={() => setShowNewProjectForm(true)}
            className="bg-neptune-600 hover:bg-neptune-700 text-white px-6 py-2 rounded-lg font-semibold transition-colors"
          >
            Create Your First Project
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {projects.map((project) => (
            <div
              key={project.id}
              className="bg-slate-800 rounded-lg border border-slate-700 p-6 hover:border-neptune-500 transition-colors cursor-pointer"
            >
              <h3 className="text-lg font-bold text-white mb-2">{project.name}</h3>
              <p className="text-slate-400 text-sm mb-4">{project.description}</p>
              <div className="flex items-center justify-between text-xs">
                <span className="bg-slate-700 px-3 py-1 rounded text-slate-300">
                  {project.projectType}
                </span>
                <span
                  className={`px-3 py-1 rounded ${
                    project.status === 'InProgress'
                      ? 'bg-green-900 text-green-200'
                      : 'bg-slate-700 text-slate-300'
                  }`}
                >
                  {project.status}
                </span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
