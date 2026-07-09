param(
    [string]$OutputDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "dist")
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$staging = Join-Path $OutputDir "cunica-installer"
$zipPath = Join-Path $OutputDir "cunica-installer.zip"

if (Test-Path -LiteralPath $staging) {
    Remove-Item -LiteralPath $staging -Recurse -Force
}
New-Item -ItemType Directory -Force -Path (Join-Path $staging "scripts\lib") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $staging "templates") | Out-Null

Copy-Item -LiteralPath (Join-Path $repoRoot "scripts\install-cunica.ps1") -Destination (Join-Path $staging "scripts\install-cunica.ps1")
Copy-Item -LiteralPath (Join-Path $repoRoot "scripts\cunica-init.ps1") -Destination (Join-Path $staging "scripts\cunica-init.ps1")
Copy-Item -LiteralPath (Join-Path $repoRoot "scripts\lib\cunica-common.ps1") -Destination (Join-Path $staging "scripts\lib\cunica-common.ps1")
Copy-Item -LiteralPath (Join-Path $repoRoot "unica-contract.json") -Destination (Join-Path $staging "unica-contract.json")
Copy-Item -LiteralPath (Join-Path $repoRoot "templates\1c-unica.mdc") -Destination (Join-Path $staging "templates\1c-unica.mdc")
Copy-Item -LiteralPath (Join-Path $repoRoot "templates\1c-unica-version-check.mdc") -Destination (Join-Path $staging "templates\1c-unica-version-check.mdc")

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($staging, $zipPath)

if (-not (Test-Path -LiteralPath $zipPath)) {
    throw "Failed to create installer zip: $zipPath"
}

Write-Output "==> Built: $zipPath"
