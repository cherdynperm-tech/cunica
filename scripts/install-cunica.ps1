param(
    [string]$Version = "latest",
    [ValidateSet("", "win-x64", "darwin-arm64", "linux-x64")]
    [string]$Target = "",
    [string]$ArchivePath = "",
    [string]$ProjectDir = "",
    [switch]$Update,
    [switch]$Status,
    [switch]$Uninstall,
    [switch]$Verify,
    [switch]$AgentCheck,
    [switch]$AgentUpdate,
    [switch]$AgentInstall,
    [switch]$StrictVersion,
    [switch]$SkipVerify,
    [switch]$PrintDownloadUrl,
    [switch]$Quiet,
    [switch]$NoInstallLog
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

function Test-BoundSwitchPresent {
    param($Value)

    return ($Value -is [System.Management.Automation.SwitchParameter] -and $Value.IsPresent)
}

function Test-BoundParametersQuiet {
    param([hashtable]$BoundParameters)

    if (-not $BoundParameters.ContainsKey("Quiet")) {
        return $false
    }
    return (Test-BoundSwitchPresent -Value $BoundParameters["Quiet"])
}

function Invoke-InstallerBootstrapForward {
    param([hashtable]$BoundParameters)

    $installerHome = if ($env:CUNICA_INSTALLER_PATH) {
        $env:CUNICA_INSTALLER_PATH
    } elseif ($env:USERPROFILE) {
        Join-Path $env:USERPROFILE ".cunica\installer"
    } else {
        throw "CUNICA_INSTALLER_PATH or USERPROFILE is required for installer bootstrap."
    }

    $targetScript = Join-Path $installerHome "scripts\install-cunica.ps1"
    $targetLib = Join-Path $installerHome "scripts\lib\cunica-common.ps1"
    if (-not (Test-Path -LiteralPath $targetLib)) {
        $zipUrl = if ($env:CUNICA_INSTALLER_ZIP_URL) {
            $env:CUNICA_INSTALLER_ZIP_URL
        } else {
            "https://github.com/cherdynperm-tech/cunica/releases/latest/download/cunica-installer.zip"
        }
        if (-not (Test-Path -LiteralPath $installerHome)) {
            New-Item -ItemType Directory -Path $installerHome -Force | Out-Null
        }
        $zipPath = Join-Path $env:TEMP ("cunica-installer-" + [Guid]::NewGuid().ToString("N") + ".zip")
        $bootstrapQuiet = Test-BoundParametersQuiet -BoundParameters $BoundParameters
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
                if ($bootstrapQuiet) {
                    & curl.exe -fsSL --retry 5 --retry-delay 3 --http1.1 "$zipUrl" -o "$zipPath"
                } else {
                    & curl.exe -fL --retry 5 --retry-delay 3 --http1.1 "$zipUrl" -o "$zipPath"
                }
                if ($LASTEXITCODE -ne 0) {
                    throw "curl.exe exited with code $LASTEXITCODE while downloading installer bundle."
                }
            } else {
                Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
            }
            Expand-Archive -LiteralPath $zipPath -DestinationPath $installerHome -Force
        } finally {
            if (Test-Path -LiteralPath $zipPath) {
                Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    if (-not (Test-Path -LiteralPath $targetScript)) {
        throw "Installer bootstrap failed. Expected: $targetScript"
    }

    $forward = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $targetScript)
    foreach ($entry in $BoundParameters.GetEnumerator()) {
        $name = [string]$entry.Key
        $value = $entry.Value
        if (Test-BoundSwitchPresent -Value $value) {
            $forward += "-$name"
        } elseif ($null -ne $value -and "$value".Length -gt 0) {
            $forward += "-$name", "$value"
        }
    }

    & powershell @forward
    exit $LASTEXITCODE
}

$lib = Join-Path $PSScriptRoot "lib\cunica-common.ps1"
if (-not (Test-Path -LiteralPath $lib)) {
    Invoke-InstallerBootstrapForward -BoundParameters $PSBoundParameters
}

. $lib
if ($NoInstallLog) {
    $script:CunicaInstallLogDisabled = $true
}
Set-CunicaContractPath -Path (Join-Path (Split-Path $PSScriptRoot -Parent) "unica-contract.json")
$globalRuleTemplate = Join-Path (Split-Path $PSScriptRoot -Parent) "templates\1c-unica-version-check.mdc"
$installerScriptPath = (Resolve-Path -LiteralPath $PSCommandPath).Path

if ($env:UNICA_VERSION -and $Version -eq "latest" -and -not $Update) {
    $Version = $env:UNICA_VERSION
}

if ($AgentCheck) {
    $Verify = $true
    if (-not $PSBoundParameters.ContainsKey("StrictVersion")) {
        $StrictVersion = $true
    }
}
if ($AgentUpdate) {
    $Update = $true
}

if ($PrintDownloadUrl) {
    $resolvedTarget = Get-CunicaTarget -Override $Target
    Write-Output (Get-ReleaseAssetUrl -Target $resolvedTarget -Version $Version)
    exit 0
}

if ($AgentInstall) {
    if ($Quiet) {
        $script:DownloadQuiet = $true
    }
    $resolvedProjectDir = if ($ProjectDir) {
        $ProjectDir
    } elseif ($env:CURSOR_WORKSPACE -and (Test-Path -LiteralPath $env:CURSOR_WORKSPACE)) {
        $env:CURSOR_WORKSPACE
    } else {
        (Get-Location).Path
    }
    $localLib = Join-Path $PSScriptRoot "lib\cunica-common.ps1"
    $activeInstaller = if (Test-Path -LiteralPath $localLib) {
        $installerScriptPath
    } else {
        Ensure-CunicaInstallerBundle -Quiet:$Quiet
    }
    Invoke-CunicaAgentInstall `
        -ProjectDir $resolvedProjectDir `
        -InstallerScriptPath $activeInstaller `
        -GlobalRuleSourcePath $globalRuleTemplate `
        -Quiet:$Quiet
    exit 0
}

if ($Verify) {
    Verify-InstalledUnicaContract -StrictVersion:$StrictVersion
    exit 0
}

if ($Status) {
    Show-CunicaStatus
    exit 0
}

if ($Uninstall) {
    Uninstall-Cunica
    exit 0
}

if ($Update) {
    $manifest = Read-CunicaManifest
    if (-not $manifest) {
        Write-Output "Unica is not installed. Installing latest..."
        Install-CunicaRelease -Version "latest" -Target $Target -ArchivePath $ArchivePath -GlobalRuleSourcePath $globalRuleTemplate -SkipVerify:$SkipVerify -Quiet:$Quiet | Out-Null
        exit 0
    }

    $latest = Get-LatestReleaseTag
    if ($latest -eq $manifest.version) {
        Write-Output "==> Already up to date: $($manifest.version)"
        exit 0
    }

    $releaseDir = Join-Path (Get-CunicaHome) (Join-Path "releases" $latest)
    if (Test-Path -LiteralPath $releaseDir) {
        Switch-CunicaVersion -Version $latest -GlobalRuleSourcePath $globalRuleTemplate
        exit 0
    }

    Install-CunicaRelease -Version $latest -Target ([string]$manifest.target) -ArchivePath $ArchivePath -GlobalRuleSourcePath $globalRuleTemplate -SkipVerify:$SkipVerify -Quiet:$Quiet | Out-Null
    exit 0
}

if ($Version -ne "latest") {
    $normalizedVersion = Normalize-UnicaVersion -Version $Version
    $releaseDir = Join-Path (Get-CunicaHome) (Join-Path "releases" $normalizedVersion)
    if (Test-Path -LiteralPath $releaseDir) {
        Switch-CunicaVersion -Version $normalizedVersion -GlobalRuleSourcePath $globalRuleTemplate
        exit 0
    }
    $Version = $normalizedVersion
}

Install-CunicaRelease -Version $Version -Target $Target -ArchivePath $ArchivePath -GlobalRuleSourcePath $globalRuleTemplate -SkipVerify:$SkipVerify -Quiet:$Quiet | Out-Null
