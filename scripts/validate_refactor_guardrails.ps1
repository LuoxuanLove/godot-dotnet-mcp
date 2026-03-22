$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$errors = New-Object System.Collections.Generic.List[string]

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

if ($errors.Count -gt 0) {
    foreach ($message in $errors) {
        Write-Error $message
    }

    throw "Refactor guardrail validation failed."
}

Write-Host "Refactor guardrails validated successfully."
