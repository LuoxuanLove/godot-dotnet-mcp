## 🧭 Godot .NET MCP v1.1.2: Clearer Agent Workflow Prompt Guides

Godot .NET MCP `v1.1.2` reorganizes the built-in MCP Prompt Guides around the way agents actually work in Godot projects: orienting in a project, authoring content, triaging failures, checking references, validating runtime behavior, and controlling the editor UI. The prompt surface is now broader, clearer, and less redundant while staying separate from executable `system_*` tools.

### ✨ Six High-Level Workflow Guides

- `godot.project_orientation` gives agents a stable starting path for reading project state, files, scenes, symbols, and dependency context before acting.
- `godot.content_authoring` replaces narrow scene bootstrap guidance with a broader authoring workflow for scene, script, and resource changes.
- `godot.debug_triage` now owns debugger guidance as part of one failure-triage workflow instead of splitting DAP debugging into a redundant prompt guide.
- `godot.reference_integrity`, `godot.runtime_validation`, and `godot.editor_ui_control` cover stale references, runtime checks, and editor UI automation as first-class agent workflows.

### 📚 Easier Discovery from Help and Localized Clients

- `system_help` now advertises `prompts/list`, `prompts/get`, and all six prompt IDs so agents can discover workflow guidance from the primary capability guide.
- English and Simplified Chinese prompt metadata now describe the six-guide taxonomy consistently across titles, descriptions, arguments, and prompt bodies.
- The tool-system, service-routing, and runtime-service documentation now describe the six Prompt Guides and clarify the boundary between MCP prompts and executable tools.

### 🧪 Contract Coverage for Prompt Stability

- Prompt, system help, JSON-RPC router, and localization harness contracts now assert the six-guide surface so future edits do not accidentally restore old prompt IDs or fragment the workflow taxonomy.
- Resource-path prompt arguments keep the documented scene and resource extensions aligned with the prompt contract.

### ✅ Compatibility and Upgrade Notes

`v1.1.2` keeps the existing Godot 4.6+ .NET requirement, Asset Library installation path, direct `addons/godot_dotnet_mcp/` source-copy installation path, and existing high-level `system_*` tool names. Clients that cache MCP prompt metadata should reconnect or refresh `prompts/list` after upgrading so the six Prompt Guides replace the older `godot.scene_bootstrap` and `godot.binding_fix` entries.