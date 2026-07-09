param(
    [string]$ProjectDir = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$lib = Join-Path $PSScriptRoot "lib\cunica-common.ps1"
if (-not (Test-Path -LiteralPath $lib)) {
    throw "Missing library: $lib"
}
. $lib
Set-CunicaContractPath -Path (Join-Path (Split-Path $PSScriptRoot -Parent) "unica-contract.json")

$projectDir = (Resolve-Path -LiteralPath $ProjectDir).Path
$cursorDir = Join-Path $projectDir ".cursor"
$rulesDir = Join-Path $cursorDir "rules"
$mcpPath = Join-Path $cursorDir "mcp.json"
$templatePath = Join-Path (Split-Path -Parent $PSScriptRoot) "templates\1c-unica.mdc"
$rulePath = Join-Path $rulesDir "1c-unica.mdc"

# Verify global install
$manifest = Read-CunicaManifest
if (-not $manifest) {
    throw @"
Unica is not installed globally.

Run from the cunica repository:
  powershell -ExecutionPolicy Bypass -File scripts\install-cunica.ps1
"@
}

$target = [string]$manifest.target
Verify-InstalledUnicaContract | Out-Null

$unicaEntry = Get-McpUnicaEntry -Target $target

if (-not (Test-Path -LiteralPath $cursorDir)) {
    New-Item -ItemType Directory -Path $cursorDir -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $rulesDir)) {
    New-Item -ItemType Directory -Path $rulesDir -Force | Out-Null
}

Merge-McpJson -McpPath $mcpPath -UnicaEntry $unicaEntry

if (-not (Test-Path -LiteralPath $templatePath)) {
    throw "Missing template: $templatePath"
}
Copy-Item -LiteralPath $templatePath -Destination $rulePath -Force

$gitignorePath = Join-Path $projectDir ".gitignore"
$gitignoreLine = "v8project.local.yaml"
if (Test-Path -LiteralPath $gitignorePath) {
    $content = Get-Content -LiteralPath $gitignorePath -Raw -Encoding UTF8
    if ($content -notmatch [regex]::Escape($gitignoreLine)) {
        $suffix = if ($content.EndsWith("`n") -or $content.EndsWith("`r`n")) { "" } else { "`n" }
        Write-Utf8NoBomFile -Path $gitignorePath -Content ($content + $suffix + $gitignoreLine + "`n")
    }
} else {
    Write-Utf8NoBomFile -Path $gitignorePath -Content ("$gitignoreLine`n")
}

Write-Output "==> Initialized Cunica in: $projectDir"
Write-Output "==> MCP config: $mcpPath"
Write-Output "==> Cursor rule: $rulePath"
Write-Output "==> Unica version: $($manifest.version)"
Write-Output "==> Restart Cursor or reload window to pick up MCP changes"
