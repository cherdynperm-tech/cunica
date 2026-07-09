param(
    [string]$Version = "latest",
    [ValidateSet("", "win-x64", "darwin-arm64", "linux-x64")]
    [string]$Target = "",
    [string]$ArchivePath = "",
    [switch]$Update,
    [switch]$Status,
    [switch]$Uninstall,
    [switch]$Verify,
    [switch]$AgentCheck,
    [switch]$AgentUpdate,
    [switch]$StrictVersion,
    [switch]$SkipVerify,
    [switch]$PrintDownloadUrl
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$lib = Join-Path $PSScriptRoot "lib\cunica-common.ps1"
if (-not (Test-Path -LiteralPath $lib)) {
    throw "Missing library: $lib"
}
. $lib
Set-CunicaContractPath -Path (Join-Path (Split-Path $PSScriptRoot -Parent) "unica-contract.json")
$globalRuleTemplate = Join-Path (Split-Path $PSScriptRoot -Parent) "templates\1c-unica-version-check.mdc"

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
        Install-CunicaRelease -Version "latest" -Target $Target -ArchivePath $ArchivePath -GlobalRuleSourcePath $globalRuleTemplate -SkipVerify:$SkipVerify | Out-Null
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

    Install-CunicaRelease -Version $latest -Target ([string]$manifest.target) -ArchivePath $ArchivePath -GlobalRuleSourcePath $globalRuleTemplate -SkipVerify:$SkipVerify | Out-Null
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

Install-CunicaRelease -Version $Version -Target $Target -ArchivePath $ArchivePath -GlobalRuleSourcePath $globalRuleTemplate -SkipVerify:$SkipVerify | Out-Null
