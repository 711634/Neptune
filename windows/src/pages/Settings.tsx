import { useState, useEffect } from 'react'
import { invoke } from '@tauri-apps/api/core'

export default function Settings() {
  const [settings, setSettings] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [dirty, setDirty] = useState(false)

  useEffect(() => {
    loadSettings()
  }, [])

  const loadSettings = async () => {
    try {
      const result = await invoke('cmd_load_settings')
      setSettings(result)
    } catch (error) {
      console.error('Failed to load settings:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleSettingChange = (key: string, value: any) => {
    setSettings({ ...settings, [key]: value })
    setDirty(true)
  }

  const handleSave = async () => {
    try {
      await invoke('cmd_save_settings', { settings })
      setDirty(false)
      alert('Settings saved successfully')
    } catch (error) {
      console.error('Failed to save settings:', error)
      alert('Failed to save settings')
    }
  }

  if (loading) {
    return <div className="p-8 text-slate-400">Loading settings...</div>
  }

  return (
    <div className="p-8 max-w-2xl">
      <h2 className="text-3xl font-bold mb-8">Settings</h2>

      <div className="bg-slate-800 rounded-lg border border-slate-700 p-6 space-y-6">
        {/* Claude Path */}
        <div>
          <label className="block text-sm font-semibold mb-2">Claude CLI Path</label>
          <input
            type="text"
            value={settings?.claude_path || ''}
            onChange={(e) => handleSettingChange('claude_path', e.target.value)}
            className="w-full bg-slate-900 border border-slate-700 rounded px-4 py-2 text-white focus:outline-none focus:border-neptune-500"
            placeholder="Auto-detected path to claude executable"
          />
          <p className="text-xs text-slate-500 mt-2">Leave blank to auto-detect</p>
        </div>

        {/* Workspace Directory */}
        <div>
          <label className="block text-sm font-semibold mb-2">Workspace Directory</label>
          <input
            type="text"
            value={settings?.workspace_dir || ''}
            onChange={(e) => handleSettingChange('workspace_dir', e.target.value)}
            className="w-full bg-slate-900 border border-slate-700 rounded px-4 py-2 text-white focus:outline-none focus:border-neptune-500"
            placeholder="Default workspace location"
          />
        </div>

        {/* Low Power Mode */}
        <div className="flex items-center gap-4">
          <input
            type="checkbox"
            id="lowPowerMode"
            checked={settings?.low_power_mode || false}
            onChange={(e) => handleSettingChange('low_power_mode', e.target.checked)}
            className="w-4 h-4 rounded"
          />
          <label htmlFor="lowPowerMode" className="text-sm font-semibold">
            Enable Low Power Mode
          </label>
          <span className="text-xs text-slate-400">(Reduces background agent activity)</span>
        </div>

        {/* Launch at Startup */}
        <div className="flex items-center gap-4">
          <input
            type="checkbox"
            id="launchAtStartup"
            checked={settings?.launch_at_startup || false}
            onChange={(e) => handleSettingChange('launch_at_startup', e.target.checked)}
            className="w-4 h-4 rounded"
          />
          <label htmlFor="launchAtStartup" className="text-sm font-semibold">
            Launch at Windows Startup
          </label>
        </div>

        {/* Max Concurrent Agents */}
        <div>
          <label className="block text-sm font-semibold mb-2">Max Concurrent Agents</label>
          <input
            type="number"
            value={settings?.max_concurrent_agents || 3}
            onChange={(e) =>
              handleSettingChange('max_concurrent_agents', parseInt(e.target.value))
            }
            min="1"
            max="10"
            className="w-full bg-slate-900 border border-slate-700 rounded px-4 py-2 text-white focus:outline-none focus:border-neptune-500"
          />
          <p className="text-xs text-slate-500 mt-2">Number of agents that can run in parallel</p>
        </div>

        {/* Preferred Provider */}
        <div>
          <label className="block text-sm font-semibold mb-2">Preferred Provider</label>
          <select
            value={settings?.preferred_provider || 'claude_code'}
            onChange={(e) => handleSettingChange('preferred_provider', e.target.value)}
            className="w-full bg-slate-900 border border-slate-700 rounded px-4 py-2 text-white focus:outline-none focus:border-neptune-500"
          >
            <option value="claude_code">Claude Code CLI</option>
            <option value="vscode">VS Code</option>
            <option value="claude_desktop">Claude Desktop</option>
          </select>
        </div>

        {/* Save Button */}
        <div className="pt-6 border-t border-slate-700">
          <button
            onClick={handleSave}
            disabled={!dirty}
            className={`px-6 py-2 rounded-lg font-semibold transition-colors ${
              dirty
                ? 'bg-neptune-600 hover:bg-neptune-700 text-white'
                : 'bg-slate-700 text-slate-500 cursor-not-allowed'
            }`}
          >
            Save Settings
          </button>
        </div>
      </div>

      {/* About Section */}
      <div className="mt-12 pt-8 border-t border-slate-800">
        <h3 className="text-lg font-bold mb-4">About Neptune</h3>
        <div className="text-sm text-slate-400 space-y-2">
          <p>
            <span className="text-slate-300 font-semibold">Version:</span> 1.0.0-beta
          </p>
          <p>
            <span className="text-slate-300 font-semibold">Platform:</span> Windows 10/11
          </p>
          <p>
            <span className="text-slate-300 font-semibold">Homepage:</span>{' '}
            <a href="https://github.com/anthropics/neptune" className="text-neptune-400 hover:underline">
              github.com/anthropics/neptune
            </a>
          </p>
        </div>
      </div>
    </div>
  )
}
