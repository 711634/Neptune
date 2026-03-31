import { useState, useEffect } from 'react'
import { invoke } from '@tauri-apps/api/core'

interface ProviderInfo {
  id: string
  name: string
  available: boolean
  running?: boolean
  canLaunch?: boolean
}

export default function Providers() {
  const [providers, setProviders] = useState<ProviderInfo[]>([])
  const [loading, setLoading] = useState(true)
  const [launching, setLaunching] = useState<string | null>(null)
  const [status, setStatus] = useState<Record<string, string>>({})

  useEffect(() => {
    checkProviders()
  }, [])

  const checkProviders = async () => {
    setLoading(true)
    try {
      const [claudeCode, vscode, claudeDesktop, codex] = await Promise.all([
        invoke('cmd_check_claude_code_available'),
        invoke('cmd_check_vscode_available'),
        invoke('cmd_check_claude_desktop_available'),
        invoke('cmd_check_codex_availability'),
      ])

      const newProviders: ProviderInfo[] = [
        {
          id: 'claude_code',
          name: 'Claude Code CLI',
          available: claudeCode as boolean,
          canLaunch: true,
        },
        {
          id: 'vscode',
          name: 'VS Code + Claude',
          available: vscode as boolean,
          canLaunch: true,
        },
        {
          id: 'claude_desktop',
          name: 'Claude Desktop',
          available: claudeDesktop as boolean,
          canLaunch: true,
        },
        {
          id: 'codex',
          name: 'Claude Models (Codex)',
          available: codex as boolean,
          canLaunch: false,
        },
      ]

      setProviders(newProviders)
    } catch (error) {
      console.error('Failed to check providers:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleLaunchClaude = async () => {
    setLaunching('claude_code')
    try {
      const result = await invoke('cmd_launch_claude_code', {
        projectId: 'default',
        projectPath: process.cwd?.() || '.',
      })
      setStatus({ claude_code: result as string })
    } catch (error) {
      setStatus({
        claude_code: `Error: ${error}`,
      })
    } finally {
      setLaunching(null)
    }
  }

  const handleLaunchVSCode = async () => {
    setLaunching('vscode')
    try {
      const result = await invoke('cmd_open_in_vscode', {
        projectId: 'default',
        projectPath: process.cwd?.() || '.',
      })
      setStatus({ vscode: result as string })
    } catch (error) {
      setStatus({
        vscode: `Error: ${error}`,
      })
    } finally {
      setLaunching(null)
    }
  }

  const handleLaunchClaudeDesktop = async () => {
    setLaunching('claude_desktop')
    try {
      const result = await invoke('cmd_launch_claude_desktop')
      setStatus({ claude_desktop: result as string })
    } catch (error) {
      setStatus({
        claude_desktop: `Error: ${error}`,
      })
    } finally {
      setLaunching(null)
    }
  }

  return (
    <div className="p-8">
      <h2 className="text-3xl font-bold mb-8">Integrated Tools</h2>

      {loading ? (
        <div className="text-slate-400">Checking available tools...</div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Claude Code CLI */}
          <div className="bg-slate-800 rounded-lg border border-slate-700 p-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-bold">Claude Code CLI</h3>
              <span
                className={`px-3 py-1 rounded text-sm font-semibold ${
                  providers.find((p) => p.id === 'claude_code')?.available
                    ? 'bg-green-900 text-green-200'
                    : 'bg-red-900 text-red-200'
                }`}
              >
                {providers.find((p) => p.id === 'claude_code')?.available
                  ? '✓ Installed'
                  : '✗ Not Found'}
              </span>
            </div>
            <p className="text-slate-400 text-sm mb-4">
              Run Claude as a CLI in your terminal. Supports project analysis, code generation, and
              automated tasks.
            </p>
            {status.claude_code && (
              <div className="bg-slate-900 px-3 py-2 rounded text-xs text-slate-300 mb-4">
                {status.claude_code}
              </div>
            )}
            {providers.find((p) => p.id === 'claude_code')?.available && (
              <button
                onClick={handleLaunchClaude}
                disabled={launching === 'claude_code'}
                className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-slate-700 text-white px-4 py-2 rounded font-semibold transition-colors"
              >
                {launching === 'claude_code' ? 'Launching...' : 'Launch Claude Code'}
              </button>
            )}
          </div>

          {/* VS Code */}
          <div className="bg-slate-800 rounded-lg border border-slate-700 p-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-bold">VS Code + Claude</h3>
              <span
                className={`px-3 py-1 rounded text-sm font-semibold ${
                  providers.find((p) => p.id === 'vscode')?.available
                    ? 'bg-green-900 text-green-200'
                    : 'bg-red-900 text-red-200'
                }`}
              >
                {providers.find((p) => p.id === 'vscode')?.available
                  ? '✓ Installed'
                  : '✗ Not Found'}
              </span>
            </div>
            <p className="text-slate-400 text-sm mb-4">
              Link your project to VS Code with Claude extension. Edit code with AI assistance in
              your favorite editor.
            </p>
            {status.vscode && (
              <div className="bg-slate-900 px-3 py-2 rounded text-xs text-slate-300 mb-4">
                {status.vscode}
              </div>
            )}
            {providers.find((p) => p.id === 'vscode')?.available && (
              <button
                onClick={handleLaunchVSCode}
                disabled={launching === 'vscode'}
                className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-slate-700 text-white px-4 py-2 rounded font-semibold transition-colors"
              >
                {launching === 'vscode' ? 'Opening...' : 'Open in VS Code'}
              </button>
            )}
          </div>

          {/* Claude Desktop */}
          <div className="bg-slate-800 rounded-lg border border-slate-700 p-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-bold">Claude Desktop</h3>
              <span
                className={`px-3 py-1 rounded text-sm font-semibold ${
                  providers.find((p) => p.id === 'claude_desktop')?.available
                    ? 'bg-green-900 text-green-200'
                    : 'bg-red-900 text-red-200'
                }`}
              >
                {providers.find((p) => p.id === 'claude_desktop')?.available
                  ? '✓ Installed'
                  : '✗ Not Found'}
              </span>
            </div>
            <p className="text-slate-400 text-sm mb-4">
              Use Claude Desktop app for real-time conversations about your code. Full context and
              instant interaction.
            </p>
            {status.claude_desktop && (
              <div className="bg-slate-900 px-3 py-2 rounded text-xs text-slate-300 mb-4">
                {status.claude_desktop}
              </div>
            )}
            {providers.find((p) => p.id === 'claude_desktop')?.available && (
              <button
                onClick={handleLaunchClaudeDesktop}
                disabled={launching === 'claude_desktop'}
                className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-slate-700 text-white px-4 py-2 rounded font-semibold transition-colors"
              >
                {launching === 'claude_desktop' ? 'Launching...' : 'Launch Claude Desktop'}
              </button>
            )}
          </div>

          {/* Claude Models */}
          <div className="bg-slate-800 rounded-lg border border-slate-700 p-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-bold">Claude Models</h3>
              <span
                className={`px-3 py-1 rounded text-sm font-semibold ${
                  providers.find((p) => p.id === 'codex')?.available
                    ? 'bg-green-900 text-green-200'
                    : 'bg-yellow-900 text-yellow-200'
                }`}
              >
                {providers.find((p) => p.id === 'codex')?.available
                  ? '✓ Available'
                  : 'ℹ Check Installation'}
              </span>
            </div>
            <p className="text-slate-400 text-sm mb-4">
              Access to Claude models through your configured API key. Requires Claude Code CLI
              with valid authentication.
            </p>
            <div className="text-xs text-slate-500">
              Available models will be detected automatically when Claude Code CLI is installed and
              authenticated.
            </div>
          </div>
        </div>
      )}

      {/* Tool Installation Guide */}
      <div className="mt-12 pt-8 border-t border-slate-800">
        <h3 className="text-lg font-bold mb-4">Installation Guide</h3>
        <div className="space-y-4 text-sm text-slate-300">
          <div className="bg-slate-800 rounded p-4 border border-slate-700">
            <div className="font-semibold mb-2">Claude Code CLI</div>
            <div className="text-slate-400">
              Install via npm: <code className="bg-slate-900 px-2 py-1">npm install -g @anthropic-ai/claude-code</code>
            </div>
          </div>
          <div className="bg-slate-800 rounded p-4 border border-slate-700">
            <div className="font-semibold mb-2">VS Code + Claude Extension</div>
            <div className="text-slate-400">
              Download VS Code from <a href="https://code.visualstudio.com" className="text-neptune-400 hover:underline">code.visualstudio.com</a> and install the
              Claude extension from the marketplace.
            </div>
          </div>
          <div className="bg-slate-800 rounded p-4 border border-slate-700">
            <div className="font-semibold mb-2">Claude Desktop</div>
            <div className="text-slate-400">
              Download from <a href="https://claude.ai" className="text-neptune-400 hover:underline">claude.ai</a> or install from your system's app store.
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
