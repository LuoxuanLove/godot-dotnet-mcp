## 🧩 Godot .NET MCP v1.1.1: Complete DAP Sessions, Prompt Guides, and Stability Fixes

Godot .NET MCP `v1.1.1` improves everyday Agent workflows with complete debugger sessions through the built-in Godot Debug Adapter Protocol, more actionable MCP Prompt Guides, faster large-project orientation, and fixes for project-wide audit and cache behavior that could slow down or freeze larger Godot projects.

### ✨ Full and Safer DAP Session Flow

- `system_dap_debugger` now supports runtime settings, explicit session IDs, `initialize`, `launch`, `attach`, `configuration_done`, `threads`, `terminate`, and `disconnect` while keeping one high-level Debug Adapter Protocol entry point.
- Existing breakpoint, pause, continue, step-over, stack-trace, and output-event actions continue to work through the same tool, so clients do not need to switch between fragmented debugger tools.
- DAP endpoint access defaults to loopback hosts, raw request/message details stay hidden unless `include_raw=true`, sensitive-looking fields are redacted when raw details are requested, and session, message, frame, buffer, and breakpoint caches now have fixed bounds.

### 📚 Clearer Prompt Guide Discovery

- `system_help` now points agents to MCP Prompt Guides through `prompts/list`, `prompts/get`, and the built-in `godot.scene_bootstrap`, `godot.debug_triage`, and `godot.binding_fix` prompt IDs.
- The built-in Prompt Guides now include recommended tool order, validation expectations, and avoid notes, giving agents stronger starting workflows for scene work, debugging, and C# binding repair.

### 🔧 Stability and Performance Fixes

- `system_bindings_audit` no longer needs to repeatedly load and instantiate the same scenes during broad audits, reducing the risk that large projects with many C# scripts freeze the Godot editor during project-wide binding checks.
- Atomic executor cache invalidation now distinguishes read actions from real writes more accurately, so cached reference and Roslyn data can be reused across safe reads while still being cleared after mutations.
- DAP lifecycle mistakes now return structured protocol errors such as `dap_invalid_session_state`, `dap_invalid_settings`, and `dap_limit_exceeded`, making client-side recovery easier.

### ⚡ Faster Large-Project Orientation

- `system_project_state(summary=true)` now uses lightweight file counts for the compact summary path.
- `system_project_state(sections=["summary", "project", "runtime", "capabilities"])` keeps the same sectioned workflow without forcing full path-array collection.
- Full `scene_paths`, `script_paths`, and `resource_paths` are still available through the default full payload or `sections=["files"]`, and tool guidance now clarifies that `sections=[...]` takes precedence over `summary=true` while `sections=["health"]` triggers plugin health collection.

### ✅ Compatibility and Upgrade Notes

`v1.1.1` keeps the existing Godot 4.6+ .NET requirement, Asset Library installation path, direct `addons/godot_dotnet_mcp/` source-copy installation path, and existing high-level `system_*` tool names. Reconnect or refresh the MCP tool schema after upgrading so clients see the new DAP actions and Prompt Guide discovery text.
