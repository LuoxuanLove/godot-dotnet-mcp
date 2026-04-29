$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$errors = New-Object System.Collections.Generic.List[string]

$bannedSourcePatterns = @(
    "host_shared/"
)

function Find-BannedSourceMatches {
    param(
        [string]$Pattern,
        [string]$RepositoryRoot
    )

    $ripgrep = Get-Command rg -ErrorAction SilentlyContinue
    if ($null -ne $ripgrep) {
        try {
            $matches = @(
                & $ripgrep.Source -n --case-sensitive `
                    --glob "addons/**/*.gd" `
                    --glob "addons/**/*.cs" `
                    --glob "docs/**/*.md" `
                    --glob ".github/**/*.yml" `
                    --glob ".github/**/*.yaml" `
                    --glob "scripts/**/*.ps1" `
                    --glob "README.md" `
                    --glob "README.zh-CN.md" `
                    --glob "AGENTS.md" `
                    --glob "CLAUDE.md" `
                    --glob "addons/godot_dotnet_mcp/dotnet_bridge/**/*.cs" `
                    $Pattern $RepositoryRoot 2>$null
            )
            if ($LASTEXITCODE -eq 0) {
                return $matches
            }
            if ($LASTEXITCODE -eq 1) {
                return @()
            }
        }
        catch {
        }
    }

    $searchRoots = @(
        (Join-Path $RepositoryRoot "addons"),
        (Join-Path $RepositoryRoot "docs"),
        (Join-Path $RepositoryRoot ".github"),
        (Join-Path $RepositoryRoot "scripts")
    )

    $candidateFiles = @()
    foreach ($rootFile in @("README.md", "README.zh-CN.md", "AGENTS.md", "CLAUDE.md")) {
        $absoluteRootFile = Join-Path $RepositoryRoot $rootFile
        if (Test-Path $absoluteRootFile) {
            $candidateFiles += Get-Item -LiteralPath $absoluteRootFile
        }
    }

    foreach ($root in $searchRoots) {
        if (Test-Path $root) {
            $candidateFiles += Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object {
                $_.Extension -in @(".gd", ".cs", ".md", ".yml", ".yaml", ".ps1")
            }
        }
    }

    $selfPath = Join-Path $RepositoryRoot "scripts\validate_refactor_guardrails.ps1"
    $candidateFiles = $candidateFiles | Where-Object {
        $_.FullName -ne $selfPath
    }

    $results = New-Object System.Collections.Generic.List[string]
    foreach ($file in $candidateFiles) {
            $matches = Select-String -LiteralPath $file.FullName -Pattern $Pattern -SimpleMatch -CaseSensitive -Encoding UTF8
        foreach ($match in $matches) {
            $relativePath = Get-RelativePath -BasePath $RepositoryRoot -TargetPath $file.FullName
            $results.Add(("{0}:{1}:{2}" -f $relativePath, $match.LineNumber, $match.Line.Trim()))
        }
    }

    return $results.ToArray()
}

function Get-RelativePath {
    param(
        [string]$BasePath,
        [string]$TargetPath
    )

    $baseFullPath = (Resolve-Path -LiteralPath $BasePath).Path.TrimEnd('\')
    $targetFullPath = (Resolve-Path -LiteralPath $TargetPath).Path

    if ($targetFullPath.StartsWith($baseFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $targetFullPath.Substring($baseFullPath.Length).TrimStart('\')
    }

    return $TargetPath
}

$trackedReleaseArtifacts = git ls-files "release_dist" "dist" | Where-Object {
    -not [string]::IsNullOrWhiteSpace($_)
}
foreach ($artifact in $trackedReleaseArtifacts) {
    $errors.Add("Build output must not be tracked in source control: $artifact")
}

$distRoot = Join-Path $repoRoot "dist"
$expectedDirs = @(
    (Join-Path $distRoot "godot-dotnet-mcp-plugin")
)

foreach ($path in $expectedDirs) {
    if (-not (Test-Path $path)) {
        Write-Host "Info: expected dist output not present yet (acceptable before packaging): $path"
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
