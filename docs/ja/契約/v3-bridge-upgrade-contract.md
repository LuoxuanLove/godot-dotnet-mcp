# v3 Bridge Upgrade Contract

v3 Companion bridge contract では、editor-live state の authority を Godot editor plugin に保ちます。Project session は editor が開いていない時も static/headless analysis を提供できますが、matching editor bridge が online state を報告するまでは selected nodes、Inspector state、Dock state、screenshots、runtime validation を公開できません。

## Bridge States

- `disabled`: bridge は明示的に unavailable です。
- `offline`: project session に active editor bridge がありません。
- `online`: editor bridge が同じ project に接続され、空でない `editor_session_id` を報告しています。
- `version_mismatch`: editor bridge は存在しますが、現在の Companion contract version では trust できません。

## Upgrade Rules

- Static/headless sessions は live editor capabilities なしで開始します。
- Editor-live upgrade には `state = online`、matching `project_id`、空でない `editor_session_id`、compatible `plugin_version` が必要です。
- Offline、disabled、version-mismatch states は `supports_live_editor_state = false` を維持する必要があります。
- Bridge status schema それ自体は process、port、editor launch を開始してはいけません。

## Tool Scope

Bridge status を消費するすべての tool call は `project_id` と `session_id` の両方を持つ必要があります。ある project の bridge status で別 project の session を upgrade することはできません。
