## 🧩 Godot .NET MCP v1.2.1: Verified Editor UI Automation

This release line improves editor UI automation by letting clients wait for visible Godot editor state before continuing a workflow. Agents can now act through existing editor controls and then verify that the expected UI condition actually appeared.

<p align="center"><a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.2.1/docs/en/process/release-notes/release-notes-v1.2.1.md">English</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.2.1/docs/zh-CN/流程/发布说明/发布说明-v1.2.1.md">简体中文</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.2.1/docs/ja/プロセス/リリースノート/リリースノート-v1.2.1.md">日本語</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/v1.2.1/docs/ko/프로세스/릴리스-노트/릴리스-노트-v1.2.1.md">한국어</a></p>

### ✨ Wait for Real UI State

`system_editor_control` now includes `wait_for_ui`, a bounded polling action for control existence, visibility, text matching, and enabled / disabled state. Successful waits return the matched control summary and timing details; timeouts return the final observed payload so clients can adjust their locator or next action.

### 🔧 Safer Automation Loops

The new wait action complements menu, popup, click, hover, and text-entry controls without requiring OS mouse automation. This makes workflows such as opening editor dialogs, filtering settings, and confirming transient panels easier to verify from inside Godot.

### 🧭 Settings Dialog Navigation

`system_settings_dialog` adds a high-level workflow for Project Settings and Editor Settings. Clients can open a settings surface through editor menus, wait for the dialog to become visible, search candidate setting rows, focus a returned result, capture evidence, and close the surface without writing setting values directly.

The workflow exposes read-only row models through `list_rows`, summarizing visible settings-like controls with conservative confidence and evidence fields before optional value reads, writes, or assertions.

It can list and activate settings tabs through `list_tabs` and `activate_tab`, including `open(tab=...)`, so clients can move between Project Settings or Editor Settings tabs without coordinate clicks.

It can also read the current value of a uniquely matched visible row through `read_value`, returning typed text, bool, number, or enum payloads with row and value-control evidence while still avoiding direct setting writes.

Supported unique visible rows can now be edited through `set_value` for text, number, and bool controls. The workflow writes through editor UI controls and then observes the row again so agents can verify the value they changed instead of assuming the click or text edit worked.

Agents can also use read-only `verify_value` checks to compare expected text, bool, number, or enum values against the uniquely matched visible row. This gives settings workflows a non-mutating assertion step before or after a UI action.

### ✅ Compatibility and Upgrade Notes

This change only extends the public tool schema. Existing `system_editor_control` and `system_settings_dialog` actions remain available, and clients that do not call the new actions do not need to change their requests.
