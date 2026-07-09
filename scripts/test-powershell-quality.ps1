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
    (Join-Path $repoRoot "scripts\build-installer-zip.ps1"),
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

    if ($content -match '[\u0400-\u04FF]') {
        Add-Failure "non-English (Cyrillic) text in script: $relative"
    } else {
        Add-Pass "english-only script text: $relative"
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

function Test-CunicaBoundSwitchPresent {
    param($Value)

    return ($Value -is [System.Management.Automation.SwitchParameter] -and $Value.IsPresent)
}

function Get-CunicaBoundForwardArgs {
    param([hashtable]$BoundParameters)

    $forward = @()
    foreach ($entry in $BoundParameters.GetEnumerator()) {
        $name = [string]$entry.Key
        $value = $entry.Value
        if (Test-CunicaBoundSwitchPresent -Value $value) {
            $forward += "-$name"
        } elseif ($null -ne $value -and "$value".Length -gt 0) {
            $forward += "-$name", "$value"
        }
    }
    return $forward
}

$forwardTest = {
    param(
        [switch]$Quiet,
        [switch]$AgentInstall,
        [switch]$Verify,
        [string]$ProjectDir = ""
    )
    Get-CunicaBoundForwardArgs -BoundParameters $PSBoundParameters
}
$forwardArgs = & $forwardTest -AgentInstall -Quiet -Verify -ProjectDir "C:\proj"
if ($forwardArgs -notcontains "-AgentInstall" -or $forwardArgs -notcontains "-Quiet" -or $forwardArgs -notcontains "-Verify") {
    Add-Failure "bootstrap forward: switch parameters not forwarded"
} elseif ($forwardArgs -notcontains "-ProjectDir" -or $forwardArgs -notcontains "C:\proj") {
    Add-Failure "bootstrap forward: string parameters not forwarded"
} else {
    Add-Pass "bootstrap forward: switch and string parameters"
}

$installScriptPath = Join-Path $repoRoot "scripts\install-cunica.ps1"
$installScriptContent = Get-Content -LiteralPath $installScriptPath -Raw -Encoding UTF8
if ($installScriptContent -notmatch 'Test-BoundSwitchPresent') {
    Add-Failure "install-cunica.ps1: missing Test-BoundSwitchPresent helper"
} elseif ($installScriptContent -match '\$value\s+-is\s+\[switch\]') {
    Add-Failure "install-cunica.ps1: bootstrap forward still uses -is [switch]"
} else {
    Add-Pass "install-cunica.ps1: bootstrap switch forwarding helper"
}

$commonContent = Get-Content -LiteralPath $libPath -Raw -Encoding UTF8
if ($commonContent -notmatch 'function Ensure-CunicaInstallerBundle\s*\{[^\}]*param\(\[switch\]\$Quiet\)') {
    Add-Failure "Ensure-CunicaInstallerBundle: missing -Quiet parameter"
} elseif ($commonContent -notmatch 'Invoke-DownloadFile -Url \$zipUrl -Destination \$zipPath -Quiet:\$Quiet') {
    Add-Failure "Ensure-CunicaInstallerBundle: Invoke-DownloadFile must use -Quiet:`$Quiet"
} else {
    Add-Pass "Ensure-CunicaInstallerBundle: respects -Quiet for download"
}

$tmp1c = Join-Path $env:TEMP ("cunica-1c-test-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path (Join-Path $tmp1c "src") | Out-Null
"<?xml version=`"1.0`"?>" | Out-File -LiteralPath (Join-Path $tmp1c "src\Configuration.xml") -Encoding utf8
if (-not (Test-OneCProjectDir -Path $tmp1c)) {
    Add-Failure "Test-OneCProjectDir: expected true for src/Configuration.xml"
} else {
    Add-Pass "Test-OneCProjectDir: src/Configuration.xml"
}
Remove-Item -LiteralPath $tmp1c -Recurse -Force -ErrorAction SilentlyContinue

$tmpEmpty = Join-Path $env:TEMP ("cunica-empty-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tmpEmpty | Out-Null
if (Test-OneCProjectDir -Path $tmpEmpty) {
    Add-Failure "Test-OneCProjectDir: expected false for empty dir"
} else {
    Add-Pass "Test-OneCProjectDir: empty dir"
}
Remove-Item -LiteralPath $tmpEmpty -Recurse -Force -ErrorAction SilentlyContinue

$prevLogDisabled = $script:CunicaInstallLogDisabled
$script:CunicaInstallLogDisabled = $false
$script:CunicaLogPath = $null
$script:CunicaLogOwner = $null
$testLog = Start-CunicaInstallLog -Context "quality-test" -Metadata @{ test = "1" }
if (-not $testLog -or -not (Test-Path -LiteralPath $testLog)) {
    Add-Failure "Start-CunicaInstallLog: log file not created"
} else {
    Write-CunicaInstallLog -Message "quality-check"
    Complete-CunicaInstallLog -Status "completed" -Context "quality-test"
    $logContent = Get-Content -LiteralPath $testLog -Raw -Encoding UTF8
    if ($logContent -notmatch "quality-check") {
        Add-Failure "Write-CunicaInstallLog: message missing in log"
    } else {
        Add-Pass "install log session"
    }
    Remove-Item -LiteralPath $testLog -Force -ErrorAction SilentlyContinue
}
$script:CunicaInstallLogDisabled = $prevLogDisabled
$script:CunicaLogPath = $null
$script:CunicaLogOwner = $null

$buildZip = Join-Path $repoRoot "scripts\build-installer-zip.ps1"
if (Test-Path -LiteralPath $buildZip) {
  $buildOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $buildZip 2>&1
  if ($LASTEXITCODE -ne 0) {
    Add-Failure "build-installer-zip.ps1 failed: $($buildOutput | Out-String)"
  } else {
    $zipPath = Join-Path $repoRoot "dist\cunica-installer.zip"
    if (-not (Test-Path -LiteralPath $zipPath)) {
      Add-Failure "missing dist/cunica-installer.zip"
    } else {
      Add-Pass "build-installer-zip.ps1"
      Add-Pass "dist/cunica-installer.zip exists"
    }
  }
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
