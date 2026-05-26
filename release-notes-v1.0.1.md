## 🛠️ Godot .NET MCP v1.0.1: Update Flow and Resource Audit Reliability

Godot .NET MCP `v1.0.1` is a focused maintenance release for the first stable line. It keeps the `v1.0.0` editor-native MCP surface intact while improving the plugin update workflow, reducing release-dispatch ambiguity, and making resource-reference audits more accurate for C# custom `Resource` scripts.

This release is about confidence in day-to-day maintenance. Copied source installs get a clearer update path, maintainers get a simpler one-click release entry, and projects that use C# custom resources get less noisy audit evidence before agents or developers make changes.

### 🔄 Plugin Updates from Settings

The Settings page now gives copied source installs a clearer way to stay current. Users can target a selected branch, the default `dev` branch, the latest stable release, the latest release including prereleases, or a specific discovered release/tag.

The sync flow downloads GitHub archives, extracts only `addons/godot_dotnet_mcp/`, preserves `custom_tools/`, records sync metadata, and schedules a plugin lifecycle reload after a successful update. That keeps project-specific user tools safe while making source-copy updates a first-class path instead of a manual folder replacement chore.

### 🧭 Cleaner Dock and Update State

Persistent update controls now live in the Settings tab, while Home stays focused on diagnostics, service status, and quick service actions. The update panel also removes redundant current-version, plugin-path, and commit-summary rows so the selected source, discovered target, comparison result, and sync state are easier to read.

The editor tab label is shortened to `MCP`, while Dock headers and dialogs keep the full `Godot .NET MCP` name. The result is a compact editor tab without losing clarity in dialogs, documentation, or user-facing copy.

### 🔎 Resource Audit Fixes for C# Resources

`system_resource_reference_audit` now resolves C# `[GlobalClass] Resource` scripts through Roslyn `types[]` metadata before falling back to script inspection. Valid custom resource scripts should no longer be reported as unresolved simply because the audit could not connect the `.tres` script class to the C# type.

The audit also separates missing `ExtResource id`s from IDs that point to non-Script resources, recognizes unquoted `ExtResource id=` declarations, and ignores `id=` text inside quoted attribute values. These parsing boundaries help `.tscn` and `.tres` diagnostics describe the real reference problem instead of surfacing misleading resource-class warnings.

### 🚀 Simpler Release Dispatch

The one-click release workflow now uses GitHub Actions' built-in `Use workflow from` selector as the only release source selector. Maintainers still run releases from `dev`, and the workflow still validates that source, but the manual dispatch UI no longer asks for the same branch twice.

Dry-run-first release automation remains in place: the workflow validates source, version metadata, manual release notes, duplicate tags/releases, build output, and plugin harness before creating a new `v*` GitHub Release. Matching successful dry runs can still be reused for the final non-dry-run release when the version and target commit are unchanged.

### 📚 Documentation and Validation

The release runbook, CI notes, System tool documentation, and changelogs were updated to match the new update, audit, and release behavior. Contract coverage now includes C# resource scripts, quoted and unquoted resource IDs, missing IDs, and non-Script ID diagnostics.

### 🏁 Upgrade Notes

`v1.0.1` is intended as a low-risk update for `v1.0.0` users. It does not remove the stable `system_*` tool surface or change the installation model. Users who copy the addon source into projects should especially benefit from the improved in-plugin update flow, while projects that rely on C# custom resources should see fewer false-positive resource audit warnings.