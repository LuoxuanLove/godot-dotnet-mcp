# ロードマップ

このロードマップは Godot .NET MCP の今後の製品方向を説明するものです。これは計画文書であり、リリース約束や issue レベル設計の代替ではありません。実装上の制約、テスト結果、ユーザーフィードバックが明確になるにつれて、バージョン範囲は変わる可能性があります。

<p align="center"><a href="../../../ROADMAP.md">English</a> | <a href="../ko/ROADMAP.md">한국어</a> | <a href="ROADMAP.md">日本語</a> | <a href="../zh-CN/ROADMAP.md">简体中文</a></p>

## 製品ポジショニング

Godot .NET MCP は、Godot 4.6 以降の .NET プロジェクト向けのエディター内 MCP プラグインです。1.x における基本的な位置付けは次の通りです。

- MCP サービスを Godot エディター内で直接実行する。
- ライブのエディター、プロジェクト、シーン、ランタイム、診断、スクリーンショット、C# 構造、リソース、ツール拡張の文脈を提供する。
- 低レベルの atomic tool で Agent を圧倒するのではなく、高レベルの `system_*` ワークフローを公開する。
- セットアップを直接的に保ち、コアプラグイン体験に別の常駐バックグラウンドサーバーを要求しない。
- Agent の作業を、ファイル編集だけでなく診断、ランタイム証拠、エディター状態によって検証可能にする。

このプロジェクトは、単純なツール数で競争すべきではありません。競争すべきなのは、意味品質、セットアップ状況を理解した案内、C#/.NET プロジェクト理解、エディター状態の正確性、ランタイム検証、安定した公開 MCP surface です。

## v1.x 開発方向

1.x 系列では、Godot .NET MCP を Agent 向けの証拠優先ワークフロープラットフォームにしつつ、エディター内プラグインアーキテクチャを継続的に磨きます。優先目標は、Agent が正しい能力を見つけ、焦点を絞った変更を行い、Godot を通じて検証し、信頼できる証拠を報告できるようにすることです。

### 能力発見とツールガバナンス

- `system_help` とツールカタログリソースを強化し、Agent が大きなフラットリストから推測するのではなく、タスクに応じてツールを選べるようにする。
- core、runtime、DAP、editor UI、visual、plugin、user-extension などのツールグループと profile をより明確にする。
- プロジェクト未実行、runtime control 不可、DAP endpoint 不可、エディター前面化が必要、ユーザーツール欠落などの setup-gated 状態を表示する。
- 高レベルの `system_*` 入口を公開ワークフロー層として維持し、低レベル executor は内部実装詳細として保つ。
- 公開ツール名、パラメーター、戻り値フィールド、protocol facts を 1.x ワークフローの安定 API surface として扱う。

### クローズドループのランタイム検証

- 既存の project run、runtime control、runtime step、スクリーンショット、editor log、runtime diagnosis ツールを、より明確な検証ワークフローにする。
- 何を実行したか、どの marker が一致したか、どのスクリーンショットやランタイム状態を取得したか、エラーが出たか、クリーンアップが行われたかを説明する証拠重視のレポートを支援する。
- 起動成功を動作検証成功と見なさない。ランタイム検証では、起動、操作、診断、証明を区別する。
- marker validation、runtime event 処理、スクリーンショット可用性、stop/cleanup 動作、エラー報告の contract と harness coverage を拡張する。

### C# と Godot バインディングの深度

- Godot .NET プロジェクト構造、export メンバー、partial class、signal、NodePath 使用、resource、PackedScene、生成されたプロジェクトメタデータに対する Roslyn ベース検査を深める。
- C# diagnostics、Godot のシーン/リソース参照、エディター上で見えるバインディング、ランタイムエラーの接続を改善する。
- managed C# デバッグ境界を明示する。Godot DAP ツールは Godot debugger ワークフローを支援できるが、managed C# breakpoint には専用 .NET debugger が必要な場合がある。
- 広く浅いコード分析主張よりも、実用的なバインディング、リソース、ビルド診断ワークフローを優先する。

### プロジェクト能力パックとしてのユーザー拡張

- `custom_tools/` の scaffolding、互換性チェック、hot-load 安全性、audit 出力、復旧案内を改善する。
- Agent がプラグインソースを変更せずにプロジェクト専用の `user_*` ツールを作れるよう支援する。
- ユーザーツールの期待 schema、戻り値構造、dry-run パターン、検証期待、障害隔離を文書化する。
- Tools ページと prompt guidance で、ユーザー拡張を一級能力として表示しつつ、組み込みツールとは明確に分離する。

### 実演可能なワークフロー

1.x 系列では、プラグインが実際の Godot .NET 問題を端から端まで解決する再現可能な例を含めるべきです。

- C# export または NodePath バインディング問題を発見し、修正し、再検証する。
- 壊れたシーン/リソース参照を診断して修復する。
- ログ、診断、スクリーンショット、焦点を絞った修正を通じてランタイム障害を追跡する。
- ユーザー拡張を scaffolding、ロード、audit し、安全に使用する。

これらの例では、マーケティング上の広さよりも再現性と証拠を重視します。

### 安定性と公開 schema の規律

- 確立された `system_*` ツール identity を保ち、不要な破壊的変更を避ける。
- 可能な場合はフィールドを削除または改名するのではなく追加する。
- protocol facts、tool schemas、resources、prompts、localized descriptions、docs、changelogs、tests を同期させる。
- 公開動作を変更せざるを得ない場合は明確な migration notes を維持する。

### エディター UX と Agent UX

- Dock を service health、current context、tool discoverability、configuration、update status、actionable diagnostics に集中させる。
- editor UI 作業向けの screenshot-backed UI verification path を改善する。
- 対応 MCP client の設定摩擦を減らし続けつつ、現在の installation/configuration state を見えるようにする。
- ユーザーに見えるプラグイン surface と tool descriptions のローカライズを完全に保つ。

### 診断と証拠品質

- 大規模プロジェクトで完全なファイル列挙を強制せずに project-state summaries を改善する。
- scene dependency、resource reference、binding audit、runtime log、performance snapshots を読みやすい evidence summaries に拡張する。
- 失敗レポートを具体的にする。何が失敗したか、現在の session がその action を実行できない理由、どの setup step が解除条件になるかを説明する。

### テストとリリース信頼性

- headless harness、editor probe、contract、localization、release validation coverage を継続的に拡張する。
- Asset Library install validation をエクスポートされるプラグイン内容と一致させる。
- release notes と changelogs が実装ログではなく、ユーザーに見える能力と重要な内部検証変更を説明するようにする。

## v2.0 開発方向

v2.0 は、1.x のエディター内プラグイン境界を超えるアーキテクチャ拡張を検討する適切な時期です。主な探索領域は、任意の外部または headless companion mode です。

### 任意の外部または Headless Companion

v2.0 companion は、エディター内プラグインでは十分に扱えない実際のワークフローを解決する場合にのみ検討すべきです。考えられる目標は次の通りです。

- エディター UI を開かずに `.tscn`、`.tres`、`.csproj`、solution files、C# sources を検査する。
- ローカル自動化または CI 風の環境で build、restore、static audit、resource reference、binding checks を実行する。
- ライブエディター文脈が不要な場合に、制御された headless または runtime validation mode で Godot を開始する。
- リモートまたは自動化 Agent session 向けに、より低摩擦の経路を提供する。
- エディタープラグイン session が利用可能な場合は、ライブエディター文脈へアップグレードする。

この companion はコアプラグイン体験を弱めてはいけません。エディタープラグインは、ライブエディター状態、選択中ノード、Dock 状態、エディタースクリーンショット、エディターログ、エディター UI control の authoritative source であり続けるべきです。

### v2.0 アーキテクチャ原則

- 1.x エディター内プラグインを安定モードとして保ち、廃止予定の踏み台にしない。
- companion は任意、明示的、capability-gated にする。隠れた必須バックグラウンドプロセスにしてはいけない。
- editor-live capabilities と headless/static capabilities の間に厳格な protocol boundary を定義する。
- 結果形状と制限が明確に文書化されていない限り、モード間で tool semantics を重複させない。
- write operations を可能な範囲で previewable、auditable、reversible にし、ユーザーの信頼を保つ。

### より深い .NET ランタイムとデバッグの物語

Godot と .NET の debugging/tooling 境界が実用的であれば、v2.0 ではより深い .NET-oriented workflows も探索できます。

- managed exception と C# source、scenes、resources のより強い相関。
- より豊かな MSBuild と SDK compatibility diagnostics。
- Godot DAP debugging と managed .NET debugging responsibilities のより良い分離。
- runtime failures から project files、scene bindings、exported members へのより正確な mapping。

## 非目標

- より大きな raw tool count を成功指標として追いかけない。
- 任意のローカルコード実行をデフォルトのユーザー向け能力として公開しない。
- 専用 .NET IDE debugger を曖昧な debugging claims で置き換えない。
- external companion を 1.x エディター内 workflow の必須条件にしない。
- project-specific business tools をプラグインリポジトリに埋め込まない。プロジェクト固有能力は user extensions に属する。
- この roadmap を確約された release schedule として扱わない。