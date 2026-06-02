<div align="center">
  <a href="#godot-net-mcp"><img src="../../../asset_library/hero.svg" alt="GODOT .NET MCP - Godot .NET 向けのエディター内 MCP ブリッジ" width="960"></a>
</div>

<p align="center"><a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/releases/latest"><img alt="Latest Stable" src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.github.com%2Frepos%2FLuoxuanLove%2Fgodot-dotnet-mcp%2Freleases%2Flatest&amp;query=%24.tag_name&amp;label=stable&amp;color=f59e0b&amp;style=flat-square&amp;labelColor=24292f"></a> <a href="https://godotengine.org/"><img alt="Godot 4.6+" src="https://img.shields.io/badge/Godot-4.6%2B-478cbf?style=flat-square&amp;labelColor=24292f"></a> <a href="https://dotnet.microsoft.com/"><img alt=".NET 8" src="https://img.shields.io/badge/.NET-8-512bd4?style=flat-square&amp;labelColor=24292f"></a> <a href="https://godotengine.org/asset-library/asset/4923"><img alt="Godot Asset Library 4923" src="https://img.shields.io/badge/Godot%20Asset%20Library-4923-478cbf?style=flat-square&amp;labelColor=24292f"></a> <a href="../../../LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-22c55e?style=flat-square&amp;labelColor=24292f"></a></p>

<p align="center"><a href="../../../README.md">English</a> | <a href="../ko/README.md">한국어</a> | <a href="README.md">日本語</a> | <a href="../zh-CN/README.md">简体中文</a></p>

| ホーム | ツール | 設定 |
|---|---|---|
| ![ホームダッシュボード](../../../asset_library/home-en.png) | ![ツールブラウザー](../../../asset_library/tools-en.png) | ![クライアント設定](../../../asset_library/config-en.png) |

# Godot .NET MCP

Godot .NET MCP は、Godot 4.6 以降の .NET プロジェクト向けに作られた、エディター内で動作する MCP プラグインです。Godot エディターの中で直接動き、MCP 対応クライアントにエディター状態、現在のシーン、選択中ノード、実行情報、診断結果、スクリーンショットなどのリアルタイムなプロジェクト文脈を渡します。

MCP サービスは Godot プラグインに組み込まれています。プラグインを有効化し、Dock からサービスを開始するだけで利用できます。追加のバックグラウンドプロセスを起動する必要はありません。

## なぜ必要なのか

Godot プロジェクトは、単なる `.tscn`、`.tres`、スクリプトファイルの集まりではありません。

表示中のシーン、選択中のノード、エディター出力、ゲーム実行時の画面と状態、最近のエラー、プラグイン設定は、どのような変更が適切かを左右します。Godot .NET MCP はこのエディター内文脈を整理して MCP クライアントに提供し、ディレクトリのスナップショットだけに頼った推測を減らします。

作業の中心がコードファイルだけでなく、Godot エディターやゲーム実行時にもあるなら、このプラグインは役に立ちます。

## 主な機能

|       | 機能 | 内容 |
| :---: | :--- | :--- |
| 🎛️ | **エディターと一緒に動作** | MCP サービスは Godot プラグインから直接提供され、追加のバックグラウンドプロセスは不要です。 |
| 🚀 | **低い導入コスト** | Godot Asset Library からインストールし、一般的な MCP クライアント向け設定を生成し、GitHub ソースからプラグインを更新できます。 |
| 🎮 | **ライブ Godot エディター文脈** | 現在のシーン、選択中ノード、Dock 状態、ログ、実行情報、診断サマリー、エディタースクリーンショットを Agent に提供します。 |
| 🌳 | **シーン、リソース、バインディング診断** | シーンツリー、リソース参照、依存関係、シーン構造の問題、C# エクスポートバインディング状態の確認を支援します。 |
| ▶️ | **ゲーム実行時サポート** | シーンの開始と停止、実行時診断の確認、入力操作、ゲーム実行時画面のキャプチャを行えます。 |
| 🔎 | **Roslyn ベースの C# サポート** | プラグイン内部の Roslyn 構文チェックにより、クラス、基底型、メソッド、列挙型、エクスポートメンバーなどの C# スクリプト構造を読み取ります。 |
| 🐞 | **Godot DAP デバッグ** | Godot DAP 経由でブレークポイント、スレッド、スタックトレース、出力イベントを読み取り、一時停止、続行、ステップオーバーを実行します。C# のマネージドブレークポイントには別途 .NET デバッガーが必要です。 |
| 📚 | **MCP Resources と Prompts** | プロジェクトリソース、診断読み取りエントリー、一般的な Godot ワークフロー向け Prompt Guide を提供します。 |
| 🧰 | **ツール拡張** | `custom_tools/` から `user_*` GDScript ツールを任意でホットロードし、プロジェクト独自の MCP 機能を追加できます。 |

## インストール

### Godot Asset Library から

1. Godot でプロジェクトを開きます。
2. `AssetLib` タブを開きます。
3. `Godot .NET MCP` を検索します。
4. プラグインをインストールします。
5. `Project Settings > Plugins` で `Godot .NET MCP` を有効化します。
6. `MCPDock` を開き、`Home` からサービスを開始します。

### ソースから

プラグインのソースディレクトリを Godot プロジェクトへコピーします。

```text
addons/godot_dotnet_mcp
```

その後、`Project Settings > Plugins` から有効化します。

## 最初の使い方

1. Godot 4.6 以降の .NET プロジェクトにプラグインをインストールして有効化します。
2. `MCPDock` を開きます。
3. `Home` から MCP サービスを開始します。
4. 設定ページで MCP クライアント設定を生成またはコピーします。
5. クライアントに戻ってサービスへ接続し、現在の Godot プロジェクト状態を読み取らせます。

## ドキュメント

- [日本語の変更履歴](CHANGELOG.md)
- [日本語ロードマップ](ROADMAP.md)
- [Documentation overview](../../../docs/概述.md)
- [Installation and release](../../../docs/架构/安装与发布.md)
- [User extensions](../../../docs/模块/用户扩展.md)

## 作者メモ

私はまだ学生ですが、ゲーム作りに強い情熱があります。以前は昔ながらの方法で、ひとりでリズムゲームのプロジェクト全体を書いたことがあります。正直に言うと、細かいコードやデバッグと格闘するのは苦痛でした。

AI の時代になって、すべてが変わりました。コードは安くなり、Agent や MCP のような素晴らしい概念を知ったとき、私はとても興奮しました。AI が私のアイデアをシンプルかつ素早く形にし、設計、開発、検証、そのほかすべてを自律的に完了してくれることを望みました。

そこで私は、この MCP プラグインを自分で作り、自分のゲーム制作で実際に使うことにしました。このプラグインは私自身の実作業で鍛えられます。私が先に落とし穴を踏み、磨き、修正します。

このプロジェクトのコードは 100% AI によって直接生成されていますが、正式版に入る前にできるだけ検証できるよう、厳格な自動チェック、開発フロー、リリースフローを用意しています。

ここまで読んだなら、Godot .NET MCP を試してみませんか。私は市場を調べ、強力なアイデアを学び続け、このプラグインに反映していきます。これはあなたの Agent とゲームプロジェクトを結ぶ、最も密接な接点になります。

## ライセンス

MIT。詳しくは [LICENSE](../../../LICENSE) を参照してください。
