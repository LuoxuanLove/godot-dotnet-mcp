param(
    [switch]$SkipBuild,
    [switch]$UseUserProfileState,
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,
    [Parameter(Mandatory = $true)]
    [string]$GodotExecutablePath,
    [string]$AttachHost,
    [int]$AttachPort,
    [int]$EditorAttachTimeoutMs
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

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

if (-not $UseUserProfileState) {
    $releaseStateRoot = Join-Path $repoRoot '.tmp/central_server_release_validation'
    $centralHome = Join-Path $releaseStateRoot 'CentralHome'
    $dotnetCliHome = Join-Path $releaseStateRoot 'DotnetCli'

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

    $reuseResult = Invoke-JsonCommand -Executable 'powershell' -Arguments (@('-ExecutionPolicy', 'Bypass', '-File', $smokeScript) + $smokeCommonArguments)
    $summary.reuseSmoke = $reuseResult.Json
    if ($reuseResult.ExitCode -ne 0) {
        throw "Reuse session smoke failed."
    }

    $autoLaunchArguments = @(
        '-ExecutionPolicy', 'Bypass',
        '-File', $smokeScript
    ) + $smokeCommonArguments + @(
        '-AutoLaunch',
        '-RequireAutoLaunch',
        '-ProjectRoot', $ProjectRoot,
        '-GodotExecutablePath', $GodotExecutablePath
    )
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
