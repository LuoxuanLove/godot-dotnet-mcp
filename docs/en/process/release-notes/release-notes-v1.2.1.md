## 🧩 Godot .NET MCP v1.2.1: Verified Editor UI Automation

This release line improves editor UI automation by letting clients wait for visible Godot editor state before continuing a workflow. Agents can now act through existing editor controls and then verify that the expected UI condition actually appeared.

<p align="center"><a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.2.1/docs/en/process/release-notes/release-notes-v1.2.1.md">English</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.2.1/docs/zh-CN/流程/发布说明/发布说明-v1.2.1.md">简体中文</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.2.1/docs/ja/プロセス/リリースノート/リリースノート-v1.2.1.md">日本語</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.2.1/docs/ko/프로세스/릴리스-노트/릴리스-노트-v1.2.1.md">한국어</a></p>

### ✨ Wait for Real UI State

`system_editor_control` now includes `wait_for_ui`, a bounded polling action for control existence, visibility, text matching, and enabled / disabled state. Successful waits return the matched control summary and timing details; timeouts return the final observed payload so clients can adjust their locator or next action.

### 🔧 Safer Automation Loops

The new wait action complements menu, popup, click, hover, and text-entry controls without requiring OS mouse automation. This makes workflows such as opening editor dialogs, filtering settings, and confirming transient panels easier to verify from inside Godot.

Editor UI guidance now makes the automation order explicit: semantic workflows and navigation first, control-level focus, text, value, and popup actions second, and control-local mouse or pointer events only as fallback. Agents can choose a higher-level path before reaching for coordinates.

Resource and prompt diagnostics now redact mixed-case URL credentials, bearer/API-key variants, and nested metadata secrets before reporting resource outputs. Troubleshooting evidence stays useful for automation loops without exposing credentials in summaries.

### 🪟 Floating Window Evidence

`system_editor_control` can now read and crop visible floating popup/window surfaces through `get_popup` and `capture_popup`. That gives clients a direct evidence path for modal editor windows and popup menus before choosing a button, menu item, text field, or close action.

### 🧭 Configuration Navigation and Evidence

`system_settings_dialog` adds a high-level workflow for Project Settings and Editor Settings. Clients can open a settings surface through editor menus, wait for the dialog to become visible, search candidate setting rows, focus a returned result, capture evidence, and close the surface without writing setting values directly.

The workflow exposes read-only row models through `list_rows`, summarizing visible settings-like controls with conservative confidence and evidence fields before optional value reads, writes, or assertions.

It can list and activate settings tabs through `list_tabs` and `activate_tab`, including `open(tab=...)`, so clients can move between Project Settings or Editor Settings tabs without coordinate clicks.

The settings workflow can list visible category tree items and focus a unique category before row inspection, making Project Settings and Editor Settings navigation less dependent on raw control enumeration.

It can also read the current value of a uniquely matched visible row through `read_value`, returning typed text, bool, number, or enum payloads with row and value-control evidence while still avoiding direct setting writes.

Project configuration evidence now also covers input maps: agents can inspect a single project input action through `system_project_configure`, including its deadzone and concrete key, mouse, or controller bindings. This makes input-map reviews easier to ground in the actual project configuration before changing gameplay or editor shortcuts.

Project configuration can also list export presets through `system_project_configure(action="list_export_presets")`. The response summarizes preset names, platforms, runnable state, filters, script export mode, and export-path shape while redacting sensitive option keys and absolute local export paths.

Clients can now resolve a unique visible settings row through `resolve_row` before reading a value or choosing a follow-up UI action. The response carries row paths, confidence, selector evidence, and ambiguity diagnostics while staying read-only.

When an agent only needs to move keyboard focus to the matched value editor, `focus_value` focuses the value control and returns focused editor evidence without changing the setting.

Supported unique visible rows can now be edited through `set_value` for text, number, and bool controls. The workflow writes through editor UI controls and then observes the row again so agents can verify the value they changed instead of assuming the click or text edit worked.

Agents can also use read-only `verify_value` checks to compare expected text, bool, number, or enum values against the uniquely matched visible row. This gives settings workflows a non-mutating assertion step before or after a UI action.

### 🔎 Searchable Tool Discovery

`system_tool_catalog` gives clients a read-only search surface for the current tool catalog. Clients can search by query, category, or domain and inspect why each tool matched, which actions and parameters it exposes, whether it is visible, and whether it is currently enabled.

This makes configuration and editor workflows easier to re-enter after profiles, plugin-domain tools, or user-tool state change: agents can rediscover the right system, project, editor, runtime, script, or user-facing tool before choosing the next verified action.

Native MCP discovery now localizes resource and resource-template metadata too. When clients call `resources/list` or `resources/templates/list`, resource names and descriptions follow the active plugin language while URIs and templates remain stable.


### 🧭 Project Runtime Lifecycle

Project runtime control now uses `system_project_lifecycle(action=start|stop)` as its canonical high-level entry. Start, marker validation, auto-stop, explicit stop, foreground-window fallback guidance, and runtime capability context now live under one lifecycle surface instead of separate run and stop tool names.

Clients that previously called the old project run or stop tool names should migrate to `system_project_lifecycle(action=start)` and `system_project_lifecycle(action=stop)`. The lifecycle wording is intended to make editor automation flows read as a controllable runtime session rather than a one-off launch command.

### ✅ Compatibility and Upgrade Notes

The project runtime control surface now uses `system_project_lifecycle(action=start|stop)`. Clients using earlier project run or stop tool names should migrate to the lifecycle entry, while existing editor, settings, and project configuration workflows remain available.
