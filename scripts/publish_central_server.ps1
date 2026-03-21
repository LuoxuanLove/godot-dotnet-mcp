param(
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64",
    [string]$OutputRoot = "release_dist/central_server",
    [string]$BundledPackageRoot = "addons/godot_dotnet_mcp/central_server_packages"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot "addons/godot_dotnet_mcp/central_server_release_manifest.json"
if (-not (Test-Path $manifestPath)) {
    throw "Central server release manifest not found: $manifestPath"
}

$manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
$version = [string]$manifest.version
$assetTemplate = [string]$manifest.asset_name_template
if ([string]::IsNullOrWhiteSpace($version) -or [string]::IsNullOrWhiteSpace($assetTemplate)) {
    throw "Release manifest is missing version or asset_name_template."
}

$assetName = $assetTemplate.Replace("{version}", $version)
$publishDir = Join-Path $repoRoot "central_server/bin/$Configuration/net8.0/$Runtime/publish"
$distDir = Join-Path $repoRoot $OutputRoot
$stageDir = Join-Path $distDir "stage"
$zipPath = Join-Path $distDir $assetName
$hashPath = "$zipPath.sha256"
$bundledDir = Join-Path $repoRoot $BundledPackageRoot
$bundledZipPath = Join-Path $bundledDir $assetName
$bundledHashPath = "$bundledZipPath.sha256"

if (Test-Path $stageDir) {
    Remove-Item -Path $stageDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stageDir -Force | Out-Null
New-Item -ItemType Directory -Path $distDir -Force | Out-Null
New-Item -ItemType Directory -Path $bundledDir -Force | Out-Null

dotnet publish `
    (Join-Path $repoRoot "central_server/CentralServer.csproj") `
    -c $Configuration `
    -r $Runtime `
    --self-contained true `
    /p:PublishSingleFile=false `
    /p:DebugType=embedded

Copy-Item -Path (Join-Path $publishDir "*") -Destination $stageDir -Recurse -Force

if (Test-Path $zipPath) {
    Remove-Item -Path $zipPath -Force
}
Compress-Archive -Path (Join-Path $stageDir "*") -DestinationPath $zipPath -CompressionLevel Optimal

$hash = Get-FileHash -Path $zipPath -Algorithm SHA256
"$($hash.Hash.ToLowerInvariant())  $assetName" | Set-Content -Path $hashPath -Encoding utf8

Get-ChildItem -Path $bundledDir -Filter "*.zip" -File -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -Path $bundledDir -Filter "*.sha256" -File -ErrorAction SilentlyContinue | Remove-Item -Force
Copy-Item -Path $zipPath -Destination $bundledZipPath -Force
Copy-Item -Path $hashPath -Destination $bundledHashPath -Force

Write-Host "Central server package created:"
Write-Host "  Zip:  $zipPath"
Write-Host "  SHA:  $hashPath"
Write-Host "Bundled plugin package updated:"
Write-Host "  Zip:  $bundledZipPath"
Write-Host "  SHA:  $bundledHashPath"
