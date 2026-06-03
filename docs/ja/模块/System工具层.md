# System Tool Layer

この文書は、system layer の公開 built-in tool、Atomic Bridge、impl file の分割、User tool extension を説明します。

---

## system layer の役割

System layer は、Agent が最初に触れる高レベルの公開面です。ここでは、project、scene、script、runtime、diagnostic を 1 つの workflow として扱います。

---

## 公開される主な tool

- `system_help`
- `system_project_state`
- `system_project_run`
- `system_runtime_step`
- `system_editor_state`
- `system_editor_control`
- `system_editor_log`
- `system_scene_tree`
- `system_scene_validate`
- `system_resource_reference_audit`
- `system_plugin_reload`

これらは、内部の細かい operation をそのまま expose するのではなく、意味のある作業単位として見せることを意図しています。

---

## Atomic Bridge

Atomic Bridge は、内部の原子的 helper を高レベル tool の裏で使うための橋です。

- Agent には高レベル tool を見せる
- 実装側では atomic helper を組み合わせる
- ただし、atomic helper をそのまま public surface にしすぎない

Atomic Bridge の考え方は、「内部では細かくても、外には意味のある単位で出す」です。

---

## impl file の分割

system layer は、内部実装を複数の `impl` file に分けて保ちます。

- public 入口は読みやすく保つ
- 実装 detail は適切に切り分ける
- ただし、意味の薄い wrapper を増やしすぎない

---

## User tool extension との関係

system layer は user tool を邪魔しません。

- built-in tool は plugin が提供する
- `user_*` tool は project 側が足す
- Tools page では、両方を同じ tree で見られるが、由来は分かるようにする

---

## 実装の考え方

- system tool は、Agent が「何をしたいか」で選べるようにする
- 内部の algorithm ではなく、作業 flow を表現する
- tool 数を増やすより、既存 tool の意味をはっきりさせる

---

## 関連文書

- tool の全体像は [工具系统.md](工具系统.md)
- tool の directory 索引は [工具域索引.md](工具域索引.md)
- user tool の詳細は [用户扩展.md](用户扩展.md)
