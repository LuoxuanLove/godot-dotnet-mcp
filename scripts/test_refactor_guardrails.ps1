param()

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $PSScriptRoot
$validatorPath = Join-Path $scriptRoot "scripts\validate_refactor_guardrails.ps1"
$manifestPath = Join-Path $scriptRoot "scripts\contract_case_manifest.json"

function Write-GuardrailFixture {
    param(
        [string]$RepositoryRoot,
        [string]$RootReadmeText,
        [string]$AddonReadmeText
    )

    git -C $RepositoryRoot init | Out-Null
    git -C $RepositoryRoot config user.email "fixture@example.com" | Out-Null
    git -C $RepositoryRoot config user.name "Fixture" | Out-Null

    New-Item -ItemType Directory -Path (Join-Path $RepositoryRoot "addons\godot_dotnet_mcp") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $RepositoryRoot "scripts") -Force | Out-Null

    Copy-Item -LiteralPath $validatorPath -Destination (Join-Path $RepositoryRoot "scripts\validate_refactor_guardrails.ps1")
    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $RepositoryRoot "scripts\contract_case_manifest.json")
    Set-Content -LiteralPath (Join-Path $RepositoryRoot "README.md") -Value $RootReadmeText -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $RepositoryRoot "addons\godot_dotnet_mcp\README.md") -Value $AddonReadmeText -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $RepositoryRoot "addons\godot_dotnet_mcp\README.zh-CN.md") -Value $AddonReadmeText -Encoding UTF8

    git -C $RepositoryRoot add README.md addons/godot_dotnet_mcp/README.md addons/godot_dotnet_mcp/README.zh-CN.md scripts/validate_refactor_guardrails.ps1 scripts/contract_case_manifest.json | Out-Null
    git -C $RepositoryRoot commit -m "fixture" | Out-Null
}

function Invoke-GuardrailScenario {
    param(
        [string]$Name,
        [string]$RootReadmeText,
        [string]$AddonReadmeText,
        [bool]$ShouldPass
    )

    $repo = Join-Path ([System.IO.Path]::GetTempPath()) ("godot-dotnet-mcp-refactor-guardrails-" + [System.Guid]::NewGuid().ToString("N"))
    $previousLocation = (Get-Location).Path
    New-Item -ItemType Directory -Path $repo | Out-Null
    try {
        Write-GuardrailFixture -RepositoryRoot $repo -RootReadmeText $RootReadmeText -AddonReadmeText $AddonReadmeText
        $passed = $true
        $failureMessage = ""
        try {
            $output = & (Join-Path $repo "scripts\validate_refactor_guardrails.ps1") -SkipVersionPolicy 2>&1
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

Use Godot Asset Library installation or direct source-copy installation.
"@

Invoke-GuardrailScenario -Name "release-facing README install paths" -RootReadmeText $cleanRootReadme -AddonReadmeText $cleanAddonReadme -ShouldPass $true

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
