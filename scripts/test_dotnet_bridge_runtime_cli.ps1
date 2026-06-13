param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

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

    Write-Host "Dotnet bridge runtime CLI regression tests passed."
}
finally {
    $env:GODOT_DOTNET_MCP_PROJECT_ROOT = $previousProjectRoot
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
