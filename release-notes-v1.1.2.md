## 🧭 Godot .NET MCP v1.1.2: Clearer Agent Workflows and Cleaner Installs

Godot .NET MCP `v1.1.2` is a maintenance update for agents and users who rely on clear workflow guidance, localized tool previews, and clean plugin installation. It keeps the same Godot 4.6+ .NET target and installation paths while reorganizing Prompt Guides, improving Tools-page language coverage, and tightening Asset Library export validation.

### ✨ Clearer Workflow Guide Taxonomy

The built-in Prompt Guides now use six workflow-oriented entries instead of mixing broad project workflows with narrower one-off prompts. Agents can discover guidance for project orientation, content authoring, debugging, reference checks, runtime validation, and editor UI control from one clearer prompt surface.

Debugger guidance now belongs to `godot.debug_triage`, while scene/script/resource authoring and reference validation each have their own workflow paths. This keeps prompt discovery focused on what the agent is trying to do, not on which underlying tool family happens to be involved.

### 🌐 More Complete Localized Tool Previews

Localized clients now show cleaner Tools-page previews for DAP debugger categories, actions, and parameters instead of exposing raw English schema labels. Dynamic action labels and empty-parameter fallback text also have locale coverage while still preserving schema descriptions when a specific localized key is not available.

French localization rendering is cleaned up as part of the same polish pass, so accented characters, curly apostrophes, non-breaking spaces, and ligatures display correctly in release-facing text.

### 📦 Cleaner Asset Library and Source-Copy Installs

Asset Library exports now exclude Roslyn bridge implementation sources, preventing downloaded plugin copies from being compiled as part of the host Godot C# project. Addon README copies also point exported installs to repository-hosted docs, changelogs, and preview images instead of package-local paths that are not included in exports.

Clean install validation now exercises the archived plugin copy, keeping the exported installation path aligned with the documented install experience and reducing the chance of package-only regressions reaching users.

### 🧪 Release Stability Guardrails

Prompt, system help, JSON-RPC router, and localization contracts now assert the six-guide surface so future edits keep prompt discovery predictable. Tool-loader localization inventory coverage also checks visible Tools-page tree, action, and parameter fallback text across supported locales.

Locale key parity checks now fail CI when any supported language is missing a translation key present in another locale, making release-facing localization gaps harder to miss before publication.

### ✅ Compatibility and Upgrade Notes

`v1.1.2` keeps the existing Godot 4.6+ .NET requirement, Asset Library installation path, direct `addons/godot_dotnet_mcp/` source-copy installation path, and existing high-level `system_*` tool names. Clients that cache MCP prompt metadata should reconnect or refresh `prompts/list` after upgrading so they see the six current Prompt Guides.

Upgrade from `v1.1.1` when you want clearer Prompt Guide discovery, more complete localized Tools-page previews, and cleaner Asset Library install behavior while preserving the stable installation and tool-surface expectations from the previous release.
