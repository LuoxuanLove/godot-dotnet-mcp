param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$bridgeProject = Join-Path $repoRoot "addons\godot_dotnet_mcp\dotnet_bridge\DotnetBridge.csproj"
$bridgeExe = Join-Path $repoRoot "addons\godot_dotnet_mcp\dotnet_bridge\bin\$Configuration\net8.0\GodotDotnetMcp.PluginBridge.exe"
$stageRoot = Join-Path $repoRoot (".tmp\dotnet_bridge_safe_writes_" + [System.Guid]::NewGuid().ToString("N"))

if (Test-Path -LiteralPath $stageRoot) {
    Remove-Item -LiteralPath $stageRoot -Recurse -Force -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Path $stageRoot | Out-Null
New-Item -ItemType File -Path (Join-Path $stageRoot "project.godot") | Out-Null

try {
    dotnet build $bridgeProject -c $Configuration | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet build failed for DotnetBridge with exit code $LASTEXITCODE."
    }

    if (-not (Test-Path -LiteralPath $bridgeExe)) {
        throw "DotnetBridge executable was not produced: $bridgeExe"
    }

    $env:GODOT_DOTNET_MCP_PROJECT_ROOT = $stageRoot

    $scriptPath = Join-Path $stageRoot "SafeWriteProbe.cs"
    [System.IO.File]::WriteAllText(
        $scriptPath,
        "public partial class SafeWriteProbe { public int Value() { return 1; } }",
        (New-Object System.Text.UTF8Encoding($false)))

    $patchRequestPath = Join-Path $stageRoot "cs-file-patch-request.json"
    [System.IO.File]::WriteAllText(
        $patchRequestPath,
        (@{
            path = $scriptPath
            dryRun = $false
            patches = @(
                @{
                    kind = "replace"
                    find = "return 1;"
                    replacement = "return 2;"
                    expectedCount = 1
                }
            )
        } | ConvertTo-Json -Depth 8),
        (New-Object System.Text.UTF8Encoding($false)))

    $patchOutput = & $bridgeExe --call-json-file cs_file_patch $patchRequestPath
    if ($LASTEXITCODE -ne 0) {
        throw "cs_file_patch failed with exit code $LASTEXITCODE. Output: $patchOutput"
    }

    $patchJson = $patchOutput | ConvertFrom-Json
    if (-not [bool]$patchJson.success) {
        throw "cs_file_patch reported failure: $patchOutput"
    }

    $updatedScript = [System.IO.File]::ReadAllText($scriptPath)
    if (-not $updatedScript.Contains("return 2;")) {
        throw "cs_file_patch did not persist the safe-write update."
    }

    $projectPath = Join-Path $stageRoot "SafeWriteProbe.csproj"
    [System.IO.File]::WriteAllText(
        $projectPath,
        "<Project Sdk=`"Microsoft.NET.Sdk`"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup></Project>",
        (New-Object System.Text.UTF8Encoding($false)))

    $csprojRequestPath = Join-Path $stageRoot "csproj-write-request.json"
    [System.IO.File]::WriteAllText(
        $csprojRequestPath,
        (@{
            path = $projectPath
            dryRun = $false
            properties = @{
                Nullable = "enable"
            }
        } | ConvertTo-Json -Depth 8),
        (New-Object System.Text.UTF8Encoding($false)))

    $csprojOutput = & $bridgeExe --call-json-file csproj_write $csprojRequestPath
    if ($LASTEXITCODE -ne 0) {
        throw "csproj_write failed with exit code $LASTEXITCODE. Output: $csprojOutput"
    }

    $csprojJson = $csprojOutput | ConvertFrom-Json
    if (-not [bool]$csprojJson.success) {
        throw "csproj_write reported failure: $csprojOutput"
    }

    $updatedProject = [System.IO.File]::ReadAllText($projectPath)
    if (-not $updatedProject.Contains("<Nullable>enable</Nullable>")) {
        throw "csproj_write did not persist the safe-write update."
    }

    $tmpFiles = @(Get-ChildItem -LiteralPath $stageRoot -File -Filter ".*.tmp" -ErrorAction SilentlyContinue)
    if ($tmpFiles.Count -gt 0) {
        throw "Safe write left temporary files behind: $($tmpFiles.Name -join ', ')"
    }

    Write-Host "Dotnet bridge safe-write regression tests passed."
}
finally {
    Remove-Item Env:\GODOT_DOTNET_MCP_PROJECT_ROOT -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $stageRoot) {
        Remove-Item -LiteralPath $stageRoot -Recurse -Force
    }
}
