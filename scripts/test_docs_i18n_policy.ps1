$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $PSScriptRoot
$validatorPath = Join-Path $scriptRoot "scripts\validate_docs_i18n.ps1"

function Write-DocFixture {
    param(
        [string]$RepositoryRoot,
        [bool]$InvalidChangelogOrder,
        [bool]$DuplicateChangelogSection
    )

    $docsRoot = Join-Path $RepositoryRoot "docs"
    $paths = @{
        en = @{
            "README.md" = "# Fixture README`n`nEnglish fixture content with enough lines.`n`n## Intro`n`nLine 1.`nLine 2.`nLine 3.`nLine 4.`nLine 5.`nLine 6.`n";
            "CHANGELOG.md" = ""
            "ROADMAP.md" = "# Roadmap`n`nEnglish roadmap content.`n`n## Direction`n`nLine 1.`nLine 2.`nLine 3.`nLine 4.`nLine 5.`nLine 6.`n";
            "overview.md" = "# Overview`n`nEnglish overview content.`n`n## Usage`n`nLine 1.`nLine 2.`nLine 3.`nLine 4.`nLine 5.`nLine 6.`n"
        }
        "zh-CN" = @{
            "说明.md" = "# 说明`n`n中文内容用于测试。`n`n## 使用`n`n第 1 行。`n第 2 行。`n第 3 行。`n第 4 行。`n第 5 行。`n第 6 行。`n";
            "变更日志.md" = "";
            "路线图.md" = "# 路线图`n`n中文路线图内容。`n`n## 方向`n`n第 1 行。`n第 2 行。`n第 3 行。`n第 4 行。`n第 5 行。`n第 6 行。`n";
            "概述.md" = "# 概述`n`n中文概述内容。`n`n## 使用`n`n第 1 行。`n第 2 行。`n第 3 行。`n第 4 行。`n第 5 行。`n第 6 行。`n"
        }
        ja = @{
            "はじめに.md" = "# はじめに`n`n日本語の内容です。`n`n## 使い方`n`n1 行目。`n2 行目。`n3 行目。`n4 行目。`n5 行目。`n6 行目。`n";
            "変更履歴.md" = "";
            "ロードマップ.md" = "# ロードマップ`n`n日本語の内容です。`n`n## 方針`n`n1 行目。`n2 行目。`n3 行目。`n4 行目。`n5 行目。`n6 行目。`n";
            "概要.md" = "# 概要`n`n日本語の内容です。`n`n## 使い方`n`n1 行目。`n2 行目。`n3 行目。`n4 行目。`n5 行目。`n6 行目。`n"
        }
        ko = @{
            "소개.md" = "# 소개`n`n한국어 내용입니다.`n`n## 사용`n`n1번째 줄.`n2번째 줄.`n3번째 줄.`n4번째 줄.`n5번째 줄.`n6번째 줄.`n";
            "변경-로그.md" = "";
            "로드맵.md" = "# 로드맵`n`n한국어 내용입니다.`n`n## 방향`n`n1번째 줄.`n2번째 줄.`n3번째 줄.`n4번째 줄.`n5번째 줄.`n6번째 줄.`n";
            "개요.md" = "# 개요`n`n한국어 내용입니다.`n`n## 사용`n`n1번째 줄.`n2번째 줄.`n3번째 줄.`n4번째 줄.`n5번째 줄.`n6번째 줄.`n"
        }
    }

    $localizedChangelogLines = @{
        en = @{ Intro = "Fixture changelog content."; Target = "Target version: 1.4.0."; Documentation = "Documentation item."; Internal = "Internal item." }
        "zh-CN" = @{ Intro = "中文变更日志内容。"; Target = "目标版本：1.4.0。"; Documentation = "文档条目。"; Internal = "内部条目。" }
        ja = @{ Intro = "日本語の変更履歴です。"; Target = "対象バージョン: 1.4.0。"; Documentation = "ドキュメント項目。"; Internal = "内部項目。" }
        ko = @{ Intro = "한국어 변경 로그입니다."; Target = "대상 버전은 1.4.0입니다."; Documentation = "문서 항목입니다."; Internal = "내부 항목입니다." }
    }
    $changelogPaths = @{ en = "CHANGELOG.md"; "zh-CN" = "变更日志.md"; ja = "変更履歴.md"; ko = "변경-로그.md" }
    foreach ($locale in $localizedChangelogLines.Keys) {
        $text = $localizedChangelogLines[$locale]
        $sectionLines = @("### Documentation", "", "- $($text.Documentation)", "", "### Internal", "", "- $($text.Internal)")
        if ($InvalidChangelogOrder) {
            $sectionLines = @("### Internal", "", "- $($text.Internal)", "", "### Documentation", "", "- $($text.Documentation)")
        }
        if ($DuplicateChangelogSection) {
            $sectionLines += @("", "### Internal", "", "- Duplicate $($text.Internal)")
        }
        $changelogText = @(
            "# Changelog",
            "",
            $text.Intro,
            "",
            "## [Unreleased] ([1.4.0])",
            "",
            $text.Target,
            ""
        ) + $sectionLines
        $paths[$locale][$changelogPaths[$locale]] = ($changelogText -join "`n") + "`n"
    }

    foreach ($locale in $paths.Keys) {
        $localeRoot = Join-Path $docsRoot $locale
        New-Item -ItemType Directory -Path $localeRoot -Force | Out-Null
        foreach ($relativePath in $paths[$locale].Keys) {
            $target = Join-Path $localeRoot $relativePath
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            Set-Content -LiteralPath $target -Value $paths[$locale][$relativePath] -Encoding UTF8
        }
    }
}

function Invoke-DocsScenario {
    param(
        [string]$Name,
        [bool]$InvalidChangelogOrder,
        [bool]$DuplicateChangelogSection,
        [bool]$ShouldPass
    )

    $repo = Join-Path ([System.IO.Path]::GetTempPath()) ("godot-dotnet-mcp-docs-policy-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $repo | Out-Null
    try {
        Write-DocFixture -RepositoryRoot $repo -InvalidChangelogOrder $InvalidChangelogOrder -DuplicateChangelogSection $DuplicateChangelogSection
        $passed = $true
        $failureMessage = ""
        try {
            $output = & $validatorPath -DocsRoot (Join-Path $repo "docs") -Locales @("en", "zh-CN", "ja", "ko") -SkipDocumentMapValidation 2>&1
            $output | Out-Host
        } catch {
            $passed = $false
            $failureMessage = $_.Exception.Message
            Write-Host "Scenario '$Name' failed as expected candidate: $failureMessage"
        }

        if ($passed -ne $ShouldPass) {
            throw "Scenario '$Name' expected pass=$ShouldPass but got pass=$passed."
        }
        if (-not $ShouldPass -and $failureMessage -notlike "*Docs i18n validation failed*") {
            throw "Scenario '$Name' failed with unexpected message: $failureMessage"
        }
        Write-Host "Scenario '$Name' passed."
    } finally {
        Remove-Item -LiteralPath $repo -Recurse -Force
    }
}

Invoke-DocsScenario -Name "ordered changelog sections" -InvalidChangelogOrder $false -DuplicateChangelogSection $false -ShouldPass $true
Invoke-DocsScenario -Name "invalid changelog section order" -InvalidChangelogOrder $true -DuplicateChangelogSection $false -ShouldPass $false
Invoke-DocsScenario -Name "duplicate changelog section" -InvalidChangelogOrder $false -DuplicateChangelogSection $true -ShouldPass $false

Write-Host "Docs i18n policy scenarios validated successfully."
