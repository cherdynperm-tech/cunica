---
name: github-release-publishing
description: Configure and maintain GitHub Release automation for tag-based publishing with stable release assets. Use when the user asks about GitHub releases, release workflows, tag triggers, or release troubleshooting.
disable-model-invocation: true
---

# GitHub Release Publishing

## When to use

Use this skill when changing or validating release automation in GitHub Actions.

## Standard pattern

1. Trigger releases on tags `v*`.
2. Set workflow permission `contents: write`.
3. Create or update release with `softprops/action-gh-release`.
4. Attach a stable asset name expected by users.

## Cunica defaults

- Workflow path: `.github/workflows/release.yml`
- Asset source: `scripts/install-cunica.ps1`
- Published asset name: `install-cunica.ps1`
- Consumer URL pattern:
  `https://github.com/cherdynperm-tech/cunica/releases/latest/download/install-cunica.ps1`

## Quick verification

```powershell
git tag v0.0.0-test
git push origin v0.0.0-test
```

Then confirm release creation and asset availability in GitHub UI.
