# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] ([2.0.0])

Target version: 2.0.0.

### Added

- Added an isolated Roslyn runtime bundle so Asset Library and prepared addon installs keep C# semantic read/patch workflows without compiling plugin Roslyn or bridge source files inside the host project.
- Added MCP 2025-11-25 Resources, Resource Templates, Prompts, and Tools metadata, including titles, icons, annotations, input schemas, output schemas, and JSON Schema 2020-12 declarations.
- Added Dock Resources and Prompts tabs with protocol catalog counts, ID copy actions, resource previews, prompt argument inputs, generated prompt previews, and bounded icon rendering.
- Added read-only editor log resources at `godot-dotnet-mcp://logs/editor/output` and `godot-dotnet-mcp://logs/editor/errors`.
- Added mouse move and click support to `runtime_step(action=input)` with viewport coordinate fields in the tool schema.
- Added structured User-tool recovery diagnostics with diagnostic codes, recommended actions, and follow-up tool hints.
- Added idle-process and User-tool watch diagnostics so self diagnostics can report frame budgets, scan slices, and watcher progress without forcing heavy runtime queries on every Dock refresh.

### Changed

- Changed the default MCP protocol baseline to `2025-11-25`, including initialize metadata, tool-name validation, schema dialect policy, and explicit optional-capability boundaries.
- Changed the default stdio transport to newline-delimited JSON-RPC, with legacy `Content-Length` framing retained only as an explicit compatibility mode.
- Changed the default HTTP endpoint at `127.0.0.1:3000/mcp` toward MCP Streamable HTTP semantics, including protocol/session headers, JSON and SSE `Accept` negotiation, Origin/CORS checks, GET SSE streams, resumable event history, finite POST SSE responses, heartbeat events, queued server-to-client delivery, and `DELETE /mcp` session termination.
- Changed public discovery to be resource-first and prompt-first: passive help, activity, catalog, editor-log, plugin maintenance, and scene validation discovery now use Resources, Prompts, or canonical action tools instead of legacy public discovery tools.
- Changed `tools/list` to return a flat callable tool list with schema, annotation, and output metadata while tree/group presentation data moves to catalog resources and shared Dock presentation snapshots.
- Changed catalog snapshots, catalog resources, `/api/tools`, Dock model metadata, and Tools tab preview/search/schema-copy paths to use `ToolCatalogManifest` and `ToolCatalogSnapshotService` as the shared catalog fact path.
- Changed Dock Tools rows, action previews, Resources, Prompts, and schema inspection to render shared protocol metadata rather than rebuilding private UI catalog facts.
- Changed the Dock Tools tab to default to the Agent Tools call surface, with separate Internal and Diagnostics views for executor layout and legacy/public-tool diagnostics.
- Changed Dock Resources and Prompts tabs to consume explicit presentation trees, grouping resource URIs, resource templates, workflow prompts, and prompt arguments by shared protocol metadata instead of Dock-side URI or name guesses.
- Changed Dock Resources and Prompts tabs to expose separate Catalog and Diagnostics views so users can switch between readable protocol entries and source/visibility/callability/group metadata.
- Changed editor startup and idle refresh to keep MCP server startup lightweight, defer auto-start outside `_enter_tree`, lazy-load non-active Dock tabs, load the HTTP service bundle and tool runtimes on demand, cache disabled-tool filters until runtime initialization, keep Resources/Prompts protocol list projections loaderless, build Dock catalog projections only for the active tab, and pace User-tool polling and scan slices more conservatively to reduce editor stalls in large projects.
- Changed Dock Tools refresh checks and User-tool runtime definition comparisons to use reusable lightweight signatures instead of repeatedly serializing full presentation trees, metadata maps, or tool definition arrays during idle refresh.
- Changed User-tool polling to skip synchronous scans when runtime loading is disabled and to split large directory walks into budgeted slices so idle refresh stays responsive.
- Changed root domain implementations to split executors for audio, animation, signal, TileMap, UI, filesystem, node, project, resource, scene, group, geometry, material, lighting, navigation, particle, physics, shader, debug, and editor domains, with debug/editor kept as thin compatibility wrappers.
- Changed AtomicBridge, `MCPToolLoader`, stdio routing, plugin lifecycle wiring, reload handling, runtime context wiring, status/query projections, and User-tool maintenance to use dedicated services while preserving their public facades.
- Changed the project and bundled plugin license from MIT to Apache-2.0 for the v2.0 line.

### Fixed

- Hardened HTTP and stdio JSON-RPC envelope handling, malformed framing, duplicate/conflicting HTTP body headers, response-envelope handling, disabled-tool parity, and session validation so transport errors are deterministic across supported MCP transports.
- Fixed Prompt and Resource validation so unknown or incorrectly typed prompt arguments are rejected with allowed-argument metadata and binary `.scn` / `.res` files are not read as text resources.
- Fixed Dock catalog rendering so visible tool families are retained and invalid Resource/Prompt icons are bounded before SVG loading.
- Fixed C# bridge patch/write actions to revalidate project-root and reparse-point boundaries before and after writes.
- Fixed clean Asset Library validation so exported addon installs prove isolated Roslyn runtime availability, exclude plugin bridge/Roslyn source files, and reject dirty addon/archive inputs.
- Fixed PR policy validation so BOM-prefixed titles/headings are recognized and policy/version workflows run on merge queue events.
- Fixed startup stability for upgraded addon copies by preventing split tool executors from registering legacy global `MCP*Tools` class names and by removing Dock script reloads that could emit `Cannot reload script while instances exist`.
- Fixed Dock update sync so branch/tag archive installs mirror the addon directory with the existing safe preserve list, removing stale plugin files such as old root tool monolith scripts instead of only overwriting files.
- Fixed plugin update sync from MCP tools so custom branches with slash-separated names resolve their commit before archive download, retry through commit/ref archive fallbacks, and trigger ref discovery for release-derived targets instead of failing while the Dock path can still recover.
- Fixed Dock status snapshots so lightweight views reuse cached lifecycle context and avoid calling heavy server diagnostics unless the active tab explicitly needs them.

### Documentation

- Updated the v2.0 protocol refactor plan and progress tracker to reflect the completed MCP 2025-11-25 target, Streamable HTTP endpoint shape, newline stdio default, schema metadata policy, optional capability boundaries, public-tool cleanup, and UI metadata adaptation.
- Updated release-facing README and localized entry pages so installation and migration guidance stays focused on plugin-owned install surfaces, Resources, Prompts, Tools, and reproducible validation.
- Added draft v2.0 release-note sources and localized navigation for the protocol refactor line.
- Clarified legacy `system_help` guidance so clients start from MCP Resources for passive context, Prompts for planning, and Tools for actions or computed workflow results.

### Internal

- Added aggregate v2.0 conformance and guardrail coverage for lifecycle, JSON-RPC, Tools, Resources, Prompts, schema metadata, Streamable HTTP, stdio, Dock metadata, public-tool removals, root monolith closure, catalog facts, optional capabilities, release-facing install guidance, changelog section order, and Roslyn runtime bundle shape.
- Added release-policy, PR-policy, and merge-queue validation coverage for v2.0 branch integration, trusted `refactor/v2.0.0` to `dev` version metadata handoff, version metadata changes, BOM-prefixed PR headings, and formal changelog section requirements.
- Hardened tag-triggered plugin verification so manual branch runs cannot skip release preflight, release-note rendering, or release-note artifact validation.
- Added safe-write and clean-install validation scripts for the DotnetBridge write surface, isolated Roslyn runtime bundle, and exported Asset Library addon shape.
- Updated PR policy and version-policy CI to validate pull requests targeting the v1.4 refactor integration branch while keeping release version metadata changes limited to release branches targeting `dev`.
- Updated version-policy CI so v2.0 predevelopment pull requests can validate against trusted v2 policy scripts while release version metadata remains limited to release branches targeting `dev` or `v2.0`.

## [1.3.0] - 2026-06-08

### Added

- Added the v1.3.0 semantic editor automation model: editor UI guidance now directs clients toward semantic workflows first, control-level focus/text/value/popup actions second, and control-local mouse or pointer events only as fallback.
- Added `system_editor_control(action="wait_for_ui")` so clients can wait for real editor controls by existence, visibility, text, and enabled/disabled state before continuing an automation workflow.
- Added `system_editor_control(action="get_popup")` and `system_editor_control(action="capture_popup")` for inspecting and cropping visible floating editor popups or windows by returned popup paths.
- Added click fallback observation evidence for `system_editor_control` and low-level `ui_control` click actions, including dispatched input events, Button-like target state before/after the click, observed control signals, and hints when input is delivered without activation evidence.
- Added `system_editor_evidence`, a high-level visual evidence workflow for editor, control, popup, active-dialog, and automatic surfaces with explicit target, fallback, degradation, visible-popup, and capture-policy metadata.
- Added `system_settings_dialog`, a high-level Project Settings and Editor Settings workflow covering open/status/search/navigation, tab and category focusing, row modeling, row resolution, value read/focus/set/verify, surface capture, close, and trusted `run_task` orchestration.
- Added `system_inspector`, a high-level Inspector property workflow for visible property models, unique property resolution, typed value reads, value focusing, guarded text/number/bool writes, verification, capture, and trusted property tasks on current or prepared targets.
- Added `system_project_lifecycle(action=start|stop)` as the canonical project runtime session lifecycle entry, including marker validation, auto-stop handling, stop control, foreground-window fallback metadata, and runtime capability context.
- Added `system_tool_catalog` so clients can search exposed tools by query, category, or domain and inspect match reasons, actions, parameters, visibility, enabled state, and optional schemas.
- Added `system_tool_activity` query filters and slow/failure diagnostics so clients can inspect running or recent calls by state, tool, and slow-call threshold without fetching unrelated activity records.
- Added User-tool naming diagnostics that expose declared, normalized, and public MCP tool names in User-tool listings, scaffold previews, and compatibility reports.
- Added `system_scene_inspect` as a unified read-only scene inspection entry with `validate`, `analyze`, and `full` actions while preserving the existing scene validation and analysis tools.
- Added `system_plugin_maintenance`, the canonical high-level plugin maintenance entry for status, reload, update-status, update-reference refresh, update-source selection, and update-start workflows.
- Added project configuration inspection for export presets and individual input actions, including redaction for sensitive export option keys and absolute local export paths.
- Added localized MCP resource and resource-template metadata so `resources/list` and `resources/templates/list` follow the active plugin language instead of hard-coded English.
- Added canonical v1.4 MCP resources for guide discovery, project and editor state, activity status/recent reads, and exposed/visible tool catalogs while preserving the existing compatibility resource URIs.
- Added a stable Config client capability matrix for client cards, including support levels, available action metadata, and note keys.
- Added `structuredContent` to every `tools/call` result while preserving the text JSON content for existing clients.

### Changed

- Bumped plugin metadata, protocol facts, .NET bridge metadata, plugin-update contract expectations, localized changelogs, and release-note sources to `1.3.0`.
- Changed `system_settings_dialog(action="capture")` to prefer visible settings popup/window bounds, then dialog control bounds, before falling back to full-editor screenshots, with `capture_backend` and `capture_target_path` evidence metadata.
- Changed project runtime control to use `system_project_lifecycle(action=start|stop)` as the public surface and removed compatibility aliases for the older project run/stop tool names.
- Changed generated User-tool scaffolds to extend the base tool script by resource path, reducing headless catalog-scan dependence on global script-class registration.
- Updated protocol facts to schema version `2026-06-08.27` for structured tool result payloads.

### Fixed

- Hardened editor UI write actions so hidden, disabled, display-only, and low-confidence settings controls are rejected before text/value mutation.
- Hardened project path handling for filesystem/project-file tools and the .NET bridge so remote tool requests cannot escape the Godot project tree through `user://`, absolute paths, URI schemes, or traversal segments.
- Made the release workflows recoverable when an existing release tag already points at the target commit but the GitHub Release still needs to be created, and clarified that the tag-triggered workflow now validates release sources without creating the formal Release.
- Made release verification consistently select the Godot console executable and made rendered commit summaries honor the configured commit limit.
- Capped Settings update source and branch selector popup heights so long discovered ref lists scroll inside the menu instead of covering the editor.
- Fixed Tools tab enabled and total counts so plugin-domain tools are included alongside core and user tool domains.
- Hardened MCP resource diagnostics redaction so mixed-case URL credentials, bearer/API-key variants, sensitive text markers, and nested metadata secrets are masked before outputs are reported.

### Documentation

- Added a localized v1.4.0 protocol refactor plan and linked it from the four localized roadmaps.
- Refreshed README Highlights to align the top-level feature story with the v1.2.0 and v1.3.0 release lines, grouping overlapping entries into consistent editor-native service, semantic automation, evidence, diagnostics, runtime, workflow discovery, and User-tool extension themes.
- Reframed the v1.3.0 release documentation around semantic editor automation and evidence-backed workflows.
- Updated localized overview links and release-note validation maps so English, Simplified Chinese, Japanese, and Korean docs point at the v1.3.0 release-note sources.

### Internal

- Added documentation localization validation coverage for the localized v1.4.0 protocol plan page.
- Added a v1.4.0 contract case manifest and made the plugin harness required-case selection derive from manifest labels.
- Added editor UI and Settings Dialog contract coverage for guarded write refusal paths.
- Added filesystem executor contract coverage for unsafe path rejection across directory, file, JSON, and search entry points.
- Updated editor UI prompt, help, localization, schema facts, tool tree, Tools tab rendering, catalog discovery, and harness contracts for the v1.3.0 semantic-control priority model.
- Extended settings-dialog contracts for `run_task` read/verify/set/set-and-verify flows, ambiguity and write-refusal guards, capture-required write preflight behavior, tab/category/row/value actions, prompt/help guidance, and tool rendering.
- Added Inspector workflow contracts for property model resolution, typed reads, guarded text/number/bool writes, capture fallback behavior, catalog discovery, prompt/help guidance, and tool rendering.
- Added editor evidence surface contracts for exact/fallback/degraded capture behavior, visible-popup metadata, localized tool metadata, prompt/help guidance, and Tools tab rendering.
- Added project lifecycle contracts for explicit lifecycle actions, marker validation, foreground-window fallback behavior, and removed run/stop compatibility names.
- Added tool catalog, tool activity, User-tool naming, scene inspect, plugin maintenance, project configuration, and userdata maintenance contract coverage across loader, router, Tools tab, localization inventory, and protocol facts.
- Added resource contract coverage for canonical guide, state, activity, and tool-catalog resources plus the activity-call resource template, and bumped the tool schema facts to `2026-06-08.26`.
- Extended editor/system control harness coverage for wait conditions, popup capture, hover/leave pointer fallback, click input dispatch, Button-like target observation, activation-signal separation, and input-only Button diagnostics.

## [1.2.0] - 2026-06-06

### Added

- Added output size safeguards for MCP resources and prompts: oversized file-backed resources are rejected before full reads, and oversized prompt text is truncated with `_meta` byte-size details.
- Added top menu, popup selection, hover/leave, main-screen switching, and distraction-free control actions to `system_editor_control`, giving agents more Godot editor UI coverage without OS mouse automation.
- Added `system_tool_activity` and optional `_mcp_context` metadata for MCP tool calls, giving clients a lightweight view of running calls, recent completions, execution order, and self-reported agent coordination context without changing individual tool schemas.
- Added HTTP client session identity and request audit fields to `/health`, including per-connection IDs, request IDs, client summaries, active sessions, and recent disconnected sessions for multi-client diagnostics.
- Added User-tool runtime diagnostics through `plugin_evolution_runtime_diagnostics` and `project_state(include_runtime_health=true)`, including discovery counts, load failures, watcher state, compatibility summary, and recent audit entries.
- Added Korean as a selectable Dock UI language with localized labels for key Home, Tools, Config, Settings, tool preview, category, and plugin-developer surfaces.
- Completed supported-language Dock localization coverage so visible labels, tool metadata, client configuration guidance, prompt guides, and fallback entries no longer rely on English text outside approved product names and technical tokens.
- Added a maintenance window contract to health, plugin reload, and plugin update responses so clients can detect temporary disconnects, reconnect requirements, tool-list refresh requirements, and retry guidance during lifecycle reloads or update sync.
- Localized reconnect guidance emitted by maintenance-window responses across every supported Dock language.
- Added `system_editor_plugin_control` so clients can inspect third-party EditorPlugin project-setting state, editor-session state, visible UI hints, restart/manual-activation guidance, and guarded enable/disable behavior.

### Changed

- Changed plugin update sync to refresh and wait for the Godot editor file-system scan after writing addon files and before scheduling the plugin lifecycle reload.
- Changed the public documentation entry points to live in localized documentation trees with locale-specific directory and file names.
- Changed release rendering so GitHub Release bodies are generated from the English `v1.2.0` release note while the persisted release notes link to English, Simplified Chinese, Japanese, and Korean versions.

### Fixed

- Fixed malformed JSON-RPC parameter handling so HTTP and stdio requests reject non-object top-level `params` consistently with `-32602`, while non-object `tools/call.arguments` remains a tool-level `isError` result.
- Fixed C# empty-method generation so internal edit helpers no longer emit ambiguous fallback bodies when a body is missing.
- Fixed plugin evolution runtime diagnostics so the public `runtime_diagnostics` entry forwards the live user-tool runtime snapshot, keeping the report aligned with project health diagnostics.
- Fixed HTTP transport pipelining so multiple requests already buffered on a keep-alive connection continue draining after an async route completes instead of waiting for more socket bytes.
- Added HTTP reconnect backpressure safeguards for multi-client recovery by accepting several pending connections per frame, rejecting oversized pending request buffers, and closing clients after response write failures.
- Guarded stdio frame processing against async reentry, stop/restart response writes, and one-frame request bursts while preserving tool-loader ticking, improving stability for consecutive stdio requests.
- Fixed lifecycle reload scheduling failures so failed schedule attempts no longer leave the plugin reload state marked as pending.
- Fixed project file reimport handling so `project.godot`, text files, sidecar metadata, and unsupported paths return structured `not_importable_resource` errors instead of being passed to Godot's import pipeline.
- Fixed popup menu automation guardrails so hidden popups, disabled items, separators, submenu rows, duplicate text, and conflicting selectors fail clearly instead of selecting the wrong entry.
- Fixed DAP debugger size and timeout guardrails so abnormal endpoints return clear `dap_limit_exceeded` errors instead of occupying long agent requests.
- Fixed localized documentation facts, links, encoding examples, release-note wording, UI/config references, obsolete draft fragments, and invalid Japanese README screenshot references.

### Documentation

- Added English and Chinese roadmap entry points in `docs/en/ROADMAP.md` and `docs/zh-CN/路线图.md`.
- Added complete English, Simplified Chinese, Japanese, and Korean documentation trees under `docs/`, with each locale using localized directory and file names.
- Moved public docs navigation to the localized documentation trees and removed the old root technical-structure documentation pages from the public docs set.
- Removed redundant root-level localized README and changelog copies after moving those entries into the localized docs tree.
- Finalized persistent `v1.2.0` release notes in English, Simplified Chinese, Japanese, and Korean, including cross-language release-note links below the title and introduction.
- Updated the release runbook and release-note renderer documentation so formal GitHub Releases use the English release note and changelog as the rendered body source.

### Internal

- Extended JSON-RPC request, HTTP server, stdio resources/prompts, and tool router contracts to cover malformed `params` and `tools/call.arguments` boundaries with the `2026-06-05.6` tool schema facts update.
- Extended `mcp_resources_prompts_contracts` to verify resource output limits, prompt truncation metadata, and the `2026-06-05.5` tool schema facts update.
- Extended script edit service harness coverage to require explicit C# `NotImplementedException` guard bodies instead of ambiguous generated fallback bodies.
- Extended User-tool service, runtime health, and project-state harness coverage for runtime diagnostics and failed custom-tool load reporting.
- Extended plugin-evolution harness coverage so public runtime diagnostics keep forwarding the live user-tool runtime snapshot.
- Bumped the tool schema facts version and extended editor UI harness coverage for `list_menus`, `open_menu`, and `select_menu_item`.
- Added tool activity registry coverage to the router, stdio, registry, and tool-loader harness contracts so context stripping, response activity summaries, transport coverage, and the public `system_tool_activity` entry stay verified.
- Updated the Tools page documentation with the `system_tool_activity` tree entry and `_mcp_context` protocol boundary.
- Updated protocol facts with the new tool schema version for the public `system_tool_activity` surface.
- Added a docs i18n validation workflow that checks tree-shape hashes, localized path mappings, Markdown links, draft wording, and cross-locale path leakage.
- Extended docs i18n validation to reject redundant root documentation files that should live in localized docs.
- Extended docs i18n validation to catch wrong-locale README presentation assets and duplicate path keys in file-responsibility tables.
- Switched plugin metadata, protocol facts, .NET bridge metadata, and plugin-update contract fixture expectations to the `1.2.0` development line.
- Updated locale contract coverage so merged fallback translations are validated for languages that keep localized overrides instead of duplicating the full English table.
- Tightened localization CI contracts so every supported locale must expose the same key set and may not silently reuse English strings except for explicit shared product names, paths, identifiers, and technical abbreviations.
- Fixed the refactor guardrail scan so the banned-source identifier audit no longer reports its own validation script as a violation.
- Extended HTTP transport and health harness coverage to verify stable connection IDs, per-request audit IDs, client summaries, and recent disconnected session reporting.
- Guarded headless HTTP server runtime-control setup so standalone harness servers do not pass non-plugin parents into the runtime-control service.
- Extended HTTP transport, health, plugin reload, plugin update, and maintenance-contract harness coverage to cover pipelined requests, localized reconnect hints, stale-schema state precedence, and maintenance-window response fields for reconnect-aware clients.
- Extended plugin harness failure reports with `failureClasses`, `primaryFailureClass`, and `exitCleanupWarningFailure` so Godot exit cleanup warnings are visible without hiding runtime error markers.
- Extended editor-control harness and tool-tree coverage for dynamic main-screen discovery, plugin main-screen activation, and distraction-free actions.
- Updated release workflows to validate all four localized changelogs and release-note sources while rendering GitHub Release bodies from the English source file.

## [1.1.2] - 2026-06-02

### Changed

- Reorganized built-in MCP Prompt Guides into six workflow-oriented entries: `godot.project_orientation`, `godot.content_authoring`, `godot.debug_triage`, `godot.reference_integrity`, `godot.runtime_validation`, and `godot.editor_ui_control`.
- Folded debugger guidance into `godot.debug_triage` so prompt discovery presents one failure-triage workflow instead of a separate debugger-only guide.

### Fixed

- Exposed the reorganized MCP Prompt Guides through `system_help` so agents can discover `prompts/list`, `prompts/get`, and all six built-in prompt IDs from the primary capability guide.
- Localized DAP debugger Tools-page category labels, action names, and parameter descriptions so localized tool previews no longer fall back to raw English schema text.
- Localized Tools-page dynamic action and empty-parameter fallback text while preserving existing schema descriptions when a specific tool key is not defined.
- Fixed clean Asset Library installs so Roslyn bridge implementation sources are excluded from exported plugin downloads instead of being compiled by the host Godot C# project.
- Fixed the French localization file so accented characters, curly apostrophes, non-breaking spaces, and ligatures render correctly instead of mojibake.
- Aligned the reference-integrity Prompt Guide `resource_path` argument with system_resource_reference_audit text-file support by accepting .tscn and .tres paths only.

### Documentation

- Added the `v1.1.2` manual release notes source for the Prompt Guides, localization, and clean Asset Library install maintenance release.
- Updated the addon README copies for Asset Library installs so exported packages link to repository-hosted docs, changelogs, and current dev branch preview images instead of package-local paths that are not exported.
- Updated Prompt Guides documentation to describe the six high-level workflow entries and clarify that DAP debugging is part of `godot.debug_triage` rather than a separate prompt guide.

### Internal

- Added a clean Asset Library install harness build that uses `git archive --worktree-attributes`, removes fixture Roslyn package references, and verifies the exported plugin copy still builds without Roslyn runtime sources or bridge sources.
- Added a real tool-loader localization inventory contract so visible Tools-page tree, action, and parameter fallback coverage is checked across every supported locale.
- Added a locale key parity harness contract to fail CI when any supported language is missing a translation key present in another locale.
- Updated MCP prompt, system help, router, and localization contracts so the prompt surface remains exactly the six high-level workflow guides.

## [1.1.1] - 2026-05-31

### Added

- Expanded `system_dap_debugger` into a complete Debug Adapter Protocol session entry with runtime settings, persistent session IDs, `initialize`, `launch`, `attach`, `configuration_done`, `threads`, `terminate`, and `disconnect` actions while keeping one high-level DAP tool surface.

### Changed

- Strengthened built-in MCP Prompt Guides so `godot.scene_bootstrap`, `godot.debug_triage`, and `godot.binding_fix` return actionable workflow guidance with recommended tool order, validation expectations, and avoid notes instead of thin one-line hints.

### Fixed

- Fixed `system_bindings_audit` freezing the Godot editor on large projects by adding a per-call scene audit cache so each unique scene is loaded and instantiated only once, and by reusing atomic executor instances across consecutive calls so the reference index and Roslyn caches survive between script inspections.
- Fixed atomic executor cache invalidation so read actions such as `get_settings` no longer match write-action substrings, while successful writes clear cached executors after mutation to avoid stale reference and Roslyn data.
- Fixed `system_project_state(summary=true)` and summary-only section reads so they use one bulk lightweight file-count request instead of building full script, scene, and resource path arrays before trimming the response.
- Exposed MCP Prompt Guides through `system_help` so agents can discover `prompts/list`, `prompts/get`, and the three built-in prompt IDs from the primary capability guide.

### Documentation

- Documented that `system_project_state(sections=[...])` takes precedence over `summary=true`, that the `health` section triggers plugin health collection, and that the `files` section is the path-array boundary for large projects.
- Documented Prompt Guides discovery and usage in the tool-system, service-routing, and runtime-service docs, including the separation between MCP prompts and executable tools.

### Internal

- Extended the DAP contract harness with persistent fake-server lifecycle coverage, loopback-only default endpoint safety, sanitized raw-response handling, and published `dap_invalid_session_state` / `dap_invalid_settings` / `dap_limit_exceeded` protocol error identifiers.
- Reused atomic executor instances in `atomic_bridge.call_atomic` / `call_atomic_async` instead of recreating them on every call, preserving `reference_service._reference_index`, `inspect_service._plugin_roslyn_service`, and other instance-level caches across consecutive atomic invocations.
- Added contract coverage proving `system_project_state` compact reads skip full path enumeration, batch project file totals through one count-only request, and still collect file paths on demand for default and `files` section reads.
- Expanded prompt guide, system help, router, and localization harness contracts to prevent regressions in prompt content depth, prompt discoverability, real prompt IDs, and supported-locale Help descriptions.

## [1.1.0] - 2026-05-28

### Added

- Added `system_dap_debugger` and the internal `dap` tool category for Godot Debug Adapter Protocol workflows, including endpoint status, breakpoint set/remove/list, pause/continue/step-over, stack trace, output event collection, Content-Length JSON framing, and published `dap_unavailable` / `dap_response_failed` error identifiers.
- Added first-class MCP Resources and Prompts support: clients can discover project info and diagnostics summary resources, read scene/script/resource files through strict `res://` templates, and retrieve guided `godot.scene_bootstrap`, `godot.debug_triage`, and `godot.binding_fix` prompts.
- Added compact `system_project_state(summary=true)` and section-based `system_project_state(sections=[...])` reads so large projects can inspect key health, file, runtime, capability, and plugin-health sections without returning the full state payload every time.

### Fixed

- Fixed plugin startup and settings persistence paths so runtime state, settings storage, and core services are initialized before load/save or update callbacks access them.
- Fixed plugin harness validation so Godot stdout/stderr runtime and parser error markers such as `SCRIPT ERROR:`, `Invalid call.`, and `Parse Error:` fail the run instead of being hidden behind a successful process exit.

### Documentation

- Added the `v1.1.0` manual release notes source for the debugging, resources, project-state, and startup-validation release, and removed the obsolete `v1.0.1` source note after the release line moved forward.
- Updated README, runtime-service, tool-system, Tools page, testing, and CI documentation for MCP Resources and Prompts, DAP debugger tools, `system_project_state` compact reads, tool catalog resources, and harness validation behavior.
- Completed and corrected localized DAP and system tool descriptions across English, Chinese, German, Spanish, French, Japanese, Portuguese, and Russian locale resources, and documented the emoji release-note template plus Documentation/Internal changelog maintenance rules in the release runbook.

### Internal

- Expanded plugin harness and contract coverage for DAP debugger workflows, MCP Resources and Prompts routing, `system_project_state` compact reads, JSON-RPC resource/prompt methods, tool-loader catalog classification, debug executor compatibility, update fixtures, and plugin entrypoint initialization.
- Added runtime/parser error marker detection to the Godot harness so stdout/stderr diagnostics fail validation even when the Godot process exits successfully.
- Isolated the Tools tab rendering harness case and updated the plugin-side Roslyn harness path so required validation remains stable while the new protocol and tool-surface coverage grows.

## [1.0.1] - 2026-05-26

### Fixed

- Fixed `system_resource_reference_audit` so valid C# `[GlobalClass] Resource` scripts resolved through Roslyn `types[]` metadata are not reported as unresolved, unquoted `ExtResource id=` declarations are recognized before missing-id diagnostics are emitted, and `id=` text inside quoted attribute values is ignored while parsing resource IDs.
- Fixed the Tools tab preview pane so the selected item description fills the lower split area instead of leaving unused bottom space.

### Documentation

- Added the `v1.0.1` manual release notes source for the focused stable-line maintenance update and removed the obsolete `v1.0.0` source note now that plugin metadata targets `1.0.1`.
- Documented the release-note writing style and template so manual notes stay user-facing, follow the `v1.0.0-pre3` narrative structure, and exclude maintenance-only workflow mechanics.
- Cleaned up release changelog entries so the `v1.0.1` section reflects only post-`v1.0.0` changes.

### Internal

- Added a dry-run-first one-click release workflow that validates the `dev` source, version metadata, manual release notes, duplicate tags/releases, build output, and plugin harness before creating a new `v*` GitHub Release, records successful dry runs so matching non-dry-run releases can skip repeated build and harness checks, and keeps tag-triggered releases read-only until the tag is verified against `dev`.
- Simplified the one-click release workflow dispatch UI so the built-in `Use workflow from` branch selector is the only release source selector.
- Switched plugin metadata, protocol facts, and .NET bridge metadata to the `1.0.1` stable maintenance version.
- Changed plugin harness CI to run the Godot console executable for headless validation instead of the GUI executable.
- Added a trusted PR version-policy workflow so non-release branches cannot change plugin public version metadata before release finalization.
- Reduced plugin harness required subset runtime by batching regular headless cases into one stage and Godot run while keeping editor probe cases isolated, with phase and per-case timings reported in the console and GitHub Step Summary.

## [1.0.0] - 2026-05-26

### Changed

- Added Settings update modes for a selected branch (defaulting to `dev`), the latest stable release, the latest release including prereleases, and a selected release/tag through discovered selectors.
- Added safe in-plugin update sync from GitHub archives that extracts only `addons/godot_dotnet_mcp/`, preserves `custom_tools/`, records sync metadata, automatically discovers refs after source selection, keeps latest release targets tied to GitHub Releases, and exposes the selected target through the Sync action.
- Added `system_plugin_update` so MCP clients can inspect the installed plugin version and fingerprint, choose an update source, start async ref discovery or sync, and poll sync/reload progress.
- Settings update sync now schedules a deferred plugin lifecycle reload after successful sync so updated plugin files take effect immediately.
- Removed the redundant current version, plugin path, and commit summary rows from Settings Updates.
- Split persistent Dock controls into a new Settings tab, keeping Home focused on diagnostics, service status, and quick service actions.
- Changed the editor Dock tab and header labels so the tab shows `MCP` while the Dock header and dialogs show `Godot .NET MCP`.

### Fixed

- Fixed Config-page client action buttons so the initial render refreshes the action grid columns after layout width is available, preventing full-width one-button rows until client selection changes.
- Fixed debug `dotnet` default C# project discovery so automatic build/restore selection skips the plugin bridge project instead of treating it as the user project.

### Documentation

- Refreshed the root README product presentation with a new local hero image, synchronized Chinese/English copy, and simplified release badges.
- Updated README release badges so stable and prerelease entry points are clearer from the product pages.
- Added README and release-note guidance for keeping copied source installs current with the latest GitHub code through GUI file updates or MCP project-file tools.
- Added the `v1.0.0` manual release notes source and synchronized the release workflow documentation with the stable release flow.
- Expanded the `v1.0.0` manual release notes into a fuller first-stable-release overview that follows the pre3 narrative style.
- Cleaned up release changelog entries so the `v1.0.0` section reflects post-`v1.0.0-pre3` development without mixing prerelease records.

### Internal

- Added a dry-run-first one-click release workflow that validates the `dev` source, version metadata, manual release notes, duplicate tags/releases, build output, and plugin harness before creating a new `plugin-v*` GitHub Release.
- Updated PR policy validation to read live pull request metadata and added a manual dispatch fallback so edited PR bodies can be revalidated without relying on stale rerun payloads.
- Switched plugin metadata, protocol facts, and .NET bridge metadata to the `1.0.0` stable version.
- Removed the unregistered legacy plugin aggregate tool executor and stale documentation references, then tightened contract coverage around the split plugin tool categories.
- Replaced repository-local project names in public docs, issue templates, and harness fixtures with plugin-scoped wording and neutral sample paths.
- Enforced release note commit summaries to resolve a previous release tag boundary instead of falling back to arbitrary recent commits.

## [1.0.0-pre3] - 2026-05-21

### Added

- Added optional `system_project_run` runtime bridge log marker validation with success/failure marker matching, timeout handling, marker-mode auto-stop, and fake-event contract coverage.
- Added runtime foreground-window capability reporting with `requires_foreground_window` rejection details for unsupported background, minimized, or no-focus project runs.
- Added contract coverage for Tools-page popup coordinate semantics, including the real right-click path and the local/canvas/viewport/screen boundary used by Dock popup placement.

### Fixed

- Fixed plugin self-diagnostics slow-operation reports so they identify the slowest startup/reload phase and include phase timing details in copied diagnostics.
- Fixed Config-page client cards so the visible capability summary distinguishes full one-click config support from CLI auto-add, launch/path-only, and manual-guidance clients.
- Fixed fast .NET build and plugin harness build failures so Godot `.godot/mono/temp` `CS2012` file-lock errors are classified as `transient_file_lock` with actionable recovery guidance.
- Fixed MCP server listen self-diagnostics so occupied ports, access-denied binds, and Windows reserved/excluded TCP ports report distinct reasons and remediation hints.
- Fixed runtime capture so headless or dummy rendering backends return structured skipped results instead of attempting unavailable viewport screenshots.
- Fixed runtime debugger bridge messages so project startup no longer emits Godot `Invalid message received` errors when runtime event, log, or reply messages are sent.
- Fixed `system_project_run` marker validation to read live shared runtime bridge events, avoid filtering out a new run event that repeats pre-run marker text, and drain marker events by event-id cursor so high log volume does not hide a matched marker behind the latest tail window while merged live/fallback event cursors stay ordered across inserted fallback events and full buffer trimming, and full tail batches yield between polls.
- Fixed tool context helpers so editor-interface overrides no longer trigger Godot GDScript VM internal errors during tool execution.
- Fixed `system_project_run` failure diagnostics so inconsistent `Editor interface not available` launch failures report state-probe versus run-invoker details, recovery suggestions, and a CLI fallback when enough paths are known.
- Fixed project file enumeration for `system_project_state` and `system_resource_reference_audit` so empty scans are reported as suspect diagnostics instead of being mistaken for a clean resource audit.
- Fixed TileMap tool script parsing so the TileMap tool domain can instantiate during MCP tool registration.

### Documentation

- Added the `v1.0.0-pre3` manual release notes source used by the two-layer GitHub Release body.
- Removed the obsolete `v1.0.0-pre2` manual release notes source so the release branch only carries the active pre3 source.
- Documented Tools-page popup coordinate boundaries, editor-control responsibilities, runtime foreground limitations, no-focus capability fields, and run-log marker validation.
- Documented the release notes source file, draft preview, and formal release rendering flow.
- Updated CI and testing docs for harness timing summaries, failure diagnostic artifacts, cache behavior, hosted .NET SDK selection, PR validation triggers, and relay-created PR policy behavior.
- Added and refined PR, issue, release, and agent-process documentation for the short-branch contribution flow.
- Simplified the PR template to Summary / Changes / Screenshots / Testing / Related Issues while keeping detailed readiness rules in process documentation.
- Cleaned up unreleased changelog entries so the pre3 section reflects current development history without stale or misplaced records.

### Internal

- Updated CI workflows to use the hosted Windows runner's preinstalled .NET 8 SDK through `global.json` SDK selection.
- Limited CI push triggers to `dev` while preserving pull request, merge queue, and manual validation paths to reduce duplicate same-branch PR runs without changing required check names.
- Added PR-only concurrency cancellation and job timeouts to the fast .NET build and heavy plugin harness workflows while preserving non-PR behavior.
- Added timing output and optional GitHub Step Summary reporting to the heavy plugin harness script so slow cases and phases are easier to identify.
- Preserved and uploaded plugin harness failure diagnostics from CI while keeping successful harness runs cleaned up.
- Added NuGet package caching to build workflows and cached the Godot 4.6 mono extraction used by the plugin harness while preserving existing check names.
- Added lightweight PR policy checks for objective PR titles, summaries, changes, and testing fields.
- Added actions-bot relay PR metadata with base/head SHAs, changed paths, diffstat, actor, run URL, and validation workflow links.
- Added an `actions-bot-relay` workflow so `github-actions[bot]` can submit patch-based short-branch pull requests.
- Split PR target policy and fast .NET build checks from the heavy Godot harness while preserving the `validate-plugin-harness` check name.
- Added a release notes renderer so `next` draft releases and formal tag releases use the same manual-summary plus generated commit-summary body while validating the matching changelog section.
- Updated release automation to run validation and create GitHub releases without producing zip package assets.

## [1.0.0-pre2] - 2026-05-06

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
- Updated README, component, UI, testing, release, persistence, and coding-standard docs to match the v1.0 plugin shape.

### Removed

- Removed the old public `intelligence_*` tool names. Most workflows now use matching `system_*` tools instead, such as `system_project_state`, `system_runtime_diagnose`, `system_scene_analyze`, `system_script_analyze`, and `system_bindings_audit`.
- Removed `intelligence_project_advise` as a separate advice tool. Agents should now inspect state with `system_help`, `system_project_state`, `system_editor_state`, diagnostics, scene/script analysis, and then choose the next tool directly.
- Removed low-level atomic tool domains as the primary public workflow surface. Scene, script, editor, runtime, filesystem, animation, node, resource, debug, and other lower-level building blocks remain internal implementation details behind high-level tools and the Tools page tree.
- Removed the old public Intelligence tool tree and documentation page in favor of the System tool tree and updated System tool documentation.
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
- Added a complete technical documentation system covering plugin structure, UI, components, and appendices.

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

[Unreleased]: https://github.com/LuoxuanLove/godot-dotnet-mcp/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/LuoxuanLove/godot-dotnet-mcp/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/LuoxuanLove/godot-dotnet-mcp/compare/v1.1.2...v1.2.0
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
