param()

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $PSScriptRoot
$validatorPath = Join-Path $scriptRoot "scripts\validate_release_changelog_section.ps1"

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function Invoke-ReleaseChangelogScenario {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$ChangelogPath,
        [Parameter(Mandatory = $true)]
        [string]$ChangelogText,
        [Parameter(Mandatory = $true)]
        [bool]$ShouldPass
    )

    $repo = Join-Path ([System.IO.Path]::GetTempPath()) ("godot-dotnet-mcp-release-changelog-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $repo | Out-Null
    try {
        if ([string]::IsNullOrWhiteSpace($ChangelogPath)) {
            throw "Scenario '$Name' contains a changelog fixture without a Path."
        }
        $target = Join-Path $repo $ChangelogPath
        Write-Utf8NoBom -Path $target -Text $ChangelogText
        $paths = @($target)

        $passed = $true
        $failureMessage = ""
        try {
            $output = & $validatorPath -Version "1.4.0" -ChangelogPaths $paths 2>&1
            $output | Out-Host
        } catch {
            $passed = $false
            $failureMessage = $_.Exception.Message
            Write-Host "Scenario '$Name' failed as expected candidate: $failureMessage"
        }

        if ($passed -ne $ShouldPass) {
            throw "Scenario '$Name' expected pass=$ShouldPass but got pass=$passed."
        }
        if (-not $ShouldPass -and $failureMessage -notlike "*Release changelog section validation failed*" -and $failureMessage -notlike "*must contain a formal*" -and $failureMessage -notlike "*duplicate formal release sections*") {
            throw "Scenario '$Name' failed with unexpected message: $failureMessage"
        }
        Write-Host "Scenario '$Name' passed."
    } finally {
        Remove-Item -LiteralPath $repo -Recurse -Force
    }
}

$formalChangelog = @"
# Changelog

## [1.4.0] - 2026-06-13

- Final release item.
"@

$unreleasedTargetChangelog = @"
# Changelog

## [Unreleased] ([1.4.0])

Target version: 1.4.0.

- Development item.
"@

$duplicateChangelog = @"
# Changelog

## [1.4.0]

- First item.

## 1.4.0 - 2026-06-13

- Duplicate item.
"@

Invoke-ReleaseChangelogScenario -Name "formal release sections" -ChangelogPath "docs/en/CHANGELOG.md" -ChangelogText $formalChangelog -ShouldPass $true
Invoke-ReleaseChangelogScenario -Name "unreleased target is not formal release" -ChangelogPath "docs/en/CHANGELOG.md" -ChangelogText $unreleasedTargetChangelog -ShouldPass $false
Invoke-ReleaseChangelogScenario -Name "duplicate formal release sections" -ChangelogPath "docs/en/CHANGELOG.md" -ChangelogText $duplicateChangelog -ShouldPass $false

Write-Host "Release changelog section policy scenarios validated successfully."
$global:LASTEXITCODE = 0
