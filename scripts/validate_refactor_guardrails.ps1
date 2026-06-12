param(
    [switch]$SkipVersionPolicy,
    [switch]$SkipBridgeSafeWrites,
    [switch]$SkipReleaseChangelogPolicy
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

function Assert-FileContainsText {
    param(
        [string]$Path,
        [string]$Label,
        [string[]]$RequiredText
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        $errors.Add("Required refactor document is missing: $Label ($Path)")
        return
    }

    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    foreach ($needle in $RequiredText) {
        if ($text.IndexOf($needle, [System.StringComparison]::Ordinal) -lt 0) {
            $errors.Add("Required refactor document '$Label' is missing expected MCP 2025-11-25 fact: $needle")
        }
    }
}

function Assert-FileDoesNotMatch {
    param(
        [string]$Path,
        [string]$Label,
        [hashtable[]]$BannedPatterns
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    foreach ($entry in $BannedPatterns) {
        if ($text -match $entry.Pattern) {
            $errors.Add("Required refactor document '$Label' contains contradictory MCP 2025-11-25 target fact: $($entry.Description)")
        }
    }
}

function Assert-V14PlanConsistency {
    param(
        [string]$RepositoryRoot
    )

    $planPath = Join-Path $RepositoryRoot "docs\en\process\v1.4.0-protocol-refactor-plan.md"
    $trackerPath = Join-Path $RepositoryRoot "docs\en\process\v1.4.0-refactor-progress-tracker.md"

    Assert-FileContainsText -Path $planPath -Label "v1.4 protocol refactor plan" -RequiredText @(
        "MCP 2025-11-25",
        "protocolVersion = 2025-11-25",
        "http://127.0.0.1:3000/mcp",
        "Accept: application/json, text/event-stream",
        "MCP-Protocol-Version: 2025-11-25",
        "Sampling, Elicitation, and Tasks as optional capabilities",
        "do not implement or advertise them by default",
        "legacy compatibility surfaces"
    )

    Assert-FileDoesNotMatch -Path $planPath -Label "v1.4 protocol refactor plan" -BannedPatterns @(
        @{
            Pattern = '(?im)\bprotocolVersion\s*=\s*2025-06-18\b'
            Description = 'protocolVersion = 2025-06-18'
        },
        @{
            Pattern = '(?im)\b(?:MCP\s+)?2025-06-18\b\s+(?:is|as|serves as|should be|must be)\s+(?:the\s+)?(?:default|target|goal|baseline)\b|\b(?:default|target|goal|baseline)\s+(?:protocol|version|baseline|target|goal)?\s*(?:is|:|=)\s*(?:MCP\s+)?2025-06-18\b'
            Description = 'MCP 2025-06-18 described as the default or target baseline'
        },
        @{
            Pattern = '(?im)/api/tools\s+(?:is|serves as|should be|must be)\s+(?:the\s+)?(?:default|primary|canonical)\b|(?:default|primary|canonical)\s+(?:MCP\s+)?endpoint\s+(?:is|:)\s+/api/tools\b'
            Description = '/api/tools described as the default, primary, or canonical MCP endpoint'
        }
    )

    Assert-FileContainsText -Path $trackerPath -Label "v1.4 refactor progress tracker" -RequiredText @(
        'MCP 2025-11-25 conformance by default',
        '2025-06-18 alignment retained as a compatibility foundation',
        'http://127.0.0.1:3000/mcp',
        'MCP Streamable HTTP',
        'legacy `/api/tools`, `/health`, JSON-only POST behavior, and `Content-Length` stdio',
        'A PR is not ready to merge into the v1.4 refactor branch until local validation, relevant GitHub checks, all conversations, and the Codex review gate are complete.'
    )

    Assert-FileDoesNotMatch -Path $trackerPath -Label "v1.4 refactor progress tracker" -BannedPatterns @(
        @{
            Pattern = '(?im)\bprotocolVersion\s*=\s*2025-06-18\b'
            Description = 'protocolVersion = 2025-06-18'
        },
        @{
            Pattern = '(?im)\b(?:MCP\s+)?2025-06-18\b\s+(?:is|as|serves as|should be|must be)\s+(?:the\s+)?(?:default|target|goal|baseline)\b|\b(?:default|target|goal|baseline)\s+(?:protocol|version|baseline|target|goal)?\s*(?:is|:|=)\s*(?:MCP\s+)?2025-06-18\b'
            Description = 'MCP 2025-06-18 described as the default or target baseline'
        },
        @{
            Pattern = '(?im)/api/tools\s+(?:is|serves as|should be|must be)\s+(?:the\s+)?(?:default|primary|canonical)\b|(?:default|primary|canonical)\s+(?:MCP\s+)?endpoint\s+(?:is|:)\s+/api/tools\b'
            Description = '/api/tools described as the default, primary, or canonical MCP endpoint'
        }
    )
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
    @{ Pattern = '(?i)\bgodot-dotnet-mcp-[0-9][0-9A-Za-z_.-]*\.zip\b'; Description = "versioned zip artifact install wording" },
    @{ Pattern = '(?i)\bcopy source files directly\b|\bdirect copy of the `addons/godot_dotnet_mcp/` source files\b|\bcopy (?:the )?raw repository\b|\bcopy raw source\b'; Description = "raw source-copy install wording" }
)
foreach ($relativeReadmePath in $releaseFacingReadmes) {
    $absoluteReadmePath = Join-Path $repoRoot $relativeReadmePath
    if (-not (Test-Path -LiteralPath $absoluteReadmePath)) {
        continue
    }
    $readmeText = Get-Content -LiteralPath $absoluteReadmePath -Encoding UTF8 -Raw
    foreach ($entry in $bannedReadmeInstallPatterns) {
        if ($readmeText -match $entry.Pattern) {
            $errors.Add("Release-facing README must only document Asset Library or prepared installable addon contents; found $($entry.Description) in ${relativeReadmePath}.")
        }
    }
}

$workflowGuardSpecs = @(
    @{ Path = ".github/workflows/pr-policy.yml"; Required = @("merge_group:", "python scripts/test_validate_pr_policy.py") },
    @{ Path = ".github/workflows/version-policy.yml"; Required = @("merge_group:") }
)
foreach ($spec in $workflowGuardSpecs) {
    $workflowPath = Join-Path $repoRoot $spec.Path
    if (-not (Test-Path -LiteralPath $workflowPath)) {
        $errors.Add("Required workflow guard file is missing: $($spec.Path)")
        continue
    }
    $workflowText = Get-Content -LiteralPath $workflowPath -Raw -Encoding UTF8
    foreach ($requiredText in $spec.Required) {
        if (-not $workflowText.Contains($requiredText)) {
            $errors.Add("Workflow guard '$($spec.Path)' must contain '$requiredText'.")
        }
    }
}

$roslynRuntimeBundleScript = Join-Path $repoRoot "scripts\validate_roslyn_runtime_bundle.ps1"
if (-not (Test-Path -LiteralPath $roslynRuntimeBundleScript)) {
    $errors.Add("Roslyn runtime release guard script is missing: scripts\validate_roslyn_runtime_bundle.ps1")
}
else {
    $roslynRuntimeBundleScriptText = Get-Content -LiteralPath $roslynRuntimeBundleScript -Raw -Encoding UTF8
    foreach ($requiredText in @("dotnet publish", "roslyn-runtime-manifest.json", "Get-FileHash", "isolated-runtime-bundle")) {
        if (-not $roslynRuntimeBundleScriptText.Contains($requiredText)) {
            $errors.Add("Roslyn runtime release guard script must contain '$requiredText'.")
        }
    }
}

$roslynHarnessScript = Join-Path $repoRoot "scripts\test_plugin_side_roslyn.ps1"
if (Test-Path -LiteralPath $roslynHarnessScript) {
    $roslynHarnessScriptText = Get-Content -LiteralPath $roslynHarnessScript -Raw -Encoding UTF8
    foreach ($requiredText in @("validate_roslyn_runtime_bundle.ps1", "exportedPluginRoslynServiceProbeSucceeded")) {
        if (-not $roslynHarnessScriptText.Contains($requiredText)) {
            $errors.Add("Plugin-side Roslyn harness must contain '$requiredText'.")
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

Assert-V14PlanConsistency -RepositoryRoot $repoRoot

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

if ($SkipBridgeSafeWrites) {
    Write-Host "Dotnet bridge safe-write regression tests skipped: caller opted out."
} else {
    & "$PSScriptRoot\test_dotnet_bridge_safe_writes.ps1"
    if ($LASTEXITCODE -ne 0) {
        throw "Dotnet bridge safe-write regression tests failed with exit code $LASTEXITCODE."
    }
}

if ($SkipReleaseChangelogPolicy) {
    Write-Host "Release changelog section policy tests skipped: caller opted out."
} else {
    & "$PSScriptRoot\test_release_changelog_section.ps1"
    if ($LASTEXITCODE -ne 0) {
        throw "Release changelog section policy tests failed with exit code $LASTEXITCODE."
    }
}
