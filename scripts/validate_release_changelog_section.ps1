param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string[]]$ChangelogPaths = @(
        "docs/en/CHANGELOG.md",
        "docs/zh-CN/变更日志.md",
        "docs/ja/変更履歴.md",
        "docs/ko/변경-로그.md"
    )
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

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
