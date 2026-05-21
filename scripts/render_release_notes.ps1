[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Version,

  [Parameter(Mandatory = $true)]
  [string]$OutputPath,

  [string]$ManualNotesPath = "",
  [string]$ChangelogPath = "CHANGELOG.zh-CN.md",
  [string]$TagName = "",
  [int]$CommitLimit = 30,
  [switch]$PreferUnreleased
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$env:LESSCHARSET = "utf-8"

if ([string]::IsNullOrWhiteSpace($ManualNotesPath)) {
  $ManualNotesPath = "release-notes-v$Version.md"
}

function Read-Utf8Text {
  param([Parameter(Mandatory = $true)][string]$Path)
  return Get-Content -LiteralPath $Path -Raw -Encoding UTF8
}

function Get-ChangelogSection {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Version,
    [switch]$PreferUnreleased
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Changelog file not found: $Path"
  }

  $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
  $versionStart = -1
  $unreleasedStart = -1
  $escapedVersion = [regex]::Escape($Version)
  $versionHeadingPattern = "^##\s+(?:\[$escapedVersion\]|$escapedVersion)(?:\s+-.*)?\s*$"
  $targetVersionPattern = "^(?:Target version|目标版本)[：:]\s*[\x60]?$escapedVersion[\x60]?[。.]?\s*$"

  for ($i = 0; $i -lt $lines.Count; $i++) {
    $trimmed = $lines[$i].Trim()
    if ($unreleasedStart -lt 0 -and $trimmed -eq "## Unreleased") {
      $unreleasedStart = $i
    }
    if ($versionStart -lt 0 -and $trimmed -match $versionHeadingPattern) {
      $versionStart = $i
    }
  }

  function Read-SectionAt {
    param([int]$Start)

    $section = New-Object System.Collections.Generic.List[string]
    for ($i = $Start + 1; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match '^##\s+') {
        break
      }
      $section.Add($lines[$i])
    }

    return ($section -join "`n").Trim()
  }

  function Test-UnreleasedTargetsVersion {
    param([string]$SectionText)
    return @($SectionText -split "`r?`n" | Where-Object { $_.Trim() -match $targetVersionPattern }).Count -gt 0
  }

  $selectedText = ""
  $selectedLabel = ""

  if ($PreferUnreleased -and $unreleasedStart -ge 0) {
    $unreleasedText = Read-SectionAt -Start $unreleasedStart
    if (Test-UnreleasedTargetsVersion -SectionText $unreleasedText) {
      $selectedText = $unreleasedText
      $selectedLabel = "Unreleased"
    }
  }

  if ([string]::IsNullOrWhiteSpace($selectedText) -and $versionStart -ge 0) {
    $selectedText = Read-SectionAt -Start $versionStart
    $selectedLabel = $Version
  }

  if ([string]::IsNullOrWhiteSpace($selectedText) -and -not $PreferUnreleased -and $unreleasedStart -ge 0) {
    $unreleasedText = Read-SectionAt -Start $unreleasedStart
    if (Test-UnreleasedTargetsVersion -SectionText $unreleasedText) {
      $selectedText = $unreleasedText
      $selectedLabel = "Unreleased targeting $Version"
    }
  }

  if ([string]::IsNullOrWhiteSpace($selectedText)) {
    throw "Cannot find non-empty changelog section for $Version in $Path"
  }

  Write-Host "Using $selectedLabel section from $Path"
  return $selectedText
}

function Get-CommitSummary {
  param(
    [string]$TagName,
    [int]$CommitLimit
  )

  $gitCommand = Get-Command git -ErrorAction SilentlyContinue
  if (-not $gitCommand) {
    return @("_Commit summary unavailable: git is not installed._")
  }

  $previousTag = ""
  if (-not [string]::IsNullOrWhiteSpace($TagName)) {
    $tags = @(git tag --sort=-creatordate 2>$null | Where-Object { $_ -and $_ -ne $TagName -and $_ -ne "next" })
    if ($tags.Count -gt 0) {
      $previousTag = $tags[0]
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($previousTag)) {
    $commits = @(git -c core.quotepath=false -c i18n.logOutputEncoding=utf-8 log --no-merges --pretty=format:'- %h %s' "$previousTag..HEAD" 2>$null)
  } else {
    $commits = @(git -c core.quotepath=false -c i18n.logOutputEncoding=utf-8 log --no-merges --pretty=format:'- %h %s' -n $CommitLimit 2>$null)
  }

  $commits = @($commits | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($commits.Count -eq 0) {
    return @("_No notable commits found._")
  }

  return $commits
}

if (-not (Test-Path -LiteralPath $ManualNotesPath)) {
  throw "Manual release notes file not found: $ManualNotesPath"
}

$manualNotes = (Read-Utf8Text -Path $ManualNotesPath).Trim()
$manualVersionPattern = "(?<![0-9A-Za-z.-])(?:[vV])?$([regex]::Escape($Version))(?![0-9A-Za-z.-])"
if ($manualNotes -notmatch $manualVersionPattern) {
  throw "Manual release notes $ManualNotesPath must mention version $Version"
}

$null = Get-ChangelogSection -Path $ChangelogPath -Version $Version -PreferUnreleased:$PreferUnreleased
$commitSummary = Get-CommitSummary -TagName $TagName -CommitLimit $CommitLimit

$bodyParts = @(
  $manualNotes,
  "",
  "## Commit Summary",
  "",
  ($commitSummary -join "`n")
)

$outputDirectory = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
  New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

Set-Content -LiteralPath $OutputPath -Value (($bodyParts -join "`n").TrimEnd() + "`n") -Encoding UTF8
Write-Host "Rendered release notes to $OutputPath"
