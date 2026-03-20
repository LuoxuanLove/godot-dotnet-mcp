# Changelog

## Unreleased

### Added

- Added the first completed `.NET MCP Bridge` implementation for Godot .NET workflows, including a standalone .NET 8 bridge process, stdio MCP transport, Windows self-contained publish profile, Bridge-first plugin installation, and C# / `.csproj` read-write tooling.
- Added external `custom_tools/` watch coordination so valid user tool scripts dropped into `res://addons/godot_dotnet_mcp/custom_tools/` are discovered without restarting Godot.
- Added user-tool runtime status to the Tools preview, including runtime domain, version, state, pending reload, last error, discovery source, and last refresh reason.

### Changed

- Finished the user-tool hot reload refactor: user tools now reload as per-script runtime slots instead of being mixed into the `system` executor lifecycle.
- Unified user-tool refresh flow under explicit registry refresh, runtime reload, and UI rebuild stages.
- Refined the Tools page so it keeps separate `System` and `User` roots while counting only System high-level tools plus User tools in the visible total.
- Limited externally exposed MCP tools to the 15 `system_*` high-level tools; atomic tools remain internal-only.
- Simplified self-diagnostic presentation by separating the latest operation from the latest incident and adding a clear action for recoverable warnings.

### Fixed

- Fixed user-tool runtime lifecycle so external add / change / delete / restore flows apply cleanly without requiring a Godot restart.
- Fixed user-domain cleanup so removing the final user tool returns the domain to `uninitialized`.

## 0.5.0 - 2026-03-19

### Added

- Added asynchronous GDScript diagnostics: `system_script_analyze(include_diagnostics=true)` now returns script structure immediately and fills `diagnostics` in the background from the saved file on disk. The first call may return `pending`.
- Added runtime health summaries and detailed self-check split:
  - `plugin_runtime_state(action=get_lsp_diagnostics_status)` is the only detailed LSP self-check entry and returns `loader / service / client`
  - `system_project_state(include_runtime_health=true)` returns a lightweight `lsp_diagnostics` health summary
- Added `stdio` transport (`plugin/runtime/mcp_stdio_server.gd`) for standard `Content-Length` framed stdin/stdout MCP communication.
- Expanded structured editing support:
  - `system_scene_patch` adds `rename_node` and `update_property`
  - `system_script_patch` adds `replace_method_body`, `delete_member`, and `rename_member`
  - `system_runtime_diagnose` adds `include_gd_errors`

### Changed

- `system_script_analyze(include_diagnostics=true)` now returns structure data immediately and resolves LSP diagnostics in the background instead of blocking for `publishDiagnostics`.
- `/api/tools`, MCP `tools/list`, and Dock Tools now share the same generated visible tool set; aliases remain callable but are no longer the primary presentation entry.
- The GDScript LSP diagnostics service is owned by `tool_loader` and survives `reload_domain`, `reload_all_domains`, and `soft_reload_plugin` lifecycle handoff to reduce stale-instance drift.
- Runtime docs and external guidance are consolidated around `plugin_runtime_state`, `system_project_state`, and the current routing behavior.

### Fixed

- Fixed the intermittent issue where `soft_reload_plugin` left the HTTP server running while the tool registry was empty. The server/controller and tool loader are now rebuilt together, keeping `/health`, `/api/tools`, and `tools/call` consistent.
- Fixed the persistent state mismatch in the Tools tree when recursively expanding/collapsing. The root node and `atomic` layer now restore correctly under the unified state model and no longer bounce back or require repeated Shift clicks.

## 0.4.0 - 2026-03-17

### Added

- Added the System tool layer, providing 15 high-level tools for project-level reasoning and actions, grouped into four categories:
  - **Project (6)**: `system_project_state`, `system_project_advise`, `system_project_configure`, `system_project_run`, `system_project_stop`, `system_runtime_diagnose`
  - **Scene (3)**: `system_scene_validate`, `system_scene_analyze`, `system_scene_patch`
  - **Script (3)**: `system_bindings_audit`, `system_script_analyze`, `system_script_patch`
  - **Index (3)**: `system_project_index_build`, `system_project_symbol_search`, `system_scene_dependency_graph`
- Added an Atomic Bridge scheduling layer to connect System tools with lower-level atomic tools and support tool-chain composition.
- Added user-defined tool integration: tools placed under `custom_tools/` must use the `user_*` prefix and implement `handles()`, `get_tools()`, and `execute()`.
- Added plugin-directory write protection via `PLUGIN_PROTECTED_PATHS` to prevent unauthorized edits to plugin-owned files.
- Added localized System documentation in 9 languages: de/en/es/fr/ja/pt/ru/zh_cn/zh_tw.

### Changed

- Reworked the `Tools` page tree so top-level System tools are shown directly, each tool can expand to its dependent atomic tool chain, and atomic tools can expand further into action-level nodes.
- Added tree recursive expand/collapse with Shift-click, plus a right-click context menu for copy tool name, schema, and user-tool deletion.
- Overhauled `MCPDebugBuffer` logging: unified source naming, added log levels (`trace/debug/info/warning/error`), and filled in key log points across `tool_loader`, `system`, `atomic_bridge`, and `impl_*`.
- Restructured the repository layout to match the Godot Asset Library convention under `addons/godot_dotnet_mcp/`, and added `.gitattributes` rules for release ZIP contents.

### Removed

- Removed the `Tools` page profile preset management UI. Profile management moved to the `plugin_developer_*` tool group via MCP.
- Temporarily removed the `Tools` page user-tool management UI. User-tool create/delete/restore workflows are now handled by the `plugin_evolution_*` tool group; the UI entry may return in a later version.

### Fixed

- Fixed `Invalid schema` errors caused by missing `items` definitions on array-type MCP tools, affecting tools such as `node_call`, `undo_redo`, `group`, `signal`, and `collision_shape`.
- Fixed permissive acceptance of invalid parameter types in `editor_status` and `node_transform` tools to improve validation robustness.

## 0.3.0 - 2026-03-12

### Added

- Added Godot .NET / C# workflow support: `.csproj` parsing, template-based C# script writes, cross-file script reference indexing, and `dotnet restore/build`-based structural diagnostics.
- Added structured runtime and plugin self-diagnostics, covering runtime error context, compile-error positioning, plugin self-summary, error timelines, and health lookup.
- Added user tool governance features, including script versioning and compatibility checks, audit filtering and conversation labeling, backup-before-delete and recent-restore access.
- Added tool usage statistics for call counts and recent usage timestamps.
- Added tool configuration import/export support, including JSON round-trip for profiles and disabled tools.
- Added a complete technical documentation system covering architecture, UI, modules, and appendices.

### Changed

- Moved Dock plugin self-summary display to the top of the `Server` page to reduce duplicated cross-page information.
- Reworked the `Tools` page tree interaction and information hierarchy, including search, tooltip, status markers, preview cards, drag separators, and profile action routing.
- Added localized resource and documentation support to fill in the keys required by the `v0.3` feature set.
- Raised the public version to `0.3.0` and synchronized plugin metadata with runtime-reported version strings.

### Fixed

- Fixed repeated plugin registration caused by the compatibility executor aggregator, keeping the separate `plugin_runtime`, `plugin_evolution`, and `plugin_developer` entry points.
- Fixed incomplete tool-domain loading caused by inherited-script hot reload issues, restoring stable discovery for the `script` domain and related extension tools.
- Fixed the HTTP transport interruption during plugin enable/disable and runtime reload, changing soft reload into deferred scheduling.

## 0.2.0 - 2026-03-11

### Added

- Added runtime readback for the main project so Godot editor start/stop actions can be traced through `debug_runtime_bridge`.
- Added a more complete plugin governance layer, including runtime control, automation tool management, developer entry points, and usage guides.
- Added plugin permission levels and authorization boundaries to separate stable use, self-automation expansion, and developer debugging.
- Added `User` category management support for discovery, auditing, and cleanup of user-side extension tools.

### Changed

- Reorganized tool groups and plugin categories to reduce the number of actions exposed by a single tool entry and improve discoverability.
- Simplified Dock UI layout and documentation, with special attention to `Server`, `Config`, and `Tools` usability at narrow widths.
- Added more multilingual content for categories, tool descriptions, and hints to reduce untranslated markers in non-English environments.
- Synchronized `README`, the Chinese README, and release docs so first-time access, installation, and configuration flows are aligned.

### Fixed

- Fixed duplicate `plugin` registration from the compatibility executor aggregator, preserving the `plugin_runtime`, `plugin_evolution`, and `plugin_developer` entry points.
- Fixed incomplete tool-domain loading caused by `tool_loader` not fully hot-reloading inherited scripts, restoring stable discovery for the `script` domain and related extension tools.
- Fixed HTTP transport interruption during plugin enable/disable and runtime reload by switching soft reload to deferred scheduling.

### Known Limitations

- The current runtime readback is better suited to structured state and lifecycle information than a full mirror of the native Godot Output / Debugger panels.
- If a same-named `MCPRuntimeBridge` Autoload already exists in the project, the plugin will not forcibly overwrite that setting; runtime readback will appear as not installed.

## 0.1.0 - 2026-03-11

### Added

- First public release.
- Dock-based configuration UI and tool profile management.
- 75 top-level MCP tools.
- Scene, node, resource, script, animation, material, TileMap, navigation, physics, audio, and UI capabilities.
- Godot .NET / C# scene binding analysis and export-member auditing.
- TileSet minimal loop support: `create_empty` and `assign_to_tilemap`.
- Debug event buffer and basic runtime diagnostics readback tools.
- Managed temporary scene directories and scene-save routing.
- Inherited resource type filtering.
- Installation and release packaging docs.

### Known Limitations

- `/root/...` path compatibility has been patched, but the final black-box behavior still depends on plugin reload timing.
