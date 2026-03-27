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
    "addons/godot_dotnet_mcp/tools/geometry_tools.gd",
    "addons/godot_dotnet_mcp/tools/filesystem_tools.gd"
)

$bannedSourcePatterns = @(
    "compatibility_alias",
    "workspace_editor_proxy_call",
    "SERVER_VERSION"
)

function Find-BannedSourceMatches {
    param(
        [string]$Pattern,
        [string]$RepositoryRoot
    )

    $ripgrep = Get-Command rg -ErrorAction SilentlyContinue
    if ($null -ne $ripgrep) {
        return @(rg -n --case-sensitive --glob "addons/**/*.gd" --glob "central_server/**/*.cs" --glob "host_shared/**/*.cs" $Pattern $RepositoryRoot 2>$null)
    }

    $searchRoots = @(
        (Join-Path $RepositoryRoot "addons"),
        (Join-Path $RepositoryRoot "central_server"),
        (Join-Path $RepositoryRoot "host_shared")
    )

    $candidateFiles = foreach ($root in $searchRoots) {
        if (Test-Path $root) {
            Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object {
                $_.Extension -in @(".gd", ".cs")
            }
        }
    }

    $results = New-Object System.Collections.Generic.List[string]
    foreach ($file in $candidateFiles) {
            $matches = Select-String -LiteralPath $file.FullName -Pattern $Pattern -SimpleMatch -CaseSensitive -Encoding UTF8
        foreach ($match in $matches) {
            $relativePath = [System.IO.Path]::GetRelativePath($RepositoryRoot, $file.FullName)
            $results.Add(("{0}:{1}:{2}" -f $relativePath, $match.LineNumber, $match.Line.Trim()))
        }
    }

    return $results.ToArray()
}

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
    $matches = Find-BannedSourceMatches -Pattern $pattern -RepositoryRoot $repoRoot
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
