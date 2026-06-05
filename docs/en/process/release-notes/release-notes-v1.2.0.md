## 🧩 Godot .NET MCP v1.2.0: Reconnect-Aware Agent Workflows

This release makes the plugin easier to use from several MCP clients or agent sessions at once. It improves maintenance-window reporting, reconnect guidance, transport resilience, health diagnostics, update-sync refresh behavior, and editor UI control so clients can recover cleanly after plugin reloads or update syncs while still navigating registered editor main screens and visible Godot UI flows.

### ✨ Highlights

- Added top menu control to `system_editor_control`, so agents can list editor menus, open a `MenuButton`, and choose a `PopupMenu` item by text or index before continuing with popup inspection or text/button actions.
- Added maintenance-window metadata to health, plugin reload, and plugin update responses so clients can detect temporary disconnects, retry timing, and tool-list refresh requirements.
- Added HTTP client session identity and request audit fields to `/health`, including stable connection IDs, request IDs, client summaries, active sessions, and recently disconnected sessions.
- Added User-tool runtime diagnostics so clients can inspect discovered custom tools, load failures, watcher state, compatibility, and recent audit entries from the plugin evolution tools or project health.
- Added `system_tool_activity` so clients can inspect currently running tool calls, recent completions, execution order, and optional self-reported Agent context across HTTP and stdio tool calls when coordinating parallel work.
- Localized reconnect guidance across the supported Dock languages.
- Added output size safeguards for MCP resources and prompt guides so very large file-backed resources are rejected before expensive reads, while long generated prompt text reports byte-size truncation metadata.
- Added editor UI hover and leave actions so agents can validate tooltips, hover-only menus, and floating panels through Godot input events instead of OS mouse automation.
- Added editor plugin session diagnostics so clients can inspect third-party EditorPlugin project settings, live editor state, visible UI hints, and guarded enable/disable behavior.
- Added editor-control actions for listing main-screen buttons, switching to registered plugin main screens, and controlling distraction-free mode.
- Added a high-level editor-control action for selecting visible `PopupMenu` items by index, id, or exact text.
- Added docs i18n validation coverage for locale file parity, Markdown link targets, and cross-locale link leakage.
- Kept the localized docs trees aligned with the current plugin UI, tool, and binding references.

### 🔧 Fixes

- Refreshed the Godot editor file system after plugin update sync writes files, before scheduling the plugin lifecycle reload.
- Made generated C# empty-method guard bodies explicit by using `NotImplementedException` instead of ambiguous fallback bodies.
- Kept the public plugin-evolution runtime diagnostics path aligned with project health by forwarding the live user-tool runtime snapshot into the summary.
- Guarded popup menu automation against hidden popups, disabled items, separators, submenu rows, conflicting selectors, and ambiguous duplicate text matches.
- Corrected English and Japanese documentation facts around service routing, .NET support, UI flow, and tool-domain indexes.
- Replaced broken or outdated localization draft fragments with current user-facing content.
- Removed invalid screenshot references from the Japanese README.
- Improved HTTP keep-alive handling so already buffered pipelined requests continue draining after async tool execution.
- Added reconnect backpressure safeguards for multi-client recovery, including bounded pending request buffers and connection cleanup after response write failures.
- Hardened stdio burst processing and lifecycle reload scheduling so stale responses and failed reload schedules do not leave misleading pending state.

### ✅ Compatibility and Upgrade Notes

- Existing tool names remain compatible.
- The tool schema version changed because editor control gained new UI actions and user-tool runtime diagnostics now expose live runtime-state fields.
- `system_editor_plugin_control` is additive; use dedicated plugin reload/update tools for this plugin instead of generic self-disable flows.
- Update sync now asks the editor to rescan plugin files before the lifecycle reload step.
- Clients should poll health during update syncs or plugin reloads, reconnect if the transport drops, and fetch the tool list again when the maintenance window says schemas may be stale.
- User-tool diagnostics are read-only and do not change existing custom-tool loading behavior.
- No file layout or tool schema migration is required.
- Clients may pass a short `_mcp_context` object with tool calls for coordination; it is treated as self-reported context, not as authentication.
- Switching to a plugin main screen requires that the current editor session has already registered that screen.
- Popup menu selection adds a tool-schema action; reconnect and fetch tools again after upgrading.
- No file layout migration is required.
- Existing installs do not need migration.
- Clients that read resources should handle standard JSON-RPC errors for oversized file-backed resources and inspect `_meta` on prompt responses when prompt text is shortened.
