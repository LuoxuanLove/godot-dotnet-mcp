param(
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64",
    [string]$OutputRoot = "dist"
)

$ErrorActionPreference = "Stop"

function Reset-Directory {
    param([string]$Path)

    if (Test-Path $Path) {
        Remove-Item -Path $Path -Recurse -Force
    }

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function New-Sha256File {
    param(
        [string]$PackagePath
    )

    $hashPath = "$PackagePath.sha256"
    $assetName = Split-Path -Path $PackagePath -Leaf
    $hash = Get-FileHash -Path $PackagePath -Algorithm SHA256
    "$($hash.Hash.ToLowerInvariant())  $assetName" | Set-Content -Path $hashPath -Encoding utf8
    return $hashPath
}

function New-ZipFromStage {
    param(
        [string]$StageDir,
        [string]$PackagePath
    )

    if (Test-Path $PackagePath) {
        Remove-Item -Path $PackagePath -Force
    }

    Compress-Archive -Path (Join-Path $StageDir "*") -DestinationPath $PackagePath -CompressionLevel Optimal
    return New-Sha256File -PackagePath $PackagePath
}

function Copy-PluginSourceToStage {
    param(
        [string]$PluginSourceDir,
        [string]$StageDir
    )

    $addonsDir = Join-Path $StageDir "addons"
    New-Item -ItemType Directory -Path $addonsDir -Force | Out-Null
    Copy-Item -Path $PluginSourceDir -Destination $addonsDir -Recurse -Force
    return Join-Path $addonsDir (Split-Path -Path $PluginSourceDir -Leaf)
}

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
$distRoot = Join-Path $repoRoot $OutputRoot
$pluginSourceDir = Join-Path $repoRoot "addons/godot_dotnet_mcp"
$pluginLeanPackageName = "godot-dotnet-mcp-plugin-lean-v$version.zip"
$pluginBundledPackageName = "godot-dotnet-mcp-plugin-bundled-$Runtime-v$version.zip"

$centralDistDir = Join-Path $distRoot "central-server-win-x64"
$centralStageDir = Join-Path $centralDistDir "stage"
$centralZipPath = Join-Path $centralDistDir $assetName

$pluginLeanDistDir = Join-Path $distRoot "plugin-lean"
$pluginLeanStageDir = Join-Path $pluginLeanDistDir "stage"
$pluginLeanZipPath = Join-Path $pluginLeanDistDir $pluginLeanPackageName

$pluginBundledDistDir = Join-Path $distRoot "plugin-bundled-win-x64"
$pluginBundledStageDir = Join-Path $pluginBundledDistDir "stage"
$pluginBundledZipPath = Join-Path $pluginBundledDistDir $pluginBundledPackageName

Reset-Directory -Path $centralStageDir
Reset-Directory -Path $pluginLeanStageDir
Reset-Directory -Path $pluginBundledStageDir
New-Item -ItemType Directory -Path $centralDistDir -Force | Out-Null
New-Item -ItemType Directory -Path $pluginLeanDistDir -Force | Out-Null
New-Item -ItemType Directory -Path $pluginBundledDistDir -Force | Out-Null

dotnet publish `
    (Join-Path $repoRoot "central_server/CentralServer.csproj") `
    -c $Configuration `
    -r $Runtime `
    --self-contained true `
    /p:PublishSingleFile=false `
    /p:DebugType=embedded

Copy-Item -Path (Join-Path $publishDir "*") -Destination $centralStageDir -Recurse -Force
$centralHashPath = New-ZipFromStage -StageDir $centralStageDir -PackagePath $centralZipPath

$pluginLeanAddonDir = Copy-PluginSourceToStage -PluginSourceDir $pluginSourceDir -StageDir $pluginLeanStageDir
$pluginLeanBundleDir = Join-Path $pluginLeanAddonDir "central_server_packages"
Get-ChildItem -Path $pluginLeanBundleDir -Filter "*.zip" -File -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -Path $pluginLeanBundleDir -Filter "*.sha256" -File -ErrorAction SilentlyContinue | Remove-Item -Force
$pluginLeanHashPath = New-ZipFromStage -StageDir $pluginLeanStageDir -PackagePath $pluginLeanZipPath

$pluginBundledAddonDir = Copy-PluginSourceToStage -PluginSourceDir $pluginSourceDir -StageDir $pluginBundledStageDir
$pluginBundledBundleDir = Join-Path $pluginBundledAddonDir "central_server_packages"
Get-ChildItem -Path $pluginBundledBundleDir -Filter "*.zip" -File -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -Path $pluginBundledBundleDir -Filter "*.sha256" -File -ErrorAction SilentlyContinue | Remove-Item -Force
Copy-Item -Path $centralZipPath -Destination (Join-Path $pluginBundledBundleDir $assetName) -Force
Copy-Item -Path $centralHashPath -Destination (Join-Path $pluginBundledBundleDir "$assetName.sha256") -Force
$pluginBundledHashPath = New-ZipFromStage -StageDir $pluginBundledStageDir -PackagePath $pluginBundledZipPath

Write-Host "Central server package created:"
Write-Host "  Zip:  $centralZipPath"
Write-Host "  SHA:  $centralHashPath"
Write-Host "Plugin lean package created:"
Write-Host "  Zip:  $pluginLeanZipPath"
Write-Host "  SHA:  $pluginLeanHashPath"
Write-Host "Plugin bundled package created:"
Write-Host "  Zip:  $pluginBundledZipPath"
Write-Host "  SHA:  $pluginBundledHashPath"
Write-Host "Bundled package injection is now staged under dist output only; the source tree is not overwritten."
