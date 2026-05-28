## ⚡ Godot .NET MCP v1.1.1: Faster Project State Probing

Godot .NET MCP `v1.1.1` improves the large-project experience for Agents that start by checking project health. Compact project-state reads now avoid building full file path arrays unless the caller explicitly asks for the files section.

### ✨ Faster Large-Project Orientation

- `system_project_state(summary=true)` now uses lightweight file counts for the compact summary path.
- `system_project_state(sections=["summary", "project", "runtime", "capabilities"])` keeps the same sectioned workflow without forcing full path-array collection.

### 🔧 Clearer Section Boundaries

- Full `scene_paths`, `script_paths`, and `resource_paths` are still available through the default full payload or `sections=["files"]`.
- Tool guidance now clarifies that `sections=[...]` takes precedence over `summary=true`, and that `sections=["health"]` triggers plugin health collection.

### ✅ Compatibility and Upgrade Notes

This update keeps the Godot 4.6+ and .NET 8 requirements unchanged. Existing callers that use the full payload or the `files` section continue to receive the same path arrays; compact callers should see lower file-enumeration overhead on larger projects.
