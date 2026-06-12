param()

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $PSScriptRoot
$validatorPath = Join-Path $scriptRoot "scripts\validate_refactor_guardrails.ps1"
$manifestPath = Join-Path $scriptRoot "scripts\contract_case_manifest.json"
$roslynRuntimeGuardPath = Join-Path $scriptRoot "scripts\validate_roslyn_runtime_bundle.ps1"

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Text
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function Write-GuardrailFixture {
    param(
        [string]$RepositoryRoot,
        [string]$RootReadmeText,
        [string]$AddonReadmeText,
        [switch]$MissingTrackerFact,
        [switch]$ContradictoryLegacyFacts
    )

    git -C $RepositoryRoot init | Out-Null
    git -C $RepositoryRoot config user.email "fixture@example.com" | Out-Null
    git -C $RepositoryRoot config user.name "Fixture" | Out-Null

    New-Item -ItemType Directory -Path (Join-Path $RepositoryRoot "addons\godot_dotnet_mcp") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $RepositoryRoot "scripts") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $RepositoryRoot ".github\workflows") -Force | Out-Null

    Copy-Item -LiteralPath $validatorPath -Destination (Join-Path $RepositoryRoot "scripts\validate_refactor_guardrails.ps1")
    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $RepositoryRoot "scripts\contract_case_manifest.json")
    Copy-Item -LiteralPath $roslynRuntimeGuardPath -Destination (Join-Path $RepositoryRoot "scripts\validate_roslyn_runtime_bundle.ps1")
    Set-Content -LiteralPath (Join-Path $RepositoryRoot "README.md") -Value $RootReadmeText -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $RepositoryRoot "addons\godot_dotnet_mcp\README.md") -Value $AddonReadmeText -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $RepositoryRoot "addons\godot_dotnet_mcp\README.zh-CN.md") -Value $AddonReadmeText -Encoding UTF8

    $planText = @'
# v1.4.0 Protocol Refactor Plan

MCP 2025-11-25
protocolVersion = 2025-11-25
http://127.0.0.1:3000/mcp
Accept: application/json, text/event-stream
MCP-Protocol-Version: 2025-11-25
Sampling, Elicitation, and Tasks as optional capabilities
do not implement or advertise them by default
legacy compatibility surfaces
'@

    $trackerText = @'
# v1.4.0 Refactor Progress Tracker

MCP 2025-11-25 conformance by default
2025-06-18 alignment retained as a compatibility foundation
http://127.0.0.1:3000/mcp
MCP Streamable HTTP
legacy `/api/tools`, `/health`, JSON-only POST behavior, and `Content-Length` stdio
A PR is not ready to merge into the v1.4 refactor branch until local validation, relevant GitHub checks, all conversations, and the Codex review gate are complete.
'@

    if ($MissingTrackerFact) {
        $trackerText = $trackerText.Replace("MCP Streamable HTTP", "HTTP endpoint")
    }
    if ($ContradictoryLegacyFacts) {
        $planText += @'

protocolVersion = 2025-06-18
/api/tools is the default endpoint.
'@
        $trackerText += @'

MCP 2025-06-18 is the default target baseline.
/api/tools is the canonical MCP endpoint.
'@
    }

    Write-Utf8NoBom -Path (Join-Path $RepositoryRoot "docs\en\process\v1.4.0-protocol-refactor-plan.md") -Text $planText
    Write-Utf8NoBom -Path (Join-Path $RepositoryRoot "docs\en\process\v1.4.0-refactor-progress-tracker.md") -Text $trackerText
    Write-Utf8NoBom -Path (Join-Path $RepositoryRoot ".github\workflows\pr-policy.yml") -Text @'
name: pr-policy
on:
  pull_request:
  merge_group:
jobs:
  pr-standards:
    steps:
      - run: python scripts/test_validate_pr_policy.py
'@
    Write-Utf8NoBom -Path (Join-Path $RepositoryRoot ".github\workflows\version-policy.yml") -Text @'
name: version-policy
on:
  pull_request_target:
  merge_group:
'@

    git -C $RepositoryRoot add README.md addons/godot_dotnet_mcp/README.md addons/godot_dotnet_mcp/README.zh-CN.md scripts/validate_refactor_guardrails.ps1 scripts/contract_case_manifest.json scripts/validate_roslyn_runtime_bundle.ps1 .github/workflows/pr-policy.yml .github/workflows/version-policy.yml docs/en/process/v1.4.0-protocol-refactor-plan.md docs/en/process/v1.4.0-refactor-progress-tracker.md | Out-Null
    git -C $RepositoryRoot commit -m "fixture" | Out-Null
}

function Invoke-GuardrailScenario {
    param(
        [string]$Name,
        [string]$RootReadmeText,
        [string]$AddonReadmeText,
        [bool]$ShouldPass,
        [switch]$MissingTrackerFact,
        [switch]$ContradictoryLegacyFacts
    )

    $repo = Join-Path ([System.IO.Path]::GetTempPath()) ("godot-dotnet-mcp-refactor-guardrails-" + [System.Guid]::NewGuid().ToString("N"))
    $previousLocation = (Get-Location).Path
    New-Item -ItemType Directory -Path $repo | Out-Null
    try {
        Write-GuardrailFixture -RepositoryRoot $repo -RootReadmeText $RootReadmeText -AddonReadmeText $AddonReadmeText -MissingTrackerFact:$MissingTrackerFact -ContradictoryLegacyFacts:$ContradictoryLegacyFacts
        $passed = $true
        $failureMessage = ""
        try {
            $output = & (Join-Path $repo "scripts\validate_refactor_guardrails.ps1") -SkipVersionPolicy -SkipBridgeSafeWrites 2>&1
            $output | Out-Host
        } catch {
            $passed = $false
            $failureMessage = $_.Exception.Message
            Write-Host "Scenario '$Name' failed as expected candidate: $failureMessage"
        }

        if ($passed -ne $ShouldPass) {
            throw "Scenario '$Name' expected pass=$ShouldPass but got pass=$passed."
        }
        if (-not $ShouldPass -and $failureMessage -notlike "*Refactor guardrail validation failed*") {
            throw "Scenario '$Name' failed with unexpected message: $failureMessage"
        }
        Write-Host "Scenario '$Name' passed."
    } finally {
        Set-Location $previousLocation
        Remove-Item -LiteralPath $repo -Recurse -Force
    }
}

$cleanRootReadme = @"
# Fixture

## Installation

Install from the Godot Asset Library or copy `addons/godot_dotnet_mcp` directly into a Godot project.
"@

$cleanAddonReadme = @"
# Addon Fixture

## Installation

Use Godot Asset Library installation or prepared installable addon contents.
"@

Invoke-GuardrailScenario -Name "release-facing README install paths" -RootReadmeText $cleanRootReadme -AddonReadmeText $cleanAddonReadme -ShouldPass $true
Invoke-GuardrailScenario -Name "missing v1.4 tracker MCP fact" -RootReadmeText $cleanRootReadme -AddonReadmeText $cleanAddonReadme -ShouldPass $false -MissingTrackerFact
Invoke-GuardrailScenario -Name "contradictory legacy MCP target facts" -RootReadmeText $cleanRootReadme -AddonReadmeText $cleanAddonReadme -ShouldPass $false -ContradictoryLegacyFacts

$zipReadme = @"
# Fixture

## Installation

Download `godot-dotnet-mcp-1.4.0.zip` and extract it into the project.
"@

Invoke-GuardrailScenario -Name "forbidden zip install wording" -RootReadmeText $zipReadme -AddonReadmeText $cleanAddonReadme -ShouldPass $false

$releasePackageReadme = @"
# Fixture

## Installation

Download the release-package build and extract it into the project.
"@

Invoke-GuardrailScenario -Name "forbidden release-package install wording" -RootReadmeText $releasePackageReadme -AddonReadmeText $cleanAddonReadme -ShouldPass $false

$localReleaseReadme = @"
# Fixture

## Installation

Install from the local-release bundle and copy it into the project.
"@

Invoke-GuardrailScenario -Name "forbidden local-release install wording" -RootReadmeText $localReleaseReadme -AddonReadmeText $cleanAddonReadme -ShouldPass $false

$zipPackageReadme = @"
# Fixture

## Installation

Use the zip_package installer artifact for manual installation.
"@

Invoke-GuardrailScenario -Name "forbidden zip_package install wording" -RootReadmeText $zipPackageReadme -AddonReadmeText $cleanAddonReadme -ShouldPass $false

$zipArchiveReadme = @"
# Fixture

## Installation

Download the ZIP archive from GitHub Releases and extract it into the project.
"@

Invoke-GuardrailScenario -Name "forbidden zip archive install wording" -RootReadmeText $zipArchiveReadme -AddonReadmeText $cleanAddonReadme -ShouldPass $false

$zipDownloadReadme = @"
# Fixture

## Installation

Download a zip from GitHub Releases and extract it into the project.
"@

Invoke-GuardrailScenario -Name "forbidden zip download install wording" -RootReadmeText $zipDownloadReadme -AddonReadmeText $cleanAddonReadme -ShouldPass $false

$releaseDistReadme = @"
# Fixture

## Installation

Copy files from release_dist into the project.
"@

Invoke-GuardrailScenario -Name "forbidden release_dist install wording" -RootReadmeText $releaseDistReadme -AddonReadmeText $cleanAddonReadme -ShouldPass $false

Write-Host "Refactor guardrail policy scenarios validated successfully."
