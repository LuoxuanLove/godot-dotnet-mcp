## 🧩 Godot .NET MCP v1.1.0: Stable Metadata Baseline

Godot .NET MCP `v1.1.0` prepares the next stable plugin line on top of the `v1.0.1` maintenance baseline. It keeps the same Godot 4.6+ .NET target, installation paths, and high-level `system_*` tool surface while aligning the plugin, protocol facts, and bridge metadata around one stable version.

### Version Clarity

The plugin metadata, MCP protocol facts, and .NET bridge assembly metadata now report `1.1.0` consistently. Clients that display plugin freshness, health, update, or bridge information should see the same stable version across those surfaces.

### Stable Tool Surface

`v1.1.0` does not require client-side migration for existing high-level tools. The update keeps the current MCP tool names, Settings update flow, resource audit behavior, and editor automation entry points intact while moving the release baseline forward.

### Lighter Project State Reads

Large projects can now request a compact `system_project_state` response with `summary=true`, or fetch only selected project-state areas with `sections=[...]`. Existing full responses remain the default, while clients that only need project counts, file lists, runtime capability details, or health diagnostics can avoid pulling every scene, script, and resource path in one call.

### Compatibility and Upgrade Notes

`v1.1.0` keeps the existing Godot 4.6+ .NET requirement, Asset Library installation path, direct `addons/godot_dotnet_mcp/` source-copy installation path, and stable high-level `system_*` tool surface. Existing `system_project_state` calls keep returning the full payload unless a client opts into `summary=true` or `sections=[...]`. Upgrade from `v1.0.1` when you want the plugin and bridge metadata to identify the next stable line consistently.
