# Change Log

All important changes to this project are recorded here.

This file follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] ([1.2.0])

Target version: 1.2.0.

### Documentation

- Added complete English, Simplified Chinese, Korean, and Japanese documentation trees under `docs/en/`, `docs/zh-CN/`, `docs/ko/`, and `docs/ja/` with same-locale internal links.
- Added structured English README, changelog, and roadmap entry points under `docs/en/`, and added locale-switch links in the root docs.
- Initialized the `v1.2.0` release-note source file with the pending-theme template, and removed the obsolete `v1.1.2` source file after the plugin metadata moved forward.

### Internal

- Added a docs i18n validation workflow and guardrail coverage for locale directory parity, file parity, same-locale Markdown links, and cross-locale link leakage.
- Switched the plugin metadata, protocol facts file, .NET bridge metadata, and plugin update contract fixture expectations to the `1.2.0` development line.

## [1.1.2] - 2026-06-02

### Changed

- Reorganized the builtin MCP Prompt Guides into six workflow-oriented entry points: `godot.project_orientation`, `godot.content_authoring`, `godot.debug_triage`, `godot.reference_integrity`, `godot.runtime_validation`, and `godot.editor_ui_control`.
- Folded debugger guidance into `godot.debug_triage`, so prompt discovery now reads as a failure-diagnosis workflow instead of a standalone debugger-only guide.

### Fixed

- Exposed the reorganized MCP Prompt Guides through `system_help`, so the Agent can discover `prompts/list`, `prompts/get`, and all six builtin prompt IDs from the main capability summary.
- Completed DAP debugger localization in the Tools page so the localized preview no longer falls back to the raw English schema text.
- Filled the localized text for dynamic tool actions and empty-parameter fallbacks in the Tools page, while keeping the existing schema description when a specific key is missing.
- Fixed clean Asset Library installs so exported plugin downloads no longer include the Roslyn bridge implementation source code.
- Fixed the French localization files so accented characters, curly quotes, non-breaking spaces, and ligatures display correctly.
- Aligned the `resource_path` parameter in the reference-integrity Prompt Guide with the text-file support scope of `system_resource_reference_audit`, which only accepts `.tscn` and `.tres` paths.

### Documentation

- Added the `v1.1.2` handwritten release-note source file for the Prompt Guides, localization, and clean Asset Library maintenance release.
- Updated the plugin README copy so the Asset Library export points at the repository-hosted docs, changelog, and current `dev` branch preview images instead of non-exported relative paths.
- Updated the Prompt Guides docs to describe the six high-level workflow entry points and to make it clear that DAP debugging belongs to `godot.debug_triage`.

### Internal

- Added a clean Asset Library install harness build that uses `git archive --worktree-attributes`, removes the fixture’s Roslyn package references, and verifies that the exported plugin copy still builds without the Roslyn runtime and bridge source files.
- Added a localization inventory contract based on the real tool loader, covering visible tool tree text, actions, and parameter fallbacks across all supported languages.
- Added a localization key parity harness contract so CI blocks whenever one supported language is missing a translation key that exists in another locale.
- Updated the MCP prompt, system help, router, and localization contracts so the prompt surface stays at six high-level workflow guides.

## [1.1.1] - 2026-05-31

### Added

- Extended `system_dap_debugger` into a full Debug Adapter Protocol session entry point with runtime settings, persistent session IDs, `initialize`, `launch`, `attach`, `configuration_done`, `threads`, `terminate`, and `disconnect`, while keeping the surface as a single high-level DAP tool.

### Changed

- Strengthened the builtin MCP Prompt Guides: `godot.scene_bootstrap`, `godot.debug_triage`, and `godot.binding_fix` now return actionable workflow text with recommended tool order, validation requirements, and things to avoid.

### Fixed

- Fixed a Godot editor freeze that could happen in `system_bindings_audit` on large projects by caching the scene audit result during a single call.
- Fixed atomic executor cache invalidation so read operations such as `get_settings` are no longer mistaken for writes, and successful writes clear the cached executor so reference and Roslyn data do not go stale.
- Fixed `system_project_state(summary=true)` so it no longer builds the full script, scene, and resource path arrays before returning the compact payload.
- Exposed the MCP Prompt Guides through `system_help`, so the Agent can discover `prompts/list`, `prompts/get`, and the three builtin prompt IDs.

### Documentation

- Recorded that `system_project_state(sections=[...])` takes priority over `summary=true`, that the `health` section triggers plugin health collection, and that `files` is the section used when full path arrays are truly needed.
- Documented prompt discovery and usage in the tool system, service routing, and runtime service docs, and clarified the boundary between MCP prompts and executable tools.

### Internal

- Extended the DAP contract harness to cover persistent fake-server lifecycle flows, the loopback-only endpoint safety boundary, and raw-response sanitization, and exposed the protocol error codes `dap_invalid_session_state`, `dap_invalid_settings`, and `dap_limit_exceeded`.
- Reused the atomic executor instance inside `atomic_bridge.call_atomic` and `call_atomic_async` instead of recreating it each time, so consecutive atomic calls keep their cached state.
- Added contract coverage to verify that compact `system_project_state` reads skip full path enumeration and count files in one pass.
- Expanded the prompt guide, system help, router, and localization harness contracts so prompt depth, discoverability, real prompt IDs, and multilingual Help text do not regress.

## [1.1.0] - 2026-05-28

### Added

- Added `system_dap_debugger` and the internal `dap` category for endpoint state, breakpoint management, pause / continue / step, stack traces, and output events.
- Added first-class MCP Resources and Prompts support for project information, diagnostics summaries, strict `res://` scene/script/resource templates, and workflow prompts.
- Added `system_project_state(summary=true)` and `system_project_state(sections=[...])` so large projects can read only the health, file, runtime, capability, and plugin-health slices they need.

### Fixed

- Fixed plugin startup and settings persistence order so runtime state and services are initialized before load/save callbacks run.
- Fixed harness validation so runtime or parse error markers in Godot stdout and stderr fail the run, even if the process exit code is successful.

### Documentation

- Added the `v1.1.0` handwritten release-note source file and removed the outdated `v1.0.1` source note after the version line moved forward.
- Updated the README, architecture, runtime services, tool system, Tools tab, test, and CI docs to cover MCP Resources and Prompts, the DAP debugger tool, compact `system_project_state` reads, tool catalog resources, and harness validation behavior.
- Filled in the English, Chinese, German, Spanish, French, Japanese, Portuguese, and Russian locale resources for the DAP and system tool descriptions, and recorded the emoji release-note template plus the Documentation and Internal changelog rules in the release runbook.

### Internal

- Expanded the plugin harness and contract-test coverage to include DAP flows, MCP Resources and Prompts routing, compact project-state reads, JSON-RPC resource and prompt methods, tool-loader catalog grouping, debug executor compatibility, fixture updates, and plugin entry-point initialization.
- Added runtime and parse error marker detection to the Godot harness so stdout and stderr diagnostics can fail validation even when the Godot process exits successfully.
- Isolated the Tools tab rendering harness case and updated the Roslyn harness path so the expanded protocol and tool-surface coverage stays stable.

## [1.0.1] - 2026-05-26

### Fixed

- Fixed `system_resource_reference_audit` so valid C# `[GlobalClass] Resource` scripts are resolved through Roslyn `types[]` metadata instead of being reported as unresolved.
- Fixed the Tools tab preview panel so the selected item description now fills the lower split area.

### Documentation

- Added the `v1.0.1` handwritten release-note source file and removed the outdated `v1.0.0` source note after the version line moved to `1.0.1`.
- Expanded the release-note style and template rules so handwritten notes stay user-facing and keep the `v1.0.0-pre3` narrative structure.
- Cleaned up the release changelog so the `v1.0.1` section only covers changes after `v1.0.0`.

### Internal

- Added the default-dry-run one-click release workflow.
- Simplified the release workflow manual trigger UI to use the GitHub Actions `Use workflow from` branch selector.
- Switched the plugin metadata, protocol facts file, and .NET bridge metadata to the `1.0.1` maintenance version.
- Switched the plugin harness CI to the Godot console executable.
- Added a trusted PR version policy workflow that blocks non-release branches from changing public version metadata too early.
- Shortened the required plugin harness subset by batching regular headless cases into one Godot run and keeping editor probe cases isolated.

## [1.0.0] - 2026-05-26

### Changed

- Split the Dock persistence controls into a new Settings page so the Home page could focus on diagnostics, service state, and quick actions.
- Added Settings update sources for branch selection, latest stable, latest release including prerelease, and a specific release or tag.
- Added in-plugin safe update sync that extracts only `addons/godot_dotnet_mcp/` from the GitHub archive, keeps `custom_tools/`, writes sync metadata, and processes the selected target after auto-discovery.
- Added `system_plugin_update` so MCP clients can read the installed plugin version and fingerprint, choose an update source, start ref discovery or sync, and poll sync and reload progress.
- Settings update sync now schedules a delayed plugin lifecycle reload so the updated files take effect immediately.
- Removed redundant current-version, plugin-path, and commit-summary rows from the Settings update page.
- Adjusted the editor Dock tabs and title text so the tab label is `MCP` and the Dock title and popup title are `Godot .NET MCP`.

### Fixed

- Fixed the Config page client-action buttons so they no longer collapse into a single row on the first render before layout width is ready.
- Fixed debug `dotnet` default C# project discovery so plugin bridge projects are skipped during auto build and restore selection.

### Documentation

- Updated the root README product page, added new local promo images, aligned the Chinese and English copy, and simplified the release badges.
- Updated the README release badges so the stable and pre-release entries are clearer on the product page.
- Added the `v1.0.0` handwritten release-note source file and synchronized the formal release-flow docs.
- Expanded the `v1.0.0` handwritten release note into a fuller first-stable-version overview and kept the pre3 narrative style.
- Cleaned the release changelog so the `v1.0.0` section only reflects work after `v1.0.0-pre3`.

### Internal

- Added the default-dry-run one-click release workflow.
- Updated PR policy validation to read live PR metadata and added a manual-dispatch fallback so edited PR bodies can be revalidated.
- Switched the plugin metadata, protocol facts file, and .NET bridge metadata to `1.0.0`.
- Removed the old unregistered plugin aggregator executor and stale doc references, and strengthened coverage for the split plugin tool categories.
- Replaced repository-local project names in public docs, issue templates, and harness fixtures with neutral plugin-scoped wording.
- Made release-note commit summary parsing respect the previous release tag boundary instead of falling back to arbitrary recent commits.

## [1.0.0-pre3] - 2026-05-21

### Added

- Added optional runtime-bridge log marker checks to `system_project_run`, including success and failure markers, timeout handling, automatic stop in marker mode, and fake runtime event coverage.
- Added runtime foreground-window capability reporting and structured rejection when background, minimized, or no-focus project runs are not supported.
- Added popup coordinate contract coverage for the Tools page, covering the real right-click path and the local, canvas, viewport, and screen coordinate boundaries used by Dock floating UI.

### Fixed

- Fixed slow-operation self-diagnostic reporting so the slowest startup or reload phase is now listed in the copied diagnostic text.
- Fixed the Config page client card capability descriptions so the page clearly distinguishes full one-click configuration, CLI one-click add, open-only or path-management clients, and manual onboarding clients.
- Fixed the fast .NET build and plugin harness diagnostics so `CS2012` file-lock failures from Godot `.godot/mono/temp` output are classified as `transient_file_lock`.
- Fixed MCP server listen failure diagnostics so port-in-use, bind-denied, and Windows reserved or excluded port cases now report different reasons and guidance.
- Fixed runtime screenshots so headless or dummy render backends now return a structured skipped result instead of trying an unavailable viewport capture.
- Fixed the runtime-debug bridge message format so sending runtime event, log, and reply messages during project startup no longer produces `Invalid message received` errors in the Godot output.
- Fixed `system_project_run` marker validation so live shared runtime bridge events are read correctly, marker events are consumed by event-id cursor, and fallback and live event cursors stay ordered.
- Fixed helper functions used by tools context so editor interface overrides no longer trigger Godot GDScript VM internal errors.
- Fixed `system_project_run` failure diagnostics so inconsistent `Editor interface not available` states now include a state-probe vs run-invoker comparison, a recovery hint, and a CLI fallback when path information is available.
- Fixed project file enumeration in `system_project_state` and `system_resource_reference_audit` so empty scans now return suspicious diagnostics instead of being treated as clean.
- Fixed the TileMap tool script parsing issue so the TileMap domain can instantiate normally during tool registration.

### Documentation

- Added the `v1.0.0-pre3` handwritten release-note source file for the two-layer GitHub Release body.
- Removed the outdated `v1.0.0-pre2` handwritten release-note source file.
- Documented the Tools page popup coordinate boundaries, editor control responsibilities, runtime foreground restrictions, no-focus capability fields, and runtime log marker validation.
- Documented the release-note source file, draft preview, and final release rendering flow.
- Updated the CI and test docs to cover harness timing summaries, failure diagnostics artifacts, cache behavior, hosted .NET SDK selection, PR validation triggers, and the relay-created PR policy path.
- Added and improved the PR, issue, release, and Agent workflow docs so they match the short-branch contribution flow.
- Simplified the PR template to Summary, Changes, Screenshots, Testing, and Related Issues, while keeping the detailed readiness rules in the workflow docs.
- Cleaned the unreleased changelog so the pre3 section reflects the current development history.

### Internal

- Updated the CI workflows to use the hosted Windows runner’s .NET 8 SDK and constrain SDK selection through `global.json`.
- Narrowed CI push triggers to `dev` while keeping PR, merge queue, and manual validation entry points, which reduces duplicate runs for the same branch without changing required check names.
- Added PR-only concurrency cancellation and job timeouts for the fast .NET build and heavy plugin harness workflows, while keeping non-PR behavior unchanged.
- Added timing output and optional GitHub Step Summary reporting for the heavy plugin harness script.
- Kept and upload plugin harness failure diagnostics in CI while still cleaning up successful runs.
- Added NuGet caching to the build workflow and cached the Godot 4.6 mono extraction directory for the harness, while keeping the existing check names unchanged.
- Added a light PR policy check for objective PR title, summary, change, and test-description fields.
- Added base and head SHA, changed paths, diffstat, trigger source, run URL, and validation workflow metadata to PR bodies created by `actions-bot-relay`.
- Added the `actions-bot-relay` workflow so `github-actions[bot]` can submit patch-based short-branch PRs.
- Split the PR target-branch policy and fast .NET build checks out of the heavy Godot harness while keeping the `validate-plugin-harness` check name.
- Added the release-note render script so the `next` draft release and the final tag release both use the same handwritten-summary plus automatic commit-summary body, while validating the matching changelog section.
- Updated the release automation so it validates and creates the GitHub Release without producing zip package assets.

## [1.0.0-pre2] - 2026-05-06

### Added

- Added local left and right clicks, popup metadata, and multi-coordinate mapping to `system_editor_control` so the Agent can interact with editor UI more reliably.
- `system_project_state` and `system_editor_state` now report clearer runtime capabilities, and `system_project_run` failure context is richer so the Agent can tell whether project startup, runtime control, or screenshot capability is ready.
- Added `system_plugin_reload(action="full_reload_plugin")`, health checks, and localized Tools page guidance so the Agent can reload the plugin and confirm that the running instance matches the installed files.
- Added editor session identity into `/health`, `system_editor_state`, and `system_project_state` so the Agent can distinguish the current MCP-hosting editor session from other Godot processes.
- Added `system_resource_reference_audit` and improved `system_scene_validate` UID and fallback-path guidance so stale `.tscn` and `.tres` references can be found even when `dotnet build` passes.

### Changed

- Moved runtime screenshot and input into `system_runtime_step(action=step|capture|input)` so the public runtime automation surface stays high-level while the tool tree still shows the internal atomic relationships.

### Fixed

- Fixed User tools loaded from `custom_tools/` not appearing in MCP `tools/list`.
- Fixed the MCP server port used by the plugin display and usage flow so explicit non-default ports stay in place even across multiple editor sessions.
- Fixed the Config page copy button so it stays visible on hover and periodic refreshes no longer hide it.
- Fixed tool-tree language refresh on the Tools page so changing Dock language refreshes tool names, internal nodes, and action labels immediately.
- Fixed `system_script_patch` and `edit_gd add_variable` default-value handling so `default_value` now writes correctly and is reported by `system_script_analyze`.
- Fixed full plugin reload tool refresh so newly connected sessions can see new System tools and schema changes.
- Fixed local HTTP CORS handling so arbitrary origins are no longer allowed by default while already configured browser clients still pass origin validation.
- Fixed resource reference auditing so missing UID and fallback-path targets are reported correctly and ordinary `.tscn` C# node scripts are not misclassified as custom resources.

## [1.0.0-pre1] - 2026-04-28

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
- Removed the old public Intelligence tool tree and documentation page in favor of the System tool tree and `docs/妯″潡/System宸ュ叿灞?md`.
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

## [0.5.0] - 2026-03-19

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

## [0.4.0] - 2026-03-17

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

## [0.3.0] - 2026-03-12

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

## [0.2.0] - 2026-03-11

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

## [0.1.0] - 2026-03-11

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

[Unreleased]: https://github.com/LuoxuanLove/godot-dotnet-mcp/compare/v1.1.2...HEAD
[1.2.0]: https://github.com/LuoxuanLove/godot-dotnet-mcp/compare/v1.1.2...HEAD
[1.1.2]: https://github.com/LuoxuanLove/godot-dotnet-mcp/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/LuoxuanLove/godot-dotnet-mcp/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/LuoxuanLove/godot-dotnet-mcp/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/LuoxuanLove/godot-dotnet-mcp/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/LuoxuanLove/godot-dotnet-mcp/compare/v1.0.0-pre3...v1.0.0
[1.0.0-pre3]: https://github.com/LuoxuanLove/godot-dotnet-mcp/compare/v1.0.0-pre2...v1.0.0-pre3
[1.0.0-pre2]: https://github.com/LuoxuanLove/godot-dotnet-mcp/compare/v1.0.0-pre1...v1.0.0-pre2
[1.0.0-pre1]: https://github.com/LuoxuanLove/godot-dotnet-mcp/compare/v0.5.0...v1.0.0-pre1
[0.5.0]: https://github.com/LuoxuanLove/godot-dotnet-mcp/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/LuoxuanLove/godot-dotnet-mcp/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/LuoxuanLove/godot-dotnet-mcp/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/LuoxuanLove/godot-dotnet-mcp/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/LuoxuanLove/godot-dotnet-mcp/releases/tag/v0.1.0
