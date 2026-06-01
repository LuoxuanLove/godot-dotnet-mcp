## 🧭 Godot .NET MCP v1.1.2: Clearer Agent Workflows and Cleaner Installs

Godot .NET MCP `v1.1.2` is a maintenance update for agents and users who rely on clear workflow guidance, localized tool previews, and clean plugin installation. The release reorganizes MCP Prompt Guides into six practical workflows, improves Tools-page language coverage, and tightens Asset Library export validation so installed projects avoid plugin-internal build noise.

### ✨ Six High-Level Workflow Guides

- `godot.project_orientation` gives agents a stable starting path for reading project state, files, scenes, symbols, and dependency context before acting.
- `godot.content_authoring` broadens authoring guidance for scene, script, and resource changes instead of focusing on one bootstrap path.
- `godot.debug_triage` keeps debugger guidance inside one failure-triage workflow, so agents can move from diagnostics to DAP debugging without discovering a separate prompt category.
- `godot.reference_integrity`, `godot.runtime_validation`, and `godot.editor_ui_control` cover stale references, runtime checks, and editor UI automation as first-class agent workflows.

### 🌐 More Complete Localized Tool Previews

- DAP debugger categories, actions, and parameters now use localized Tools-page text instead of exposing raw English schema labels in localized clients.
- Dynamic action labels and empty-parameter fallback text now have locale coverage while preserving schema descriptions when a specific localized key is not available.
- French localization text renders accented characters, curly apostrophes, non-breaking spaces, and ligatures correctly.

### 📦 Cleaner Asset Library and Source-Copy Installs

- Asset Library exports exclude Roslyn bridge implementation sources so downloaded plugin copies are not compiled as part of the host Godot C# project.
- Addon README copies now point exported installs to repository-hosted docs, changelogs, and preview images rather than package-local paths that are not included in exports.
- Clean install validation now exercises the archived plugin copy, keeping the exported installation path aligned with the documented install experience.

### 🧪 Contract Coverage for Release Stability

- Prompt, system help, JSON-RPC router, and localization contracts assert the six-guide surface so future edits keep prompt discovery predictable.
- Tool-loader localization inventory checks visible Tools-page tree, action, and parameter fallback coverage across supported locales.
- Locale key parity checks now fail CI when any supported language is missing a translation key present in another locale.

### ✅ Compatibility and Upgrade Notes

`v1.1.2` keeps the existing Godot 4.6+ .NET requirement, Asset Library installation path, direct `addons/godot_dotnet_mcp/` source-copy installation path, and existing high-level `system_*` tool names. Clients that cache MCP prompt metadata should reconnect or refresh `prompts/list` after upgrading so they see the six current Prompt Guides.
