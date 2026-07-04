param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$bridgeProject = Join-Path $repoRoot "addons\godot_dotnet_mcp\.dotnet_bridge\DotnetBridge.csproj"
$bridgeExe = Join-Path $repoRoot "addons\godot_dotnet_mcp\.dotnet_bridge\bin\$Configuration\net8.0\GodotDotnetMcp.PluginBridge.exe"
$stageRoot = Join-Path $repoRoot (".tmp\dotnet_bridge_safe_writes_" + [System.Guid]::NewGuid().ToString("N"))
$outsideRoot = Join-Path $repoRoot (".tmp\dotnet_bridge_safe_writes_outside_" + [System.Guid]::NewGuid().ToString("N"))
$junctionPath = Join-Path $stageRoot "junction"

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

    $pluginPatchRequestPath = Join-Path $stageRoot "cs-plugin-patch-request.json"
    [System.IO.File]::WriteAllText(
        $pluginPatchRequestPath,
        (@{
            path = $scriptPath
            action = "replace_method_body"
            type_name = "SafeWriteProbe"
            member_name = "Value"
            body = "return 3;"
        } | ConvertTo-Json -Depth 8),
        (New-Object System.Text.UTF8Encoding($false)))

    $pluginPatchDryRunResponsePath = Join-Path $stageRoot "cs-plugin-patch-dry-run-response.json"
    $pluginPatchDryRunOutput = & $bridgeExe --response-json-file $pluginPatchDryRunResponsePath --call-json-file cs_plugin_patch $pluginPatchRequestPath
    if ($LASTEXITCODE -ne 0) {
        throw "cs_plugin_patch dry-run failed with exit code $LASTEXITCODE. Output: $pluginPatchDryRunOutput"
    }
    $pluginPatchDryRunJson = Get-Content -LiteralPath $pluginPatchDryRunResponsePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($pluginPatchDryRunJson.success -ne $true -or $pluginPatchDryRunJson.structuredContent.dryRun -ne $true -or $pluginPatchDryRunJson.structuredContent.written -ne $false) {
        throw "cs_plugin_patch should default to dryRun=true and written=false: $($pluginPatchDryRunJson | ConvertTo-Json -Depth 8)"
    }
    if ([System.IO.File]::ReadAllText($scriptPath).Contains("return 3;")) {
        throw "cs_plugin_patch dry-run should not persist source changes."
    }

    $pluginPatchWriteRequestPath = Join-Path $stageRoot "cs-plugin-patch-write-request.json"
    [System.IO.File]::WriteAllText(
        $pluginPatchWriteRequestPath,
        (@{
            path = $scriptPath
            dryRun = $false
            action = "replace_method_body"
            type_name = "SafeWriteProbe"
            member_name = "Value"
            body = "return 3;"
        } | ConvertTo-Json -Depth 8),
        (New-Object System.Text.UTF8Encoding($false)))

    $pluginPatchWriteResponsePath = Join-Path $stageRoot "cs-plugin-patch-write-response.json"
    $pluginPatchWriteOutput = & $bridgeExe --response-json-file $pluginPatchWriteResponsePath --call-json-file cs_plugin_patch $pluginPatchWriteRequestPath
    if ($LASTEXITCODE -ne 0) {
        throw "cs_plugin_patch write failed with exit code $LASTEXITCODE. Output: $pluginPatchWriteOutput"
    }
    $pluginPatchWriteJson = Get-Content -LiteralPath $pluginPatchWriteResponsePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($pluginPatchWriteJson.success -ne $true -or $pluginPatchWriteJson.structuredContent.dryRun -ne $false -or $pluginPatchWriteJson.structuredContent.written -ne $true) {
        throw "cs_plugin_patch dryRun=false should report a persisted write: $($pluginPatchWriteJson | ConvertTo-Json -Depth 8)"
    }
    if (-not [System.IO.File]::ReadAllText($scriptPath).Contains("return 3;")) {
        throw "cs_plugin_patch dryRun=false did not persist the safe-write update."
    }

    New-Item -ItemType Directory -Path $outsideRoot | Out-Null
    $outsideScriptPath = Join-Path $outsideRoot "Outside.cs"
    [System.IO.File]::WriteAllText(
        $outsideScriptPath,
        "public partial class Outside { public int Value() { return 1; } }",
        (New-Object System.Text.UTF8Encoding($false)))

    $outsidePatchRequestPath = Join-Path $stageRoot "cs-file-patch-outside-request.json"
    [System.IO.File]::WriteAllText(
        $outsidePatchRequestPath,
        (@{
            path = $outsideScriptPath
            dryRun = $false
            patches = @(
                @{
                    kind = "replace"
                    find = "return 1;"
                    replacement = "return 9;"
                    expectedCount = 1
                }
            )
        } | ConvertTo-Json -Depth 8),
        (New-Object System.Text.UTF8Encoding($false)))

    $outsidePatchOutput = & $bridgeExe --call-json-file cs_file_patch $outsidePatchRequestPath
    if ($LASTEXITCODE -eq 0) {
        throw "cs_file_patch should reject absolute paths outside the project root. Output: $outsidePatchOutput"
    }
    if ([System.IO.File]::ReadAllText($outsideScriptPath).Contains("return 9;")) {
        throw "cs_file_patch wrote through an absolute path outside the project root."
    }

    $traversalPatchRequestPath = Join-Path $stageRoot "cs-file-patch-traversal-request.json"
    [System.IO.File]::WriteAllText(
        $traversalPatchRequestPath,
        (@{
            path = "..\dotnet_bridge_safe_writes_outside_traversal\Traversal.cs"
            dryRun = $false
            patches = @(
                @{
                    kind = "replace"
                    find = "return 1;"
                    replacement = "return 9;"
                    expectedCount = 1
                }
            )
        } | ConvertTo-Json -Depth 8),
        (New-Object System.Text.UTF8Encoding($false)))
    $traversalPatchOutput = & $bridgeExe --call-json-file cs_file_patch $traversalPatchRequestPath
    if ($LASTEXITCODE -eq 0) {
        throw "cs_file_patch should reject traversal segments. Output: $traversalPatchOutput"
    }

    $junctionTarget = Join-Path $outsideRoot "junction-target"
    New-Item -ItemType Directory -Path $junctionTarget | Out-Null
    $junctionScriptPath = Join-Path $junctionTarget "JunctionTarget.cs"
    [System.IO.File]::WriteAllText(
        $junctionScriptPath,
        "public partial class JunctionTarget { public int Value() { return 1; } }",
        (New-Object System.Text.UTF8Encoding($false)))
    $junctionCreated = $false
    try {
        New-Item -ItemType Junction -Path $junctionPath -Target $junctionTarget -ErrorAction Stop | Out-Null
        $junctionCreated = $true
    }
    catch {
        Write-Host "Skipping junction write-negative coverage because junction creation failed: $($_.Exception.Message)"
    }
    if ($junctionCreated) {
        $junctionPatchRequestPath = Join-Path $stageRoot "cs-plugin-patch-junction-request.json"
        [System.IO.File]::WriteAllText(
            $junctionPatchRequestPath,
            (@{
                path = (Join-Path $junctionPath "JunctionTarget.cs")
                dryRun = $false
                action = "replace_method_body"
                type_name = "JunctionTarget"
                member_name = "Value"
                body = "return 9;"
            } | ConvertTo-Json -Depth 8),
            (New-Object System.Text.UTF8Encoding($false)))
        $junctionPatchOutput = & $bridgeExe --call-json-file cs_plugin_patch $junctionPatchRequestPath
        if ($LASTEXITCODE -eq 0) {
            throw "cs_plugin_patch should reject writes through junction/reparse-point segments. Output: $junctionPatchOutput"
        }
        if ([System.IO.File]::ReadAllText($junctionScriptPath).Contains("return 9;")) {
            throw "cs_plugin_patch wrote through a junction/reparse-point segment."
        }

        $junctionResponsePath = Join-Path $junctionPath "response.json"
        $junctionResponseOutput = & $bridgeExe --response-json-file $junctionResponsePath --capabilities
        if ($LASTEXITCODE -eq 0) {
            throw "--response-json-file should reject paths through junction/reparse-point segments. Output: $junctionResponseOutput"
        }
        if (Test-Path -LiteralPath $junctionResponsePath) {
            throw "--response-json-file wrote through a junction/reparse-point segment."
        }
    }

    $outsideResponsePath = Join-Path $outsideRoot "response.json"
    $outsideResponseOutput = & $bridgeExe --response-json-file $outsideResponsePath --capabilities
    if ($LASTEXITCODE -eq 0) {
        throw "--response-json-file should reject paths outside the project root unless explicitly allowed. Output: $outsideResponseOutput"
    }
    if (Test-Path -LiteralPath $outsideResponsePath) {
        throw "--response-json-file wrote outside the project root."
    }
    if (-not (($outsideResponseOutput | Out-String).Contains("response_json_file_outside_allowed_roots"))) {
        throw "--response-json-file outside-root rejection should report response_json_file_outside_allowed_roots. Output: $outsideResponseOutput"
    }

    $allowedResponseRoot = Join-Path $outsideRoot "allowed-response-root"
    New-Item -ItemType Directory -Path $allowedResponseRoot | Out-Null
    $allowedResponsePath = Join-Path $allowedResponseRoot "response.json"
    $env:GODOT_DOTNET_MCP_RESPONSE_ROOTS = $allowedResponseRoot
    try {
        $allowedResponseOutput = & $bridgeExe --response-json-file $allowedResponsePath --capabilities
        if ($LASTEXITCODE -ne 0) {
            throw "--response-json-file should allow paths under GODOT_DOTNET_MCP_RESPONSE_ROOTS. Output: $allowedResponseOutput"
        }
        $allowedResponseJson = Get-Content -LiteralPath $allowedResponsePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($allowedResponseJson.success -ne $true -or $allowedResponseJson.component -ne "godot-dotnet-mcp-roslyn-runtime") {
            throw "--response-json-file allowed root should receive bridge capabilities JSON."
        }
    }
    finally {
        Remove-Item Env:\GODOT_DOTNET_MCP_RESPONSE_ROOTS -ErrorAction SilentlyContinue
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
    Remove-Item Env:\GODOT_DOTNET_MCP_RESPONSE_ROOTS -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $junctionPath) {
        try {
            [System.IO.Directory]::Delete($junctionPath)
        }
        catch {
            Write-Host "Warning: failed to remove junction '$junctionPath': $($_.Exception.Message)"
        }
    }
    if (Test-Path -LiteralPath $stageRoot) {
        Remove-Item -LiteralPath $stageRoot -Recurse -Force
    }
    if (Test-Path -LiteralPath $outsideRoot) {
        Remove-Item -LiteralPath $outsideRoot -Recurse -Force
    }
}
