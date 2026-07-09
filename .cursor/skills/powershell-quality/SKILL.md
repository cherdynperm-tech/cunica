---
name: powershell-quality
description: Apply when writing or reviewing PowerShell scripts to enforce strict mode, safe error handling, compatibility, and verification checks.
disable-model-invocation: true
---

# PowerShell Quality Skill

## When to use

Use this skill for any change touching `.ps1` or `.psm1` files.

## Authoring checklist

1. Add strict baseline:
   - `Set-StrictMode -Version 2.0`
   - `$ErrorActionPreference = 'Stop'`
2. Keep functions focused and parameterized.
3. Validate inputs and paths before side effects.
4. Return or print deterministic outputs for automation.
5. Emit clear error messages with recovery hints.

## Review checklist

- No silent failure blocks like `catch {}` without handling.
- No implicit global state mutation unless required and documented.
- No destructive command execution without explicit user request.
- Encoding and path handling are consistent.
- Script remains compatible with Windows PowerShell 5.1 unless documented otherwise.

## Anti-patterns and fixes

- Anti-pattern: `if (Test-Path ...) { ... }` repeated many times inline.
  - Fix: extract helper functions (`Get-*`, `Assert-*`, `Write-*`).
- Anti-pattern: relying on default `$ErrorActionPreference`.
  - Fix: set it explicitly to `Stop` at script start.
- Anti-pattern: broad `catch` that masks failures.
  - Fix: rethrow with context or emit actionable diagnostic and stop.

## Required post-change checks

Run the repository quality script:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-powershell-quality.ps1
```

CI: `.github/workflows/powershell-quality.yml`.

Optional: `-RequireScriptAnalyzer` if PSScriptAnalyzer module is installed.
