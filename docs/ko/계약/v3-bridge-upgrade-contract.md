# v3 Bridge Upgrade Contract

v3 Companion bridge contract는 editor-live state의 authority를 Godot editor plugin에 둡니다. Project session은 editor가 열려 있지 않을 때도 static/headless analysis를 제공할 수 있지만, matching editor bridge가 online state를 보고하기 전에는 selected nodes, Inspector state, Dock state, screenshots, runtime validation을 제공할 수 없습니다.

## Bridge States

- `disabled`: bridge가 명시적으로 unavailable 상태입니다.
- `offline`: project session에 active editor bridge가 없습니다.
- `online`: editor bridge가 같은 project에 연결되어 있고 비어 있지 않은 `editor_session_id`를 보고합니다.
- `version_mismatch`: editor bridge가 있지만 현재 Companion contract version에서는 trust할 수 없습니다.

## Upgrade Rules

- Static/headless sessions는 live editor capabilities 없이 시작합니다.
- Editor-live upgrade에는 `state = online`, matching `project_id`, 비어 있지 않은 `editor_session_id`, compatible `plugin_version`이 필요합니다.
- Offline, disabled, version-mismatch states는 `supports_live_editor_state = false`를 유지해야 합니다.
- Bridge status schema 자체는 process, port, editor launch를 시작하면 안 됩니다.

## Tool Scope

Bridge status를 사용하는 모든 tool call은 `project_id`와 `session_id`를 모두 가져야 합니다. 한 project의 bridge status로 다른 project의 session을 upgrade할 수 없습니다.
