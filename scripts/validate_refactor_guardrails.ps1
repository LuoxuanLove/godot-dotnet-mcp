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

    Assert-FileContainsText -Path $trackerPath -Label "v1.4 refactor progress tracker" -RequiredText @(
        'MCP 2025-11-25 conformance by default',
        '2025-06-18 alignment retained as a compatibility foundation',
        'http://127.0.0.1:3000/mcp',
        'MCP Streamable HTTP',
        'legacy `/api/tools`, `/health`, JSON-only POST behavior, and `Content-Length` stdio',
        'A PR is not ready to merge into the v1.4 refactor branch until local validation, relevant GitHub checks, all conversations, and the Codex review gate are complete.'
    )
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

Assert-V14PlanConsistency -RepositoryRoot $repoRoot

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
