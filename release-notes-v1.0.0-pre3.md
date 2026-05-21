## 🧭 Runtime Diagnostics + Release Pipeline Hardening

Godot .NET MCP `v1.0.0-pre3` focuses on making editor automation failures explain themselves. Runtime marker checks, foreground-window limits, listener failures, headless captures, empty project scans, tool context overrides, and startup diagnostics now preserve enough evidence for clients to decide whether to retry, fall back, or fix the project state.

### 🧪 Runtime Execution Evidence

`system_project_run` can now wait for runtime bridge marker text before declaring success or failure. Success and failure markers share the same live event stream, marker mode can auto-stop the running scene, and event-id cursors keep high-volume logs or repeated pre-run marker text from hiding the real match.

Foreground-only runtime launches are also explicit now. Unsupported `background`, `minimized`, and `no_focus` requests return `requires_foreground_window` with the relevant capability context instead of looking like a generic launch failure.

### 🛠️ Editor and Tool Stability

Runtime bridge traffic sent during project startup no longer produces Godot `Invalid message received` noise. Editor-interface overrides avoid the GDScript VM internal error path, TileMap tool scripts instantiate during MCP registration, and headless or dummy rendering backends return structured skipped capture results instead of attempting unavailable viewport screenshots.

The Tools page also has contract coverage for popup coordinate semantics, including the real right-click path and the local / canvas / viewport / screen boundaries used by dock popups.

### 🚨 Actionable Failure Diagnostics

Self-diagnostics now point at the slowest startup or reload phase. MCP server listener failures distinguish occupied ports, access-denied binds, and Windows reserved or excluded TCP port ranges. Empty project scans are reported as suspect diagnostics instead of being mistaken for clean resource audits.

When `system_project_run` hits inconsistent `Editor interface not available` state, the report separates state-probe evidence from run-invoker evidence and includes recovery suggestions, with a CLI fallback when enough paths are known.

### 🚀 Release and CI Discipline

The prerelease line now has a single source for GitHub Release text: a hand-written user-facing summary plus a generated commit summary. The same renderer refreshes the `next` draft release and formal tag releases, while preflight checks keep tag, plugin version, changelog, and manual release notes aligned.

CI now leans on the hosted .NET 8 SDK, keeps the plugin harness check name stable, records harness timing summaries, preserves failure diagnostics, caches NuGet and Godot harness inputs, and keeps workflow lint plus PR policy checks close to the release path. Formal plugin releases still create GitHub Releases without zip package assets.

### 🧩 Misc

- Config cards now describe client capabilities more precisely, separating full one-click setup from CLI auto-add, launch/path-only, and manual-guidance clients.
- PR, issue, release, and agent-process documentation now line up with the short-branch contribution flow.
- Unreleased changelog entries were cleaned up so the pre3 section reflects current development history without stale records.

---

## Minor Compatibility and Stability Release

This prerelease keeps the minimum target at Godot 4.6 with .NET support and does not change the supported installation paths.

- Install from the Godot Asset Library, or copy the source `addons/godot_dotnet_mcp/` directory directly.
- Expect better diagnostics around runtime automation, editor tool execution, CI verification, and release sequencing.
- Treat this as a prerelease for users who want the newest runtime diagnostics and release-pipeline hardening before the next stable line.
