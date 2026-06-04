## 🧩 Godot .NET MCP v1.2.0: Localized Docs Trees and i18n Validation

This release focuses on documentation quality and safer plugin maintenance. It brings the localized documentation trees into closer alignment with the current plugin layout, tightens validation so each locale tree stays structurally aligned, and improves update-sync refresh behavior before lifecycle reloads.

### ✨ Highlights

- Added docs i18n validation coverage for locale file parity, Markdown link targets, and cross-locale link leakage.
- Kept the localized docs trees aligned with the current plugin UI, tool, and binding references.

### 🔧 Fixes

- Refreshed the Godot editor file system after plugin update sync writes files, before scheduling the plugin lifecycle reload.
- Corrected English and Japanese documentation facts around service routing, .NET support, UI flow, and tool-domain indexes.
- Replaced broken or outdated localization draft fragments with current user-facing content.
- Removed invalid screenshot references from the Japanese README.

### ✅ Compatibility and Upgrade Notes

- Update sync now asks the editor to rescan plugin files before the lifecycle reload step.
- No file layout or tool schema migration is required.
- Existing installs do not need migration.
