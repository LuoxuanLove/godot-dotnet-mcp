param(
    [string]$DocsRoot = "docs",
    [string[]]$Locales = @("en", "ko", "ja", "zh-CN")
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$docsRootPath = Join-Path $repoRoot $DocsRoot
$errors = New-Object System.Collections.Generic.List[string]

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

function Normalize-RelativePath {
    param([string]$Path)
    return $Path.Replace('\', '/')
}

function Get-LocaleMarkdownFiles {
    param(
        [string]$LocaleRoot,
        [string]$RepositoryRoot
    )

    if (-not (Test-Path -LiteralPath $LocaleRoot)) {
        return @()
    }

    return @(
        Get-ChildItem -LiteralPath $LocaleRoot -Recurse -File -Filter "*.md" |
            ForEach-Object {
                Normalize-RelativePath (Get-RelativePath -BasePath $LocaleRoot -TargetPath $_.FullName)
            } |
            Sort-Object -Unique
    )
}

function Get-LocaleFiles {
    param(
        [string]$LocaleRoot,
        [string]$RepositoryRoot
    )

    if (-not (Test-Path -LiteralPath $LocaleRoot)) {
        return @()
    }

    return @(
        Get-ChildItem -LiteralPath $LocaleRoot -Recurse -File |
            ForEach-Object {
                Normalize-RelativePath (Get-RelativePath -BasePath $LocaleRoot -TargetPath $_.FullName)
            } |
            Sort-Object -Unique
    )
}

function Get-DirectoriesFromFiles {
    param([string[]]$RelativeFiles)

    $directories = New-Object System.Collections.Generic.List[string]
    foreach ($relativeFile in $RelativeFiles) {
        $normalizedFile = Normalize-RelativePath $relativeFile
        $lastSlash = $normalizedFile.LastIndexOf('/')
        while ($lastSlash -gt 0) {
            $directory = $normalizedFile.Substring(0, $lastSlash)
            $directories.Add($directory)
            $lastSlash = $directory.LastIndexOf('/')
        }
    }

    return @($directories | Sort-Object -Unique)
}

function Is-ExternalLink {
    param([string]$Target)
    return $Target -match '^(https?:|mailto:|tel:|#)'
}

function Get-LinkPathPart {
    param([string]$Target)
    $clean = $Target.Trim()
    if ($clean.StartsWith('<') -and $clean.EndsWith('>')) {
        $clean = $clean.Substring(1, $clean.Length - 2)
    }
    $clean = ($clean -split '#', 2)[0]
    return [System.Uri]::UnescapeDataString($clean)
}

function Test-LinkTarget {
    param(
        [System.IO.FileInfo]$File,
        [string]$Target,
        [string]$Locale,
        [string]$LocaleRoot,
        [string]$RepositoryRoot,
        [System.Collections.Generic.List[string]]$Errors
    )

    if (Is-ExternalLink -Target $Target) {
        return
    }

    $pathPart = Get-LinkPathPart -Target $Target
    if ([string]::IsNullOrWhiteSpace($pathPart)) {
        return
    }

    if (-not ($pathPart -like '*.md')) {
        return
    }

    $baseDirectory = Split-Path -Parent $File.FullName
    $candidate = Join-Path $baseDirectory $pathPart
    $fullCandidate = [System.IO.Path]::GetFullPath($candidate)

    if (-not (Test-Path -LiteralPath $fullCandidate)) {
        $relativeFile = Normalize-RelativePath (Get-RelativePath -BasePath $RepositoryRoot -TargetPath $File.FullName)
        $Errors.Add("Broken Markdown link in ${relativeFile}: $Target")
        return
    }

    $resolved = (Resolve-Path -LiteralPath $fullCandidate).Path
    $localeRootFull = (Resolve-Path -LiteralPath $LocaleRoot).Path.TrimEnd('\')

    if (-not $resolved.StartsWith($localeRootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relativeFile = Normalize-RelativePath (Get-RelativePath -BasePath $RepositoryRoot -TargetPath $File.FullName)
        $relativeTarget = Normalize-RelativePath (Get-RelativePath -BasePath $RepositoryRoot -TargetPath $resolved)
        $Errors.Add("Cross-locale docs link in ${relativeFile}: $Target -> $relativeTarget")
    }
}

$localeFileSets = @{}
$localeMarkdownFileSets = @{}
$localeDirectorySets = @{}
foreach ($locale in $Locales) {
    $localeRoot = Join-Path $docsRootPath $locale
    if (-not (Test-Path -LiteralPath $localeRoot)) {
        $errors.Add("Missing locale docs root: $DocsRoot/$locale")
        $localeFileSets[$locale] = @()
        $localeMarkdownFileSets[$locale] = @()
        $localeDirectorySets[$locale] = @()
        continue
    }

    $localeFileSets[$locale] = @(Get-LocaleFiles -LocaleRoot $localeRoot -RepositoryRoot $repoRoot)
    $localeMarkdownFileSets[$locale] = @(Get-LocaleMarkdownFiles -LocaleRoot $localeRoot -RepositoryRoot $repoRoot)
    $localeDirectorySets[$locale] = @(Get-DirectoriesFromFiles -RelativeFiles $localeFileSets[$locale])
}

$expectedDirectoryCount = $null
foreach ($locale in $Locales) {
    $directoryCount = $localeDirectorySets[$locale].Count
    if ($null -eq $expectedDirectoryCount) {
        $expectedDirectoryCount = $directoryCount
        continue
    }

    if ($directoryCount -ne $expectedDirectoryCount) {
        $errors.Add("Locale directory count mismatch: $DocsRoot/$locale has $directoryCount directories; expected $expectedDirectoryCount")
    }
}

$expectedFileCount = $null
foreach ($locale in $Locales) {
    $fileCount = $localeFileSets[$locale].Count
    if ($null -eq $expectedFileCount) {
        $expectedFileCount = $fileCount
        continue
    }

    if ($fileCount -ne $expectedFileCount) {
        $errors.Add("Locale file count mismatch: $DocsRoot/$locale has $fileCount files; expected $expectedFileCount")
    }
}

$allRelativeDirectories = @(
    foreach ($locale in $Locales) {
        foreach ($relativeDirectory in $localeDirectorySets[$locale]) {
            $relativeDirectory
        }
    }
) | Sort-Object -Unique

foreach ($relativeDirectory in $allRelativeDirectories) {
    foreach ($locale in $Locales) {
        if ($localeDirectorySets[$locale] -notcontains $relativeDirectory) {
            $errors.Add("Missing locale directory mirror: $DocsRoot/$locale/$relativeDirectory")
        }
    }
}

$allRelativeFiles = @(
    foreach ($locale in $Locales) {
        foreach ($relativeFile in $localeFileSets[$locale]) {
            $relativeFile
        }
    }
) | Sort-Object -Unique

foreach ($relativeFile in $allRelativeFiles) {
    foreach ($locale in $Locales) {
        if ($localeFileSets[$locale] -notcontains $relativeFile) {
            $errors.Add("Missing locale file mirror: $DocsRoot/$locale/$relativeFile")
        }
    }
}

$allRelativeMarkdownFiles = @(
    foreach ($locale in $Locales) {
        foreach ($relativeFile in $localeMarkdownFileSets[$locale]) {
            $relativeFile
        }
    }
) | Sort-Object -Unique

foreach ($relativeFile in $allRelativeMarkdownFiles) {
    foreach ($locale in $Locales) {
        if ($localeMarkdownFileSets[$locale] -notcontains $relativeFile) {
            $errors.Add("Missing locale Markdown mirror: $DocsRoot/$locale/$relativeFile")
        }
    }
}

foreach ($locale in $Locales) {
    $localeRoot = Join-Path $docsRootPath $locale
    if (-not (Test-Path -LiteralPath $localeRoot)) {
        continue
    }

    $files = Get-ChildItem -LiteralPath $localeRoot -Recurse -File -Filter "*.md"
    foreach ($file in $files) {
        $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
        $markdownMatches = [regex]::Matches($content, '(?<!\!)\[[^\]]+\]\(([^)]+)\)')
        foreach ($match in $markdownMatches) {
            $target = $match.Groups[1].Value
            Test-LinkTarget -File $file -Target $target -Locale $locale -LocaleRoot $localeRoot -RepositoryRoot $repoRoot -Errors $errors
        }

        $htmlMatches = [regex]::Matches($content, 'href\s*=\s*"([^"]+\.md(?:#[^"]*)?)"')
        foreach ($match in $htmlMatches) {
            $target = $match.Groups[1].Value
            Test-LinkTarget -File $file -Target $target -Locale $locale -LocaleRoot $localeRoot -RepositoryRoot $repoRoot -Errors $errors
        }
    }
}

if ($errors.Count -gt 0) {
    foreach ($message in $errors) {
        Write-Error $message -ErrorAction Continue
    }
    throw "Docs i18n validation failed."
}

Write-Host "Docs i18n validation passed for locales: $($Locales -join ', ')"
