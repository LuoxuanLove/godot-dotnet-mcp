param(
    [string]$DocsRoot = "docs",
    [string[]]$Locales = @("en", "zh-CN", "ja", "ko")
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$docsRootPath = Join-Path $repoRoot $DocsRoot
$errors = New-Object System.Collections.Generic.List[string]

function Normalize-RelativePath {
    param([string]$Path)
    return $Path.Replace('\\', '/')
}

function Get-RelativePath {
    param(
        [string]$BasePath,
        [string]$TargetPath
    )

    $baseFullPath = [System.IO.Path]::GetFullPath($BasePath).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $targetFullPath = [System.IO.Path]::GetFullPath($TargetPath)

    if ($targetFullPath.StartsWith($baseFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        return Normalize-RelativePath $targetFullPath.Substring($baseFullPath.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar)
    }

    return Normalize-RelativePath $TargetPath
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

function Get-FilesUnder {
    param([string]$Root)

    if (-not (Test-Path -LiteralPath $Root)) {
        return @()
    }

    return @(
        Get-ChildItem -LiteralPath $Root -Recurse -File |
            ForEach-Object { Get-RelativePath -BasePath $Root -TargetPath $_.FullName } |
            Sort-Object -Unique
    )
}

function Get-MarkdownLinkTargets {
    param([string]$Content)

    $targets = New-Object System.Collections.Generic.List[string]
    foreach ($match in [regex]::Matches($Content, '(?<!\!)\[[^\]]+\]\(([^)]+)\)')) {
        $targets.Add($match.Groups[1].Value)
    }

    foreach ($match in [regex]::Matches($Content, 'href\s*=\s*"([^"]+\.md(?:#[^"]*)?)"')) {
        $targets.Add($match.Groups[1].Value)
    }

    return @($targets)
}

function Get-MarkdownSection {
    param(
        [string]$Content,
        [string]$Heading
    )

    $escapedHeading = [regex]::Escape($Heading)
    $match = [regex]::Match($Content, "(?ms)^## $escapedHeading\s*\r?\n(?<body>.*?)(?=^##\s+|\z)")
    if (-not $match.Success) {
        return ""
    }

    return $match.Groups["body"].Value
}

function Resolve-MarkdownTarget {
    param(
        [System.IO.FileInfo]$File,
        [string]$Target
    )

    if (Is-ExternalLink -Target $Target) {
        return $null
    }

    $pathPart = Get-LinkPathPart -Target $Target
    if ([string]::IsNullOrWhiteSpace($pathPart) -or -not ($pathPart -like '*.md')) {
        return $null
    }

    $baseDirectory = Split-Path -Parent $File.FullName
    return [System.IO.Path]::GetFullPath((Join-Path $baseDirectory $pathPart))
}

function Test-MarkdownLinks {
    param(
        [System.IO.FileInfo[]]$Files,
        [string]$AllowedRoot,
        [string]$RepositoryRoot,
        [System.Collections.Generic.List[string]]$Errors,
        [string]$ScopeName
    )

    $allowedFull = [System.IO.Path]::GetFullPath($AllowedRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar)

    foreach ($file in $Files) {
        $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
        foreach ($target in Get-MarkdownLinkTargets -Content $content) {
            $resolvedTarget = Resolve-MarkdownTarget -File $file -Target $target
            if ($null -eq $resolvedTarget) {
                continue
            }

            $relativeFile = Get-RelativePath -BasePath $RepositoryRoot -TargetPath $file.FullName
            if (-not (Test-Path -LiteralPath $resolvedTarget)) {
                $Errors.Add("Broken Markdown link in ${relativeFile}: $target")
                continue
            }

            $resolvedFull = (Resolve-Path -LiteralPath $resolvedTarget).Path
            if (-not $resolvedFull.StartsWith($allowedFull, [System.StringComparison]::OrdinalIgnoreCase)) {
                $relativeTarget = Get-RelativePath -BasePath $RepositoryRoot -TargetPath $resolvedFull
                $Errors.Add("Cross-language Markdown link in ${relativeFile} (${ScopeName}): $target -> $relativeTarget")
            }
        }
    }
}

if (-not (Test-Path -LiteralPath $docsRootPath)) {
    throw "Missing docs root: $DocsRoot"
}

$legacyI18nPath = Join-Path $docsRootPath "i18n"
if (Test-Path -LiteralPath $legacyI18nPath) {
    $errors.Add("Forbidden legacy docs path exists: $DocsRoot/i18n")
}

$scannedFiles = @(
    Get-ChildItem -LiteralPath $repoRoot -Recurse -File |
        Where-Object {
            $_.FullName -notmatch '\\.git\\' -and
            $_.Extension -in @(".md", ".ps1", ".yml", ".yaml")
        }
)
foreach ($file in $scannedFiles) {
    $fileContent = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    $relativeFile = Get-RelativePath -BasePath $repoRoot -TargetPath $file.FullName
    if ($relativeFile -eq "scripts/validate_docs_i18n.ps1") {
        continue
    }

    $legacyReference = "docs/" + "i18n"
    if ($fileContent.Contains($legacyReference)) {
        $errors.Add("Forbidden legacy docs path reference in ${relativeFile}: $legacyReference")
    }
}

$allowedLocaleRoots = @{}
foreach ($locale in $Locales) {
    $allowedLocaleRoots[$locale] = Join-Path $docsRootPath $locale
}

$rootMarkdownFiles = @(
    Get-ChildItem -LiteralPath $docsRootPath -File -Filter "*.md" |
        ForEach-Object { Get-RelativePath -BasePath $repoRoot -TargetPath $_.FullName }
)
foreach ($relativePath in $rootMarkdownFiles) {
    $errors.Add("Forbidden root docs Markdown file: $relativePath")
}

$localeFileSets = @{}
foreach ($locale in $Locales) {
    $localeRoot = $allowedLocaleRoots[$locale]
    if (-not (Test-Path -LiteralPath $localeRoot)) {
        $errors.Add("Missing locale docs root: $DocsRoot/$locale")
        $localeFileSets[$locale] = @()
        continue
    }

    $localeFileSets[$locale] = @(Get-FilesUnder -Root $localeRoot)
    foreach ($requiredFile in @("README.md", "CHANGELOG.md", "ROADMAP.md", "overview.md")) {
        if ($localeFileSets[$locale] -notcontains $requiredFile) {
            $errors.Add("Missing required locale file: $DocsRoot/$locale/$requiredFile")
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

foreach ($locale in $Locales) {
    $localeRoot = $allowedLocaleRoots[$locale]
    if (-not (Test-Path -LiteralPath $localeRoot)) {
        continue
    }

    $markdownFiles = @(Get-ChildItem -LiteralPath $localeRoot -Recurse -File -Filter "*.md")
    Test-MarkdownLinks -Files $markdownFiles -AllowedRoot $localeRoot -RepositoryRoot $repoRoot -Errors $errors -ScopeName $locale
}

$rootReadmePath = Join-Path $repoRoot "README.md"
if (Test-Path -LiteralPath $rootReadmePath) {
    $rootReadme = Get-Item -LiteralPath $rootReadmePath
    $content = Get-Content -LiteralPath $rootReadme.FullName -Raw -Encoding UTF8
    $documentationSection = Get-MarkdownSection -Content $content -Heading "Documentation"
    foreach ($target in Get-MarkdownLinkTargets -Content $documentationSection) {
        if (Is-ExternalLink -Target $target) {
            continue
        }

        $pathPart = Get-LinkPathPart -Target $target
        if ([string]::IsNullOrWhiteSpace($pathPart) -or -not ($pathPart -like '*.md')) {
            continue
        }

        if ($pathPart -like 'docs/*' -and -not ($pathPart -like 'docs/en/*')) {
            $errors.Add("Root README English documentation link must target docs/en: $target")
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
