# Release Workflow Testing Guide

This guide explains how to test and use the GitHub Actions release workflow for building Neptune on macOS and Windows.

## Workflow Overview

The `release.yml` workflow:
- **Triggers** on version tags: `v1.0.0`, `v1.0.1`, `v2.0.0-beta`, etc.
- **Builds macOS** DMG installer on `macos-latest` runner
- **Builds Windows** MSI installer on `windows-latest` runner
- **Creates GitHub Release** with both installers as downloadable assets

## Prerequisites

Before testing, ensure:

1. **GitHub CLI installed** (for testing locally)
   ```bash
   brew install gh
   gh auth login
   ```

2. **Repository access** with push permissions to `anthropics/neptune`

3. **CHANGELOG.md exists** with properly formatted entries:
   ```markdown
   ## [v1.0.0] - 2026-03-31
   
   ### Added
   - macOS native support
   - Windows Tauri integration
   - Real-time agent visualization
   ```
   (The workflow reads release notes from CHANGELOG.md)

## Testing Methods

### Method 1: Test with Dry-Run Tag (Recommended)

Create a test tag and push it to trigger the workflow without publishing a real release:

```bash
# From Neptune root directory

# Create a test tag
git tag v1.0.0-test-$(date +%s)

# Push the tag to trigger the workflow
git push origin v1.0.0-test-$(date +%s)

# Monitor the workflow in GitHub Actions
gh workflow view release.yml
```

**Result:** A GitHub Release will be created as a **draft** (not visible publicly). You can inspect it, then delete it to clean up.

### Method 2: Test on a Fork

1. Fork `anthropics/neptune` to your personal account
2. Push a test tag to your fork:
   ```bash
   git tag v1.0.0-test
   git push origin v1.0.0-test
   ```
3. View the release in your fork's Releases page
4. Delete the test release when done

### Method 3: Manual Workflow Dispatch (GitHub UI)

1. Go to **Actions** → **Release** workflow
2. Click **Run workflow**
3. Enter test parameters:
   - Branch: `main`
   - Additional inputs (if configured)

## Workflow Execution Steps

When you push a version tag, GitHub Actions runs:

### 1. Build macOS DMG (7-10 minutes)
- Checks out code
- Installs XcodeGen and create-dmg
- Generates Xcode project via `xcodegen`
- Builds Neptune app with `xcodebuild release`
- Creates DMG installer with `create-dmg`
- Uploads `Neptune.dmg` as artifact

### 2. Build Windows MSI (5-8 minutes, runs in parallel)
- Checks out code
- Sets up Node 18 and Rust toolchain
- Installs npm dependencies in `windows/` directory
- Runs `npm run tauri build` to compile Rust + bundle MSI
- Uploads `Neptune_*.msi` as artifact

### 3. Create Release (1-2 minutes, runs after both builds complete)
- Downloads both artifacts
- Reads release notes from `CHANGELOG.md`
- Creates GitHub Release with:
  - DMG for macOS users
  - MSI for Windows users
  - Release notes in description
  - Draft status for prerelease versions (alpha/beta)

## Expected Outputs

After successful workflow run:

```
Neptune/releases/tag/v1.0.0/
├── Neptune.dmg          (macOS installer, ~150 MB)
├── Neptune_*.msi        (Windows installer, ~80 MB)
└── Release notes        (from CHANGELOG.md)
```

**Release page URL format:**
```
https://github.com/anthropics/neptune/releases/tag/v1.0.0
```

## Troubleshooting

### Workflow fails on macOS build
- **Error:** `xcodegen: command not found`
  - Fix: Verify `brew install xcodegen` runs successfully
  - Check: macOS-latest has Xcode CLI tools installed

- **Error:** `create-dmg: command not found`
  - Fix: Ensure `brew install create-dmg` completes
  - Fallback: Use `hdiutil` command directly (more complex)

- **Error:** Build output not found in derivedDataPath
  - Check: XcodeGen generated correct project structure
  - Debug: Run `xcodegen generate` locally and verify `.xcodeproj` exists

### Workflow fails on Windows build
- **Error:** `npm install` timeout
  - Fix: Increase timeout or split into separate step
  - Cause: Large Windows Tauri dependencies (~1 GB)

- **Error:** `target/release/bundle/msi/*.msi` not found
  - Check: `npm run tauri build` completed successfully
  - Verify: icons directory exists at `windows/icons/icon.png`
  - Debug: Bundle path may differ; check `windows/tauri.conf.json`

- **Error:** Rust compilation fails
  - Fix: Ensure `build.rs` exists and Cargo.toml is correct
  - Check: All dependencies resolve (run locally first)

### Release creation fails
- **Error:** `Release already exists for tag`
  - Fix: Either delete the release manually or use unique tag
  - Note: Tags are immutable; can't re-push same tag

- **Error:** `CHANGELOG.md` not found / no release notes
  - Behavior: Workflow continues but uses empty notes
  - Fix: Add CHANGELOG.md with proper format:
    ```markdown
    ## [v1.0.0] - 2026-03-31
    
    ### Added
    - Feature description
    ```

## Tag Format Convention

Use **semantic versioning** for releases:

```bash
# Standard releases
git tag v1.0.0          # Initial release
git tag v1.0.1          # Patch (bug fixes)
git tag v1.1.0          # Minor (new features, backward compatible)
git tag v2.0.0          # Major (breaking changes)

# Prerelease versions (marked as drafts in workflow)
git tag v1.0.0-alpha.1  # Alpha (early testing)
git tag v1.0.0-beta.1   # Beta (feature complete, testing)
git tag v1.0.0-rc.1     # Release candidate

# Push to trigger workflow
git push origin v1.0.0
```

## Clean Up Test Releases

After testing, remove draft/test releases:

```bash
# List all releases (including drafts)
gh release list

# Delete a test release
gh release delete v1.0.0-test

# Or delete via GitHub UI:
# Releases → click test release → Delete this release
```

## Monitoring Workflow Execution

### In GitHub UI
1. Go to **Actions** tab
2. Click **Release** workflow
3. Find your tag's run
4. Watch live logs as jobs run

### Via GitHub CLI
```bash
# Watch the latest run
gh run watch

# List recent runs
gh run list

# Get detailed log for a specific run
gh run view [RUN_ID] --log
```

### Email Notifications
GitHub sends notifications if workflow fails (configure in Settings → Notifications)

## Version Updates for Release

Before creating a release tag, update the version in:

1. **Windows** (`windows/Cargo.toml`):
   ```toml
   [package]
   version = "1.0.0"
   ```

2. **Windows** (`windows/tauri.conf.json`):
   ```json
   {
     "version": "1.0.0"
   }
   ```

3. **macOS** (`Neptune.xcodeproj` via Xcode or project.yml)

4. **Root** (`CHANGELOG.md`):
   ```markdown
   ## [v1.0.0] - 2026-03-31
   
   ### Added
   - List new features
   ```

Push all version updates before creating the release tag:

```bash
git add -A
git commit -m "chore: bump version to 1.0.0"
git tag v1.0.0
git push origin main --tags
```

## CI/CD Integration

The workflow respects:
- **Branch protection rules** (PR reviews, status checks)
- **GitHub Secrets** (GITHUB_TOKEN for release creation)
- **Artifact retention** (artifacts deleted after 1 day)

To adjust artifact retention:
```yaml
# In .github/workflows/release.yml
retention-days: 7  # Keep for 7 days instead of 1
```

## Further Reading

- [GitHub Actions documentation](https://docs.github.com/en/actions)
- [Tauri build documentation](https://tauri.app/v1/guides/building/)
- [XcodeGen documentation](https://github.com/yonaskolb/XcodeGen)
- [Semantic versioning](https://semver.org/)
