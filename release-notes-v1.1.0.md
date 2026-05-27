## 🧩 Godot .NET MCP v1.1.0: Debugging, Resources, and Faster Project Insight

Godot .NET MCP `v1.1.0` is a capability release for users who already rely on the stable `v1.0.1` plugin line. It keeps the same Godot 4.6+ .NET target and installation paths while adding three practical MCP surfaces: DAP debugging control, MCP Resources and Prompts, and lighter project-state reads for larger projects.

### 🐞 DAP Debugger Control from MCP

Agents can now use `system_dap_debugger` for Godot Debug Adapter Protocol workflows when a DAP endpoint is available. The new debugger surface covers endpoint status, breakpoint set/remove/list, pause and continue, step-over, stack trace reads, and output event collection using the same `Content-Length` JSON framing expected by DAP clients.

Debugger failures are also easier to interpret. When no endpoint is reachable or a DAP response fails, the plugin returns structured error identifiers such as `dap_unavailable` and `dap_response_failed` instead of leaving agents to infer the failure from generic connection behavior.

### 📚 MCP Resources and Prompt Guides

`v1.1.0` adds first-class MCP Resources and Prompts support. Clients can discover project info and diagnostics summary resources, read scene, script, and resource files through strict `res://` templates, and use built-in prompts for common Godot workflows.

The new prompt guides include `godot.scene_bootstrap`, `godot.debug_triage`, and `godot.binding_fix`, giving agents more structured starting points for scene setup, debugging, and binding repair without adding more one-off public tools.

### ⚡ Lighter Project State Reads

Large projects can now request a compact `system_project_state` response with `summary=true`, or fetch only selected project-state areas with `sections=[...]`. Existing full responses remain the default, while clients that only need project counts, file lists, runtime capability details, or health diagnostics can avoid pulling every scene, script, and resource path in one call.

This should make repeated health checks and status polling easier to fit into agent workflows, especially when the full project inventory is large but the next decision only needs a small part of the state.

### 🛡️ Startup and Validation Guardrails

Plugin startup now initializes runtime state, settings storage, and core services before settings load/save paths or update callbacks can use them. This reduces the chance that an otherwise successful plugin start still leaves `Nil` service calls in the Godot output.

The plugin harness also treats basic Godot runtime and parser error markers as validation failures. Messages such as `SCRIPT ERROR:`, `Invalid call.`, and `Parse Error:` are no longer hidden behind a successful process exit, so future releases have a stronger guard against startup and parser regressions.

### ✅ Compatibility and Upgrade Notes

`v1.1.0` keeps the existing Godot 4.6+ .NET requirement, Asset Library installation path, direct `addons/godot_dotnet_mcp/` source-copy installation path, and existing high-level `system_*` tool names. Existing `system_project_state` calls keep returning the full payload unless a client opts into `summary=true` or `sections=[...]`.

Upgrade from `v1.0.1` when you want DAP debugger control, MCP Resources and Prompts, lighter project-state reads, and stronger startup validation while preserving the stable installation and tool-surface expectations from the previous release.
