# Changelog

## Unreleased

Target version: `1.0.0-pre3`.

### Fixed

- Fixed runtime debugger bridge messages so project startup no longer emits Godot `Invalid message received` errors when runtime event, log, or reply messages are sent.
- Fixed tool context helpers so editor-interface overrides no longer trigger Godot GDScript VM internal errors during tool execution.

## 1.0.0-pre2 - 2026-05-06

### Added

- Added `system_editor_control` support for local left/right control clicks, popup metadata, and coordinate mapping across controls, screenshots, screens, and OS windows for more reliable editor UI automation.
- Added clearer runtime capability reporting to `system_project_state` and `system_editor_state`, with richer `system_project_run` failure context for project launch, runtime control, and capture readiness.
- Added `system_plugin_reload(action="full_reload_plugin")` with health checks and localized Tools-page descriptions so agents can reload the plugin and verify that the running instance matches the installed files.
- Added editor session identity details to `/health`, `system_editor_state`, and `system_project_state` so agents can distinguish the active MCP editor session from other Godot processes.
- Added `system_resource_reference_audit` and richer `system_scene_validate` UID/fallback-path hints for stale `.tscn` / `.tres` references and C# custom Resource script mismatches that can remain even when `dotnet build` succeeds.

### Changed

- Consolidated runtime screenshot and input entry points into `system_runtime_step(action=step|capture|input)` so the public runtime automation surface stays high-level while retaining internal atomic tools in the Tools tree.

### Fixed

- Fixed custom User tools loaded from `custom_tools/` so they are exposed through MCP `tools/list` and callable by clients instead of only appearing in the Tools page state.
- Fixed the MCP server port shown and used by the plugin so an explicitly configured non-default Settings port, such as `3001`, stays stable across multiple Godot editor sessions instead of being overridden by inherited server environment variables.
- Fixed the Config page code block copy button so it remains visible while hovering over generated configuration content and reliably forwards copy actions without being hidden by periodic UI refreshes.
- Fixed the Tools page tree so switching the Dock language refreshes tool, atomic tool, and action labels without requiring a full plugin restart.
- Fixed `system_script_patch` / `edit_gd add_variable` so GDScript variable `default_value` expressions are saved correctly and reported by `system_script_analyze`.
- Fixed full plugin reload so newly added System tools and schema changes are available after reconnecting.
- Fixed local HTTP CORS handling so browser-based clients no longer receive wildcard cross-origin access by default, while configured browser clients can still pass origin validation.
- Fixed resource reference auditing so it reports missing UID targets with missing fallback paths and avoids treating ordinary `.tscn` C# node scripts as custom Resource scripts.

## 1.0.0-pre1 - 2026-04-28

### Added

- Added an internal .NET bridge library backed by Roslyn, expanding the older C# workflow into C# diagnostics, C# file reading and patching, `.csproj` reading and writing, and solution/project inspection.
- Added `system_help` so agents can discover the plugin's capabilities, recommended first steps, screenshot guidance, hidden-control discovery, and current tool schema information after connecting.
- Added `system_editor_state`, `system_editor_log`, and expanded `system_editor_control` so agents can inspect the editor, read or clear Output logs, activate docks and bottom panels, work with popups, and capture editor UI state.
- Added `system_project_files` and `system_scene_tree` for direct project FileSystem workflows and currently edited scene-tree workflows.
- Added runtime automation tools: `system_runtime_control`, `system_runtime_capture`, `system_runtime_input`, and `system_runtime_step` for commandable runtime sessions, scripted input, screenshots, and input-wait-capture loops.
- Added configurable output directories for editor and runtime captures, plus `system_userdata_maintenance` for listing and cleaning managed screenshot/cache files with dry-run preview by default.
- Added automatic discovery and hot reload for user tools placed in `res://addons/godot_dotnet_mcp/custom_tools/`, including status, source, pending reload, and latest error details in the Tools page.
- Added one-click setup and clearer install detection for more clients, including Claude Code CLI, Codex CLI/Desktop, Gemini CLI, OpenCode Desktop, Windsurf, Cline, Roo Code, Qwen Code, and Cherry Studio.
- Added shared tool metadata so the Dock Tools page and MCP tool listings use the same names, descriptions, categories, actions, and internal links.
- Added protocol fact files for server version and tool schema information, making version changes easier for agents and clients to detect.
- Added broad localization coverage for the new Home, Config, Tools, user-tool, diagnostics, and tool-description UI text.
- Added a Godot headless plugin test harness, expanded contract tests for tool executors and runtime services, and validation/publish workflows for release checks.

### Changed

- Reworked the Dock around clearer Home, Config, and Tools pages. The first tab is now `Home`, with service status, endpoint, full reload, and plugin diagnostics in one place.
- Redesigned the Config page so supported clients show clearer install/remove/open actions and exact install locations when available.
- Reworked the Tools page to show high-level System tools and User tools in a consistent tree, with localized descriptions, action nodes, counts, and internal implementation links.
- Migrated the previous Intelligence project, scene, script, runtime-diagnose, and index workflows to `system_*` tool names.
- Focused the core Agent-facing MCP surface on high-level `system_*` tools while keeping lower-level building blocks internal to the plugin.
- Renamed and reorganized the former Intelligence tool layer into the System tool layer, matching the public `system_*` API names.
- Split large tool executors into smaller editor, script, animation, runtime, system, user, shared, and domain-specific services so the plugin is easier to maintain and test.
- Rebuilt the runtime/server internals around smaller HTTP, JSON-RPC, stdio, tool-routing, reload, diagnostic, and runtime-control services instead of a monolithic server file.
- Expanded stdio routing so high-level `system_*` tools follow the same public tool path as HTTP clients.
- Reworked plugin startup, reload, dock coordination, runtime state, diagnostics, and settings projection so the plugin can recover and report its state more clearly after reloads.
- Reworked user-tool loading into explicit discovery, catalog refresh, runtime reload, and UI refresh steps.
- Consolidated public logging levels to `debug`, `info`, `warning`, and `error`.
- Rebuilt the changelog from tag-to-tag git comparisons so each version now records only the changes that actually shipped relative to the previous release.
- Updated README and architecture, module, UI, testing, release, persistence, and coding-standard docs to match the v1.0 plugin shape.

### Removed

- Removed the old public `intelligence_*` tool names. Most workflows now use matching `system_*` tools instead, such as `system_project_state`, `system_runtime_diagnose`, `system_scene_analyze`, `system_script_analyze`, and `system_bindings_audit`.
- Removed `intelligence_project_advise` as a separate advice tool. Agents should now inspect state with `system_help`, `system_project_state`, `system_editor_state`, diagnostics, scene/script analysis, and then choose the next tool directly.
- Removed low-level atomic tool domains as the primary public workflow surface. Scene, script, editor, runtime, filesystem, animation, node, resource, debug, and other lower-level building blocks remain internal implementation details behind high-level tools and the Tools page tree.
- Removed the old public Intelligence tool tree and documentation page in favor of the System tool tree and `docs/模块/System工具层.md`.
- Removed the old permission-level UI and Home-tab advanced permission settings; users no longer need to manually choose a capability level.
- Removed `trace` as a distinct public log level. Legacy `trace` input is still accepted as a compatibility alias for `debug`.
- Removed the old root-level `user://` cache layout as the active storage model. Plugin-managed captures, runtime data, logs, profiles, and config exchange files now live under `user://godot_dotnet_mcp/`, with explicit maintenance tools for legacy cleanup.
- Removed stale script-tool and Intelligence dispatcher files from the shipped plugin layout after splitting their behavior into System and script-service implementations.

### Fixed

- Fixed high-level `system_*` tool routing across HTTP and stdio so the same public tools are available through both transports.
- Fixed plugin reload and dock rebuild flows so reload actions preserve settings, refresh the dock model, and surface diagnostics more reliably.
- Fixed runtime service shutdown and port reuse behavior to reduce stuck-listener failures after reloads.
- Fixed `system_project_run` timeout handling so long-running scenes can be stopped automatically when requested.
- Fixed GDScript diagnostics access and script-edit helper paths after the tool-layer reorganization.
- Fixed user-tool add, edit, delete, restore, and final-tool cleanup flows so the Tools page returns to the correct empty state without restarting Godot.
- Fixed tool metadata, category, manifest, and presentation mismatches so the Tools page and MCP tool list stay aligned.
- Fixed several headless validation and contract-test gaps so CI covers more of the plugin runtime, UI presentation, and tool executor behavior.

## 0.5.0 - 2026-03-19

### Added

- Added asynchronous GDScript diagnostics: `intelligence_script_analyze(include_diagnostics=true)` now returns script structure immediately and fills `diagnostics` in the background from the saved file on disk. The first call may return `pending`.
- Added runtime health summaries and detailed self-check split:
  - `plugin_runtime_state(action=get_lsp_diagnostics_status)` is the only detailed LSP self-check entry and returns `loader / service / client`
  - `intelligence_project_state(include_runtime_health=true)` returns a lightweight `lsp_diagnostics` health summary
- Added `stdio` transport (`plugin/runtime/mcp_stdio_server.gd`) for standard `Content-Length` framed stdin/stdout MCP communication.
- Expanded structured editing support:
  - `intelligence_scene_patch` adds `rename_node` and `update_property`
  - `intelligence_script_patch` adds `replace_method_body`, `delete_member`, and `rename_member`
  - `intelligence_runtime_diagnose` adds `include_gd_errors`

### Changed

- `intelligence_script_analyze(include_diagnostics=true)` now returns structure data immediately and resolves LSP diagnostics in the background instead of blocking for `publishDiagnostics`.
- `/api/tools`, MCP `tools/list`, and Dock Tools now share the same generated visible tool set; aliases remain callable but are no longer the primary presentation entry.
- The GDScript LSP diagnostics service is owned by `tool_loader` and survives `reload_domain`, `reload_all_domains`, and `soft_reload_plugin` lifecycle handoff to reduce stale-instance drift.
- Runtime docs and external guidance are consolidated around `plugin_runtime_state`, `intelligence_project_state`, and the current routing behavior.

### Fixed

- Fixed the intermittent issue where `soft_reload_plugin` left the HTTP server running while the tool registry was empty. The server/controller and tool loader are now rebuilt together, keeping `/health`, `/api/tools`, and `tools/call` consistent.
- Fixed the persistent state mismatch in the Tools tree when recursively expanding/collapsing. The root node and `atomic` layer now restore correctly under the unified state model and no longer bounce back or require repeated Shift clicks.

## 0.4.0 - 2026-03-17

### Added

- Added the Intelligence tool layer, providing 15 high-level tools for project-level reasoning and actions, grouped into four categories:
  - **Project (6)**: `intelligence_project_state`, `intelligence_project_advise`, `intelligence_project_configure`, `intelligence_project_run`, `intelligence_project_stop`, `intelligence_runtime_diagnose`
  - **Scene (3)**: `intelligence_scene_validate`, `intelligence_scene_analyze`, `intelligence_scene_patch`
  - **Script (3)**: `intelligence_bindings_audit`, `intelligence_script_analyze`, `intelligence_script_patch`
  - **Index (3)**: `intelligence_project_index_build`, `intelligence_project_symbol_search`, `intelligence_scene_dependency_graph`
- Added an Atomic Bridge scheduling layer to connect Intelligence tools with lower-level atomic tools and support tool-chain composition.
- Added user-defined tool integration: tools placed under `custom_tools/` must use the `user_*` prefix and implement `handles()`, `get_tools()`, and `execute()`.
- Added plugin-directory write protection via `PLUGIN_PROTECTED_PATHS` to prevent unauthorized edits to plugin-owned files.
- Added localized Intelligence documentation in 9 languages: de/en/es/fr/ja/pt/ru/zh_cn/zh_tw.

### Changed

- Reworked the `Tools` page tree so top-level Intelligence tools are shown directly, each tool can expand to its dependent atomic tool chain, and atomic tools can expand further into action-level nodes.
- Added tree recursive expand/collapse with Shift-click, plus a right-click context menu for copy tool name, schema, and user-tool deletion.
- Overhauled `MCPDebugBuffer` logging: unified source naming, added log levels (`trace/debug/info/warning/error`), and filled in key log points across `tool_loader`, `intelligence`, `atomic_bridge`, and `impl_*`.
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

- Fixed `Tree blocked` / empty-instance errors on the `Tools` page during collapse and rebuild flows, reducing Dock interruptions and cascading UI errors.

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
