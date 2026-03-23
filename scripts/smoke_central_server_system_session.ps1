param(
    [switch]$SkipBuild,
    [switch]$AutoLaunch,
    [switch]$RequireAutoLaunch,
    [switch]$UseUserProfileState,
    [string]$ProjectRoot,
    [string]$GodotExecutablePath,
    [string]$AttachHost,
    [int]$AttachPort,
    [int]$EditorAttachTimeoutMs
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$projectFile = Join-Path $repoRoot 'central_server/CentralServer.csproj'
$outputDll = Join-Path $repoRoot 'central_server/bin/Release/net8.0/GodotDotnetMcp.CentralServer.dll'

if (-not $UseUserProfileState) {
    $smokeStateRoot = Join-Path $repoRoot '.tmp/central_server_smoke'
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
