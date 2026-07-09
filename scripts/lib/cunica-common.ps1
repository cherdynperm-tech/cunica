# Shared helpers for Cunica (Unica adapter for Cursor).

$script:CunicaRepo = if ($env:UNICA_REPO) { $env:UNICA_REPO } else { "IngvarConsulting/unica" }
$script:CunicaProjectRepo = if ($env:CUNICA_PROJECT_REPO) { $env:CUNICA_PROJECT_REPO } else { "cherdynperm-tech/cunica" }
$script:CunicaHomeName = ".cunica"
$script:CunicaInstallerDirName = "installer"
$script:CunicaInstallerZipName = "cunica-installer.zip"
$script:CursorHomeName = ".cursor"
$script:SkillPrefix = "unica-"
$script:McpServerName = "unica"
$script:CunicaContractPath = $null
$script:GlobalPlanningRuleName = "1c-unica-version-check.mdc"
$script:DownloadQuiet = $false
$script:CunicaLogDirName = "logs"
$script:CunicaLogPath = $null
$script:CunicaInstallLogDisabled = $false
$script:CunicaLogOwner = $null

function Set-CunicaContractPath {
    param([string]$Path)
    $script:CunicaContractPath = $Path
}

function Get-CunicaContractPath {
    if ($script:CunicaContractPath -and (Test-Path -LiteralPath $script:CunicaContractPath)) {
        return (Resolve-Path -LiteralPath $script:CunicaContractPath).Path
    }
    if ($env:CUNICA_CONTRACT_PATH -and (Test-Path -LiteralPath $env:CUNICA_CONTRACT_PATH)) {
        return (Resolve-Path -LiteralPath $env:CUNICA_CONTRACT_PATH).Path
    }
    $fromLib = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "unica-contract.json"
    if (Test-Path -LiteralPath $fromLib) {
        return (Resolve-Path -LiteralPath $fromLib).Path
    }
    $fromScripts = Join-Path (Split-Path $PSScriptRoot -Parent) "unica-contract.json"
    if (Test-Path -LiteralPath $fromScripts) {
        return (Resolve-Path -LiteralPath $fromScripts).Path
    }
    throw @"
Missing unica-contract.json.

Expected at repository root: unica-contract.json
Or set CUNICA_CONTRACT_PATH to the contract file.
"@
}

function Get-CunicaContract {
    $path = Get-CunicaContractPath
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Normalize-UnicaVersion {
    param([string]$Version)
    $v = $Version.Trim()
    if ($v.StartsWith("v", [StringComparison]::OrdinalIgnoreCase)) {
        return $v.Substring(1)
    }
    return $v
}

function Get-GitHubReleaseTag {
    param([string]$Version)
    if ($Version -eq "latest") { return "latest" }
    $normalized = Normalize-UnicaVersion -Version $Version
    return "v$normalized"
}

function Test-UnicaVersionMismatch {
    param(
        [string]$InstalledVersion,
        [object]$Contract
    )
    $installed = Normalize-UnicaVersion -Version $InstalledVersion
    $expected = Normalize-UnicaVersion -Version ([string]$Contract.developmentVersion)
    return ($installed -ne $expected)
}

function Write-UnicaVersionWarning {
    param(
        [string]$InstalledVersion,
        [object]$Contract
    )
    $expected = [string]$Contract.developmentVersion
    Write-Warning @"
Unica version mismatch: cunica is developed for $expected, but installed version is $InstalledVersion.
Some features may not work until you install Unica $expected or update unica-contract.json for the new Unica layout.
"@
}

function Assert-UnicaContract {
    param(
        [string]$PluginRoot,
        [string]$MarketplaceDir = "",
        [string]$Target,
        [string]$InstalledVersion,
        [switch]$StrictVersion
    )

    $contract = Get-CunicaContract

    if (Test-UnicaVersionMismatch -InstalledVersion $InstalledVersion -Contract $contract) {
        if ($StrictVersion) {
            throw @"
Unica version mismatch: cunica is developed for $($contract.developmentVersion), but installed version is $InstalledVersion.
Install matching Unica version or update unica-contract.json in the cunica repository.
"@
        }
        Write-UnicaVersionWarning -InstalledVersion $InstalledVersion -Contract $contract
    }

    if ($MarketplaceDir) {
        $markerRel = [string]$contract.marketplace.marker
        $marker = Join-Path $MarketplaceDir $markerRel
        if (-not (Test-Path -LiteralPath $marker)) {
            throw "Missing required Unica marketplace file: $markerRel (expected at $marker)"
        }
    }

    foreach ($rel in @($contract.requiredPluginFiles)) {
        $full = Join-Path $PluginRoot ([string]$rel)
        if (-not (Test-Path -LiteralPath $full)) {
            throw "Missing required Unica file: $rel (expected at $full)"
        }
    }

    foreach ($rel in @($contract.requiredPluginDirectories)) {
        $full = Join-Path $PluginRoot ([string]$rel)
        if (-not (Test-Path -LiteralPath $full)) {
            throw "Missing required Unica directory: $rel (expected at $full)"
        }
    }

    foreach ($bin in @($contract.requiredBinaries)) {
        $full = Get-ToolBinary -PluginRoot $PluginRoot -Target $Target -Tool ([string]$bin)
        if (-not (Test-Path -LiteralPath $full)) {
            throw "Missing required Unica binary: bin/$Target/$bin (expected at $full)"
        }
    }

    foreach ($skill in @($contract.requiredSkills)) {
        $skillName = [string]$skill
        $skillMd = Join-Path $PluginRoot (Join-Path "skills" (Join-Path $skillName "SKILL.md"))
        if (-not (Test-Path -LiteralPath $skillMd)) {
            throw "Missing required Unica skill: skills/$skillName/SKILL.md (expected at $skillMd)"
        }
    }

    return $contract
}

function Verify-InstalledUnicaContract {
    param([switch]$StrictVersion)

    $manifest = Read-CunicaManifest
    if (-not $manifest) {
        throw "Unica is not installed."
    }

    $pluginRoot = Get-CurrentPluginRoot
    $releaseDir = [string]$manifest.releaseDir
    if (-not $releaseDir -or -not (Test-Path -LiteralPath $releaseDir)) {
        $releaseDir = Split-Path -Parent (Split-Path -Parent $pluginRoot)
    }

    $contract = Assert-UnicaContract `
        -PluginRoot $pluginRoot `
        -MarketplaceDir $releaseDir `
        -Target ([string]$manifest.target) `
        -InstalledVersion ([string]$manifest.version) `
        -StrictVersion:$StrictVersion

    Write-Output "Contract OK for Unica $($manifest.version) (cunica targets $($contract.developmentVersion))"
}

function Install-GlobalPlanningRule {
    param([string]$RuleSourcePath)

    if (-not (Test-Path -LiteralPath $RuleSourcePath)) {
        throw "Missing global planning rule template: $RuleSourcePath"
    }
    $rulesDir = Join-Path (Get-CursorHome) "rules"
    if (-not (Test-Path -LiteralPath $rulesDir)) {
        New-Item -ItemType Directory -Path $rulesDir -Force | Out-Null
    }
    $ruleDest = Join-Path $rulesDir $script:GlobalPlanningRuleName
    Copy-Item -LiteralPath $RuleSourcePath -Destination $ruleDest -Force
    return $ruleDest
}

function Remove-GlobalPlanningRule {
    $ruleDest = Join-Path (Join-Path (Get-CursorHome) "rules") $script:GlobalPlanningRuleName
    if (Test-Path -LiteralPath $ruleDest) {
        Remove-Item -LiteralPath $ruleDest -Force
    }
}

function Get-CunicaHome {
    if ($env:CUNICA_HOME) { return $env:CUNICA_HOME }
    if ($env:USERPROFILE) { return Join-Path $env:USERPROFILE $script:CunicaHomeName }
    if ($env:HOME) { return Join-Path $env:HOME $script:CunicaHomeName }
    throw "CUNICA_HOME, USERPROFILE, or HOME is required."
}

function Get-CursorHome {
    if ($env:CURSOR_HOME) { return $env:CURSOR_HOME }
    if ($env:USERPROFILE) { return Join-Path $env:USERPROFILE $script:CursorHomeName }
    if ($env:HOME) { return Join-Path $env:HOME $script:CursorHomeName }
    throw "CURSOR_HOME, USERPROFILE, or HOME is required."
}

function Get-CunicaTarget {
    param([string]$Override = "")
    if ($Override) { return $Override }
    if ($env:CUNICA_TARGET) { return $env:CUNICA_TARGET }
    if ($env:OS -match "Windows") { return "win-x64" }
    $uname = & uname -s 2>$null
    $arch = & uname -m 2>$null
    switch ("$uname-$arch") {
        { $_ -match "Darwin-(arm64|aarch64)" } { return "darwin-arm64" }
        { $_ -match "Linux-(x86_64|amd64)" } { return "linux-x64" }
        default { throw "Unsupported platform: $uname-$arch" }
    }
}

function Get-ArchiveExtension {
    param([string]$Target)
    switch ($Target) {
        "win-x64" { return "zip" }
        "darwin-arm64" { return "tar.gz" }
        "linux-x64" { return "tar.gz" }
        default { throw "Unsupported Unica release target: $Target" }
    }
}

function Get-ReleaseAssetUrl {
    param(
        [string]$Target,
        [string]$Version
    )
    $ext = Get-ArchiveExtension -Target $Target
    $asset = "unica-codex-marketplace-$Target.$ext"
    if ($Version -eq "latest") {
        return "https://github.com/$script:CunicaRepo/releases/latest/download/$asset"
    }
    $tag = Get-GitHubReleaseTag -Version $Version
    return "https://github.com/$script:CunicaRepo/releases/download/$tag/$asset"
}

function Get-LatestReleaseTag {
    $uri = "https://api.github.com/repos/$script:CunicaRepo/releases/latest"
    try {
        $response = Invoke-RestMethod -Uri $uri -UseBasicParsing
        return Normalize-UnicaVersion -Version ([string]$response.tag_name)
    } catch {
        throw "Failed to fetch latest Unica release from GitHub: $_"
    }
}

function Write-Utf8NoBomFile {
    param(
        [string]$Path,
        [string]$Content
    )
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Get-CunicaInstallerHome {
    if ($env:CUNICA_INSTALLER_PATH) {
        return (Resolve-Path -LiteralPath $env:CUNICA_INSTALLER_PATH).Path
    }
    return Join-Path (Get-CunicaHome) $script:CunicaInstallerDirName
}

function Get-CunicaInstallerScriptPath {
    return Join-Path (Get-CunicaInstallerHome) (Join-Path "scripts" "install-cunica.ps1")
}

function Get-CunicaInstallerZipUrl {
    if ($env:CUNICA_INSTALLER_ZIP_URL) {
        return $env:CUNICA_INSTALLER_ZIP_URL
    }
    return "https://github.com/$($script:CunicaProjectRepo)/releases/latest/download/$($script:CunicaInstallerZipName)"
}

function Test-OneCProjectDir {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) {
        return $false
    }
    if (Test-Path -LiteralPath (Join-Path $Path "src\Configuration.xml")) {
        return $true
    }
    if (Test-Path -LiteralPath (Join-Path $Path "Configuration.xml")) {
        return $true
    }
    $srcDir = Join-Path $Path "src"
    if (Test-Path -LiteralPath $srcDir) {
        $bsl = Get-ChildItem -LiteralPath $srcDir -Filter "*.bsl" -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($bsl) {
            return $true
        }
    }
    return $false
}

function Test-CunicaProjectInitialized {
    param([string]$Path)
    $mcpPath = Join-Path $Path (Join-Path ".cursor" "mcp.json")
    if (-not (Test-Path -LiteralPath $mcpPath)) {
        return $false
    }
    $raw = Get-Content -LiteralPath $mcpPath -Raw -Encoding UTF8
    return ($raw -match '"unica"')
}

function Test-CunicaInstallLogEnabled {
    if ($script:CunicaInstallLogDisabled) {
        return $false
    }
    if ($env:CUNICA_INSTALL_LOG -match '^(0|false|off|no)$') {
        return $false
    }
    return $true
}

function Get-CunicaLogDir {
    $dir = Join-Path (Get-CunicaHome) $script:CunicaLogDirName
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return $dir
}

function Get-CunicaInstallLogPath {
    return $script:CunicaLogPath
}

function Write-CunicaInstallLog {
    param(
        [string]$Message,
        [switch]$SkipTimestampPrefix
    )
    if (-not (Test-CunicaInstallLogEnabled)) {
        return
    }
    if (-not $script:CunicaLogPath) {
        return
    }
    $line = if ($SkipTimestampPrefix) {
        $Message
    } else {
        "[{0}] {1}" -f (Get-Date).ToUniversalTime().ToString("o"), $Message
    }
    $payload = $line + [Environment]::NewLine
    [System.IO.File]::AppendAllText($script:CunicaLogPath, $payload, [System.Text.UTF8Encoding]::new($false))
}

function Start-CunicaInstallLog {
    param(
        [string]$Context = "install",
        [hashtable]$Metadata = @{}
    )
    if (-not (Test-CunicaInstallLogEnabled)) {
        return $null
    }
    if ($script:CunicaLogPath) {
        return $script:CunicaLogPath
    }

    $stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
    $fileName = "install-$stamp-$PID-$Context.log"
    $path = Join-Path (Get-CunicaLogDir) $fileName
    $script:CunicaLogPath = $path
    $script:CunicaLogOwner = $Context

    Write-CunicaInstallLog -Message "=== Cunica install session started ===" -SkipTimestampPrefix
    Write-CunicaInstallLog -Message "context=$Context"
    Write-CunicaInstallLog -Message "user=$env:USERNAME computer=$env:COMPUTERNAME"
    foreach ($entry in $Metadata.GetEnumerator()) {
        Write-CunicaInstallLog -Message ("{0}={1}" -f $entry.Key, $entry.Value)
    }
    return $path
}

function Complete-CunicaInstallLog {
    param(
        [string]$Status = "completed",
        [string]$Context = ""
    )
    if (-not $script:CunicaLogPath) {
        return
    }
    if ($Context -and $script:CunicaLogOwner -and $script:CunicaLogOwner -ne $Context) {
        return
    }
    Write-CunicaInstallLog -Message "=== session $Status ==="
    $script:CunicaLogPath = $null
    $script:CunicaLogOwner = $null
}

function Write-InstallOutput {
    param([string]$Message)
    Write-Output $Message
    Write-CunicaInstallLog -Message $Message
}

function Write-CunicaAgentResult {
    param(
        [string]$Result,
        [string]$Version = "",
        [string]$Target = "",
        [string]$ProjectInit = "not_applicable",
        [string]$InstallerPath = "",
        [string]$LogPath = ""
    )
    Write-Output "CUNICA_RESULT=$Result"
    if ($Version) {
        Write-Output "CUNICA_VERSION=$Version"
    }
    if ($Target) {
        Write-Output "CUNICA_TARGET=$Target"
    }
    Write-Output "CUNICA_PROJECT_INIT=$ProjectInit"
    if ($InstallerPath) {
        Write-Output "CUNICA_INSTALLER=$InstallerPath"
    }
    $resolvedLogPath = if ($LogPath) { $LogPath } else { $script:CunicaLogPath }
    if ($resolvedLogPath) {
        Write-Output "CUNICA_LOG_PATH=$resolvedLogPath"
        Write-CunicaInstallLog -Message "CUNICA_RESULT=$Result"
        if ($Version) {
            Write-CunicaInstallLog -Message "CUNICA_VERSION=$Version"
        }
        if ($Target) {
            Write-CunicaInstallLog -Message "CUNICA_TARGET=$Target"
        }
        Write-CunicaInstallLog -Message "CUNICA_PROJECT_INIT=$ProjectInit"
        Write-CunicaInstallLog -Message "CUNICA_LOG_PATH=$resolvedLogPath"
    }
}

function Ensure-CunicaInstallerBundle {
    param([switch]$Quiet)

    $installerHome = Get-CunicaInstallerHome
    $installerScript = Get-CunicaInstallerScriptPath
    $installerLib = Join-Path (Split-Path $installerScript -Parent) (Join-Path "lib" "cunica-common.ps1")
    if ((Test-Path -LiteralPath $installerScript) -and (Test-Path -LiteralPath $installerLib)) {
        return $installerScript
    }

    if (-not (Test-Path -LiteralPath $installerHome)) {
        New-Item -ItemType Directory -Path $installerHome -Force | Out-Null
    }

    $zipUrl = Get-CunicaInstallerZipUrl
    $zipPath = Join-Path ([System.IO.Path]::GetTempPath()) ("cunica-installer-" + [Guid]::NewGuid().ToString("N") + ".zip")
    try {
        Write-InstallOutput "==> Download installer bundle: $zipUrl"
        Invoke-DownloadFile -Url $zipUrl -Destination $zipPath -Quiet:$Quiet
        Write-CunicaInstallLog -Message "installer bundle downloaded: $zipPath"
        Expand-Archive -LiteralPath $zipPath -DestinationPath $installerHome -Force
        Write-CunicaInstallLog -Message "installer bundle extracted to: $installerHome"
    } finally {
        if (Test-Path -LiteralPath $zipPath) {
            Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not (Test-Path -LiteralPath $installerScript)) {
        throw "Installer bootstrap failed. Expected: $installerScript"
    }
    return $installerScript
}

function Invoke-CunicaAgentInstall {
    param(
        [string]$ProjectDir = "",
        [string]$InstallerScriptPath,
        [string]$GlobalRuleSourcePath = "",
        [switch]$Quiet
    )

    if ($Quiet) {
        $script:DownloadQuiet = $true
    }

    $logPath = Start-CunicaInstallLog -Context "agent-install" -Metadata @{
        installer = $InstallerScriptPath
        projectDir = $ProjectDir
        quiet      = [string]$Quiet.IsPresent
    }

    $result = "already_installed"
    $projectInit = "not_applicable"
    $sessionStatus = "completed"

    try {
        $manifestBefore = Read-CunicaManifest
        if ($manifestBefore) {
            Write-CunicaInstallLog -Message "manifest.version=$($manifestBefore.version)"
        } else {
            Write-CunicaInstallLog -Message "manifest=not_installed"
        }

        if (-not $manifestBefore) {
            Write-CunicaInstallLog -Message "action=install_latest"
            Install-CunicaRelease `
                -Version "latest" `
                -GlobalRuleSourcePath $GlobalRuleSourcePath `
                -Quiet:$Quiet | Out-Null
            $result = "installed"
        } else {
            $latest = Get-LatestReleaseTag
            Write-CunicaInstallLog -Message "latest_release=$latest"
            if ($latest -ne [string]$manifestBefore.version) {
                $releaseDir = Join-Path (Get-CunicaHome) (Join-Path "releases" $latest)
                if (Test-Path -LiteralPath $releaseDir) {
                    Write-CunicaInstallLog -Message "action=switch_cached version=$latest"
                    Switch-CunicaVersion -Version $latest -GlobalRuleSourcePath $GlobalRuleSourcePath
                } else {
                    Write-CunicaInstallLog -Message "action=install_update version=$latest"
                    Install-CunicaRelease `
                        -Version $latest `
                        -Target ([string]$manifestBefore.target) `
                        -GlobalRuleSourcePath $GlobalRuleSourcePath `
                        -Quiet:$Quiet | Out-Null
                }
                $result = "updated"
            } else {
                Write-CunicaInstallLog -Message "action=already_installed"
            }
        }

        $verifyLines = @(Verify-InstalledUnicaContract)
        foreach ($line in $verifyLines) {
            Write-CunicaInstallLog -Message "verify: $line"
        }

        $manifest = Read-CunicaManifest
        if (-not $manifest) {
            throw "Unica is not installed after agent install."
        }

        Write-CunicaManifest `
            -Version ([string]$manifest.version) `
            -Target ([string]$manifest.target) `
            -ReleaseDir ([string]$manifest.releaseDir) `
            -InstallerPath $InstallerScriptPath `
            -LastInstallLogPath $logPath

        if ($ProjectDir) {
            $projectDirResolved = (Resolve-Path -LiteralPath $ProjectDir).Path
            Write-CunicaInstallLog -Message "project_dir=$projectDirResolved"
            if (Test-OneCProjectDir -Path $projectDirResolved) {
                if (Test-CunicaProjectInitialized -Path $projectDirResolved) {
                    $projectInit = "done"
                } else {
                    $projectInit = "needed"
                }
            } else {
                $projectInit = "skipped"
            }
            Write-CunicaInstallLog -Message "project_init=$projectInit"
        }

        if ($logPath) {
            Write-InstallOutput "==> Install log: $logPath"
        }

        Write-CunicaAgentResult `
            -Result $result `
            -Version ([string]$manifest.version) `
            -Target ([string]$manifest.target) `
            -ProjectInit $projectInit `
            -InstallerPath $InstallerScriptPath `
            -LogPath $logPath
    } catch {
        $sessionStatus = "blocked"
        Write-CunicaInstallLog -Message ("error={0}" -f $_.Exception.Message)
        Write-CunicaAgentResult `
            -Result "blocked" `
            -ProjectInit "not_applicable" `
            -InstallerPath $InstallerScriptPath `
            -LogPath $logPath
        if ($logPath) {
            Write-InstallOutput "==> Install log: $logPath"
        }
        throw
    } finally {
        $script:DownloadQuiet = $false
        Complete-CunicaInstallLog -Status $sessionStatus -Context "agent-install"
    }
}

function Invoke-DownloadFile {
    param(
        [string]$Url,
        [string]$Destination,
        [switch]$Quiet
    )
    $errors = New-Object System.Collections.Generic.List[string]
    $useQuiet = $Quiet -or $script:DownloadQuiet

    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        if ($useQuiet) {
            & curl.exe -fsSL --retry 5 --retry-delay 3 --http1.1 "$Url" -o "$Destination"
        } else {
            & curl.exe -fL --retry 5 --retry-delay 3 --http1.1 "$Url" -o "$Destination"
        }
        if ($LASTEXITCODE -eq 0) { return }
        $errors.Add("curl.exe exited with code $LASTEXITCODE") | Out-Null
    }

    if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
        try {
            Start-BitsTransfer -Source $Url -Destination $Destination -ErrorAction Stop
            return
        } catch {
            $errors.Add("Start-BitsTransfer: $($_.Exception.Message)") | Out-Null
        }
    }

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {
        $errors.Add("TLS12 setup: $($_.Exception.Message)") | Out-Null
    }

    try {
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
        return
    } catch {
        $errors.Add("Invoke-WebRequest: $($_.Exception.Message)") | Out-Null
    }

    try {
        $client = New-Object System.Net.WebClient
        try {
            $client.DownloadFile($Url, $Destination)
            return
        } finally {
            $client.Dispose()
        }
    } catch {
        $errors.Add("WebClient: $($_.Exception.Message)") | Out-Null
    }

    $details = ($errors | ForEach-Object { "  - $_" }) -join [Environment]::NewLine
    throw @"
Failed to download: $Url
$details

If GitHub release downloads are blocked on your network, download the archive manually
from https://github.com/IngvarConsulting/unica/releases and run:

  install-cunica.ps1 -ArchivePath C:\path\to\unica-codex-marketplace-win-x64.zip
"@
}

function Find-MarketplaceRoot {
    param([string]$Root)
    $marker = Get-ChildItem -LiteralPath $Root -Filter "marketplace.json" -Recurse -ErrorAction SilentlyContinue |
        Where-Object {
            -not $_.PSIsContainer -and
            $_.FullName -match [regex]::Escape((Join-Path ".agents" (Join-Path "plugins" "marketplace.json")))
        } |
        Select-Object -First 1
    if (-not $marker) {
        throw "Downloaded archive does not contain .agents/plugins/marketplace.json"
    }
    return (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $marker.FullName)))
}

function Get-PluginRoot {
    param([string]$MarketplaceDir)
    return Join-Path $MarketplaceDir (Join-Path "plugins" "unica")
}

function Read-PluginVersion {
    param([string]$PluginJsonPath)
    $plugin = Get-Content -LiteralPath $PluginJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    return [string]$plugin.version
}

function Get-ToolBinary {
    param(
        [string]$PluginRoot,
        [string]$Target,
        [string]$Tool
    )
    $name = if ($Target -eq "win-x64") { "$Tool.exe" } else { $Tool }
    return Join-Path $PluginRoot (Join-Path "bin" (Join-Path $Target $name))
}

function Invoke-NativeChecked {
    param(
        [string]$Program,
        [string[]]$Arguments = @()
    )
    & $Program @Arguments | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "$Program exited with code $LASTEXITCODE"
    }
}

function Set-DirectoryLink {
    param(
        [string]$LinkPath,
        [string]$TargetPath
    )
    $parent = Split-Path -Parent $LinkPath
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if (Test-Path -LiteralPath $LinkPath) {
        Remove-Item -LiteralPath $LinkPath -Recurse -Force
    }
    $item = New-Item -ItemType SymbolicLink -Path $LinkPath -Target $TargetPath -ErrorAction SilentlyContinue
    if (-not $item) {
        cmd /c mklink /J "$LinkPath" "$TargetPath" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create link from '$LinkPath' to '$TargetPath'"
        }
    }
}

function Get-CurrentPluginRoot {
    $cunicaHomePath = Get-CunicaHome
    $current = Join-Path $cunicaHomePath "current"
    if (-not (Test-Path -LiteralPath $current)) {
        throw "Unica is not installed. Run install-cunica.ps1 first. Expected: $current"
    }
    return (Resolve-Path -LiteralPath $current).Path
}

function Read-CunicaManifest {
    $path = Join-Path (Get-CunicaHome) "manifest.json"
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Write-CunicaManifest {
    param(
        [string]$Version,
        [string]$Target,
        [string]$ReleaseDir,
        [string]$InstallerPath = "",
        [string]$LastInstallLogPath = ""
    )
    $contractDev = $null
    $contractPath = $null
    try {
        $contract = Get-CunicaContract
        $contractDev = $contract.developmentVersion
        $contractPath = Get-CunicaContractPath
    } catch {
        # Contract metadata is optional when installing outside the cunica repository.
    }

    $installerPathValue = $InstallerPath
    if (-not $installerPathValue) {
        $existing = Read-CunicaManifest
        if ($existing -and $existing.PSObject.Properties.Name -contains "installerPath") {
            $installerPathValue = [string]$existing.installerPath
        }
    }

    $lastInstallLogPathValue = $LastInstallLogPath
    if (-not $lastInstallLogPathValue) {
        $existing = Read-CunicaManifest
        if ($existing -and $existing.PSObject.Properties.Name -contains "lastInstallLogPath") {
            $lastInstallLogPathValue = [string]$existing.lastInstallLogPath
        }
    }
    if (-not $lastInstallLogPathValue -and $script:CunicaLogPath) {
        $lastInstallLogPathValue = $script:CunicaLogPath
    }

    $manifest = [ordered]@{
        version                    = $Version
        target                     = $Target
        installedAt                = (Get-Date).ToUniversalTime().ToString("o")
        sourceRepo                 = "https://github.com/$script:CunicaRepo"
        releaseDir                 = $ReleaseDir
        contractDevelopmentVersion = $contractDev
        contractPath               = $contractPath
        installerPath              = $installerPathValue
        lastInstallLogPath         = $lastInstallLogPathValue
    }
    $path = Join-Path (Get-CunicaHome) "manifest.json"
    $json = $manifest | ConvertTo-Json -Depth 4
    Write-Utf8NoBomFile -Path $path -Content ($json + [Environment]::NewLine)
}

function Get-McpUnicaEntry {
    param(
        [string]$Target
    )
    $userHomeVar = '${userHome}'
    $pluginRoot = "$userHomeVar/.cunica/current"
    $binary = if ($Target -eq "win-x64") {
        "$pluginRoot/bin/win-x64/unica.exe"
    } else {
        "$pluginRoot/bin/$Target/unica"
    }
    return [ordered]@{
        type    = "stdio"
        command = $binary
        args    = @()
        cwd     = $pluginRoot
    }
}

function Merge-McpJson {
    param(
        [string]$McpPath,
        [hashtable]$UnicaEntry
    )
    $dir = Split-Path -Parent $McpPath
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $config = @{ mcpServers = @{} }
    if (Test-Path -LiteralPath $McpPath) {
        $raw = Get-Content -LiteralPath $McpPath -Raw -Encoding UTF8
        if ($raw.Trim()) {
            $parsed = $raw | ConvertFrom-Json
            if ($parsed.mcpServers) {
                $parsed.mcpServers.PSObject.Properties | ForEach-Object {
                    $config.mcpServers[$_.Name] = $_.Value
                }
            }
        }
    }

    $config.mcpServers[$script:McpServerName] = $UnicaEntry
    $json = @{ mcpServers = $config.mcpServers } | ConvertTo-Json -Depth 10
    Write-Utf8NoBomFile -Path $McpPath -Content ($json + [Environment]::NewLine)
}

function Remove-McpUnicaEntry {
    param([string]$McpPath)
    if (-not (Test-Path -LiteralPath $McpPath)) { return }
    $raw = Get-Content -LiteralPath $McpPath -Raw -Encoding UTF8
    if (-not $raw.Trim()) { return }
    $parsed = $raw | ConvertFrom-Json
    if (-not $parsed.mcpServers) { return }
    $servers = @{}
    $parsed.mcpServers.PSObject.Properties | ForEach-Object {
        if ($_.Name -ne $script:McpServerName) {
            $servers[$_.Name] = $_.Value
        }
    }
    $json = @{ mcpServers = $servers } | ConvertTo-Json -Depth 10
    Write-Utf8NoBomFile -Path $McpPath -Content ($json + [Environment]::NewLine)
}

function Install-CunicaSkillLinks {
    param([string]$PluginRoot)
    $skillsSrc = Join-Path $PluginRoot "skills"
    if (-not (Test-Path -LiteralPath $skillsSrc)) {
        throw "Skills directory not found: $skillsSrc"
    }

    $skillsDst = Join-Path (Get-CursorHome) "skills"
    if (-not (Test-Path -LiteralPath $skillsDst)) {
        New-Item -ItemType Directory -Path $skillsDst -Force | Out-Null
    }

    $count = 0
    Get-ChildItem -LiteralPath $skillsSrc -Directory | ForEach-Object {
        $linkName = $script:SkillPrefix + $_.Name
        $linkPath = Join-Path $skillsDst $linkName
        Set-DirectoryLink -LinkPath $linkPath -TargetPath $_.FullName
        $count++
    }
    return $count
}

function Remove-CunicaSkillLinks {
    $skillsDst = Join-Path (Get-CursorHome) "skills"
    if (-not (Test-Path -LiteralPath $skillsDst)) { return 0 }
    $removed = 0
    Get-ChildItem -LiteralPath $skillsDst -Directory | Where-Object { $_.Name -like "$($script:SkillPrefix)*" } | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Recurse -Force
        $removed++
    }
    return $removed
}

function Install-CunicaRelease {
    param(
        [string]$Version = "latest",
        [string]$Target = "",
        [string]$ArchivePath = "",
        [string]$GlobalRuleSourcePath = "",
        [switch]$SkipVerify,
        [switch]$Quiet
    )

    if ($Quiet) {
        $script:DownloadQuiet = $true
    }

    $logPath = Start-CunicaInstallLog -Context "install" -Metadata @{
        version     = $Version
        target      = $Target
        archivePath = $ArchivePath
        quiet       = [string]$Quiet.IsPresent
    }
    $sessionStatus = "completed"

    $resolvedTarget = Get-CunicaTarget -Override $Target

    $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("cunica-install-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tmpRoot | Out-Null

    try {
        $ext = Get-ArchiveExtension -Target $resolvedTarget
        $archive = Join-Path $tmpRoot "unica-codex-marketplace-$resolvedTarget.$ext"
        $extractDir = Join-Path $tmpRoot "extract"
        New-Item -ItemType Directory -Path $extractDir | Out-Null

        Write-InstallOutput "==> Unica target: $resolvedTarget"
        if ($ArchivePath) {
            if (-not (Test-Path -LiteralPath $ArchivePath)) {
                throw "Archive not found: $ArchivePath"
            }
            Write-InstallOutput "==> Using local archive: $ArchivePath"
            Copy-Item -LiteralPath $ArchivePath -Destination $archive
        } else {
            $url = Get-ReleaseAssetUrl -Target $resolvedTarget -Version $Version
            Write-InstallOutput "==> Download: $url"
            Invoke-DownloadFile -Url $url -Destination $archive -Quiet:$Quiet
            if (Test-Path -LiteralPath $archive) {
                $sizeMb = [math]::Round((Get-Item -LiteralPath $archive).Length / 1MB, 2)
                Write-CunicaInstallLog -Message "download_complete size_mb=$sizeMb path=$archive"
            }
        }

        if ($ext -eq "zip") {
            Expand-Archive -LiteralPath $archive -DestinationPath $extractDir -Force
        } else {
            if (-not (Get-Command tar -ErrorAction SilentlyContinue)) {
                throw "tar is required to extract $archive"
            }
            & tar -xzf $archive -C $extractDir
            if ($LASTEXITCODE -ne 0) { throw "tar extraction failed with code $LASTEXITCODE" }
        }

        $marketplaceDir = Find-MarketplaceRoot -Root $extractDir
        $pluginRoot = Get-PluginRoot -MarketplaceDir $marketplaceDir
        $pluginVersion = Read-PluginVersion -PluginJsonPath (Join-Path $pluginRoot (Join-Path ".codex-plugin" "plugin.json"))

        $cunicaHome = Get-CunicaHome
        $releaseDir = Join-Path $cunicaHome (Join-Path "releases" $pluginVersion)
        if (Test-Path -LiteralPath $releaseDir) {
            Remove-Item -LiteralPath $releaseDir -Recurse -Force
        }
        $releasesParent = Split-Path -Parent $releaseDir
        if (-not (Test-Path -LiteralPath $releasesParent)) {
            New-Item -ItemType Directory -Path $releasesParent -Force | Out-Null
        }
        Copy-Item -LiteralPath $marketplaceDir -Destination $releaseDir -Recurse

        $installedPluginRoot = Get-PluginRoot -MarketplaceDir $releaseDir
        Assert-UnicaContract `
            -PluginRoot $installedPluginRoot `
            -MarketplaceDir $releaseDir `
            -Target $resolvedTarget `
            -InstalledVersion $pluginVersion | Out-Null

        Invoke-NativeChecked -Program (Get-ToolBinary -PluginRoot $installedPluginRoot -Target $resolvedTarget -Tool "v8-runner") -Arguments @("config", "init", "--help")
        Invoke-NativeChecked -Program (Get-ToolBinary -PluginRoot $installedPluginRoot -Target $resolvedTarget -Tool "unica") -Arguments @("--help")

        $currentLink = Join-Path $cunicaHome "current"
        Set-DirectoryLink -LinkPath $currentLink -TargetPath $installedPluginRoot

        Write-CunicaManifest `
            -Version $pluginVersion `
            -Target $resolvedTarget `
            -ReleaseDir $releaseDir `
            -LastInstallLogPath $logPath

        $mcpPath = Join-Path (Get-CursorHome) "mcp.json"
        Merge-McpJson -McpPath $mcpPath -UnicaEntry (Get-McpUnicaEntry -Target $resolvedTarget)

        $skillCount = Install-CunicaSkillLinks -PluginRoot $installedPluginRoot
        $globalRuleDest = $null
        if ($GlobalRuleSourcePath) {
            $globalRuleDest = Install-GlobalPlanningRule -RuleSourcePath $GlobalRuleSourcePath
        }

        if (-not $SkipVerify) {
            $manifest = Read-CunicaManifest
            if ($manifest.version -ne $pluginVersion) {
                throw "Manifest version mismatch: expected $pluginVersion, got $($manifest.version)"
            }
            $mcpRaw = Get-Content -LiteralPath $mcpPath -Raw -Encoding UTF8
            if ($mcpRaw -notmatch '"unica"') {
                throw "MCP config does not contain unica server entry"
            }
            $skillsOnDisk = @(Get-ChildItem -LiteralPath (Join-Path $installedPluginRoot "skills") -Directory).Count
            if ($skillCount -ne $skillsOnDisk) {
                throw "Skill link count mismatch: linked $skillCount, expected $skillsOnDisk"
            }
        }

        Write-InstallOutput "==> Installed Unica $pluginVersion for Cursor"
        Write-InstallOutput "==> Plugin root: $installedPluginRoot"
        Write-InstallOutput "==> Skills linked: $skillCount"
        if ($globalRuleDest) {
            Write-InstallOutput "==> Global rule: $globalRuleDest"
        }
        Write-InstallOutput "==> MCP config: $mcpPath"
        if ($logPath) {
            Write-InstallOutput "==> Install log: $logPath"
        }
        Write-InstallOutput "==> Restart Cursor to activate MCP server 'unica'"

        return $pluginVersion
    } catch {
        $sessionStatus = "failed"
        Write-CunicaInstallLog -Message ("error={0}" -f $_.Exception.Message)
        throw
    } finally {
        $script:DownloadQuiet = $false
        Complete-CunicaInstallLog -Status $sessionStatus -Context "install"
        if (Test-Path -LiteralPath $tmpRoot) {
            Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Switch-CunicaVersion {
    param(
        [string]$Version,
        [string]$GlobalRuleSourcePath = ""
    )
    $Version = Normalize-UnicaVersion -Version $Version
    $cunicaHome = Get-CunicaHome
    $releaseDir = Join-Path $cunicaHome (Join-Path "releases" $Version)
    if (-not (Test-Path -LiteralPath $releaseDir)) {
        throw "Release $Version is not installed at $releaseDir"
    }
    $pluginRoot = Get-PluginRoot -MarketplaceDir $releaseDir
    $manifest = Read-CunicaManifest
    $target = if ($manifest) { [string]$manifest.target } else { Get-CunicaTarget }
    Assert-UnicaContract `
        -PluginRoot $pluginRoot `
        -MarketplaceDir $releaseDir `
        -Target $target `
        -InstalledVersion $Version | Out-Null

    $currentLink = Join-Path $cunicaHome "current"
    Set-DirectoryLink -LinkPath $currentLink -TargetPath $pluginRoot
    Write-CunicaManifest -Version $Version -Target $target -ReleaseDir $releaseDir
    Install-CunicaSkillLinks -PluginRoot $pluginRoot
    if ($GlobalRuleSourcePath) {
        Install-GlobalPlanningRule -RuleSourcePath $GlobalRuleSourcePath | Out-Null
    }
    Write-Output "==> Switched to Unica $Version"
}

function Uninstall-Cunica {
    $cunicaHome = Get-CunicaHome
    Remove-CunicaSkillLinks | Out-Null
    Remove-GlobalPlanningRule
    Remove-McpUnicaEntry -McpPath (Join-Path (Get-CursorHome) "mcp.json")
    if (Test-Path -LiteralPath $cunicaHome) {
        Remove-Item -LiteralPath $cunicaHome -Recurse -Force
    }
    Write-Output "==> Unica removed from Cursor (cache, MCP, skills)"
}

function Show-CunicaStatus {
    $manifest = Read-CunicaManifest
    if (-not $manifest) {
        Write-Output "Unica is not installed."
        return
    }

    Write-Output "Installed version: $($manifest.version)"
    Write-Output "Target:            $($manifest.target)"
    Write-Output "Installed at:      $($manifest.installedAt)"
    Write-Output "Plugin root:       $(Get-CurrentPluginRoot)"
    if ($manifest.PSObject.Properties.Name -contains "lastInstallLogPath" -and $manifest.lastInstallLogPath) {
        Write-Output "Last install log:  $($manifest.lastInstallLogPath)"
    }
    if ($manifest.PSObject.Properties.Name -contains "installerPath" -and $manifest.installerPath) {
        Write-Output "Installer:         $($manifest.installerPath)"
    }

    try {
        $contract = Get-CunicaContract
        Write-Output "Cunica targets:    $($contract.developmentVersion)"
        if (Test-UnicaVersionMismatch -InstalledVersion ([string]$manifest.version) -Contract $contract) {
            Write-Output "Contract:          WARNING - installed version differs from development target"
        } else {
            Write-Output "Contract:          OK"
        }
    } catch {
        Write-Output "Contract:          not found ($($_.Exception.Message))"
    }

    try {
        $latest = Get-LatestReleaseTag
        if ($latest -eq $manifest.version) {
            Write-Output "Update:            up to date ($latest)"
        } else {
            Write-Output "Update:            available ($latest)"
        }
    } catch {
        Write-Output "Update:            could not check ($($_.Exception.Message))"
    }
}
