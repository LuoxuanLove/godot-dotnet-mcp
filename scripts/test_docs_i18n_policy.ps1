$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $PSScriptRoot
$validatorPath = Join-Path $scriptRoot "scripts\validate_docs_i18n.ps1"

function Write-DocFixture {
    param(
        [string]$RepositoryRoot,
        [bool]$InvalidChangelogOrder,
        [bool]$DuplicateChangelogSection,
        [bool]$UnfinishedReleaseNoteWording
    )

    $docsRoot = Join-Path $RepositoryRoot "docs"
    $addonRoot = Join-Path $RepositoryRoot "addons\godot_dotnet_mcp"
    New-Item -ItemType Directory -Path $addonRoot -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $addonRoot "plugin.cfg") -Value "[plugin]`nversion=`"2.0.0`"`n" -Encoding UTF8

    $paths = @{
        en = @{
            "README.md" = "# Fixture README`n`nEnglish fixture content with enough lines.`n`n## Intro`n`nLine 1.`nLine 2.`nLine 3.`nLine 4.`nLine 5.`nLine 6.`n";
            "CHANGELOG.md" = ""
            "ROADMAP.md" = "# Roadmap`n`nEnglish roadmap content.`n`n## Direction`n`nLine 1.`nLine 2.`nLine 3.`nLine 4.`nLine 5.`nLine 6.`n";
            "overview.md" = "# Overview`n`nEnglish overview content for v2 preparation.`n`n## Release Prep`n`nRead the [v2.0.0 release notes](process/release-notes/release-notes-v2.0.0.md).`n`n## Usage`n`nLine 1.`nLine 2.`nLine 3.`nLine 4.`nLine 5.`nLine 6.`n"
        }
        "zh-CN" = @{
            "说明.md" = "# 说明`n`n中文内容用于测试。`n`n## 使用`n`n第 1 行。`n第 2 行。`n第 3 行。`n第 4 行。`n第 5 行。`n第 6 行。`n";
            "变更日志.md" = "";
            "路线图.md" = "# 路线图`n`n中文路线图内容。`n`n## 方向`n`n第 1 行。`n第 2 行。`n第 3 行。`n第 4 行。`n第 5 行。`n第 6 行。`n";
            "概述.md" = "# 概述`n`n中文概述内容用于 v2 准备。`n`n## 发布准备`n`n阅读 [v2.0.0 发布说明](流程/发布说明/发布说明-v2.0.0.md)。`n`n## 使用`n`n第 1 行。`n第 2 行。`n第 3 行。`n第 4 行。`n第 5 行。`n第 6 行。`n"
        }
        ja = @{
            "はじめに.md" = "# はじめに`n`n日本語の内容です。`n`n## 使い方`n`n1 行目。`n2 行目。`n3 行目。`n4 行目。`n5 行目。`n6 行目。`n";
            "変更履歴.md" = "";
            "ロードマップ.md" = "# ロードマップ`n`n日本語の内容です。`n`n## 方針`n`n1 行目。`n2 行目。`n3 行目。`n4 行目。`n5 行目。`n6 行目。`n";
            "概要.md" = "# 概要`n`n日本語の v2 準備内容です。`n`n## リリース準備`n`n[v2.0.0 リリースノート](プロセス/リリースノート/リリースノート-v2.0.0.md) を確認します。`n`n## 使い方`n`n1 行目。`n2 行目。`n3 行目。`n4 行目。`n5 行目。`n6 行目。`n"
        }
        ko = @{
            "소개.md" = "# 소개`n`n한국어 내용입니다.`n`n## 사용`n`n1번째 줄.`n2번째 줄.`n3번째 줄.`n4번째 줄.`n5번째 줄.`n6번째 줄.`n";
            "변경-로그.md" = "";
            "로드맵.md" = "# 로드맵`n`n한국어 내용입니다.`n`n## 방향`n`n1번째 줄.`n2번째 줄.`n3번째 줄.`n4번째 줄.`n5번째 줄.`n6번째 줄.`n";
            "개요.md" = "# 개요`n`n한국어 v2 준비 내용입니다.`n`n## 릴리스 준비`n`n[v2.0.0 릴리스 노트](프로세스/릴리스-노트/릴리스-노트-v2.0.0.md)를 확인합니다.`n`n## 사용`n`n1번째 줄.`n2번째 줄.`n3번째 줄.`n4번째 줄.`n5번째 줄.`n6번째 줄.`n"
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

    $releaseNoteSwitch = '<p align="center"><a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/refactor/v1.4.0/docs/en/process/release-notes/release-notes-v1.4.0.md">English</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/refactor/v1.4.0/docs/zh-CN/流程/发布说明/发布说明-v1.4.0.md">简体中文</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/refactor/v1.4.0/docs/ja/プロセス/リリースノート/リリースノート-v1.4.0.md">日本語</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/refactor/v1.4.0/docs/ko/프로세스/릴리스-노트/릴리스-노트-v1.4.0.md">한국어</a></p>'
    $v2ReleaseNoteSwitch = '<p align="center"><a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v2.0.0/docs/en/process/release-notes/release-notes-v2.0.0.md">English</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v2.0.0/docs/zh-CN/流程/发布说明/发布说明-v2.0.0.md">简体中文</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v2.0.0/docs/ja/プロセス/リリースノート/リリースノート-v2.0.0.md">日本語</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v2.0.0/docs/ko/프로세스/릴리스-노트/릴리스-노트-v2.0.0.md">한국어</a></p>'
    $releaseNoteBodies = @{
        en = @(
            "## Fixture v1.4.0 Release Notes",
            "",
            "Godot .NET MCP v1.4.0 fixture notes cover resource-first context, prompt guidance, and public tool cleanup.",
            "",
            $releaseNoteSwitch,
            "",
            "### Release Highlights",
            "",
            "The fixture describes finished release highlights for plugin behavior and validation gates.",
            "",
            "### Compatibility",
            "",
            "Clients should prefer Resources and Prompts for passive context and planning."
        )
        "zh-CN" = @(
            "## Fixture v1.4.0 发布说明",
            "",
            "Godot .NET MCP v1.4.0 fixture 发布说明覆盖 resource-first 上下文、Prompt 指引和公开工具清理。",
            "",
            $releaseNoteSwitch,
            "",
            "### 发布亮点",
            "",
            "该 fixture 描述已经完成的插件行为与验证门禁。",
            "",
            "### 兼容性",
            "",
            "客户端应优先使用 Resources 与 Prompts 获取被动上下文和规划入口。"
        )
        ja = @(
            "## Fixture v1.4.0 リリースノート",
            "",
            "Godot .NET MCP v1.4.0 fixture notes は resource-first context、Prompt guidance、public tool cleanup を扱います。",
            "",
            $releaseNoteSwitch,
            "",
            "### Release Highlights",
            "",
            "この fixture は完了済みの plugin behavior と validation gate を説明します。",
            "",
            "### Compatibility",
            "",
            "client は passive context と planning に Resources と Prompts を優先します。"
        )
        ko = @(
            "## Fixture v1.4.0 릴리스 노트",
            "",
            "Godot .NET MCP v1.4.0 fixture notes는 resource-first context, Prompt guidance, public tool cleanup을 다룹니다.",
            "",
            $releaseNoteSwitch,
            "",
            "### Release Highlights",
            "",
            "이 fixture는 완료된 plugin behavior와 validation gate를 설명합니다.",
            "",
            "### Compatibility",
            "",
            "client는 passive context와 planning에 Resources 및 Prompts를 우선 사용합니다."
        )
    }
    if ($UnfinishedReleaseNoteWording) {
        $releaseNoteBodies.en[8] = "The final highlights will be written from the actual release contents."
    }
    $releaseNotePaths = @{ en = "process/release-notes/release-notes-v1.4.0.md"; "zh-CN" = "流程/发布说明/发布说明-v1.4.0.md"; ja = "プロセス/リリースノート/リリースノート-v1.4.0.md"; ko = "프로세스/릴리스-노트/릴리스-노트-v1.4.0.md" }
    foreach ($locale in $releaseNoteBodies.Keys) {
        $paths[$locale][$releaseNotePaths[$locale]] = ($releaseNoteBodies[$locale] -join "`n") + "`n"
    }

    $v2ReleaseNotePaths = @{ en = "process/release-notes/release-notes-v2.0.0.md"; "zh-CN" = "流程/发布说明/发布说明-v2.0.0.md"; ja = "プロセス/リリースノート/リリースノート-v2.0.0.md"; ko = "프로세스/릴리스-노트/릴리스-노트-v2.0.0.md" }
    $v2ReleaseNoteBodies = @{
        en = @("## Fixture v2.0.0 Release Notes", "", "Godot .NET MCP v2.0.0 fixture notes cover Companion preparation and validation gates.", "", $v2ReleaseNoteSwitch, "", "### Release Highlights", "", "The fixture describes finished v2 baseline notes for plugin behavior and validation gates.", "", "### Compatibility", "", "Clients should use the v2 preparation guidance for this fixture.")
        "zh-CN" = @("## Fixture v2.0.0 发布说明", "", "Godot .NET MCP v2.0.0 fixture 发布说明覆盖 Companion 准备和验证门禁。", "", $v2ReleaseNoteSwitch, "", "### 发布亮点", "", "该 fixture 描述已经完成的 v2 基线说明、插件行为与验证门禁。", "", "### 兼容性", "", "客户端应使用此 fixture 的 v2 准备指引。")
        ja = @("## Fixture v2.0.0 リリースノート", "", "Godot .NET MCP v2.0.0 fixture notes は Companion 準備と validation gate を扱います。", "", $v2ReleaseNoteSwitch, "", "### Release Highlights", "", "この fixture は完了済みの v2 baseline notes、plugin behavior、validation gate を説明します。", "", "### Compatibility", "", "client はこの fixture の v2 準備ガイダンスを使用します。")
        ko = @("## Fixture v2.0.0 릴리스 노트", "", "Godot .NET MCP v2.0.0 fixture notes는 Companion 준비와 validation gate를 다룹니다.", "", $v2ReleaseNoteSwitch, "", "### Release Highlights", "", "이 fixture는 완료된 v2 baseline notes, plugin behavior, validation gate를 설명합니다.", "", "### Compatibility", "", "client는 이 fixture의 v2 준비 지침을 사용합니다.")
    }
    foreach ($locale in $v2ReleaseNoteBodies.Keys) {
        $paths[$locale][$v2ReleaseNotePaths[$locale]] = ($v2ReleaseNoteBodies[$locale] -join "`n") + "`n"
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
        [bool]$UnfinishedReleaseNoteWording,
        [bool]$ShouldPass
    )

    $repo = Join-Path ([System.IO.Path]::GetTempPath()) ("godot-dotnet-mcp-docs-policy-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $repo | Out-Null
    try {
        Write-DocFixture -RepositoryRoot $repo -InvalidChangelogOrder $InvalidChangelogOrder -DuplicateChangelogSection $DuplicateChangelogSection -UnfinishedReleaseNoteWording $UnfinishedReleaseNoteWording
        $passed = $true
        $failureMessage = ""
        $output = @()
        try {
            $output = & $validatorPath -DocsRoot (Join-Path $repo "docs") -Locales @("en", "zh-CN", "ja", "ko") -SkipDocumentMapValidation 2>&1
            $output | Out-Host
        } catch {
            $output | Out-Host
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

Invoke-DocsScenario -Name "ordered changelog sections" -InvalidChangelogOrder $false -DuplicateChangelogSection $false -UnfinishedReleaseNoteWording $false -ShouldPass $true
Invoke-DocsScenario -Name "invalid changelog section order" -InvalidChangelogOrder $true -DuplicateChangelogSection $false -UnfinishedReleaseNoteWording $false -ShouldPass $false
Invoke-DocsScenario -Name "duplicate changelog section" -InvalidChangelogOrder $false -DuplicateChangelogSection $true -UnfinishedReleaseNoteWording $false -ShouldPass $false
Invoke-DocsScenario -Name "unfinished release-note wording" -InvalidChangelogOrder $false -DuplicateChangelogSection $false -UnfinishedReleaseNoteWording $true -ShouldPass $false

Write-Host "Docs i18n policy scenarios validated successfully."
