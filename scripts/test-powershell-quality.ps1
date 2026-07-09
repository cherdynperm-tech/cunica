param(
    [switch]$SkipSmoke,
    [switch]$RequireScriptAnalyzer
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$repoRoot = Split-Path $PSScriptRoot -Parent
$scriptFiles = Get-ChildItem -LiteralPath (Join-Path $repoRoot "scripts") -Filter "*.ps1" -Recurse |
    Sort-Object FullName

if ($scriptFiles.Count -eq 0) {
    throw "No PowerShell scripts found under scripts/"
}

$entryScripts = @(
    (Join-Path $repoRoot "scripts\install-cunica.ps1"),
    (Join-Path $repoRoot "scripts\cunica-init.ps1"),
    (Join-Path $repoRoot "scripts\test-powershell-quality.ps1")
)

$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string]$Message)
    $failures.Add($Message) | Out-Null
    Write-Host "FAIL: $Message" -ForegroundColor Red
}

function Add-Pass {
    param([string]$Message)
    Write-Host "PASS: $Message" -ForegroundColor Green
}

Write-Host "==> PowerShell quality checks"
Write-Host "Scripts: $($scriptFiles.Count)"

foreach ($file in $scriptFiles) {
    $relative = $file.FullName.Substring($repoRoot.Length + 1)
    try {
        $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
        [void][ScriptBlock]::Create($content)
        Add-Pass "syntax: $relative"
    } catch {
        Add-Failure "syntax: $relative -> $($_.Exception.Message)"
    }

    if ($content -match '(?m)^\s*catch\s*\{\s*\}\s*$') {
        Add-Failure "empty catch block: $relative"
    } else {
        Add-Pass "no empty catch: $relative"
    }
}

foreach ($entry in $entryScripts) {
    if (-not (Test-Path -LiteralPath $entry)) { continue }
    $relative = $entry.Substring($repoRoot.Length + 1)
    $content = Get-Content -LiteralPath $entry -Raw -Encoding UTF8
    if ($content -notmatch '\$ErrorActionPreference\s*=\s*["'']Stop["'']') {
        Add-Failure "missing ErrorActionPreference Stop: $relative"
    } else {
        Add-Pass "ErrorActionPreference Stop: $relative"
    }
    if ($content -notmatch 'Set-StrictMode\s+-Version\s+2\.0') {
        Add-Failure "missing Set-StrictMode 2.0: $relative"
    } else {
        Add-Pass "Set-StrictMode 2.0: $relative"
    }
}

$libPath = Join-Path $repoRoot "scripts\lib\cunica-common.ps1"
. $libPath
if ((Normalize-UnicaVersion -Version "v0.6.1") -ne "0.6.1") {
    Add-Failure "Normalize-UnicaVersion: v0.6.1 -> 0.6.1"
} else {
    Add-Pass "Normalize-UnicaVersion: v0.6.1 -> 0.6.1"
}
if ((Get-GitHubReleaseTag -Version "0.6.1") -ne "v0.6.1") {
    Add-Failure "Get-GitHubReleaseTag: 0.6.1 -> v0.6.1"
} else {
    Add-Pass "Get-GitHubReleaseTag: 0.6.1 -> v0.6.1"
}

if (-not $SkipSmoke) {
    $installer = Join-Path $repoRoot "scripts\install-cunica.ps1"
    $status = & powershell -NoProfile -ExecutionPolicy Bypass -File $installer -Status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Add-Failure "smoke -Status exited with code $LASTEXITCODE"
    } else {
        Add-Pass "smoke -Status"
    }

    $url = & powershell -NoProfile -ExecutionPolicy Bypass -File $installer -PrintDownloadUrl 2>&1
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($url | Out-String).Trim())) {
        Add-Failure "smoke -PrintDownloadUrl failed"
    } else {
        Add-Pass "smoke -PrintDownloadUrl"
    }

    $prevErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $verifyOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $installer -Verify 2>&1
        $verifyExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevErrorAction
    }
    if ($verifyExitCode -eq 0) {
        Add-Pass "smoke -Verify (installed)"
    } elseif (($verifyOutput | Out-String) -match 'Unica is not installed') {
        Add-Pass "smoke -Verify (expected not-installed error)"
    } else {
        Add-Failure "smoke -Verify unexpected failure: $($verifyOutput | Out-String)"
    }
}

if (Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue) {
    $analyzerIssues = Invoke-ScriptAnalyzer -Path (Join-Path $repoRoot "scripts") -Recurse -Severity Warning, Error
    if ($analyzerIssues.Count -gt 0) {
        foreach ($issue in $analyzerIssues) {
            Add-Failure "PSScriptAnalyzer $($issue.RuleName) @ $($issue.ScriptName):$($issue.Line) - $($issue.Message)"
        }
    } else {
        Add-Pass "PSScriptAnalyzer: no Warning/Error issues"
    }
} elseif ($RequireScriptAnalyzer) {
    Add-Failure "PSScriptAnalyzer is required but not installed"
} else {
    Write-Host "SKIP: PSScriptAnalyzer not installed" -ForegroundColor Yellow
}

Write-Host ""
if ($failures.Count -gt 0) {
    Write-Host "Quality checks failed: $($failures.Count)" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}

Write-Host "All PowerShell quality checks passed." -ForegroundColor Green
exit 0
