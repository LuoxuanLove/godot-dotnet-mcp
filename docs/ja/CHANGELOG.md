# 変更履歴

このプロジェクトの重要な変更はすべてこのファイルに記録します。

この文書の形式は [Keep a Changelog](https://keepachangelog.com/ja/1.1.0/) に基づき、このプロジェクトは [Semantic Versioning](https://semver.org/lang/ja/spec/v2.0.0.html) に従います。

## [Unreleased] ([1.2.0])

対象バージョン: 1.2.0。

### Documentation

- `docs/en/`、`docs/zh-CN/`、`docs/ko/`、`docs/ja/` 配下に英語、簡体字中国語、韓国語、日本語の完全な文書ツリーを追加し、各言語内リンクが同じ言語の文書だけを参照するようにしました。
- `docs/ja/` 配下に、日本語の README、変更履歴、ロードマップの構造化された入口を追加し、ルート文書から日本語文書への導線を整えました。
- `v1.2.0` の release notes source file を pending-theme テンプレートで初期化し、プラグイン metadata の更新後に古い `v1.1.2` source file を削除しました。

### Internal

- locale ディレクトリの一致、ファイルの一致、同一言語 Markdown リンク、言語間リンク漏れを検証する docs i18n workflow と guardrail coverage を追加しました。
- プラグイン metadata、protocol facts、.NET bridge metadata、プラグイン更新契約 fixture の期待値を `1.2.0` の開発版ラインへ切り替えました。

## [1.1.2] - 2026-06-02

### Changed

- built-in MCP Prompt Guides を、`godot.project_orientation`、`godot.content_authoring`、`godot.debug_triage`、`godot.reference_integrity`、`godot.runtime_validation`、`godot.editor_ui_control` の 6 つのワークフロー入口へ再編しました。
- デバッグガイドを `godot.debug_triage` に集約し、prompt discovery の結果が専用のデバッグガイドではなく、失敗診断ワークフローとして見えるようにしました。

### Fixed

- `system_help` から再編後の MCP Prompt Guides を公開し、Agent が主要な能力説明から `prompts/list`、`prompts/get` と 6 つの built-in prompt ID を見つけられるようにしました。
- DAP debugger の Tools ページにおける分類、アクション名、パラメータ説明のローカライズを補完し、ローカライズされた tool preview が原文英語の schema 文言へ戻らないようにしました。
- Tools ページの動的アクションと空パラメータ fallback 文言のローカライズを補完し、特定の tool key が欠けていても既存の schema 説明を保持するようにしました。
- クリーンな Asset Library インストールを修正し、export された plugin download に Roslyn bridge 実装ソースが含まれないようにして、ホスト側の Godot C# project がそれらを直接コンパイルしないようにしました。
- フランス語ローカライズファイルを修正し、アクセント付き文字、曲線引用符、ノーブレークスペース、合字が正常に表示され、mojibake が出ないようにしました。
- reference-integrity Prompt Guide の `resource_path` パラメータと system_resource_reference_audit の text file 対応範囲を揃え、`.tscn` と `.tres` のみを受け付けるようにしました。

### Documentation

- 今回の Prompt Guides、ローカライズ、クリーンな Asset Library インストールを支える保守バージョン向けに、`v1.1.2` の手書き release notes source file を追加しました。
- plugin package 内の README copy を更新し、Asset Library インストール後の export package が repository hosted の docs、change log、現在の `dev` branch preview image を参照し、package 内の未 export 相対パスを参照しないようにしました。
- Prompt Guides の文書を更新し、6 つの高レベル workflow entry を説明し、DAP debugging が独立した prompt guide ではなく `godot.debug_triage` の診断分岐であることを明示しました。

### Internal

- `git archive --worktree-attributes` を使ったクリーンな Asset Library install harness build を追加し、fixture 内の Roslyn package reference を除去したうえで、Roslyn runtime source と bridge source がなくても export 版 plugin copy が build を完了できることを検証しました。
- 実際の tool-loader に基づく localization inventory contract を追加し、対応言語すべてにおける Tools ページで見える tool tree、action、parameter fallback 文言をカバーしました。
- localization key parity の harness contract を追加し、対応言語のどれか 1 つでも他 locale に存在する translation key を欠いていたら CI を止めるようにしました。
- MCP prompt、system help、router、localization の各 contract を更新し、prompt surface を 6 つの高レベル workflow guide のまま維持しました。

## [1.1.1] - 2026-05-31

### Added

- `system_dap_debugger` を完全な Debug Adapter Protocol session entry に拡張し、runtime settings、persistent session ID、`initialize`、`launch`、`attach`、`configuration_done`、`threads`、`terminate`、`disconnect` を扱えるようにしつつ、単一の高レベル DAP tool surface を維持しました。

### Changed

- built-in MCP Prompt Guides を強化し、`godot.scene_bootstrap`、`godot.debug_triage`、`godot.binding_fix` が、推奨 tool 順、検証要件、避けるべき事項を含む実行可能な workflow 形式で返るようにしました。

### Fixed

- `system_bindings_audit` が大きな project で Godot editor を固める可能性を修正しました。同一呼び出し内で scene audit 結果をキャッシュし、各一意の scene を 1 回だけ load / instantiate するようにし、連続する atomic call で executor を再利用して reference index と Roslyn cache を script check 間で保持できるようにしました。
- atomic executor の cache 無効化判定を修正し、`get_settings` などの read 操作が部分文字列一致だけで write と誤判定されないようにしました。書き込み成功後は cached executor を消去し、reference と Roslyn データが古くなるのを防ぎます。
- `system_project_state(summary=true)` と summary だけを要求する分割呼び出しで、完全な script、scene、resource path array を先に組み立てる問題を修正しました。現在は 1 回の bulk な軽量 file count を使ってから、コンパクトな payload を返します。
- `system_help` で MCP Prompt Guides を公開し、Agent が主要な能力説明から `prompts/list`、`prompts/get`、3 つの built-in prompt ID を見つけられるようにしました。

### Documentation

- `system_project_state(sections=[...])` が `summary=true` より優先されること、`health` section が plugin health 収集を起動すること、そして `files` section が大きな project で完全な path array が必要な境界であることを記録しました。
- tool system、service routing、runtime service の文書に Prompt Guides の発見と利用方法を記録し、MCP prompts と実行可能 tools の境界を説明しました。

### Internal

- 持続的 fake server lifecycle flow、既定で loopback endpoint のみ許可する安全境界、生の response をマスクする処理を含む DAP contract harness を拡張し、`dap_invalid_session_state`、`dap_invalid_settings`、`dap_limit_exceeded` の protocol error identifier を公開しました。
- `atomic_bridge.call_atomic` / `call_atomic_async` で atomic executor instance を再利用し、毎回再構築しないようにして、連続 atomic call で `reference_service._reference_index`、`inspect_service._plugin_roslyn_service`、その他の instance-level cache を保持できるようにしました。
- `system_project_state` のコンパクト読み取りが完全な path enumeration を飛ばし、1 回の count-only request で project file 総数をまとめて数え、既定の完全 payload と `files` section は必要に応じて path を収集することを検証する contract を追加しました。
- prompt guide、system help、router、localization の harness contract を拡張し、prompt content の深さ、prompt の発見性、実在する prompt ID、多言語 Help description の退行を防ぎました。

## [1.1.0] - 2026-05-28

### Added

- `system_dap_debugger` と内部の `dap` tool category を追加し、Godot Debug Adapter Protocol の endpoint status、breakpoint の設定 / 削除 / 一覧、pause / continue / step over、call stack と出力イベントの読み取りを、`Content-Length` JSON frame 形式でサポートし、`dap_unavailable` / `dap_response_failed` の error identifier を公開しました。
- 一等 MCP Resources と Prompts のサポートを追加しました。クライアントは project information と diagnostics summary resources を discover でき、厳格な `res://` template で scene / script / resource file を読み取り、`godot.scene_bootstrap`、`godot.debug_triage`、`godot.binding_fix` の prompt guide を取得できます。
- `system_project_state(summary=true)` の compact summary と `system_project_state(sections=[...])` の分割読み取りを追加し、大きな project でも必要な health、file、runtime、capability bit、plugin health の各 section を必要な分だけ取得できるようにしました。

### Fixed

- plugin 起動と設定永続化の path を修正し、runtime state、settings storage、core service が load / save や update callback にアクセスされる前に初期化を完了するようにしました。
- plugin harness の検証を修正し、Godot stdout / stderr に `SCRIPT ERROR:`、`Invalid call.`、`Parse Error:` などの runtime / parse error marker が出たら、process exit code が成功でも失敗扱いにするようにしました。

### Documentation

- 今回の debug、resources、project state、start validation バージョン向けに `v1.1.0` の手書き release notes source file を追加し、version line の進行後に古い `v1.0.1` source note を削除しました。
- README、architecture、runtime service、tool system、Tools page、tests、CI の文書を更新し、MCP Resources と Prompts、DAP debugger tool、`system_project_state` の compact read、tool catalog resources、harness validation behavior を網羅しました。
- 英語、中国語、ドイツ語、スペイン語、フランス語、日本語、ポルトガル語、ロシア語の locale resources における DAP と system tool の説明を補完・修正し、release Runbook に emoji 付き release note template と Documentation / Internal changelog の維持ルールを記録しました。

### Internal

- plugin harness と contract test coverage を拡張し、DAP debugger flow、MCP Resources と Prompts の routing、`system_project_state` の compact read、JSON-RPC resource/prompt method、tool-loader catalog category、debug executor compatibility、fixture 更新、plugin entry 初期化をカバーしました。
- Godot harness に runtime / parse error marker detection を追加し、stdout / stderr の診断が Godot process の成功終了より優先して失敗扱いになるようにしました。
- Tools page の rendering harness ケースを分離し、plugin 側 Roslyn harness path も更新して、公開 protocol と tool surface の拡張後も required validation を安定させました。

## [1.0.1] - 2026-05-26

### Fixed

- `system_resource_reference_audit` を修正し、Roslyn `types[]` metadata を通じて有効な C# `[GlobalClass] Resource` script を解決できるようにして class unresolved の誤報をなくし、missing id diagnostics を出す前に未引用の `ExtResource id=` declaration を認識し、resource id 解析時には引用付き属性値内の `id=` 文言を無視するようにしました。
- Tools ページの preview panel を修正し、選択項目の説明が下側の split 領域いっぱいに表示され、下部の余白が残らないようにしました。

### Documentation

- 今回の安定ライン保守更新向けに `v1.0.1` の手書き release notes source file を追加し、plugin metadata が `1.0.1` に切り替わったため、古い `v1.0.0` source note を削除しました。
- 手書き release note の文体とテンプレート制約を補足し、記述がユーザー向けで、`v1.0.0-pre3` の叙事構造を踏襲し、メンテナンス工程だけに見える release machine change を除外するようにしました。
- release change log を整理し、`v1.0.1` セクションが `v1.0.0` 以降の変更だけを反映するようにしました。

### Internal

- 既定で dry-run を先に行う one-click release workflow を追加しました。新しい `v*` GitHub Release を作成する前に、`dev` 由来、version metadata、手書き release notes、重複 tag / release、build output、plugin harness を確認し、成功した dry-run を記録して、同じ commit に対する正式 release では重複 build と harness check を省けるようにしました。tag 起点の release は、tag が `dev` から到達可能だと確認できるまで read-only 権限のままにします。
- one-click release workflow の手動起動 UI を簡素化し、release source を GitHub Actions の `Use workflow from` branch selector だけにしました。
- plugin metadata、protocol facts、.NET bridge metadata を `1.0.1` の安定保守版へ切り替えました。
- 未登録の古い plugin aggregation tool executor と古い文書参照を削除し、分割後の plugin tool category の contract coverage を強化しました。
- 公開文書、issue template、harness fixture 内の repository-local project 名を、plugin scope の表現と中立的な sample path に置き換えました。
- release notes の commit summary が、任意の最近 commit list に戻らず、直前の release tag 境界を必ず解釈するようにしました。

## [1.0.0] - 2026-05-26

### Changed

- Dock の永続設定コントロールを新しい Settings ページへ分離し、Home では診断、サービス状態、簡単なサービス操作に集中するようにしました。
- Settings 更新方式を追加し、branch selection（既定 `dev`）、latest stable、latest release（pre-release を含む）、指定 release / tag を選べるようにし、GitHub reference discovery の drop-down を通じて選択できるようにしました。
- plugin 内での安全な更新同期を追加し、GitHub archive から `addons/godot_dotnet_mcp/` だけを抽出し、`custom_tools/` を保持し、sync metadata を書き込み、選択した更新方式のあとに reference を自動検出し、latest release target は GitHub Releases のみから取り、選択 target を sync 操作で処理するようにしました。
- `system_plugin_update` を追加し、MCP クライアントがインストール済み plugin version と fingerprint を読み取り、更新 source を選び、非同期の reference discovery または sync を開始し、sync / reload 進捗を polling できるようにしました。
- Settings 更新の sync 成功後は、更新された plugin file がすぐ反映されるように、遅延 plugin lifecycle reload をスケジュールするようにしました。
- Settings 更新ページから、冗長な current version、plugin path、commit summary の行を削除しました。
- editor Dock のタブと title の文言を調整し、タブは `MCP`、Dock title と popup title は `Godot .NET MCP` と表示するようにしました。

### Fixed

- Config ページの client action button が、初回描画時に layout 幅未確定のため単列の全幅になり、client を切り替えるまで戻らない問題を修正しました。
- debug `dotnet` の既定 C# project discovery を修正し、auto build / restore を選んだときに plugin bridge project を飛ばし、user project として扱わないようにしました。

### Documentation

- ルート README の製品ページの見せ方を更新し、新しいプロモ画像を入れ、中英文案を同期し、release badge を簡素化しました。
- README の release badge を更新し、正式版と pre-release の入口が製品ページでより分かりやすくなるようにしました。
- GUI の file update や MCP project file tool を使って、copy source install した plugin を最新の GitHub code に保つ方法を README と release note に補足しました。
- `v1.0.0` の手書き release notes source file を追加し、正式版 release flow 文書と同期しました。
- `v1.0.0` の手書き release notes を、より完全な初回安定版 overview に拡張し、pre3 の release narration style を継承しました。
- release change log を整理し、`v1.0.0` セクションが `v1.0.0-pre3` 以降の開発内容だけを反映し、すでに公開済みの pre-release 記録を混ぜないようにしました。

### Internal

- 既定で dry-run を先に行う one-click release workflow を追加しました。新しい `plugin-v*` GitHub Release を作成する前に、`dev` 由来、version metadata、手書き release notes、重複 tag / release、build output、plugin harness を確認します。
- PR policy check を更新し、実時点の PR metadata を読むように改めるとともに、手動 dispatch の fallback を追加して、PR 本文を編集したあとでも古い rerun payload に依存せず再検証できるようにしました。
- plugin metadata、protocol facts、.NET bridge metadata を `1.0.0` の正式版へ切り替えました。
- 未登録の古い plugin aggregation tool executor と古い文書参照を削除し、分割後の plugin tool category の contract coverage を強化しました。
- 公開文書、issue template、harness fixture 内の repository-local project 名を、plugin scope の表現と中立的な sample path に置き換えました。
- release notes の commit summary が、任意の最近 commit list に戻らず、直前の release tag 境界を必ず解釈するようにしました。

## [1.0.0-pre3] - 2026-05-21

### Added

- `system_project_run` に optional な runtime bridge log marker check を追加し、success / failure marker の照合、timeout 処理、marker pattern の自動停止をサポートし、fake runtime events で contract coverage を補強しました。
- runtime の foreground window capability report を追加し、background / minimized / no_focus をサポートしない project run に対して `requires_foreground_window` の structured rejection を返すようにしました。
- Tools ページの popup coordinate semantics の contract coverage を追加し、実際の right-click path をカバーしつつ、Dock 浮動 UI の位置決めで使う local / canvas / viewport / screen 座標境界を明示しました。

### Fixed

- plugin の self-diagnostic slow-operation report を修正し、起動 / reload 中で最も遅い stage を示し、copy した diagnostic text に stage time details を含めるようにしました。
- Config ページの client card capability description を修正し、完全な one-click config、CLI one-click add、open / path management のみ、manual onboarding guidance client を明確に区別するようにしました。
- 速い .NET build と plugin harness build failure の診断を修正し、Godot `.godot/mono/temp` artifact による `CS2012` file lock error が出た場合は `transient_file_lock` に分類して、実行可能な復旧案を出すようにしました。
- MCP server の listen failure self-diagnostic を修正し、port 占有、binding denied、Windows の reserved / excluded TCP port を別の原因と処理ヒントで報告するようにしました。
- runtime screenshot を修正し、headless もしくは dummy rendering backend では structured skipped result を返し、使えない viewport screenshot を試さないようにしました。
- runtime debug bridge message format を修正し、project start 時に runtime event / log / reply を送っても Godot output に `Invalid message received` エラーが出ないようにしました。
- `system_project_run` の marker check を修正し、live shared runtime bridge event の読み取り、新しい run event と run 前 marker text が同じ場合のフィルタ、event-id cursor による marker event の消化、高ログ量時に marker が最新 tail window に押し出される問題、live / fallback event cursor の順序、fallback event 挿入と完全 buffer 裁断後の順序維持、tail batch 満杯時の polling yield を正しく扱うようにしました。
- tool context helper を修正し、editor interface override object で tool を実行したときに Godot GDScript VM の internal error が出ないようにしました。
- `system_project_run` の failure diagnostic を修正し、`Editor interface not available` が不整合に出た場合は state probe と run invoker の比較、復旧手順、path 情報が十分なときの CLI fallback を報告するようにしました。
- `system_project_state` と `system_resource_reference_audit` の project file enumeration を修正し、空 scan が suspicious diagnostic を返し、resource audit の clean と誤認しないようにしました。
- TileMap tool script の解析問題を修正し、TileMap tool domain が MCP tool registration 中に正常に instantiate できるようにしました。

### Documentation

- `v1.0.0-pre3` の手書き release notes source file を追加し、2 段構成の GitHub Release 本文生成に使えるようにしました。
- 古い `v1.0.0-pre2` の手書き release notes source file を削除し、release branch には現在の pre3 source のみを残しました。
- Tools ページの popup coordinate boundary、editor control responsibility、runtime foreground limitation、no-focus capability field、run log marker check の説明を補足しました。
- release notes source file、draft preview、formal release rendering の流れに関する文書を補足しました。
- CI と test 文書を更新し、harness の所要時間サマリー、failure diagnostic artifact、cache behavior、managed .NET SDK selection、PR validation trigger、relay が作る PR の policy path をカバーしました。
- PR、Issue、release、Agent の各 flow 文書を新設・整備し、短い branch の貢献フローに合わせました。
- PR template を Summary / Changes / Screenshots / Testing / Related Issues に簡素化し、詳細な ready ルールは flow 文書に残しました。
- 未公開変更記録を整理し、pre3 のセクションが現在の開発履歴を反映し、古い、またはずれた項目を外しました。

### Internal

- CI workflow を調整し、hosted Windows runner に最初から入っている .NET 8 SDK を使い、`global.json` で SDK 選択を制御するようにしました。
- CI の push trigger を `dev` に絞りつつ、PR、merge queue、手動検証の入口は残し、同じ branch の PR 重複実行を減らしながら required check 名は変えないようにしました。
- 速い .NET build と重い plugin harness workflow に、PR 限定の concurrency cancel と job timeout を追加し、非 PR 実行の挙動は変えないようにしました。
- 重い plugin harness script に timing output と任意の GitHub Step Summary 集約を追加し、遅い case や stage の切り分けをしやすくしました。
- CI で plugin harness の failure diagnostic を保持して upload しつつ、成功時の cleanup は維持しました。
- build workflow に NuGet package cache を追加し、plugin harness が使う Godot 4.6 mono 展開ディレクトリも cache しつつ、既存の check 名は変えないようにしました。
- 軽量な PR policy check を追加し、客観的な PR title、summary、change、testing description をカバーしました。
- actions-bot relay が作る PR 本文に、base/head SHA、changed paths、diffstat、triggerer、run URL、validation workflow link metadata を追加しました。
- `actions-bot-relay` workflow を追加し、`github-actions[bot]` が patch ベースの短い branch PR を作れるようにしました。
- PR target branch policy と quick .NET build check を重い Godot harness から分離しつつ、`validate-plugin-harness` の check 名は維持しました。
- release note rendering script を追加し、`next` draft release と正式 tag release が同じ “手書き summary + automatic commit summary” 本文を使い、対応する changelog section を照合するようにしました。
- release automation を更新し、検証して GitHub Release を作成するだけにし、zip asset は出力しないようにしました。

## [1.0.0-pre2] - 2026-05-06

### Added

- `system_editor_control` に対して、control のローカル左クリック / 右クリック、popup metadata、複数座標系の mapping を追加し、Agent が editor UI をより確実に見つけて操作できるようにしました。
- `system_project_state` と `system_editor_state` に、より明確な runtime capability report を追加し、`system_project_run` の failure context を強化して、project start、runtime control、screenshot capability が ready かどうかを判断しやすくしました。
- `system_plugin_reload(action="full_reload_plugin")`、health status check、Tools ページのローカライズ説明を追加し、Agent が plugin を reload して、現在の実行インスタンスがインストール済みファイルと一致しているか確認できるようにしました。
- `/health`、`system_editor_state`、`system_project_state` に editor session ID を追加し、Agent が現在の MCP editor session と他の Godot process を区別しやすくしました。
- `system_resource_reference_audit` を追加し、`system_scene_validate` の UID / fallback path のヒントを強化し、`.tscn` / `.tres` の古い参照や C# custom Resource script の不一致のような、`dotnet build` が通ったあとにも残り得る読み込みリスクを見つけやすくしました。

### Changed

- runtime screenshot と input entry を `system_runtime_step(action=step|capture|input)` にまとめ、公開 runtime automation tool を高レベルの粒度に保ちつつ、tool tree では内部 atomic tool の関連を残すようにしました。

### Fixed

- `custom_tools/` から読み込む User tool が MCP `tools/list` に入らない問題を修正し、client が Tools ページで見えるだけでなく、直接 discover して呼び出せるようにしました。
- Settings で `3001` などの非 default port を明示設定したとき、複数の Godot editor session 間でもその設定を保持し、継承された service environment variable で上書きされないようにしました。
- Config ページの code block copy button を修正し、生成された configuration content にマウスを重ねたときにボタンが表示されたままとなり、周期的な UI refresh で copy button が隠れたり copy 動作が失われたりしないようにしました。
- Tools ページの tool tree language refresh を修正し、Dock 言語を切り替えたあとに tool、内部 node、action label がすぐに更新され、plugin の完全再起動を不要にしました。
- `system_script_patch` / `edit_gd add_variable` の GDScript variable default 値処理を修正し、`default_value` が script file に正しく書き込まれ、`system_script_analyze` で数えて報告できるようにしました。
- 完全 plugin reload 後の tool refresh 問題を修正し、再接続すれば新しい System tool と schema 変更が見えるようにしました。
- ローカル HTTP service の CORS 処理を修正し、既定では任意の origin に cross-origin access を開放せず、設定済み browser client は origin check で通るようにしました。
- resource reference audit を修正し、UID target と fallback path の両方が欠けているときは正しく error を報告し、通常の `.tscn` C# node script を custom Resource script と誤判定しないようにしました。

## [1.0.0-pre1] - 2026-04-28

### Added

- Roslyn ベースの内部 .NET Bridge support library を追加し、初期の C# workflow を C# diagnostics、C# file read / patch modify、`.csproj` read / write、solution / project 情報チェックへ拡張しました。
- `system_help` を追加し、Agent は接続後に plugin capability、推奨の起手手順、screenshot 優先の案内、hidden control enumeration の案内、現在の tool schema 情報を直接確認できます。
- `system_editor_state`、`system_editor_log` を追加し、`system_editor_control` を拡張しました。Agent は editor 状態の確認、Output の読み取りやクリア、Dock と bottom panel のアクティブ化、popup 処理、editor 画面の撮影ができます。
- `system_project_files` と `system_scene_tree` を追加し、それぞれ project file tree 操作と現在の編集 scene tree 操作をカバーしました。
- runtime automation tool を追加し、`system_runtime_control`、`system_runtime_capture`、`system_runtime_input`、`system_runtime_step` で runtime session control、scripted input、screenshot、そして「input -> wait -> screenshot」の閉ループを扱えるようにしました。
- editor screenshot と runtime screenshot に出力 directory 指定を追加し、`system_userdata_maintenance` を追加して、plugin が管理する screenshot / cache file を一覧表示・清掃できるようにしました。既定ではまず preview してから cleanup します。
- `custom_tools/` の user tool 自動検出と hot reload を追加し、`res://addons/godot_dotnet_mcp/custom_tools/` に合法な script を置けば、Godot を再起動せずに plugin が検出し、Tools ページに source、state、pending reload、latest error を表示できるようにしました。
- Config ページに、Claude Code CLI、Codex CLI/Desktop、Gemini CLI、OpenCode Desktop、Windsurf、Cline、Roo Code、Qwen Code、Cherry Studio を含む、より多くの client 向け one-click 設定と install detection を追加しました。
- 統一された tool metadata を追加し、Dock の Tools ページと MCP tool list が同じ name、description、category、action、internal linkage 情報を使うようにしました。
- service version と tool schema 情報の protocol facts file を追加し、Agent と client が version 変更を識別しやすくしました。
- Home、設定ページ、Tools ページ、user tool、自診断、tool 説明などの新しい UI の多言語文言を補完しました。
- Godot headless plugin test framework を追加し、多数の tool executor と runtime service contract test を拡張し、release 前 validation と packaging workflow を補強しました。

### Changed

- Dock の Home、設定ページ、Tools ページを再整理しました。最初のタブは `主页` と呼ばれ、サービス状態、endpoint、完全 reload、plugin self-check をここに集約しています。
- 設定ページをより直感的にし、対応 client はより明確な install、remove、open action を表示し、可能なら具体的な install location も出すようにしました。
- Tools ページを統一された tree 形式にし、高レベルの System tool と User Tool が、共通のローカライズ済み name、description、action node、count statistic、内部実装リンクを持つようにしました。
- 前版の Intelligence にあった project、scene、script、runtime diagnostic、index の workflow を `system_*` tool name に移しました。
- Agent 向けの中核 MCP 公開面は高レベルの `system_*` tool に集約し、低レベル tool は plugin 内部に残しました。
- 以前の Intelligence tool layer を System tool layer に改称・整理し、公開 `system_*` API 名と揃えました。
- 大きな tool executor を、editor、script、animation、runtime、System、User、shared service、各 tool domain service に分割し、保守と test をしやすくしました。
- runtime / service-side を、HTTP、JSON-RPC、stdio、tool routing、reload、自診断、runtime control service に分け、巨大な server file に集中させないようにしました。
