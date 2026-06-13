param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Quote-ProcessArgument {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return '"' + $Value.Replace('"', '\"') + '"'
}

$projectPath = Join-Path $repoRoot "addons\godot_dotnet_mcp\dotnet_bridge\DotnetBridge.csproj"
$bridgeExe = Join-Path $repoRoot "addons\godot_dotnet_mcp\dotnet_bridge\bin\$Configuration\net8.0\GodotDotnetMcp.PluginBridge.exe"

dotnet build $projectPath -c $Configuration | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "dotnet build failed for DotnetBridge with exit code $LASTEXITCODE."
}

if (-not (Test-Path -LiteralPath $bridgeExe)) {
    throw "DotnetBridge executable was not produced: $bridgeExe"
}

$tempRoot = Join-Path $repoRoot (".tmp\dotnet_bridge_runtime_cli_" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
$previousProjectRoot = $env:GODOT_DOTNET_MCP_PROJECT_ROOT

try {
    [System.IO.File]::WriteAllText((Join-Path $tempRoot "project.godot"), "[application]`nconfig/name=`"BridgeRuntimeCliProbe`"`n", [System.Text.UTF8Encoding]::new($false))
    $env:GODOT_DOTNET_MCP_PROJECT_ROOT = $tempRoot

    $responsePath = Join-Path $tempRoot "bad-timeout-response.json"
    $badTimeoutOutput = & $bridgeExe --response-json-file $responsePath --timeout-ms not-a-number --capabilities
    if ($LASTEXITCODE -eq 0) {
        throw "DotnetBridge should reject non-integer --timeout-ms values."
    }
    if (-not (Test-Path -LiteralPath $responsePath)) {
        throw "DotnetBridge should write parse failures to --response-json-file when that option is present."
    }
    $badTimeoutJson = Get-Content -LiteralPath $responsePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([bool]$badTimeoutJson.success) {
        throw "DotnetBridge bad-timeout response file should report success=false."
    }
    if ([string]$badTimeoutJson.error -notmatch "--timeout-ms") {
        throw "DotnetBridge bad-timeout response should explain the --timeout-ms parse failure."
    }
    if (-not [string]::IsNullOrWhiteSpace($badTimeoutOutput)) {
        throw "DotnetBridge should not write response-file payloads to stdout."
    }

    $callRequestPath = Join-Path $tempRoot "call-request.json"
    $scriptPath = Join-Path $tempRoot "RuntimeCliProbe.cs"
    [System.IO.File]::WriteAllText($scriptPath, "public partial class RuntimeCliProbe { public void Run() { } }", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($callRequestPath, (@{ path = $scriptPath } | ConvertTo-Json -Compress), [System.Text.UTF8Encoding]::new($false))

    $callOutput = & $bridgeExe --call-json-file cs_file_read $callRequestPath
    if ($LASTEXITCODE -ne 0) {
        throw "DotnetBridge legacy --call-json-file invocation failed with exit code $LASTEXITCODE. Output: $callOutput"
    }
    $callJson = $callOutput | ConvertFrom-Json
    if (-not [bool]$callJson.success) {
        throw "DotnetBridge legacy --call-json-file response should report success=true."
    }
    if ([string]$callJson.structuredContent.path -ne $scriptPath) {
        throw "DotnetBridge legacy --call-json-file response should preserve the requested script path."
    }

    $timeoutProject = Join-Path $tempRoot "TimeoutProbe.csproj"
    $timeoutStartedMarker = Join-Path $tempRoot "timeout-started.txt"
    $timeoutMarker = Join-Path $tempRoot "timeout-marker.txt"
    $timeoutArgs = @{
        path = $timeoutProject
        operation = "build"
        configuration = "Debug"
        verbosity = "quiet"
    } | ConvertTo-Json -Compress
    $timeoutRequestPath = Join-Path $tempRoot "timeout-request.json"
    [System.IO.File]::WriteAllText($timeoutRequestPath, $timeoutArgs, [System.Text.UTF8Encoding]::new($false))
    $escapedStartedMarker = [System.Security.SecurityElement]::Escape($timeoutStartedMarker)
    $escapedMarker = [System.Security.SecurityElement]::Escape($timeoutMarker)
    $preBuildCommand = if ($IsWindows -or $env:OS -eq "Windows_NT") {
        "powershell -NoProfile -ExecutionPolicy Bypass -Command `"Set-Content -LiteralPath '$escapedStartedMarker' -Value started -Encoding UTF8; Start-Sleep -Seconds 8; Set-Content -LiteralPath '$escapedMarker' -Value leaked -Encoding UTF8`""
    } else {
        "sh -c 'printf started > &quot;$escapedStartedMarker&quot;; sleep 8; printf leaked > &quot;$escapedMarker&quot;'"
    }
    [System.IO.File]::WriteAllText($timeoutProject, @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <PreBuildEvent>$preBuildCommand</PreBuildEvent>
  </PropertyGroup>
</Project>
"@, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $tempRoot "TimeoutProbe.cs"), "public sealed class TimeoutProbe { }", [System.Text.UTF8Encoding]::new($false))

    dotnet restore $timeoutProject | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Timeout probe project restore failed with exit code $LASTEXITCODE."
    }

    $timeoutResponsePath = Join-Path $tempRoot "timeout-response.json"
    $timeoutStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $timeoutStartInfo.FileName = $bridgeExe
    $timeoutStartInfo.Arguments = "--timeout-ms 5000 --response-json-file $(Quote-ProcessArgument $timeoutResponsePath) --call-json-file dotnet_build $(Quote-ProcessArgument $timeoutRequestPath)"
    $timeoutStartInfo.UseShellExecute = $false
    $timeoutStartInfo.CreateNoWindow = $true
    $timeoutProcess = [System.Diagnostics.Process]::Start($timeoutStartInfo)

    $startedDeadline = [DateTime]::UtcNow.AddSeconds(10)
    while (-not (Test-Path -LiteralPath $timeoutStartedMarker) -and -not $timeoutProcess.HasExited -and [DateTime]::UtcNow -lt $startedDeadline) {
        Start-Sleep -Milliseconds 100
    }
    if (-not (Test-Path -LiteralPath $timeoutStartedMarker)) {
        if (-not $timeoutProcess.HasExited) {
            $timeoutProcess.Kill()
            $timeoutProcess.WaitForExit()
        }
        throw "DotnetBridge dotnet_build timeout regression must prove the PreBuildEvent child process started before timeout."
    }

    if (-not $timeoutProcess.WaitForExit(10000)) {
        $timeoutProcess.Kill()
        $timeoutProcess.WaitForExit()
        throw "DotnetBridge dotnet_build timeout process did not exit after the timeout window."
    }
    if ($timeoutProcess.ExitCode -ne 124) {
        $timeoutOutput = if (Test-Path -LiteralPath $timeoutResponsePath) { Get-Content -LiteralPath $timeoutResponsePath -Raw -Encoding UTF8 } else { "" }
        throw "DotnetBridge dotnet_build timeout should return exit code 124. Exit code: $($timeoutProcess.ExitCode) Output: $timeoutOutput"
    }
    if (-not (Test-Path -LiteralPath $timeoutResponsePath)) {
        throw "DotnetBridge dotnet_build timeout should write a response file."
    }
    $timeoutJson = Get-Content -LiteralPath $timeoutResponsePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]$timeoutJson.structuredContent.error -ne "runtime_timeout") {
        throw "DotnetBridge dotnet_build timeout should report structuredContent.error=runtime_timeout."
    }
    Start-Sleep -Seconds 10
    if (Test-Path -LiteralPath $timeoutMarker) {
        throw "DotnetBridge dotnet_build timeout should kill the spawned dotnet process tree before the PreBuildEvent can write its marker."
    }

    $global:LASTEXITCODE = 0
    Write-Host "Dotnet bridge runtime CLI regression tests passed."
}
finally {
    $env:GODOT_DOTNET_MCP_PROJECT_ROOT = $previousProjectRoot
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
