# v2 Bridge Upgrade Contract

The v2 Companion bridge contract keeps editor-live state authoritative inside the Godot editor plugin. A project session can remain useful for static/headless analysis without an open editor, but it cannot expose selected nodes, Inspector state, Dock state, screenshots, or runtime validation until a matching editor bridge reports an online state.

## Bridge States

- `disabled`: the bridge is intentionally unavailable.
- `offline`: the project session has no active editor bridge.
- `online`: the editor bridge is connected for the same project and reports a non-empty `editor_session_id`.
- `version_mismatch`: the editor bridge is present but cannot be trusted for the current Companion contract version.

## Upgrade Rules

- Static/headless sessions start without live editor capabilities.
- Editor-live upgrade requires `state = online`, matching `project_id`, a non-empty `editor_session_id`, and a compatible `plugin_version`.
- Offline, disabled, or version-mismatch states must keep `supports_live_editor_state = false`.
- The bridge status schema must not start processes, open ports, or launch the editor by itself.

## Tool Scope

Every tool call that consumes bridge status must carry both `project_id` and `session_id`. A bridge status from one project cannot upgrade a session from another project.
