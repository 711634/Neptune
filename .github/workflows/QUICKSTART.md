# Release Workflow — Quick Start

## One-Time Setup

```bash
cd /Users/misbah/Neptune

# Install GitHub CLI (if needed)
brew install gh
gh auth login  # Authenticate with your GitHub account
```

## Test the Workflow

### Option A: Instant Test (Recommended)
```bash
# Create and push a test tag
git tag v1.0.0-test-$(date +%s)
git push origin v1.0.0-test-$(date +%s)

# Watch the workflow execute
gh run list
gh run watch
```

Expected result: GitHub Release created as **draft** (not public).

### Option B: Interactive Test
```bash
# Create a test tag with a memorable name
git tag v1.0.0-test-20260331
git push origin v1.0.0-test-20260331

# Open workflow in browser
gh run view release.yml

# View the draft release when complete
gh release view v1.0.0-test-20260331
```

### Option C: Clean Up Test Release
```bash
# Delete test release and tag
gh release delete v1.0.0-test-20260331 --yes
git push origin --delete v1.0.0-test-20260331
```

## For Real Releases

### Step 1: Update Version Numbers

**Windows** (`windows/Cargo.toml`):
```toml
[package]
version = "1.0.0"
```

**Windows** (`windows/tauri.conf.json`):
```json
{
  "version": "1.0.0"
}
```

**CHANGELOG.md**:
```markdown
## [v1.0.0] - 2026-03-31

### Added
- Feature 1
- Feature 2

### Fixed
- Bug fix 1
```

### Step 2: Commit and Tag

```bash
git add -A
git commit -m "chore: bump version to 1.0.0"
git tag v1.0.0
git push origin main
git push origin v1.0.0
```

### Step 3: Monitor Release

```bash
# Check workflow status
gh run list

# View release when complete
gh release view v1.0.0
```

## Workflow Timeline

| Step | Duration | Platform |
|------|----------|----------|
| Checkout code | 1s | All |
| Dependencies | 2-3 min | Per platform |
| Build | 5-10 min | Per platform |
| Upload artifacts | 1 min | Per platform |
| Create release | 1 min | Ubuntu (final) |
| **Total** | **~20 min** | Parallel |

## Outputs

When complete, GitHub release contains:

- `Neptune.dmg` — macOS installer (150 MB)
- `Neptune_*.msi` — Windows installer (80 MB)
- Release notes from CHANGELOG.md

**URL:** `https://github.com/anthropics/neptune/releases/tag/v1.0.0`

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Workflow not triggering | Verify tag format: `v*.*.*` (e.g., `v1.0.0`) |
| macOS build fails | Check XcodeGen: `brew install xcodegen` |
| Windows build fails | Check icons exist: `windows/icons/icon.png` |
| Release not created | Check CHANGELOG.md exists with proper format |

## See Also

- Full testing guide: [RELEASE_TESTING.md](./RELEASE_TESTING.md)
- GitHub Actions docs: https://docs.github.com/en/actions
