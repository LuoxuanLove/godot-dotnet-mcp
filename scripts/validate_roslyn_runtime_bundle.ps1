param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$projectPath = Join-Path $repoRoot "addons\godot_dotnet_mcp\dotnet_bridge\DotnetBridge.csproj"
$runtimeDirectory = Join-Path $repoRoot "addons\godot_dotnet_mcp\plugin\runtime\roslyn_runtime"
$manifestPath = Join-Path $runtimeDirectory "roslyn-runtime-manifest.json"
$publishDirectory = Join-Path $repoRoot ".tmp\roslyn_runtime_bundle_publish"

if (-not (Test-Path -LiteralPath $projectPath)) {
    throw "Roslyn bridge project was not found: $projectPath"
}

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Roslyn runtime manifest was not found: $manifestPath"
}

if (Test-Path -LiteralPath $publishDirectory) {
    Remove-Item -LiteralPath $publishDirectory -Recurse -Force
}
New-Item -ItemType Directory -Path $publishDirectory | Out-Null

try {
    dotnet clean $projectPath -c $Configuration | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet clean failed for Roslyn bridge project with exit code $LASTEXITCODE."
    }

    dotnet publish $projectPath -c $Configuration -o $publishDirectory --no-self-contained -p:Deterministic=true -p:IncludeSourceRevisionInInformationalVersion=false | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet publish failed for Roslyn bridge project with exit code $LASTEXITCODE."
    }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.schema -ne 1) {
        throw "Roslyn runtime manifest schema must be 1."
    }
    if ([string]$manifest.distribution -ne "framework-dependent") {
        throw "Roslyn runtime manifest distribution must be framework-dependent."
    }
    if ([string]$manifest.source_surface -ne "excluded") {
        throw "Roslyn runtime manifest source_surface must be excluded."
    }
    if ([string]$manifest.semantic_runtime -ne "Roslyn") {
        throw "Roslyn runtime manifest semantic_runtime must be Roslyn."
    }
    if ([string]$manifest.runtime_requirements.host -ne "dotnet" -or [string]$manifest.runtime_requirements.framework -ne "Microsoft.NETCore.App" -or [string]$manifest.runtime_requirements.version -ne "8.0.0") {
        throw "Roslyn runtime manifest must declare the .NET 8 framework-dependent runtime requirement."
    }

    $files = @($manifest.files | ForEach-Object { [string]$_ })
    if ($files.Count -eq 0) {
        throw "Roslyn runtime manifest must list required runtime files."
    }

    $errors = New-Object System.Collections.Generic.List[string]
    foreach ($fileName in $files) {
        if ([string]::IsNullOrWhiteSpace($fileName) -or $fileName.Contains("/") -or $fileName.Contains("\")) {
            $errors.Add("Manifest file entry must be a single file name: '$fileName'")
            continue
        }

        $publishedPath = Join-Path $publishDirectory $fileName
        $bundledPath = Join-Path $runtimeDirectory $fileName
        if (-not (Test-Path -LiteralPath $publishedPath)) {
            $errors.Add("Published Roslyn runtime output is missing manifest file: $fileName")
            continue
        }
        if (-not (Test-Path -LiteralPath $bundledPath)) {
            $errors.Add("Bundled Roslyn runtime is missing manifest file: $fileName")
            continue
        }

        $publishedItem = Get-Item -LiteralPath $publishedPath
        $bundledItem = Get-Item -LiteralPath $bundledPath
        if ($publishedItem.Length -le 0 -or $bundledItem.Length -le 0) {
            $errors.Add("Roslyn runtime manifest file must not be empty: $fileName")
            continue
        }

        if ($fileName.EndsWith(".dll", [System.StringComparison]::OrdinalIgnoreCase)) {
            $publishedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $publishedPath).Hash
            $bundledHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $bundledPath).Hash
            if ($publishedHash -ne $bundledHash) {
                $errors.Add("Bundled Roslyn runtime payload is out of sync with dotnet publish output: $fileName")
            }
        }
    }

    $sourceFiles = @(Get-ChildItem -LiteralPath $runtimeDirectory -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Extension -in @(".cs", ".csproj", ".sln")
    })
    foreach ($sourceFile in $sourceFiles) {
        $errors.Add("Roslyn runtime bundle must not contain source/build input file: $($sourceFile.FullName)")
    }

    $allowedBundleFiles = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::Ordinal)
    [void]$allowedBundleFiles.Add("roslyn-runtime-manifest.json")
    [void]$allowedBundleFiles.Add(".gitkeep")
    foreach ($fileName in $files) {
        [void]$allowedBundleFiles.Add($fileName)
    }

    $extraBundleFiles = @(Get-ChildItem -LiteralPath $runtimeDirectory -File -ErrorAction SilentlyContinue | Where-Object {
        -not $allowedBundleFiles.Contains($_.Name)
    })
    foreach ($extraFile in $extraBundleFiles) {
        $errors.Add("Roslyn runtime bundle contains file not listed in manifest: $($extraFile.Name)")
    }

    if ($errors.Count -gt 0) {
        throw ($errors -join [Environment]::NewLine)
    }

    Write-Host "Roslyn runtime manifest validated for $($files.Count) framework-dependent files; DLL payload hashes match dotnet publish output."
}
finally {
    if (Test-Path -LiteralPath $publishDirectory) {
        Remove-Item -LiteralPath $publishDirectory -Recurse -Force
    }
}
