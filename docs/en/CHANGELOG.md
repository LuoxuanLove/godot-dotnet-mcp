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

- Added a Roslyn-based internal .NET bridge library so the early C# workflow could expand to C# diagnostics, C# file read and patch edits, `.csproj` read and write, and solution or project info checks.
- Added `system_help` so the Agent can immediately learn the plugin capabilities, recommended starting steps, screenshot-first guidance, hidden control enumeration guidance, and current tool schema information.
- Added `system_editor_state` and `system_editor_log`, and expanded `system_editor_control` so the Agent can inspect editor state, read or clear Output, activate the Dock and bottom panel, handle popups, and capture the editor UI.
