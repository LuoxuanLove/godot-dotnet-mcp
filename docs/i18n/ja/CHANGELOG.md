# 変更履歴

このファイルは Godot .NET MCP の日本語変更履歴入口です。完全で正規の変更履歴は [英語版 CHANGELOG](../../../CHANGELOG.md) に記録されています。

<p align="center"><a href="../../../CHANGELOG.md">English</a> | <a href="CHANGELOG.md">日本語</a> | <a href="../zh-CN/CHANGELOG.md">简体中文</a></p>

## 未リリース (1.2.0)

対象バージョン: 1.2.0。

### Documentation

- `v1.2.0` リリースノートのソースを pending-theme テンプレートで初期化し、プラグインメタデータの更新後に古い `v1.1.2` ソースを削除しました。
- README と CHANGELOG の多言語入口を整理し、日本語と簡体中文のドキュメントを `docs/i18n/` 配下へ配置しました。

### Internal

- プラグインメタデータ、protocol facts、.NET bridge メタデータ、プラグイン更新契約 fixture の期待値を `1.2.0` 開発ラインへ切り替えました。

## 1.1.2 - 2026-06-02

### Changed

- 組み込み MCP Prompt Guides を、`godot.project_orientation`、`godot.content_authoring`、`godot.debug_triage`、`godot.reference_integrity`、`godot.runtime_validation`、`godot.editor_ui_control` の 6 つのワークフロー向け入口へ再編成しました。
- デバッガー案内を `godot.debug_triage` に統合し、prompt の発見結果が個別のデバッガー専用ガイドではなく、1 つの失敗診断ワークフローとして表示されるようにしました。

### Fixed

- 再編成された MCP Prompt Guides を `system_help` から公開し、Agent が主要な能力ガイドから `prompts/list`、`prompts/get`、6 つすべての組み込み prompt ID を発見できるようにしました。
- DAP デバッガーの Tools ページカテゴリ、アクション名、パラメーター説明をローカライズし、ローカライズ済みツールプレビューが生の英語 schema テキストへ戻らないようにしました。
- Tools ページの動的アクションと空パラメーター fallback テキストをローカライズし、特定のツール key が定義されていない場合も既存の schema 説明を維持するようにしました。
- クリーンな Asset Library インストールで、Roslyn bridge 実装ソースがエクスポートされたプラグインダウンロードに含まれず、ホスト側 Godot C# プロジェクトで直接コンパイルされないようにしました。
- フランス語ローカライズファイルで、アクセント文字、カーブしたアポストロフィ、ノーブレークスペース、合字が mojibake ではなく正しく表示されるようにしました。
- reference-integrity Prompt Guide の `resource_path` 引数を system_resource_reference_audit のテキストファイル対応範囲に合わせ、.tscn と .tres パスのみを受け付けるようにしました。

### Documentation

- Prompt Guides、ローカライズ、クリーンな Asset Library インストールに関する `v1.1.2` 手動リリースノートソースを追加しました。
- Asset Library インストール向けの addon README コピーを更新し、エクスポートされたパッケージが、パッケージ内に含まれない相対パスではなく、リポジトリでホストされるドキュメント、変更履歴、現在の dev ブランチのプレビュー画像へリンクするようにしました。
- Prompt Guides ドキュメントを更新し、6 つの高レベルワークフロー入口を説明するとともに、DAP デバッグが独立した prompt guide ではなく `godot.debug_triage` の一部であることを明確にしました。

### Internal

- `git archive --worktree-attributes` を使用し、fixture の Roslyn パッケージ参照を削除し、Roslyn runtime ソースや bridge ソースなしでもエクスポートされたプラグインコピーがビルドできることを検証する、クリーンな Asset Library インストール harness ビルドを追加しました。
- 実際の tool-loader ローカライズ inventory 契約を追加し、すべての対応 locale で Tools ページの表示ツリー、アクション、パラメーター fallback カバレッジを確認できるようにしました。
- どの対応言語でも他の locale に存在する翻訳 key が欠けている場合に CI を失敗させる、locale key parity harness 契約を追加しました。
- MCP prompt、system help、router、ローカライズ契約を更新し、prompt surface が 6 つの高レベルワークフローガイドのまま維持されるようにしました。

## 過去のバージョン

1.1.1 以前の完全な履歴は [英語版 CHANGELOG](../../../CHANGELOG.md) を参照してください。日本語版は今後の公開変更に合わせて継続的に更新されます。
