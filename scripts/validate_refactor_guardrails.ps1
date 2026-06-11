param(
    [switch]$SkipVersionPolicy
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$errors = New-Object System.Collections.Generic.List[string]

$bannedSourcePatterns = @(
    "host_shared/"
)

$allowedManifestValues = @{
    mcp_version = @("2025-11-25", "2025-06-18", "legacy")
    conformance = @("required", "compat", "optional")
}

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
                    --glob "!scripts/validate_refactor_guardrails.ps1" `
                    --glob "README.md" `
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
    foreach ($rootFile in @("README.md", "AGENTS.md", "CLAUDE.md")) {
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

$releaseFacingReadmes = @(
    "README.md",
    "addons/godot_dotnet_mcp/README.md",
    "addons/godot_dotnet_mcp/README.zh-CN.md"
)
$bannedReadmeInstallPatterns = @(
    @{ Pattern = '(?i)\brelease[_ -]?dist\b'; Description = "release_dist install path" },
    @{ Pattern = '(?i)\brelease[ _-]package\b'; Description = "release package install wording" },
    @{ Pattern = '(?i)\blocal[ _-]release\b'; Description = "local release install wording" },
    @{ Pattern = '(?i)(?:^|[^A-Za-z0-9])zip(?:[ _-](?:package|archive|file|bundle|installer|download))?(?=$|[^A-Za-z0-9])'; Description = "zip install wording" },
    @{ Pattern = '(?i)\b(?:download|extract|install|release|releases)\b[^\r\n]{0,80}(?:^|[^A-Za-z0-9])zip(?=$|[^A-Za-z0-9])|(?:^|[^A-Za-z0-9])zip(?=$|[^A-Za-z0-9])[^\r\n]{0,80}\b(?:download|extract|install|release|releases)\b'; Description = "zip install context wording" },
    @{ Pattern = '(?i)\bgodot-dotnet-mcp-[0-9][0-9A-Za-z_.-]*\.zip\b'; Description = "versioned zip artifact install wording" }
)
foreach ($relativeReadmePath in $releaseFacingReadmes) {
    $absoluteReadmePath = Join-Path $repoRoot $relativeReadmePath
    if (-not (Test-Path -LiteralPath $absoluteReadmePath)) {
        continue
    }
    $readmeText = Get-Content -LiteralPath $absoluteReadmePath -Encoding UTF8 -Raw
    foreach ($entry in $bannedReadmeInstallPatterns) {
        if ($readmeText -match $entry.Pattern) {
            $errors.Add("Release-facing README must only document Asset Library or direct source-copy installs; found $($entry.Description) in ${relativeReadmePath}.")
        }
    }
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

$manifestPath = Join-Path $repoRoot "scripts\contract_case_manifest.json"
if (Test-Path -LiteralPath $manifestPath) {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest -isnot [array]) {
        $manifest = @($manifest)
    }
    foreach ($case in $manifest) {
        foreach ($field in $allowedManifestValues.Keys) {
            if (-not ($case.PSObject.Properties.Name -contains $field)) {
                $errors.Add("Contract case manifest entry '$($case.name)' is missing required field: $field")
                continue
            }
            $value = [string]$case.$field
            if ($allowedManifestValues[$field] -notcontains $value) {
                $errors.Add("Contract case manifest entry '$($case.name)' has invalid ${field}: '$value'")
            }
        }

        $isLegacyOrRemoval = $case.behavior -in @("deprecation", "removal_guard") -or $case.v1_4_disposition -in @("delete", "expires")
        if ($isLegacyOrRemoval -and [string]$case.conformance -ne "compat") {
            $errors.Add("Contract case manifest entry '$($case.name)' covers legacy/removal behavior and must use conformance='compat'.")
        }
        if (-not $isLegacyOrRemoval -and [string]$case.mcp_version -eq "legacy") {
            $errors.Add("Contract case manifest entry '$($case.name)' targets current behavior and must not use mcp_version='legacy'.")
        }
    }
} else {
    $errors.Add("Contract case manifest was not found: $manifestPath")
}

if ($SkipVersionPolicy) {
    Write-Host "Version policy validation skipped: caller opted out."
} else {
    try {
        & (Join-Path $repoRoot "scripts\validate_pr_version_policy.ps1") -RepositoryRoot $repoRoot
    } catch {
        $errors.Add("Version policy validation failed: $($_.Exception.Message)")
    }
}

if ($errors.Count -gt 0) {
    foreach ($message in $errors) {
        Write-Error $message -ErrorAction Continue
    }

    throw "Refactor guardrail validation failed."
}

Write-Host "Refactor guardrails validated successfully."
