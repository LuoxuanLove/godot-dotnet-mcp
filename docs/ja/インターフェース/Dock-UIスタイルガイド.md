# Dock UI スタイルガイド

このガイドは、Godot .NET MCP のすべての Dock ページに適用する共通の visual / interaction contract です。新規ページや既存ページの大きな変更は、editor limitation を記録して focused test で保護する場合を除き、この規則に従います。

## 基本原則

- Godot native を保ち、editor theme、controls、icons、focus behavior、scale を継承します。
- 静かな interface を作り、current task と primary action を metadata や diagnostics より先に示します。
- progressive disclosure を使い、必須 state は常時表示し、audit と technical details は必要時に展開します。
- 表示を簡潔にしても capability は削らず、移動した secondary information の action と evidence は到達可能にします。
- current、warning、error、selected、disabled state を色だけで表現しません。

## ページ階層

構造は最大 3 段階にします。

| 階層 | 目的 | 規則 |
|---|---|---|
| ページ | 1 つの Dock tab | ページレベルの `ScrollContainer` は最大 1 つとし、専用の `Tree` または preview pane は個別に scroll できます。ページ全体の横 scroll は禁止します。 |
| カード | 1 つの feature area | title は 1 つ、常設 description は最大 1 つ、status region は 1 つにします。 |
| グループ | 関連する fields / actions | labels、controls、feedback を近接させ、一定の spacing を使います。 |

visual order と keyboard focus order は一致させます。よく使う path を先に置き、固定 repository facts、hashes、timestamps、audit trail は secondary details に移します。

list、table、preview、editor の scope を決める selector は、その surface の直前に置きます。selector と対象 content の間に無関係な status、metadata、action を挟みません。

## 間隔とレイアウト単位

すべて current editor scale を乗算する logical pixels です。

| 単位 | 用途 |
|---|---|
| `4` | 密接な icon、badge、helper content |
| `8` | 1 グループ内の controls と buttons |
| `10` | card または inset status panel 内の rhythm |
| `12` | page margin、card の縦 padding、major group separation |
| `14` | card の横 padding |
| `16` | wide layout の大きな region 間だけ |

通常の margin と container separation は `.tscn` scene に置きます。script は scale または breakpoint のために変更できますが、runtime reason なしで静的 spacing を重複指定しません。

## テーマ、文字、アイコン

- editor の `PanelContainer`、`Tree`、`LineEdit`、`TextEdit` などの style box を複製して調整し、独立 palette は作りません。
- accent、separator、error、font、disabled font colors は `Editor` theme から取得します。
- 慣れた editor action には `EditorIcons` を使います。icon-only action には tooltip と理解可能な action name が必要です。
- primary content は通常の Label color を使います。description、hint、metadata は段階的に弱めますが、light / dark theme の両方で読める必要があります。
- 全ページ共通の semantic variation を導入しない限り、section title は editor default size を使います。

## フォームとコントロール幅

- regular width では label / field を 2 列の `GridContainer` に配置します。
- label の regular minimum は約 `112` logical pixels とし、field は expand させ、最長の localized item に幅を依存させません。
- ultra-narrow では 1 列へ切り替え、固定 field width を解除し、各 label を control の直前に置きます。
- 長い path、ref、ID を省略する場合、tooltip または details で完全な値を確認できるようにします。
- disabled control だけで理由を説明せず、近くの status text または localized tooltip に理由を示します。

## ステータス、ヘルプ、詳細

- 1 card に常設 description は最大 1 つ、live status region は 1 つとします。controls、status、empty state だけで workflow が分かる場合は description を省き、同じ guidance を重複させません。
- idle guidance は next action を示します。loading は active scope を示し、競合 action を lock し、測定可能なら progress を表示します。
- success text は短くします。error text は原因と、既知なら recovery action を保持します。
- trigger source、HTTP status、refresh time などの operational metadata は、説明対象と compact な contextual row を共有できます。長い値は ellipsis で制約し、完全な値を tooltip で提供します。
- persistent status region は primary result と必要な actionable diagnostics を担当します。同じ error や summary を別の領域で繰り返しません。
- routine audit information は secondary な visual hierarchy を保ち、page を押し広げたり Dock から overflow したりしてはいけません。

## リスト、テーブル、空状態

- item の選択や確認に必要な列だけを表示し、narrow layout の secondary date / identifier は tooltip または details に移します。
- current row は色に加えて text marker または icon を持ち、同じ item を再選択する action は表示しません。
- row selection が target を決める場合は row 全体を highlight します。selection は非破壊 target の更新だけを行い、mutation、navigation、switch は独立した row action で実行します。
- row action は tertiary です。editor icon があっても localized label または tooltip を付けます。
- 空の `Tree` は隠し、not loaded、loading、no results、error を区別する簡潔な empty state を表示します。
- model refresh 中も selection、scroll position、deferred row action を安定させます。

## アクションの意味

| 優先度 | 代表用途 | 配置 |
|---|---|---|
| Primary | start、apply、one-click update | card ごとに 1 つ、visual / focus order の最後 |
| Secondary | refresh、copy、retry、open details | 影響する scope の近く |
| Tertiary | row switch、compact utility | 対象 row または context menu |
| Destructive | remove、clear、delete | 通常 action と分離し、損失の可能性があれば確認 |

hover-only control は既に発見可能な action の shortcut にできますが、重要操作の唯一の入口にはしません。

cached state の復元は network access や operational mutation を発生させません。passive selector は選択値を永続化し、依存する一時的な local state をリセットできますが、discovery、update、switch、navigation、その他の external operation を開始してはいけません。これらの operation には専用の明示的な user action が必要で、repeated retry は既知の cooldown / rate-limit state に従います。

## Dock のレスポンシブ動作

| content width | 期待する layout |
|---|---|
| `>= 560` | 2 列 form、compact summary row、横並び action buttons |
| `360-559` | 読める範囲で 2 列 form、metadata 削減、compact table |
| `< 360` | 1 列 form / actions、固定 field width なし、低い table height |

container と size flags を使い、Dock minimum width でも利用可能にします。固定 column total が available width を超えないようにします。editor scale `1`、`1.5`、`2` と、short / tall Dock を検証します。

## アクセシビリティ

- すべての重要 action を keyboard focus 可能にし、focus order を visual order に合わせます。
- semantic state は色と text、icon、shape、position のいずれかを組み合わせます。
- icon-only control には tooltip と意味のある accessible text を付けます。
- page の理解や操作に hover、animation、pointer coordinate を必須にしません。
- target size と contrast は Godot editor theme に合わせます。

## ローカライズ

- visible label、tooltip、empty state、loading state、error message はすべて plugin locale files で localized にします。
- translated sentence を fragment から組み立てず、明示的 format parameter を持つ complete message を使います。
- prose は smart word wrap を使い、German / Russian expansion と Chinese / Japanese / Korean layout を検証します。
- button の action verb は残し、action を切る前に supporting copy を短くします。

## シーンとスクリプトの責務

- `.tscn` scene は semantic control names、通常 containers、base margins、separation、initial visibility を担当します。
- tab script は model rendering、signals、editor scale、breakpoints、dynamic rows、tooltips、editor 由来 theme values を担当します。
- model projection service は state normalization と presentation-ready facts を担当し、view script は translated text matching で behavior を推測しません。
- Dock root code は cross-tab coordination のみを担当し、page-specific layout は page scene / controller に置きます。

## 受け入れマトリクス

重要な UI 変更は automated contract または editor evidence で次を確認します。

| 観点 | 最低ケース |
|---|---|
| Width | `280`、`360`、`560`、wide layout |
| Scale | scale-sensitive geometry 変更時に `1`、`1.5`、`2` |
| Language | English、長い Latin/Cyrillic locale、CJK locale |
| State | idle、loading、success、error、rate limited、empty |
| Theme / input | light / dark compatible values と keyboard focus |

重なりなし、ページ全体の横 scroll なし、色だけの state なし、action の localization 完備、変更対象の surface が従来公開していたすべての feature への到達維持を受け入れ条件とします。
