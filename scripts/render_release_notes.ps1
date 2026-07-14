[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Version,

  [Parameter(Mandatory = $true)]
  [string]$OutputPath,

  [string]$ManualNotesPath = "",
  [string]$ChangelogPath = "docs/en/CHANGELOG.md",
  [string]$TagName = "",
  [int]$CommitLimit = 30,
  [switch]$PreferUnreleased
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$env:LESSCHARSET = "utf-8"

if ([string]::IsNullOrWhiteSpace($ManualNotesPath)) {
  $ManualNotesPath = "docs/en/process/release-notes/release-notes-v$Version.md"
}

function Read-Utf8Text {
  param([Parameter(Mandatory = $true)][string]$Path)
  return Get-Content -LiteralPath $Path -Raw -Encoding UTF8
}

function Test-ReleaseNotesFinishedWording {
  param(
    [Parameter(Mandatory = $true)][string]$Content,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $unfinishedPatterns = @(
    '(?i)final notes will be completed',
    '(?i)final highlights will be written',
    '(?i)compatibility and upgrade notes will be finalized',
    '(?i)will be completed from the actual',
    '(?i)release theme pending',
    '(?i)placeholder',
    '(?i)\btbd\b',
    '(?i)\btodo\b'
  )
  foreach ($pattern in $unfinishedPatterns) {
    if ($Content -match $pattern) {
      throw "Manual release notes $Path contain unfinished release wording."
    }
  }
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
  $versionTokenPattern = "(?:[vV])?$escapedVersion"
  # Support linked Keep a Changelog headings such as "## [Unreleased] ([1.0.0])".
  $versionHeadingPattern = "^##\s+(?:(?:\[unreleased\]\s*(?:\(\s*)?(?:\[$versionTokenPattern\]|$versionTokenPattern)(?:\s*\))?)|(?:\[$versionTokenPattern\]|$versionTokenPattern))(?:\s+-.*)?\s*$"
  $unreleasedHeadingPattern = "^##\s+(?:\[unreleased\]|unreleased)(?:\s+.*)?\s*$"
  $targetVersionPattern = "^(?:Target version|目标版本)[：:]\s*[\x60]?$escapedVersion[\x60]?[。.]?\s*$"
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $trimmed = $lines[$i].Trim()
    if ($unreleasedStart -lt 0 -and $trimmed -match $unreleasedHeadingPattern) {
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

function ConvertTo-SemVerInfo {
  param([Parameter(Mandatory = $true)][string]$TagOrVersion)

  $semverPattern = '^(?:plugin-)?v?(?<major>0|[1-9]\d*)\.(?<minor>0|[1-9]\d*)\.(?<patch>0|[1-9]\d*)(?:-(?<pre>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$'
  if ($TagOrVersion -notmatch $semverPattern) {
    return $null
  }

  return [pscustomobject]@{
    Source = $TagOrVersion
    Major = [int]$Matches['major']
    Minor = [int]$Matches['minor']
    Patch = [int]$Matches['patch']
    Prerelease = $Matches['pre']
  }
}

function Compare-Prerelease {
  param(
    [AllowNull()][string]$Left,
    [AllowNull()][string]$Right
  )

  $leftEmpty = [string]::IsNullOrWhiteSpace($Left)
  $rightEmpty = [string]::IsNullOrWhiteSpace($Right)
  if ($leftEmpty -and $rightEmpty) { return 0 }
  if ($leftEmpty) { return 1 }
  if ($rightEmpty) { return -1 }

  $leftParts = @($Left -split '\.')
  $rightParts = @($Right -split '\.')
  $count = [Math]::Max($leftParts.Count, $rightParts.Count)
  for ($i = 0; $i -lt $count; $i++) {
    if ($i -ge $leftParts.Count) { return -1 }
    if ($i -ge $rightParts.Count) { return 1 }

    $leftPart = $leftParts[$i]
    $rightPart = $rightParts[$i]
    $leftIsNumber = $leftPart -match '^(0|[1-9]\d*)$'
    $rightIsNumber = $rightPart -match '^(0|[1-9]\d*)$'

    if ($leftIsNumber -and $rightIsNumber) {
      $leftNumber = [int]$leftPart
      $rightNumber = [int]$rightPart
      if ($leftNumber -lt $rightNumber) { return -1 }
      if ($leftNumber -gt $rightNumber) { return 1 }
      continue
    }

    if ($leftIsNumber -and -not $rightIsNumber) { return -1 }
    if (-not $leftIsNumber -and $rightIsNumber) { return 1 }

    $textCompare = [string]::CompareOrdinal($leftPart, $rightPart)
    if ($textCompare -lt 0) { return -1 }
    if ($textCompare -gt 0) { return 1 }
  }

  return 0
}

function Compare-SemVerInfo {
  param(
    [Parameter(Mandatory = $true)]$Left,
    [Parameter(Mandatory = $true)]$Right
  )

  foreach ($field in @('Major', 'Minor', 'Patch')) {
    if ($Left.$field -lt $Right.$field) { return -1 }
    if ($Left.$field -gt $Right.$field) { return 1 }
  }

  return Compare-Prerelease -Left $Left.Prerelease -Right $Right.Prerelease
}

function Get-PreviousReleaseTag {
  param([Parameter(Mandatory = $true)][string]$Version)

  $target = ConvertTo-SemVerInfo -TagOrVersion $Version
  if ($null -eq $target) {
    throw "Cannot parse release version: $Version"
  }

  $tags = @(git tag --list 2>$null | Where-Object { $_ -and $_ -ne 'next' })
  if ($tags.Count -eq 0) {
    throw 'Cannot build commit summary because no local release tags are available. Fetch tags before rendering release notes.'
  }

  $previous = $null
  foreach ($tag in $tags) {
    $versionInfo = ConvertTo-SemVerInfo -TagOrVersion $tag
    if ($null -eq $versionInfo) {
      continue
    }
    if ((Compare-SemVerInfo -Left $versionInfo -Right $target) -ge 0) {
      continue
    }
    if ($null -eq $previous -or (Compare-SemVerInfo -Left $versionInfo -Right $previous) -gt 0) {
      $previous = $versionInfo
    }
  }

  if ($null -eq $previous) {
    throw "Cannot build commit summary because no previous release tag was found before $Version."
  }

  return $previous.Source
}

function Get-CommitSummary {
  param(
    [string]$TagName,
    [string]$Version,
    [int]$CommitLimit
  )

  $gitCommand = Get-Command git -ErrorAction SilentlyContinue
  if (-not $gitCommand) {
    return @('_Commit summary unavailable: git is not installed._')
  }

  $previousTag = Get-PreviousReleaseTag -Version $Version
  Write-Host "Using commit summary range $previousTag..HEAD"

  $commits = @(git -c core.quotepath=false -c i18n.logOutputEncoding=utf-8 log --no-merges --pretty=format:'- %h %s' "$previousTag..HEAD" 2>$null)
  $commits = @($commits | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($CommitLimit -gt 0 -and $commits.Count -gt $CommitLimit) {
    $commits = @($commits | Select-Object -First $CommitLimit)
  }
  if ($commits.Count -eq 0) {
    return @('_No notable commits found._')
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
Test-ReleaseNotesFinishedWording -Content $manualNotes -Path $ManualNotesPath

$null = Get-ChangelogSection -Path $ChangelogPath -Version $Version -PreferUnreleased:$PreferUnreleased
$commitSummary = Get-CommitSummary -TagName $TagName -Version $Version -CommitLimit $CommitLimit

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
