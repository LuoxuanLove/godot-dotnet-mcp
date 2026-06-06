param(
    [string]$DocsRoot = "docs",
    [string[]]$Locales = @("en", "zh-CN", "ja", "ko")
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$docsRootPath = Join-Path $repoRoot $DocsRoot
$errors = New-Object System.Collections.Generic.List[string]

$docMap = @(
    @{ Id = "readme"; Paths = @{ en = "README.md"; "zh-CN" = "说明.md"; ja = "はじめに.md"; ko = "소개.md" } },
    @{ Id = "changelog"; Paths = @{ en = "CHANGELOG.md"; "zh-CN" = "变更日志.md"; ja = "変更履歴.md"; ko = "변경-로그.md" } },
    @{ Id = "roadmap"; Paths = @{ en = "ROADMAP.md"; "zh-CN" = "路线图.md"; ja = "ロードマップ.md"; ko = "로드맵.md" } },
    @{ Id = "overview"; Paths = @{ en = "overview.md"; "zh-CN" = "概述.md"; ja = "概要.md"; ko = "개요.md" } },
    @{ Id = "interface-overview"; Paths = @{ en = "interface/overview.md"; "zh-CN" = "界面/总览.md"; ja = "インターフェース/概要.md"; ko = "인터페이스/개요.md" } },
    @{ Id = "interface-server-config"; Paths = @{ en = "interface/server-and-config-pages.md"; "zh-CN" = "界面/服务与配置页实现.md"; ja = "インターフェース/サーバーと設定ページ実装.md"; ko = "인터페이스/서버와-설정-페이지-구현.md" } },
    @{ Id = "interface-tools"; Paths = @{ en = "interface/tools-page.md"; "zh-CN" = "界面/工具页实现.md"; ja = "インターフェース/ツールページ実装.md"; ko = "인터페이스/도구-페이지-구현.md" } },
    @{ Id = "process-agent-bot"; Paths = @{ en = "process/agent-and-bot-workflow.md"; "zh-CN" = "流程/智能体与机器人流程.md"; ja = "プロセス/エージェントとボットの流れ.md"; ko = "프로세스/에이전트와-봇-흐름.md" } },
    @{ Id = "process-release-runbook"; Paths = @{ en = "process/release-runbook.md"; "zh-CN" = "流程/发布运行手册.md"; ja = "プロセス/リリース運用手順.md"; ko = "프로세스/릴리스-운영-절차.md" } },
    @{ Id = "process-release-notes-v1.2.0"; Paths = @{ en = "process/release-notes/release-notes-v1.2.0.md"; "zh-CN" = "流程/发布说明/发布说明-v1.2.0.md"; ja = "プロセス/リリースノート/リリースノート-v1.2.0.md"; ko = "프로세스/릴리스-노트/릴리스-노트-v1.2.0.md" } },
    @{ Id = "process-release-notes-v1.2.1"; Paths = @{ en = "process/release-notes/release-notes-v1.2.1.md"; "zh-CN" = "流程/发布说明/发布说明-v1.2.1.md"; ja = "プロセス/リリースノート/リリースノート-v1.2.1.md"; ko = "프로세스/릴리스-노트/릴리스-노트-v1.2.1.md" } },
    @{ Id = "testing-overview"; Paths = @{ en = "testing/overview.md"; "zh-CN" = "测试/总览.md"; ja = "テスト/概要.md"; ko = "테스트/개요.md" } },
    @{ Id = "testing-smoke-ci"; Paths = @{ en = "testing/smoke-and-ci.md"; "zh-CN" = "测试/冒烟测试与持续集成.md"; ja = "テスト/スモークテストと継続的インテグレーション.md"; ko = "테스트/스모크-테스트와-지속적-통합.md" } },
    @{ Id = "testing-headless"; Paths = @{ en = "testing/plugin-headless-testing.md"; "zh-CN" = "测试/插件无头测试.md"; ja = "テスト/プラグインヘッドレステスト.md"; ko = "테스트/플러그인-헤드리스-테스트.md" } },
    @{ Id = "appendix-encoding"; Paths = @{ en = "appendix/encoding-rules.md"; "zh-CN" = "附录/编码规范.md"; ja = "付録/エンコーディング規約.md"; ko = "부록/인코딩-규범.md" } },
    @{ Id = "appendix-tree"; Paths = @{ en = "appendix/directory-tree-and-file-responsibilities.md"; "zh-CN" = "附录/目录树与文件职责.md"; ja = "付録/ディレクトリツリーとファイル責務.md"; ko = "부록/디렉터리-트리와-파일-책임.md" } },
    @{ Id = "appendix-config"; Paths = @{ en = "appendix/configuration-and-persistence.md"; "zh-CN" = "附录/配置与持久化.md"; ja = "付録/設定と永続化.md"; ko = "부록/설정과-지속화.md" } }
)

function Normalize-RelativePath {
    param([string]$Path)
    return $Path.Replace('\', '/')
}

function Get-RelativePath {
    param([string]$BasePath, [string]$TargetPath)
    $baseFullPath = [System.IO.Path]::GetFullPath($BasePath).TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $targetFullPath = [System.IO.Path]::GetFullPath($TargetPath)
    $baseUri = New-Object System.Uri($baseFullPath)
    $targetUri = New-Object System.Uri($targetFullPath)
    return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString())
}

function Get-HashText {
    param([string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Get-TreeShapeHash {
    param([string]$Root)
    $childShapes = New-Object System.Collections.Generic.List[string]
    foreach ($child in @(Get-ChildItem -LiteralPath $Root -Force)) {
        if ($child.PSIsContainer) {
            $childShapes.Add("D:" + (Get-TreeShapeHash -Root $child.FullName))
        } else {
            $childShapes.Add("F")
        }
    }
    return Get-HashText ("N(" + (($childShapes | Sort-Object) -join ",") + ")")
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

function Get-MarkdownLinks {
    param([string]$Content)
    $links = @()
    foreach ($match in [regex]::Matches($Content, '(?<!\!)\[[^\]]+\]\(([^)]+)\)')) {
        $links += [pscustomobject]@{ Text = $match.Groups[0].Value; Label = $match.Groups[0].Value; Target = $match.Groups[1].Value }
    }
    foreach ($match in [regex]::Matches($Content, 'href\s*=\s*"([^"]+\.md(?:#[^"]*)?)"')) {
        $links += [pscustomobject]@{ Text = $match.Groups[0].Value; Label = ""; Target = $match.Groups[1].Value }
    }
    return @($links)
}

function Get-MarkdownImages {
    param([string]$Content)
    $images = @()
    foreach ($match in [regex]::Matches($Content, '!\[[^\]]*\]\(([^)]+)\)')) {
        $images += [pscustomobject]@{ Text = $match.Groups[0].Value; Target = $match.Groups[1].Value }
    }
    return @($images)
}

function Resolve-MarkdownTarget {
    param([System.IO.FileInfo]$File, [string]$Target)
    if (Is-ExternalLink -Target $Target) {
        return $null
    }
    $pathPart = Get-LinkPathPart -Target $Target
    if ([string]::IsNullOrWhiteSpace($pathPart)) {
        return $null
    }
    return [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $File.FullName) $pathPart))
}

function Test-LocalizedTextScript {
    param([string]$Locale, [string]$Text, [string]$Context)
    $naturalText = [regex]::Replace($Text, '`[^`]*`', '')
    switch ($Locale) {
        "en" {
            if ($naturalText -match '[\p{IsCJKUnifiedIdeographs}\p{IsHiragana}\p{IsKatakana}\p{IsHangulSyllables}]') {
                $errors.Add("English localized text contains CJK/Kana/Hangul content in ${Context}: $Text")
            }
        }
        "zh-CN" {
            if ($naturalText -match '[\p{IsHiragana}\p{IsKatakana}\p{IsHangulSyllables}]') {
                $errors.Add("Simplified Chinese localized text contains Japanese/Korean content in ${Context}: $Text")
            }
        }
        "ja" {
            if ($naturalText -match '[\p{IsHangulSyllables}]') {
                $errors.Add("Japanese localized text contains Korean content in ${Context}: $Text")
            }
        }
        "ko" {
            if ($naturalText -match '[\p{IsCJKUnifiedIdeographs}\p{IsHiragana}\p{IsKatakana}]') {
                $errors.Add("Korean localized text contains CJK/Kana content in ${Context}: $Text")
            }
        }
    }
}

function Test-MarkdownLinks {
    param([System.IO.FileInfo[]]$Files, [string]$AllowedRoot, [string]$RepositoryRoot, [string]$ScopeName)
    $allowedFull = [System.IO.Path]::GetFullPath($AllowedRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    foreach ($file in $Files) {
        $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
        $relativeFile = Get-RelativePath -BasePath $RepositoryRoot -TargetPath $file.FullName
        $localeRootName = Split-Path -Leaf $AllowedRoot
        $relativeToLocale = Normalize-RelativePath (Get-RelativePath -BasePath $AllowedRoot -TargetPath $file.FullName)
        Test-ReleaseNoteLanguageSwitch -Locale $localeRootName -RelativePath $relativeToLocale -Content $content -Context $relativeFile
        foreach ($link in Get-MarkdownLinks -Content $content) {
            if (-not [string]::IsNullOrWhiteSpace($link.Label)) {
                Test-LocalizedTextScript -Locale $ScopeName -Text $link.Label -Context $relativeFile
            }
            $resolvedTarget = Resolve-MarkdownTarget -File $file -Target $link.Target
            if ($null -eq $resolvedTarget) {
                continue
            }
            if (-not (Test-Path -LiteralPath $resolvedTarget)) {
                $errors.Add("Broken Markdown link in ${relativeFile}: $($link.Target)")
                continue
            }
            $resolvedFull = (Resolve-Path -LiteralPath $resolvedTarget).Path
            if (-not $resolvedFull.StartsWith($allowedFull, [System.StringComparison]::OrdinalIgnoreCase)) {
                $relativeTarget = Get-RelativePath -BasePath $RepositoryRoot -TargetPath $resolvedFull
                $errors.Add("Cross-language Markdown link in ${relativeFile} (${ScopeName}): $($link.Target) -> $relativeTarget")
            }
        }
    }
}

function Get-ReleaseNoteLanguageSwitchLine {
    return '<p align="center"><a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.2.0/docs/en/process/release-notes/release-notes-v1.2.0.md">English</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.2.0/docs/zh-CN/流程/发布说明/发布说明-v1.2.0.md">简体中文</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.2.0/docs/ja/プロセス/リリースノート/リリースノート-v1.2.0.md">日本語</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.2.0/docs/ko/프로세스/릴리스-노트/릴리스-노트-v1.2.0.md">한국어</a></p>'
}

function Test-ReleaseNoteLanguageSwitch {
    param([string]$Locale, [string]$RelativePath, [string]$Content, [string]$Context)
    $releaseNotePaths = @{
        en = "process/release-notes/release-notes-v1.2.0.md"
        "zh-CN" = "流程/发布说明/发布说明-v1.2.0.md"
        ja = "プロセス/リリースノート/リリースノート-v1.2.0.md"
        ko = "프로세스/릴리스-노트/릴리스-노트-v1.2.0.md"
    }
    if (-not $releaseNotePaths.ContainsKey($Locale) -or $releaseNotePaths[$Locale] -ne $RelativePath) {
        return
    }

    $expectedLine = Get-ReleaseNoteLanguageSwitchLine
    $lines = @($Content -split "`r?`n")
    $matches = @($lines | Where-Object { $_ -eq $expectedLine })
    if ($matches.Count -ne 1) {
        $errors.Add("Release note language switcher must appear exactly once with the expected four links in ${Context}")
    }
}

function Test-MarkdownImages {
    param([System.IO.FileInfo[]]$Files, [string]$RepositoryRoot)
    foreach ($file in $Files) {
        $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
        $relativeFile = Get-RelativePath -BasePath $RepositoryRoot -TargetPath $file.FullName
        foreach ($image in Get-MarkdownImages -Content $content) {
            $resolvedTarget = Resolve-MarkdownTarget -File $file -Target $image.Target
            if ($null -eq $resolvedTarget) {
                continue
            }
            if (-not (Test-Path -LiteralPath $resolvedTarget)) {
                $errors.Add("Broken Markdown image in ${relativeFile}: $($image.Target)")
            }
        }
    }
}

function Test-ReadmePresentationAssets {
    param([string]$Locale, [System.IO.FileInfo]$File, [string]$RelativePath)
    $content = Get-Content -LiteralPath $File.FullName -Raw -Encoding UTF8
    $localeImageSuffix = @{
        en = "-en.png"
        "zh-CN" = "-cn.png"
    }
    if ($localeImageSuffix.ContainsKey($Locale)) {
        foreach ($image in Get-MarkdownImages -Content $content) {
            $targetPath = Get-LinkPathPart -Target $image.Target
            if ($targetPath -notmatch '(^|/)asset_library/.+\.(png|jpg|jpeg|webp|svg)$') {
                continue
            }
            if ($targetPath -match '(^|/)asset_library/(home|tools|config)-' -and -not $targetPath.EndsWith($localeImageSuffix[$Locale], [System.StringComparison]::OrdinalIgnoreCase)) {
                $errors.Add("README screenshot asset uses the wrong locale in ${RelativePath}: $targetPath")
            }
        }
    }
    if ($Locale -eq "en" -and $content -match 'label=%E6%AD%A3%E5%BC%8F%E7%89%88') {
        $errors.Add("English README stable badge uses the Simplified Chinese label encoding: $RelativePath")
    }
}

function Test-TablePathDuplicates {
    param([System.IO.FileInfo]$File, [string]$RelativePath)
    $tableKeys = @{}
    $content = Get-Content -LiteralPath $File.FullName -Raw -Encoding UTF8
    $lines = @($content -split "`r?`n")
    $tableIndex = 0
    $inTable = $false
    foreach ($line in $lines) {
        if ($line -match '^\|\s*`([^`]+)`\s*\|') {
            if (-not $inTable) {
                $tableIndex += 1
                $tableKeys[$tableIndex] = New-Object System.Collections.Generic.HashSet[string]
                $inTable = $true
            }
            $key = $matches[1]
            if (-not $tableKeys[$tableIndex].Add($key)) {
                $errors.Add("Duplicate Markdown table path in ${RelativePath}: $key")
            }
            continue
        }
        if ($line -match '^\|') {
            continue
        }
        $inTable = $false
    }
}

function Test-MachineLocalizationPrefixes {
    param([string]$Content, [string]$RelativePath)
    $patterns = @(
        'Localized\s*:',
        'Lokalisiert\s*:',
        'Localisé\s*:',
        'Localizado\s*:',
        'Localizzato\s*:',
        'ローカライズ済み\s*:',
        '地域化済み\s*:',
        '지역화됨\s*:',
        '로컬라이즈됨\s*:'
    )
    foreach ($pattern in $patterns) {
        if ($Content -match $pattern) {
            $errors.Add("Localized document contains machine-localization prefix wording: $RelativePath")
            return
        }
    }
}

function Test-PathScript {
    param([string]$Locale, [string]$RelativePath)
    switch ($Locale) {
        "en" {
            if ($RelativePath -match '[\p{IsCJKUnifiedIdeographs}\p{IsHiragana}\p{IsKatakana}\p{IsHangulSyllables}]') {
                $errors.Add("English docs path contains non-English script: docs/en/$RelativePath")
            }
        }
        "zh-CN" {
            if ($RelativePath -match '[\p{IsHiragana}\p{IsKatakana}\p{IsHangulSyllables}]') {
                $errors.Add("Simplified Chinese docs path contains another locale script: docs/zh-CN/$RelativePath")
            }
        }
        "ja" {
            if ($RelativePath -match '[\p{IsHangulSyllables}]') {
                $errors.Add("Japanese docs path contains Korean script: docs/ja/$RelativePath")
            }
        }
        "ko" {
            if ($RelativePath -match '[\p{IsCJKUnifiedIdeographs}\p{IsHiragana}\p{IsKatakana}]') {
                $errors.Add("Korean docs path contains non-Korean CJK/Kana script: docs/ko/$RelativePath")
            }
        }
    }
}

function Remove-AllowedReleaseNoteLanguageSwitch {
    param([string]$Locale, [string]$RelativePath, [string]$Content)
    $releaseNotePaths = @{
        en = "process/release-notes/release-notes-v1.2.0.md"
        "zh-CN" = "流程/发布说明/发布说明-v1.2.0.md"
        ja = "プロセス/リリースノート/リリースノート-v1.2.0.md"
        ko = "프로세스/릴리스-노트/릴리스-노트-v1.2.0.md"
    }
    if (-not $releaseNotePaths.ContainsKey($Locale) -or $releaseNotePaths[$Locale] -ne $RelativePath) {
        return $Content
    }

    $expectedLine = [regex]::Escape((Get-ReleaseNoteLanguageSwitchLine))
    return [regex]::Replace($Content, "(?m)^$expectedLine`r?`n?", '')
}

function Test-DocumentQuality {
    param([string]$Locale, [string]$RelativePath, [System.IO.FileInfo]$File)
    $content = Get-Content -LiteralPath $File.FullName -Raw -Encoding UTF8
    $contentForQuality = Remove-AllowedReleaseNoteLanguageSwitch -Locale $Locale -RelativePath $RelativePath -Content $content
    $naturalLanguageContent = [regex]::Replace($contentForQuality, '(?ms)^```.*?^```', '')
    $naturalLanguageContent = [regex]::Replace($naturalLanguageContent, '`[^`]*`', '')
    $lines = @($content -split "`r?`n")
    $relative = "$DocsRoot/$Locale/$RelativePath"
    if ($lines.Count -lt 10) {
        $errors.Add("Localized document is too short or stub-like: $relative")
    }
    if ($naturalLanguageContent -match '(?i)\b(todo|tbd|to be filled|release theme pending|placeholder)\b|待填|待补|占位') {
        $errors.Add("Localized document contains placeholder wording: $relative")
    }
    if ($naturalLanguageContent -match '(?i)architectore|architecture|modules?|架构|模块|アーキテクチャ|モジュール|아키텍처|모듈') {
        $errors.Add("Localized document contains forbidden legacy architecture/module wording: $relative")
    }
    Test-MachineLocalizationPrefixes -Content $naturalLanguageContent -RelativePath $relative
    if ($RelativePath -in @("README.md", "说明.md", "はじめに.md", "소개.md")) {
        Test-ReadmePresentationAssets -Locale $Locale -File $File -RelativePath $relative
    }
    if ($RelativePath -in @("appendix/directory-tree-and-file-responsibilities.md", "附录/目录树与文件职责.md", "付録/ディレクトリツリーとファイル責務.md", "부록/디렉터리-트리와-파일-책임.md")) {
        Test-TablePathDuplicates -File $File -RelativePath $relative
    }
    foreach ($match in [regex]::Matches($naturalLanguageContent, '(?m)^#{1,6}\s+(.+)$')) {
        Test-LocalizedTextScript -Locale $Locale -Text $match.Groups[1].Value -Context $relative
    }
    switch ($Locale) {
        "en" {
            if ($naturalLanguageContent -match '[\p{IsCJKUnifiedIdeographs}\p{IsHiragana}\p{IsKatakana}\p{IsHangulSyllables}]') {
                $errors.Add("English document contains CJK/Kana/Hangul text: $relative")
            }
            if ($naturalLanguageContent -match 'docs/(zh-CN|ja|ko)/') {
                $errors.Add("English document references another locale docs path: $relative")
            }
        }
        "zh-CN" {
            if ($naturalLanguageContent -match '[\p{IsHiragana}\p{IsKatakana}\p{IsHangulSyllables}]') {
                $errors.Add("Simplified Chinese document contains Japanese/Korean text: $relative")
            }
            if ($naturalLanguageContent -match 'docs/(en|ja|ko)/') {
                $errors.Add("Simplified Chinese document references another locale docs path: $relative")
            }
        }
        "ja" {
            if ($naturalLanguageContent -notmatch '[\p{IsHiragana}\p{IsKatakana}]') {
                $errors.Add("Japanese document lacks Japanese kana content: $relative")
            }
            if ($naturalLanguageContent -match '[\p{IsHangulSyllables}]') {
                $errors.Add("Japanese document contains Korean text: $relative")
            }
            if ($naturalLanguageContent -match 'docs/(en|zh-CN|ko)/') {
                $errors.Add("Japanese document references another locale docs path: $relative")
            }
        }
        "ko" {
            if ($naturalLanguageContent -notmatch '[\p{IsHangulSyllables}]') {
                $errors.Add("Korean document lacks Korean Hangul content: $relative")
            }
            if ($naturalLanguageContent -match '[\p{IsHiragana}\p{IsKatakana}]') {
                $errors.Add("Korean document contains Japanese kana text: $relative")
            }
            if ($naturalLanguageContent -match 'docs/(en|zh-CN|ja)/') {
                $errors.Add("Korean document references another locale docs path: $relative")
            }
        }
    }
}

function Get-DocumentStructureMetrics {
    param([System.IO.FileInfo]$File)
    $content = Get-Content -LiteralPath $File.FullName -Raw -Encoding UTF8
    return [pscustomobject]@{
        Lines = @($content -split "`r?`n").Count
        Headings = [regex]::Matches($content, '(?m)^#{1,6}\s+.+$').Count
        TableRows = [regex]::Matches($content, '(?m)^\|').Count
        CodeFences = [regex]::Matches($content, '(?m)^```').Count
    }
}

function Test-DocumentStructureCompleteness {
    param([hashtable]$Doc, [string]$ReferenceLocale)
    $referenceRelativePath = $Doc.Paths[$ReferenceLocale]
    $referenceFilePath = Join-Path (Join-Path $docsRootPath $ReferenceLocale) $referenceRelativePath
    if (-not (Test-Path -LiteralPath $referenceFilePath)) {
        return
    }
    $referenceMetrics = Get-DocumentStructureMetrics -File (Get-Item -LiteralPath $referenceFilePath)
    foreach ($locale in $Locales) {
        if ($locale -eq $ReferenceLocale -or -not $Doc.Paths.ContainsKey($locale)) {
            continue
        }
        $localizedRelativePath = $Doc.Paths[$locale]
        $localizedFilePath = Join-Path (Join-Path $docsRootPath $locale) $localizedRelativePath
        if (-not (Test-Path -LiteralPath $localizedFilePath)) {
            continue
        }
        $localizedMetrics = Get-DocumentStructureMetrics -File (Get-Item -LiteralPath $localizedFilePath)
        $metricNames = @("Headings", "TableRows", "CodeFences")
        foreach ($metricName in $metricNames) {
            $referenceValue = [int]$referenceMetrics.$metricName
            if ($referenceValue -le 0) {
                continue
            }
            $localizedValue = [int]$localizedMetrics.$metricName
            $minimumValue = [Math]::Floor($referenceValue * 0.75)
            if ($localizedValue -lt $minimumValue) {
                $errors.Add("Localized document structure is incomplete for $($Doc.Id) in ${locale}: ${metricName}=${localizedValue}, expected at least ${minimumValue} from ${ReferenceLocale} ${referenceValue}")
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

foreach ($rootFile in @("README.zh-CN.md", "CHANGELOG.md", "CHANGELOG.zh-CN.md", "ROADMAP.md", "ROADMAP.zh-CN.md")) {
    $rootFilePath = Join-Path $repoRoot $rootFile
    if (Test-Path -LiteralPath $rootFilePath) {
        $errors.Add("Forbidden redundant root documentation file: $rootFile")
    }
}

foreach ($rootReleaseNote in @(Get-ChildItem -LiteralPath $repoRoot -File -Filter "release-notes-v*.md" -ErrorAction SilentlyContinue)) {
    $errors.Add("Forbidden redundant root release notes file: $($rootReleaseNote.Name)")
}

$expectedByLocale = @{}
foreach ($locale in $Locales) {
    $expectedByLocale[$locale] = New-Object System.Collections.Generic.HashSet[string]
}
foreach ($doc in $docMap) {
    foreach ($locale in $Locales) {
        if (-not $doc.Paths.ContainsKey($locale)) {
            $errors.Add("Missing path mapping for $($doc.Id) in $locale")
            continue
        }
        [void]$expectedByLocale[$locale].Add($doc.Paths[$locale])
    }
}

$rootMarkdownFiles = @(Get-ChildItem -LiteralPath $docsRootPath -File -Filter "*.md" -ErrorAction SilentlyContinue)
foreach ($file in $rootMarkdownFiles) {
    $errors.Add("Forbidden root docs Markdown file: $(Get-RelativePath -BasePath $repoRoot -TargetPath $file.FullName)")
}

$treeHashes = @{}
foreach ($locale in $Locales) {
    $localeRoot = Join-Path $docsRootPath $locale
    if (-not (Test-Path -LiteralPath $localeRoot)) {
        $errors.Add("Missing locale docs root: $DocsRoot/$locale")
        continue
    }
    $treeHashes[$locale] = Get-TreeShapeHash -Root $localeRoot
    $actualFiles = @(Get-ChildItem -LiteralPath $localeRoot -Recurse -File -Filter "*.md" | ForEach-Object { Normalize-RelativePath (Get-RelativePath -BasePath $localeRoot -TargetPath $_.FullName) } | Sort-Object -Unique)
    foreach ($relativePath in $actualFiles) {
        Test-PathScript -Locale $locale -RelativePath $relativePath
        if (-not $expectedByLocale[$locale].Contains($relativePath)) {
            $errors.Add("Unexpected localized docs file: $DocsRoot/$locale/$relativePath")
        }
    }
    foreach ($expected in $expectedByLocale[$locale]) {
        if ($actualFiles -notcontains $expected) {
            $errors.Add("Missing localized docs file: $DocsRoot/$locale/$expected")
        }
    }
    $localeFiles = @(Get-ChildItem -LiteralPath $localeRoot -Recurse -File -Filter "*.md")
    foreach ($file in $localeFiles) {
        $relativePath = Normalize-RelativePath (Get-RelativePath -BasePath $localeRoot -TargetPath $file.FullName)
        Test-DocumentQuality -Locale $locale -RelativePath $relativePath -File $file
    }
    Test-MarkdownLinks -Files $localeFiles -AllowedRoot $localeRoot -RepositoryRoot $repoRoot -ScopeName $locale
    Test-MarkdownImages -Files $localeFiles -RepositoryRoot $repoRoot
}

$referenceLocale = $Locales[0]
foreach ($doc in $docMap) {
    Test-DocumentStructureCompleteness -Doc $doc -ReferenceLocale $referenceLocale
}

foreach ($locale in $Locales) {
    if (-not $treeHashes.ContainsKey($locale) -or -not $treeHashes.ContainsKey($referenceLocale)) {
        continue
    }
    if ($treeHashes[$locale] -ne $treeHashes[$referenceLocale]) {
        $errors.Add("Localized docs tree shape mismatch: $locale hash $($treeHashes[$locale]) differs from $referenceLocale hash $($treeHashes[$referenceLocale])")
    }
}

$scannedFiles = @(
    Get-ChildItem -LiteralPath $repoRoot -Recurse -File |
        Where-Object {
            $_.FullName -notmatch '\\.git\\' -and
            $_.Extension -in @(".md", ".ps1", ".yml", ".yaml")
        }
)
foreach ($file in $scannedFiles) {
    $relativeFile = Normalize-RelativePath (Get-RelativePath -BasePath $repoRoot -TargetPath $file.FullName)
    if ($relativeFile -eq "scripts/validate_docs_i18n.ps1") {
        continue
    }
    $fileContent = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    if ($fileContent.Contains("docs/i18n")) {
        $errors.Add("Forbidden legacy docs path reference in ${relativeFile}: docs/i18n")
    }
}

if ($errors.Count -gt 0) {
    foreach ($message in $errors) {
        Write-Error $message -ErrorAction Continue
    }
    throw "Docs i18n validation failed."
}

Write-Host "Docs i18n validation passed for locales: $($Locales -join ', ')"
