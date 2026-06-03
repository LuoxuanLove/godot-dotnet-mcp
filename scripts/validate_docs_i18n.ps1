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
    @{ Id = "architecture-overview"; Paths = @{ en = "architecture/overview.md"; "zh-CN" = "架构/概述.md"; ja = "アーキテクチャ/概要.md"; ko = "아키텍처/개요.md" } },
    @{ Id = "architecture-installation-release"; Paths = @{ en = "architecture/installation-and-release.md"; "zh-CN" = "架构/安装与发布.md"; ja = "アーキテクチャ/インストールとリリース.md"; ko = "아키텍처/설치와-배포.md" } },
    @{ Id = "architecture-encoding"; Paths = @{ en = "architecture/encoding-and-architecture-standards.md"; "zh-CN" = "架构/编码与架构规范.md"; ja = "アーキテクチャ/エンコーディングとアーキテクチャ規約.md"; ko = "아키텍처/코딩과-아키텍처-규범.md" } },
    @{ Id = "architecture-services-routing"; Paths = @{ en = "architecture/services-and-routing.md"; "zh-CN" = "架构/服务与路由.md"; ja = "アーキテクチャ/サービスとルーティング.md"; ko = "아키텍처/서비스와-라우팅.md" } },
    @{ Id = "architecture-config-ui"; Paths = @{ en = "architecture/configuration-and-ui.md"; "zh-CN" = "架构/配置与界面.md"; ja = "アーキテクチャ/設定とユーザーインターフェース.md"; ko = "아키텍처/설정과-사용자-인터페이스.md" } },
    @{ Id = "architecture-lifecycle"; Paths = @{ en = "architecture/lifecycle-and-wiring.md"; "zh-CN" = "架构/生命周期与装配.md"; ja = "アーキテクチャ/ライフサイクルと組み立て.md"; ko = "아키텍처/생명주기와-조립.md" } },
    @{ Id = "architecture-runtime"; Paths = @{ en = "architecture/runtime-services.md"; "zh-CN" = "架构/运行时服务.md"; ja = "アーキテクチャ/ランタイムサービス.md"; ko = "아키텍처/런타임-서비스.md" } },
    @{ Id = "interface-overview"; Paths = @{ en = "interface/overview.md"; "zh-CN" = "界面/总览.md"; ja = "インターフェース/概要.md"; ko = "인터페이스/개요.md" } },
    @{ Id = "interface-server-config"; Paths = @{ en = "interface/server-and-config-pages.md"; "zh-CN" = "界面/服务与配置页实现.md"; ja = "インターフェース/サーバーと設定ページ実装.md"; ko = "인터페이스/서버와-설정-페이지-구현.md" } },
    @{ Id = "interface-tools"; Paths = @{ en = "interface/tools-page.md"; "zh-CN" = "界面/工具页实现.md"; ja = "インターフェース/ツールページ実装.md"; ko = "인터페이스/도구-페이지-구현.md" } },
    @{ Id = "process-agent-bot"; Paths = @{ en = "process/agent-and-bot-workflow.md"; "zh-CN" = "流程/智能体与机器人流程.md"; ja = "プロセス/エージェントとボットの流れ.md"; ko = "프로세스/에이전트와-봇-흐름.md" } },
    @{ Id = "process-release-runbook"; Paths = @{ en = "process/release-runbook.md"; "zh-CN" = "流程/发布运行手册.md"; ja = "プロセス/リリース運用手順.md"; ko = "프로세스/릴리스-운영-절차.md" } },
    @{ Id = "process-release-notes-v1.2.0"; Paths = @{ en = "process/release-notes/release-notes-v1.2.0.md"; "zh-CN" = "流程/发布说明/发布说明-v1.2.0.md"; ja = "プロセス/リリースノート/リリースノート-v1.2.0.md"; ko = "프로세스/릴리스-노트/릴리스-노트-v1.2.0.md" } },
    @{ Id = "modules-dotnet"; Paths = @{ en = "modules/dotnet-support.md"; "zh-CN" = "模块/点网支持.md"; ja = "モジュール/ドットネット対応.md"; ko = "모듈/닷넷-지원.md" } },
    @{ Id = "modules-system"; Paths = @{ en = "modules/system-tool-layer.md"; "zh-CN" = "模块/系统工具层.md"; ja = "モジュール/システムツール層.md"; ko = "모듈/시스템-도구-계층.md" } },
    @{ Id = "modules-tool-system"; Paths = @{ en = "modules/tool-system.md"; "zh-CN" = "模块/工具系统.md"; ja = "モジュール/ツールシステム.md"; ko = "모듈/도구-시스템.md" } },
    @{ Id = "modules-tool-domain"; Paths = @{ en = "modules/tool-domain-index.md"; "zh-CN" = "模块/工具域索引.md"; ja = "モジュール/ツールドメイン索引.md"; ko = "모듈/도구-도메인-색인.md" } },
    @{ Id = "modules-core"; Paths = @{ en = "modules/core-implementation.md"; "zh-CN" = "模块/核心实现.md"; ja = "モジュール/コア実装.md"; ko = "모듈/핵심-구현.md" } },
    @{ Id = "modules-script-scene"; Paths = @{ en = "modules/script-and-scene-analysis.md"; "zh-CN" = "模块/脚本与场景分析.md"; ja = "モジュール/スクリプトとシーン分析.md"; ko = "모듈/스크립트와-씬-분석.md" } },
    @{ Id = "modules-user-extensions"; Paths = @{ en = "modules/user-extensions.md"; "zh-CN" = "模块/用户扩展.md"; ja = "モジュール/ユーザー拡張.md"; ko = "모듈/사용자-확장.md" } },
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
    $children = @(Get-ChildItem -LiteralPath $Root -Force | Sort-Object { if ($_.PSIsContainer) { "0" } else { "1" } }, Name)
    $childHashes = New-Object System.Collections.Generic.List[string]
    foreach ($child in $children) {
        if ($child.PSIsContainer) {
            $childHashes.Add("D:" + (Get-TreeShapeHash -Root $child.FullName))
        } else {
            $childHashes.Add("F")
        }
    }
    return Get-HashText ("N(" + (($childHashes | Sort-Object) -join ",") + ")")
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

function Resolve-MarkdownTarget {
    param([System.IO.FileInfo]$File, [string]$Target)
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
    param([System.IO.FileInfo[]]$Files, [string]$AllowedRoot, [string]$RepositoryRoot, [string]$ScopeName)
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
                $errors.Add("Broken Markdown link in ${relativeFile}: $target")
                continue
            }
            $resolvedFull = (Resolve-Path -LiteralPath $resolvedTarget).Path
            if (-not $resolvedFull.StartsWith($allowedFull, [System.StringComparison]::OrdinalIgnoreCase)) {
                $relativeTarget = Get-RelativePath -BasePath $RepositoryRoot -TargetPath $resolvedFull
                $errors.Add("Cross-language Markdown link in ${relativeFile} (${ScopeName}): $target -> $relativeTarget")
            }
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

function Test-DocumentQuality {
    param([string]$Locale, [string]$RelativePath, [System.IO.FileInfo]$File)
    $content = Get-Content -LiteralPath $File.FullName -Raw -Encoding UTF8
    $naturalLanguageContent = [regex]::Replace($content, '(?ms)^```.*?^```', '')
    $naturalLanguageContent = [regex]::Replace($naturalLanguageContent, '`[^`]*`', '')
    $lines = @($content -split "`r?`n")
    $relative = "$DocsRoot/$Locale/$RelativePath"
    if ($lines.Count -lt 10) {
        $errors.Add("Localized document is too short or stub-like: $relative")
    }
    if ($naturalLanguageContent -match '(?i)\b(todo|tbd|to be filled)\b|待填|待补') {
        $errors.Add("Localized document contains placeholder wording: $relative")
    }
    switch ($Locale) {
        "en" {
            if ($naturalLanguageContent -match '[\p{IsCJKUnifiedIdeographs}\p{IsHiragana}\p{IsKatakana}\p{IsHangulSyllables}]') {
                $errors.Add("English document contains CJK/Kana/Hangul text: $relative")
            }
        }
        "zh-CN" {
            if ($naturalLanguageContent -match '[\p{IsHiragana}\p{IsKatakana}\p{IsHangulSyllables}]') {
                $errors.Add("Simplified Chinese document contains Japanese/Korean text: $relative")
            }
        }
        "ja" {
            if ($naturalLanguageContent -notmatch '[\p{IsHiragana}\p{IsKatakana}]') {
                $errors.Add("Japanese document lacks Japanese kana content: $relative")
            }
            if ($naturalLanguageContent -match '[\p{IsHangulSyllables}]') {
                $errors.Add("Japanese document contains Korean text: $relative")
            }
        }
        "ko" {
            if ($naturalLanguageContent -notmatch '[\p{IsHangulSyllables}]') {
                $errors.Add("Korean document lacks Korean Hangul content: $relative")
            }
            if ($naturalLanguageContent -match '[\p{IsHiragana}\p{IsKatakana}]') {
                $errors.Add("Korean document contains Japanese kana text: $relative")
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
    foreach ($file in @(Get-ChildItem -LiteralPath $localeRoot -Recurse -File -Filter "*.md")) {
        $relativePath = Normalize-RelativePath (Get-RelativePath -BasePath $localeRoot -TargetPath $file.FullName)
        Test-DocumentQuality -Locale $locale -RelativePath $relativePath -File $file
    }
    Test-MarkdownLinks -Files @(Get-ChildItem -LiteralPath $localeRoot -Recurse -File -Filter "*.md") -AllowedRoot $localeRoot -RepositoryRoot $repoRoot -ScopeName $locale
}

$referenceLocale = $Locales[0]
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
