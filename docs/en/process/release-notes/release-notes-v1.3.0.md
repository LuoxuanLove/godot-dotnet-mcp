## 🧭 Godot .NET MCP v1.3.0: Semantic Editor Automation and Evidence

Godot .NET MCP v1.3.0 turns the plugin from a broad collection of editor-facing tools into a more coherent automation layer: agents can locate the relevant editor surface, use semantic workflows before raw controls, read or change values through guarded high-level tasks, verify the result, and attach evidence that explains what was actually observed.

<p align="center"><a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.3.0/docs/en/process/release-notes/release-notes-v1.3.0.md">English</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.3.0/docs/zh-CN/流程/发布说明/发布说明-v1.3.0.md">简体中文</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.3.0/docs/ja/プロセス/リリースノート/リリースノート-v1.3.0.md">日本語</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.3.0/docs/ko/프로세스/릴리스-노트/릴리스-노트-v1.3.0.md">한국어</a></p>

### 🧭 Semantic Editor Control

The core design direction for v1.3.0 is explicit: semantic workflows first, control-level operations second, and mouse or coordinate fallback last. This keeps agents from treating screen clicks as the default path when the editor already exposes a clearer operation such as settings workflows, Inspector property tasks, menu selection, tab navigation, tree selection, popup buttons, focus, text, or numeric value edits.

`system_editor_control(action="wait_for_ui")` gives clients a bounded way to wait for real editor state before continuing. It can poll for control existence, visibility, text matching, and enabled or disabled state, then return the matched UI evidence or a timeout payload that explains what was last observed.

When a workflow truly needs pointer behavior, click fallback is now easier to diagnose. `click_control` and `right_click_control` results include input-dispatch metadata and target observations for Button-like controls, including before/after state, signal counts, and hints when mouse input was delivered but no activation evidence was observed. This makes click fallback auditable without making it the recommended path.

### ⚙️ Trusted Settings Workflows

`system_settings_dialog` is the largest workflow consolidation in this release. It covers Project Settings and Editor Settings as task surfaces rather than as loose coordinates or raw control lists. Clients can open a settings surface, wait for it to appear, search, list tabs, activate tabs, list categories, focus a unique category, list conservative row models, resolve a unique row, read values, focus value editors, write supported values, verify expected values, capture evidence, and close the surface.

The workflow deliberately separates read-only discovery from mutation. Text, number, and bool rows can be written only when the row is uniquely resolved, visible, confident enough, and backed by the right value editor. Enum values are readable and verifiable, while more complex editor types remain unsupported instead of being guessed.

`run_task` composes the full safe path: open and narrow the surface, resolve a unique row, read the before value, optionally write a supported value, verify the result, and attach capture evidence. When a selector is ambiguous, a hidden-control write is requested, confidence is too low, or required pre-write evidence cannot be produced, the task refuses to mutate before interaction.

### 🧩 Inspector Property Automation

`system_inspector` brings the same philosophy to the Inspector. Agents can list visible property models, resolve a unique property, read a typed value, focus the value editor, set supported text, number, and bool values, verify the result, capture property evidence, or run the full trusted property task against the current edited object or a prepared node/resource target.

The Inspector workflow is conservative by design. Hidden-control writes, ambiguous properties, disabled value editors, resource pickers, colors, arrays, dictionaries, object selectors, file selectors, and other complex editors are refused until a dedicated safe workflow exists. This gives clients a property-level path before falling back to raw editor controls.

### 🪟 Evidence-Aware Capture

Screenshots are now treated as evidence with a target and a confidence boundary, not just image files. `system_editor_evidence` can capture editor, control, popup, active-dialog, or automatic surfaces and reports the requested surface, actual backend, target path, visible popups, fallback reasons, degradation state, and capture policy.

Settings and Inspector workflows also use more explicit capture behavior. Settings capture now prefers visible settings popup/window bounds, then dialog control bounds, and only then broader editor screenshots. Clients can distinguish an exact target capture from a broader fallback and can use strict policies when a fallback would be misleading.

This release also adds popup inspection and cropped popup capture through `system_editor_control(action="get_popup")` and `system_editor_control(action="capture_popup")`, making floating editor windows and popup menus first-class evidence surfaces.

### 🚀 Project Runtime Lifecycle

Project execution is now expressed as a lifecycle surface: `system_project_lifecycle(action=start|stop)`. The start action handles main-scene or specific-scene launches, marker waits, success and failure marker matching, marker timeouts, auto-stop behavior, and foreground-window fallback guidance. The stop action closes the currently running project session through the same lifecycle entry.

The older project run and stop tool names are intentionally removed rather than kept as aliases. The new name reflects the actual contract: clients are controlling a runtime session with capability context and verification hooks, not firing a one-off launch command.

### 🔎 Tool, Activity, And User Diagnostics

`system_tool_catalog` gives clients a searchable view of the current tool catalog. Agents can search by query, category, or domain and inspect match reasons, actions, parameters, visibility, enabled state, and optional schemas before choosing the next tool.

`system_tool_activity` now supports state, tool, slow-call, and failure-focused queries. This makes long-running or parallel automation easier to monitor because clients can inspect active or recent work without fetching unrelated activity records.

User-tool naming is also clearer. Listings, scaffold previews, and compatibility reports now show declared names, normalized names, and public MCP tool names. Legacy `user_` prefix declarations remain diagnosable, and generated scaffolds load more reliably in headless catalog scans by inheriting the base tool through its resource path.

### 🛠 Scene, Plugin, Project, And Cache Workflows

`system_scene_inspect` provides one read-only scene inspection entry with `validate`, `analyze`, and `full` actions while keeping the existing scene validation and analysis tools available for clients that already call them directly.

`system_plugin_maintenance` groups common plugin status, reload, update-status, update-source, and update-start workflows without removing the lower-level reload and update tools. Maintenance responses keep the reconnect and tool-refresh guidance that clients need during reloads or update syncs.

Project configuration inspection also expands. Clients can read export preset summaries with sensitive option keys and local absolute export paths redacted, and inspect individual input actions including deadzone and concrete input bindings.

Managed user-data maintenance remains explicit and dry-run-first for cleanup workflows. Clients can inspect capture caches and preview cleanup before applying removals, with guardrails for symlinks, junctions, and reparse points.

### ✅ Compatibility and Upgrade Notes

The public plugin version, .NET bridge metadata, protocol facts, localized changelogs, and release-note sources now target `1.3.0`.

Clients using older project run or stop tool names must migrate to `system_project_lifecycle(action=start)` and `system_project_lifecycle(action=stop)`. This is the main intentional compatibility break in v1.3.0.

Existing scene validation and analysis tools remain available. `system_scene_inspect` is an additive combined route.

`system_plugin_maintenance` is an additive high-level wrapper. Existing `system_plugin_reload` and `system_plugin_update` calls remain supported.

Complex settings and Inspector editors remain conservative. Unsupported editors should be handled by future dedicated workflows or by lower-level UI operations with explicit evidence, not by guessing.
