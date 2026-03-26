param(
    [switch]$SkipBuild,
    [switch]$AutoLaunch,
    [switch]$RequireAutoLaunch,
    [switch]$CleanupLaunchedEditor,
    [switch]$UseUserProfileState,
    [string]$StateRoot,
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

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$projectFile = Join-Path $repoRoot 'central_server/CentralServer.csproj'
$outputDll = Join-Path $repoRoot 'central_server/bin/Release/net8.0/GodotDotnetMcp.CentralServer.dll'

if ($AutoLaunch -and -not $UseUserProfileState) {
    if (-not $CleanupLaunchedEditor) {
        if (-not $StateRoot) {
            $StateRoot = Join-Path $repoRoot '.tmp/central_server_smoke/persistent_auto_launch'
        }
        if ($AttachPort -le 0) {
            $AttachPort = 3020
        }
    }
}

if (-not $UseUserProfileState) {
    $smokeStateRoot = Get-IsolatedStateRoot -BaseRoot (Join-Path $repoRoot '.tmp/central_server_smoke/runs') -ExplicitStateRoot $StateRoot
    $centralHome = Join-Path $smokeStateRoot 'CentralHome'
    $dotnetCliHome = Join-Path $smokeStateRoot 'DotnetCli'

    New-Item -ItemType Directory -Force -Path $centralHome | Out-Null
    New-Item -ItemType Directory -Force -Path $dotnetCliHome | Out-Null

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

$arguments = @('--smoke-system-session')
if ($AutoLaunch) {
    $arguments += '--auto-launch'
}
if ($RequireAutoLaunch) {
    $arguments += '--require-auto-launch'
}
if ($CleanupLaunchedEditor) {
    $arguments += '--cleanup-launched-editor'
}
if ($ProjectRoot) {
    $arguments += @('--project-root', $ProjectRoot)
}
if ($GodotExecutablePath) {
    $arguments += @('--godot-executable-path', $GodotExecutablePath)
}
if ($AttachHost) {
    $arguments += @('--attach-host', $AttachHost)
}
if ($AttachPort -gt 0) {
    $arguments += @('--attach-port', $AttachPort.ToString())
}
if ($EditorAttachTimeoutMs -gt 0) {
    $arguments += @('--editor-attach-timeout-ms', $EditorAttachTimeoutMs.ToString())
}

& dotnet $outputDll @arguments
exit $LASTEXITCODE
