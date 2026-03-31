# Contributing to Neptune

Thanks for your interest in Neptune! We welcome contributions from the community.

## Areas We're Looking For Help

- **Provider Adapters** — Add support for new tools (e.g., Codex, local Ollama, etc.)
- **Skill Packs** — Create YAML blueprints for additional project types
- **Windows Version** — Help build the Windows shell and Windows-specific providers
- **Documentation** — Improve guides, examples, and technical docs
- **Testing** — Report bugs, test edge cases, verify workflows
- **UI/UX** — Design improvements, accessibility enhancements

## Development Setup

### Prerequisites

- macOS 13.0 or later
- Xcode 15.0+
- Swift 5.9+
- Claude Code CLI installed and authenticated

### Building Neptune

```bash
# Clone the repository
git clone https://github.com/your-org/neptune.git
cd neptune

# Open in Xcode
open Neptune.xcodeproj

# Build and run
cmd + b (build)
cmd + r (run)
```

### Project Structure

```
Neptune/
├── App/              # SwiftUI app entry point
├── Models/           # Data models (Agent, Task, ProjectContext, etc.)
├── Services/         # Core services (Orchestrator, ProcessManager, etc.)
├── Views/            # UI components (Dashboard, Settings, Pets, etc.)
└── Resources/        # Assets, state files, and configurations
docs/
├── architecture/     # Technical deep-dives
└── WINDOWS_ROADMAP.md # Cross-platform strategy
```

## Code Standards

### Swift Style

- Use `swift-format` for formatting
- Enable strict concurrency checking (`SWIFT_STRICT_CONCURRENCY=complete`)
- Prefer value types (struct) over classes
- Use actors for shared mutable state
- Prefer `async`/`await` over callbacks

### Testing

- Minimum 80% code coverage for new features
- Write tests first (TDD approach)
- Use Swift Testing framework (`@Test` macro)
- Test isolation: no shared state between tests

### Documentation

- Update README.md for user-facing changes
- Add comments for non-obvious logic
- Document public APIs with doc comments
- Update WINDOWS_ROADMAP.md for cross-platform implications

## Pull Request Process

1. **Fork and Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Implement and Test**
   - Write tests first
   - Ensure 80%+ coverage
   - Run `swift test` locally
   - Verify build with `xcodebuild -scheme Neptune`

3. **Commit Messages**
   ```
   feat: Add new feature
   fix: Fix bug in component
   docs: Update documentation
   refactor: Reorganize module structure
   test: Add tests for feature
   ```

4. **Push and Create PR**
   ```bash
   git push origin feature/your-feature-name
   ```
   - Reference any related issues
   - Describe what changed and why
   - Include test results

5. **Code Review**
   - Respond to feedback promptly
   - Request re-review after changes
   - Be respectful and collaborative

## Adding a Provider Adapter

See [docs/architecture/PROVIDER_ADAPTERS.md](docs/architecture/PROVIDER_ADAPTERS.md) for detailed instructions on adding new provider adapters (e.g., Codex, custom tools).

## Creating a Skill Pack

Skill packs are YAML files that define role-specific prompts for agents:

```yaml
# ~/.neptune/skills/my_project_type/role.yaml
role: coding
system: |
  You are an expert developer...
prompt: |
  Implement the following:
  {task_description}
allowed_tools: [file_edit, run_tests, git_commit]
estimated_duration: 3600
```

See `Neptune/Services/SkillRegistry.swift` for the loading mechanism.

## Reporting Issues

Use GitHub Issues to report bugs or suggest features:

- **Bugs**: Include steps to reproduce, expected vs actual behavior, and environment details
- **Features**: Describe the use case and why it's important
- **Questions**: Use GitHub Discussions for general questions

## License

All contributions are licensed under the MIT License (see [LICENSE](LICENSE)).

## Questions?

- Check [README.md](README.md) for overview
- Read [docs/architecture/PROVIDER_ADAPTERS.md](docs/architecture/PROVIDER_ADAPTERS.md) for architecture
- Review [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) for what's been built

---

**Neptune v1.0-beta** — *Local autonomous agents, no cloud required.*
