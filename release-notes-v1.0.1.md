## 🛠️ Godot .NET MCP v1.0.1: Release Flow and Audit Fixes

Godot .NET MCP `v1.0.1` is a small maintenance release after `v1.0.0`. It focuses on the changes that landed since the stable release: a Tools-page layout fix, safer release automation, a simpler manual release dispatch UI, and more accurate resource audits for C# custom `Resource` scripts.

### Tools Page Preview Fix

The Tools tab preview pane now fills the lower split area with the selected item description instead of leaving unused blank space. This is a small UI correction, but it makes the tool reference area feel more complete when browsing the Dock tool tree.

### Safer Release Automation

The one-click release flow now uses `v*` tags consistently, validates the `dev` source, checks version metadata and manual release notes, detects existing tags or releases, and records successful dry runs. When the version and target commit are unchanged, a matching formal release can reuse the recent dry-run result and skip repeated build and harness checks.

Manual dispatch was also simplified: maintainers now use GitHub Actions' built-in `Use workflow from` selector as the only release source selector. The workflow still requires `dev`, but it no longer asks for the same branch twice.

### More Accurate C# Resource Audits

`system_resource_reference_audit` now resolves C# `[GlobalClass] Resource` scripts through Roslyn `types[]` metadata before falling back to script inspection. Valid custom resource scripts should no longer be reported as unresolved just because the audit could not connect a `.tres` script class to its C# type.

The audit also recognizes unquoted `ExtResource id=` declarations, ignores `id=` text inside quoted attribute values, and distinguishes missing IDs from IDs that point to non-Script resources. These changes make `.tres` and `.tscn` diagnostics more precise when custom resources are involved.

### Upgrade Notes

`v1.0.1` does not change the main installation model or remove the stable `system_*` tool surface. It is intended as a low-risk update for `v1.0.0` users who want the release workflow fixes, the Tools-page layout correction, and more reliable resource audit results.
