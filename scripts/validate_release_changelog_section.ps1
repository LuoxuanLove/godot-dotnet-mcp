param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string[]]$ChangelogPaths = $null
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

function ConvertFrom-Utf8Bytes {
    param(
        [Parameter(Mandatory = $true)]
        [int[]]$Bytes
    )

    return [System.Text.Encoding]::UTF8.GetString([byte[]]$Bytes)
}

$defaultChangelogPaths = @(
    "docs/en/CHANGELOG.md",
    (Join-Path "docs/zh-CN" (ConvertFrom-Utf8Bytes @(229, 143, 152, 230, 155, 180, 230, 151, 165, 229, 191, 151, 46, 109, 100))),
    (Join-Path "docs/ja" (ConvertFrom-Utf8Bytes @(229, 164, 137, 230, 155, 180, 229, 177, 165, 230, 173, 180, 46, 109, 100))),
    (Join-Path "docs/ko" (ConvertFrom-Utf8Bytes @(235, 179, 128, 234, 178, 189, 45, 235, 161, 156, 234, 183, 184, 46, 109, 100)))
)

if ($null -eq $ChangelogPaths -or $ChangelogPaths.Count -eq 0) {
    $ChangelogPaths = $defaultChangelogPaths
}

function Test-FormalVersionHeading {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Heading,
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    $trimmed = $Heading.Trim()
    if ($trimmed -notmatch '^##\s+') {
        return $false
    }
    if ($trimmed -match '(?i)\bunreleased\b') {
        return $false
    }

    $escapedVersion = [regex]::Escape($Version)
    $versionTokenPattern = "(?:[vV])?$escapedVersion"
    return $trimmed -match "^##\s+(?:\[$versionTokenPattern\]|$versionTokenPattern)(?:\s+-.*)?\s*$"
}

$errors = New-Object System.Collections.Generic.List[string]
foreach ($path in $ChangelogPaths) {
    if (-not (Test-Path -LiteralPath $path)) {
        $errors.Add("Changelog file not found: $path")
        continue
    }

    $lines = @(Get-Content -LiteralPath $path -Encoding UTF8)
    $matchingHeadings = @()
    foreach ($line in $lines) {
        if (Test-FormalVersionHeading -Heading $line -Version $Version) {
            $matchingHeadings += $line.Trim()
        }
    }

    if ($matchingHeadings.Count -eq 0) {
        $errors.Add("$path must contain a formal '## [$Version]' or '## $Version' release section before publishing. An Unreleased section that merely targets $Version is not sufficient for a formal release.")
    } elseif ($matchingHeadings.Count -gt 1) {
        $errors.Add("$path contains duplicate formal release sections for $Version.")
    }
}

if ($errors.Count -gt 0) {
    foreach ($errorMessage in $errors) {
        Write-Error $errorMessage
    }
    throw "Release changelog section validation failed."
}

Write-Host "Release changelog sections validated for $Version."
