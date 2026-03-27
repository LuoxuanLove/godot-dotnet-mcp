$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$errors = New-Object System.Collections.Generic.List[string]

$removedRootToolFiles = @(
    "addons/godot_dotnet_mcp/tools/script_tools.gd",
    "addons/godot_dotnet_mcp/tools/node_tools.gd",
    "addons/godot_dotnet_mcp/tools/animation_tools.gd",
    "addons/godot_dotnet_mcp/tools/physics_tools.gd",
    "addons/godot_dotnet_mcp/tools/scene_tools.gd",
    "addons/godot_dotnet_mcp/tools/debug_tools.gd",
    "addons/godot_dotnet_mcp/tools/editor_tools.gd",
    "addons/godot_dotnet_mcp/tools/lighting_tools.gd",
    "addons/godot_dotnet_mcp/tools/geometry_tools.gd"
)

$bannedSourcePatterns = @(
    "compatibility_alias",
    "workspace_editor_proxy_call",
    "SERVER_VERSION"
)

$trackedBundledArtifacts = git ls-files "addons/godot_dotnet_mcp/central_server_packages" | Where-Object {
    $_ -match "\.(zip|sha256)$"
}
foreach ($artifact in $trackedBundledArtifacts) {
    $errors.Add("Tracked bundled artifact must not live in source tree: $artifact")
}

$trackedReleaseArtifacts = git ls-files "release_dist" "dist" | Where-Object {
    -not [string]::IsNullOrWhiteSpace($_)
}
foreach ($artifact in $trackedReleaseArtifacts) {
    $errors.Add("Build output must not be tracked in source control: $artifact")
}

$distRoot = Join-Path $repoRoot "dist"
$expectedDirs = @(
    (Join-Path $distRoot "central-server-win-x64"),
    (Join-Path $distRoot "plugin-lean"),
    (Join-Path $distRoot "plugin-bundled-win-x64")
)

foreach ($path in $expectedDirs) {
    if (-not (Test-Path $path)) {
        Write-Host "Info: expected dist output not present yet (acceptable before packaging): $path"
    }
}

foreach ($removedFile in $removedRootToolFiles) {
    $absolutePath = Join-Path $repoRoot $removedFile
    if (Test-Path $absolutePath) {
        $errors.Add("Removed root tool file must not return: $removedFile")
    }
}

foreach ($pattern in $bannedSourcePatterns) {
    $matches = rg -n --glob "addons/**/*.gd" --glob "central_server/**/*.cs" --glob "host_shared/**/*.cs" $pattern $repoRoot 2>$null
    foreach ($match in $matches) {
        if (-not [string]::IsNullOrWhiteSpace($match)) {
            $errors.Add("Banned source identifier '$pattern' found: $match")
        }
    }
}

if ($errors.Count -gt 0) {
    foreach ($message in $errors) {
        Write-Error $message
    }

    throw "Refactor guardrail validation failed."
}

Write-Host "Refactor guardrails validated successfully."
