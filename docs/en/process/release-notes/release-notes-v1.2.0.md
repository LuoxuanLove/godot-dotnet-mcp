## 🧩 Godot .NET MCP v1.2.0: Reconnect-Aware Agent Workflows

This release makes the plugin easier to use from several MCP clients or agent sessions at once. It improves maintenance-window reporting, reconnect guidance, transport resilience, health diagnostics, and update-sync refresh behavior so clients can recover cleanly after plugin reloads or update syncs.

### ✨ Highlights

- Added maintenance-window metadata to health, plugin reload, and plugin update responses so clients can detect temporary disconnects, retry timing, and tool-list refresh requirements.
- Added HTTP client session identity and request audit fields to `/health`, including stable connection IDs, request IDs, client summaries, active sessions, and recently disconnected sessions.
- Localized reconnect guidance across the supported Dock languages.
- Added editor plugin session diagnostics so clients can inspect third-party EditorPlugin project settings, live editor state, visible UI hints, and guarded enable/disable behavior.

### 🔧 Fixes

- Refreshed the Godot editor file system after plugin update sync writes files, before scheduling the plugin lifecycle reload.
- Corrected English and Japanese documentation facts around service routing, .NET support, UI flow, and tool-domain indexes.
- Replaced broken or outdated localization draft fragments with current user-facing content.
- Removed invalid screenshot references from the Japanese README.
- Improved HTTP keep-alive handling so already buffered pipelined requests continue draining after async tool execution.
- Added reconnect backpressure safeguards for multi-client recovery, including bounded pending request buffers and connection cleanup after response write failures.
- Hardened stdio burst processing and lifecycle reload scheduling so stale responses and failed reload schedules do not leave misleading pending state.

### ✅ Compatibility and Upgrade Notes

- Existing tool names remain compatible.
- `system_editor_plugin_control` is additive; use dedicated plugin reload/update tools for this plugin instead of generic self-disable flows.
- Update sync now asks the editor to rescan plugin files before the lifecycle reload step.
- Clients should poll health during update syncs or plugin reloads, reconnect if the transport drops, and fetch the tool list again when the maintenance window says schemas may be stale.
- No file layout or tool schema migration is required.
- Existing installs do not need migration.
