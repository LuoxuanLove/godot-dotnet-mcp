## 🧩 Godot .NET MCP v1.2.0: Localized Docs Trees and i18n Validation

This release focuses on documentation quality. It brings the localized documentation trees into closer alignment with the current plugin layout and tightens validation so each locale tree stays structurally aligned and self-contained.

### ✨ Highlights

- Added docs i18n validation coverage for locale file parity, Markdown link targets, and cross-locale link leakage.
- Kept the localized docs trees aligned with the current plugin UI, tool, and binding references.

### 🔧 Fixes

- Corrected English and Japanese documentation facts around service routing, .NET support, UI flow, and tool-domain indexes.
- Replaced broken or outdated localization draft fragments with current user-facing content.
- Removed invalid screenshot references from the Japanese README.

### ✅ Compatibility and Upgrade Notes

- This release changes documentation content and validation only.
- No plugin behavior, file layout, or tool schema changes are included.
- Existing installs do not need migration.
