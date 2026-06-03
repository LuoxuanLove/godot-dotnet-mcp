# Tools ページの実装

この文書は、`ui/tools_tab.tscn` と `ui/tools_tab.gd` が、どうやって tool tree、search、preview、preset、折りたたみ、shadow を組み立てているかを説明します。

---

## page の役割

Tools page は、今動いている plugin が何を見せるかを編集者が切り替える場所です。高レベルの `system_*` tool と `user_*` tool をまとめて見せ、必要なら category や domain の単位で on/off できます。

---

## scene 構造

`ui/tools_tab.tscn` の主な node は次の通りです。

- `ToolsTab`
- `ToolsTab/VBox`
- `ToolsTab/VBox/Header`
- `ToolsTab/VBox/SearchRow`
- `ToolsTab/VBox/ProfileRow`
- `ToolsTab/VBox/TreeSplit`
- `ToolsTab/VBox/TreeSplit/ToolTree`
- `ToolsTab/VBox/TreeSplit/PreviewPanel`
- `ToolsTab/VBox/TreeSplit/PreviewPanel/PreviewText`
- `ToolsTab/VBox/TreeSplit/PreviewPanel/PreviewMeta`

実際の node 名は実装の都合で少し変わることがありますが、役割はこの形です。

---

## data の流れ

`ToolsTab` の data は次の順で来ます。

1. `plugin.gd` が統一 model を作る
2. `mcp_dock.gd` が `tools_tab.gd.apply_model()` を呼ぶ
3. `tools_tab.gd` が tool tree、search input、preview、profile summary を更新する
4. user が操作すると signal を上げる
5. `plugin.gd` が state や tool access を更新し、もう一度 model を作る

---

## tool tree の見せ方

今の tree は 3 層の思考で読むとわかりやすいです。

- domain
- category
- tool

さらに、tool の中には internal action や atomic helper がぶら下がることがあります。

表示の方針。

- 高レベル tool は、実際に Agent が使う入口として見せる
- atomic helper は、実装の関係がわかるように見せるが、前に出しすぎない
- `User` category は built-in domain と並べるが、見た目で分かるようにする
- enable / disable 数は、実際に今動いている service が返す live data から計算する

---

## search

search は単なる文字列一致ではなく、tree 全体を再構成するための入口です。

- search text は tree の表示 label、tool ID、説明 text を対象にする
- result があるときは、該当 item を開き、path を表示する
- search 中でも profile と折りたたみ状態はできるだけ保つ

---

## preview panel

preview panel には、選んだ item の説明、parameter、system 側の内部つながりを見せます。

今の preview は主に次を示します。

- localized name
- English ID
- summary description
- available action
- parameter summary
- system atomic chain の要点

preview text は独立 collaborator が作るので、UI script は文字列の組み立てに溺れません。

---

## preset と profile

Tools page では、builtin profile と custom profile を切り替えます。

- builtin profile は plugin の既定 tool set を表す
- custom profile はユーザーが保存した tool exposure の組み合わせを表す
- 現在の profile と `disabled_tools` の整合を常に見えるようにする

profile を切り替えたら、tree の enabled state、count、summary がその場で変わります。

---

## 折りたたみ状態

root / domain / category / tool / atomic の折りたたみ状態は、UI の見やすさをかなり左右します。

- `collapsed_system_tools` は system tool の既定折りたたみを決める
- いくつかの root state は settings に保存され、次の起動でも戻る
- 折りたたみは見た目だけでなく、目標の tool を素早く見つけるための手段

---

## 右クリック menu

右クリック menu には、主に次の操作があります。

- localized name を copy する
- English ID を copy する
- schema text を copy する
- user tool を削除する

これらは単なる UI 飾りではなく、Agent が説明や tool 呼び出しの内容を移し替えるときに使えるようにしています。

---

## visual の見た目

Tools page は、深い background と明快な card 境界を両立させます。

- `Tree.panel` 背景を使って、Dock 全体と自然につながるようにする
- `Editor.separator_color` の border で区切りを見やすくする
- preview panel は、空白が広すぎないようにしつつ、内容が詰まりすぎないようにする
- tree の label は scale に応じて読みやすくする

---

## 実装の注意

- page script の中で live tool list を勝手に持たない。必ず model を通す
- visibility、search、preview、selection の責務を混ぜすぎない
- profile や settings の永続化を UI script に直書きしない
- tool label の翻訳を scene file に埋め込まない

---

## 関連文書

- page 全体の関係は [总览.md](总览.md)
- 設定と page の boundary は [../架构/配置与界面.md](../架构/配置与界面.md)
- tool system 全体は [../模块/工具系统.md](../模块/工具系统.md)
