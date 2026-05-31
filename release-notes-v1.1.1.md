## 🧩 Godot .NET MCP v1.1.1: Complete DAP Sessions, Prompt Guides, and Faster Project State

Godot .NET MCP `v1.1.1` improves three everyday Agent workflows: complete debugger sessions through the built-in Godot Debug Adapter Protocol, more actionable MCP Prompt Guides for common Godot tasks, and faster large-project orientation when callers only need compact project-state information.

### ✨ Full DAP Session Flow

- `system_dap_debugger` now supports runtime settings, explicit session IDs, `initialize`, `launch`, `attach`, `configuration_done`, `threads`, `terminate`, and `disconnect` while keeping one high-level Debug Adapter Protocol entry point.
- Existing breakpoint, pause, continue, step-over, stack-trace, and output-event actions continue to work through the same tool, so clients do not need to switch between fragmented debugger tools.

### 🛡️ Safer Debugger Endpoint Handling

- DAP endpoint access defaults to loopback hosts, keeping normal Godot editor debugging local unless remote hosts are explicitly enabled.
- Raw DAP request and message details are no longer returned by default; when protocol troubleshooting requires `include_raw=true`, sensitive-looking fields are redacted before being reported.
- Session, message, frame, buffer, and breakpoint caches now have fixed bounds to keep long debugger sessions from growing without limit.

### 🔧 Clearer Diagnostics and Prompt Guide Discovery

- DAP lifecycle mistakes now return structured protocol errors such as `dap_invalid_session_state`, `dap_invalid_settings`, and `dap_limit_exceeded`, making client-side recovery easier.
- `system_help` now points agents to MCP Prompt Guides through `prompts/list`, `prompts/get`, and the built-in `godot.scene_bootstrap`, `godot.debug_triage`, and `godot.binding_fix` prompt IDs.
- The built-in Prompt Guides now include recommended tool order, validation expectations, and avoid notes, giving agents stronger starting workflows for scene work, debugging, and C# binding repair.

### ⚡ Faster Large-Project Orientation

- `system_project_state(summary=true)` now uses lightweight file counts for the compact summary path.
- `system_project_state(sections=["summary", "project", "runtime", "capabilities"])` keeps the same sectioned workflow without forcing full path-array collection.

### 🔧 Clearer Section Boundaries

- Full `scene_paths`, `script_paths`, and `resource_paths` are still available through the default full payload or `sections=["files"]`.
- Tool guidance now clarifies that `sections=[...]` takes precedence over `summary=true`, and that `sections=["health"]` triggers plugin health collection.

### ✅ Compatibility and Upgrade Notes

This release keeps the Godot 4.6+ / .NET 8 compatibility target and does not change installation paths. Users should reconnect or refresh their MCP tool schema after upgrading so clients see the new `2026-05-03.13` DAP action surface and the updated `system_help` Prompt Guide discovery text. MCP Prompt Guides remain prompt templates accessed through `prompts/list` and `prompts/get`; executable editor actions continue to run through the existing high-level `system_*` tools. Existing `system_project_state` callers that use the full payload or the `files` section continue to receive the same path arrays, while compact callers should see lower file-enumeration overhead on larger projects.
