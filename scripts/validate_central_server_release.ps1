param(
    [switch]$SkipBuild,
    [switch]$CleanupLaunchedEditor,
    [switch]$UseUserProfileState,
    [string]$StateRoot,
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,
    [string]$GodotExecutablePath,
    [string]$AttachHost,
    [int]$AttachPort,
    [int]$EditorAttachTimeoutMs
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-IsolatedStateRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseRoot,
        [string]$ExplicitStateRoot
    )

    if ($ExplicitStateRoot) {
        $stateItem = New-Item -ItemType Directory -Force -Path $ExplicitStateRoot
        return $stateItem.FullName
    }

    $runId = '{0:yyyyMMddTHHmmssfff}-{1}-{2}' -f [DateTime]::UtcNow, $PID, ([Guid]::NewGuid().ToString('N').Substring(0, 8))
    $runRoot = Join-Path $BaseRoot $runId
    $stateItem = New-Item -ItemType Directory -Force -Path $runRoot
    return $stateItem.FullName
}

function Invoke-JsonCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Executable,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $outputLines = & $Executable @Arguments
    $exitCode = $LASTEXITCODE
    $text = ($outputLines -join [Environment]::NewLine).Trim()
    $normalizedText = $text.TrimStart([char]0xFEFF).Trim()
    $json = $null

    if ($normalizedText) {
        try {
            $json = $normalizedText | ConvertFrom-Json
        }
        catch {
            $json = $normalizedText
        }
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Text = $normalizedText
        Json = $json
    }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$projectFile = Join-Path $repoRoot 'central_server/CentralServer.csproj'
$outputDll = Join-Path $repoRoot 'central_server/bin/Release/net8.0/GodotDotnetMcp.CentralServer.dll'
$smokeScript = Join-Path $repoRoot 'scripts/smoke_central_server_system_session.ps1'
$releaseStateRoot = $null
$reuseSmokeStateRoot = $null
$autoLaunchSmokeStateRoot = $null

if (-not $UseUserProfileState) {
    $releaseStateRoot = Get-IsolatedStateRoot -BaseRoot (Join-Path $repoRoot '.tmp/central_server_release_validation/runs') -ExplicitStateRoot $StateRoot
    $centralHome = Join-Path $releaseStateRoot 'CentralHome'
    $dotnetCliHome = Join-Path $releaseStateRoot 'DotnetCli'
    $reuseSmokeStateRoot = Join-Path $releaseStateRoot 'reuse_smoke'
    $autoLaunchSmokeStateRoot = Join-Path $releaseStateRoot 'auto_launch_smoke'

    New-Item -ItemType Directory -Force -Path $centralHome | Out-Null
    New-Item -ItemType Directory -Force -Path $dotnetCliHome | Out-Null
    New-Item -ItemType Directory -Force -Path $reuseSmokeStateRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $autoLaunchSmokeStateRoot | Out-Null

    $env:GODOT_DOTNET_MCP_CENTRAL_HOME = $centralHome
    $env:DOTNET_CLI_HOME = $dotnetCliHome
    $env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
    $env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
    $env:DOTNET_NOLOGO = '1'
}

if (-not $SkipBuild) {
    dotnet build $projectFile -c Release /nodeReuse:false
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

if (-not (Test-Path $outputDll)) {
    throw "Central Server build output not found: $outputDll"
}

$smokeCommonArguments = @('-SkipBuild')
if ($UseUserProfileState) {
    $smokeCommonArguments += '-UseUserProfileState'
}
if ($AttachHost) {
    $smokeCommonArguments += @('-AttachHost', $AttachHost)
}
if ($AttachPort -gt 0) {
    $smokeCommonArguments += @('-AttachPort', $AttachPort.ToString())
}
if ($EditorAttachTimeoutMs -gt 0) {
    $smokeCommonArguments += @('-EditorAttachTimeoutMs', $EditorAttachTimeoutMs.ToString())
}
if ($CleanupLaunchedEditor) {
    $smokeCommonArguments += '-CleanupLaunchedEditor'
}

$reuseSmokeArguments = @($smokeCommonArguments)
$autoLaunchSmokeArguments = @($smokeCommonArguments)
if (-not $UseUserProfileState) {
    $reuseSmokeArguments += @('-StateRoot', $reuseSmokeStateRoot)
    $autoLaunchSmokeArguments += @('-StateRoot', $autoLaunchSmokeStateRoot)
}

$summary = [ordered]@{
    success = $false
    validatedAtUtc = [DateTime]::UtcNow.ToString('o')
    health = $null
    reuseSmoke = $null
    autoLaunchSmoke = $null
}

try {
    $healthResult = Invoke-JsonCommand -Executable 'dotnet' -Arguments @($outputDll, '--health')
    $summary.health = $healthResult.Json
    if ($healthResult.ExitCode -ne 0) {
        throw "Central Server --health failed."
    }

    $reuseResult = Invoke-JsonCommand -Executable 'powershell' -Arguments (@('-ExecutionPolicy', 'Bypass', '-File', $smokeScript) + $reuseSmokeArguments)
    $summary.reuseSmoke = $reuseResult.Json
    if ($reuseResult.ExitCode -ne 0) {
        throw "Reuse session smoke failed."
    }

    $autoLaunchArguments = @(
        '-ExecutionPolicy', 'Bypass',
        '-File', $smokeScript
    ) + $autoLaunchSmokeArguments + @(
        '-AutoLaunch',
        '-RequireAutoLaunch',
        '-ProjectRoot', $ProjectRoot
    )
    if ($GodotExecutablePath) {
        $autoLaunchArguments += @('-GodotExecutablePath', $GodotExecutablePath)
    }
    $autoLaunchResult = Invoke-JsonCommand -Executable 'powershell' -Arguments $autoLaunchArguments
    $summary.autoLaunchSmoke = $autoLaunchResult.Json
    if ($autoLaunchResult.ExitCode -ne 0) {
        throw "Auto-launch smoke failed."
    }

    $summary.success = $true
    $summary | ConvertTo-Json -Depth 100
    exit 0
}
catch {
    $summary.success = $false
    $summary.error = $_.Exception.Message
    $summary | ConvertTo-Json -Depth 100
    exit 1
}
