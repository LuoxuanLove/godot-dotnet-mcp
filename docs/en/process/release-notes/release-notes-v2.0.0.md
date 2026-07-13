## 🧩 Godot .NET MCP v2.0.0: Protocol-First Editor Bridge

Godot .NET MCP `v2.0.0` is a protocol-first refactor release for editor-native MCP workflows. It reorganizes context, prompts, tools, transports, and C# semantic support around the MCP 2025-11-25 model while keeping installation centered on the plugin itself.

<p align="center"><a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/refactor/v2.0.0/docs/en/process/release-notes/release-notes-v2.0.0.md">English</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/refactor/v2.0.0/docs/zh-CN/流程/发布说明/发布说明-v2.0.0.md">简体中文</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/refactor/v2.0.0/docs/ja/プロセス/リリースノート/リリースノート-v2.0.0.md">日本語</a> | <a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/refactor/v2.0.0/docs/ko/프로세스/릴리스-노트/릴리스-노트-v2.0.0.md">한국어</a></p>

v2.0.0 is a large protocol and internal service refactor, not a cosmetic cleanup. The goal is to make Godot .NET MCP behave like a first-class MCP 2025-11-25 server: passive context moves to Resources, reusable planning workflows move to Prompts, Tools stay focused on actions and computed results, and the editor Dock previews the same metadata that MCP clients receive. This matters because clients can discover less by guessing, call fewer legacy helper tools, and rely on a smaller, better-tested public surface while the plugin keeps richer internals behind that surface.

### ✨ Protocol-First MCP Surface

The default MCP protocol target moves to 2025-11-25. `initialize` now advertises the v2.0 server description and protocol baseline, tool names are guarded against invalid public names, and JSON Schema 2020-12 is the default schema dialect for public metadata.

The public surface is reorganized around the MCP roles:

- Resources expose passive context such as guide text, project/editor state, editor logs, activity views, and tool catalogs.
- Prompts hold workflow orientation so clients can ask for structured planning without calling a passive help tool.
- Tools focus on actions, mutations, captures, diagnostics, or computed workflow results.

Legacy discovery-style public tools are no longer treated as the primary entry point. Where compatibility remains, retired entries return explicit replacement guidance so clients can migrate toward Resources, Prompts, and canonical action tools.

### 🌊 Streamable HTTP and Stdio

The default endpoint remains `http://127.0.0.1:3000/mcp`, but the endpoint now follows the v2.0 Streamable HTTP shape: protocol and session headers, JSON/SSE `Accept` negotiation, Origin/CORS checks, GET SSE streams, resumable event history, finite POST SSE responses, heartbeat events, queued server-to-client delivery, and `DELETE /mcp` session termination.

Stdio now defaults to newline-delimited JSON-RPC for current MCP clients. Legacy `Content-Length` framing remains available only as an explicit compatibility mode, so older local launchers are not broken while the default transport moves forward.

Transport validation is stricter as well. HTTP and stdio now share deterministic JSON-RPC envelope behavior for malformed requests, response envelopes, disabled tools, duplicate or conflicting HTTP body headers, and session validation.

Streamable HTTP replay is also more deliberate: GET SSE `open` metadata remains visible for current streams without entering the resumable event log, proxy headers are trusted only when explicitly enabled, and generated session IDs include additional random entropy.

Long-running editor sessions also get tighter cleanup: idle partial HTTP requests close after the timeout window, User-tool definition refreshes run only after explicit invalidation, debug `dotnet build` diagnostics disable build servers, and stopped debugger sessions are removed from the live bridge map immediately.

### 🧭 Resource and Prompt UI

The Dock gains first-class Resources and Prompts tabs. Users can inspect protocol catalog counts, copy resource or prompt IDs, preview resources, fill prompt arguments, preview generated prompt messages, and see bounded icon rendering before a client consumes the same entries.

The Tools tab also moves toward the shared catalog fact path. Titles, icons, annotations, input schemas, output schemas, previews, search, schema copy actions, and visible tool families are rendered from shared protocol metadata instead of a separate private UI catalog model.

This makes the Dock a preview of the MCP server surface rather than a parallel interpretation of it. When client-visible metadata changes, the UI is expected to reflect the same facts.

### 🎛️ Focused Settings Experience

The Settings page keeps port, log level, language, Release/Development channels, branch selection, Refresh List, one-click update, and row-level Switch actions, but presents them in a quieter hierarchy. Redundant policy and repository text is removed, the channel selector sits directly above the version list, the primary status carries the result, and expandable details contain only supplemental diagnostics instead of repeating the same error.

The version list now uses three focused columns, marks the current row with text as well as color, and moves dates to row tooltips. Selecting a commit highlights the whole row and makes that exact ref/commit the comparison target; only the separate Switch action changes the installed version. Selection and startup are cache-only, while explicit refresh and one-click verification are the only paths that request GitHub. Forms and actions stack into a true single-column layout at ultra-narrow Dock widths, so the update workflow remains usable without horizontal clutter.

A four-language Dock UI style guide now defines the information hierarchy, editor-native theme use, spacing, responsive breakpoints, action priorities, status and empty-state behavior, accessibility, localization, and validation matrix that future pages must follow.

### 🧠 C# Semantic Runtime

C# semantic tooling remains part of the installation contract. Asset Library and prepared addon installs include framework-dependent Roslyn runtime files so semantic read and patch workflows continue to work after installation when the machine has the .NET 8 runtime available.

The bundle is isolated from the host project compile surface. The shipped addon does not ask user projects to compile plugin Roslyn or bridge source files, reducing dependency conflicts while preserving semantic C# capabilities.

Clean install validation now checks both sides of that contract: exported addon installs must exclude plugin bridge/Roslyn source files and must still prove that the framework-dependent Roslyn runtime files are present and usable through the local `dotnet` host.

### 🛠️ Tooling, Catalogs, and Compatibility

`tools/list` now returns a flat callable tool list with input schema, output schema, annotations, and JSON Schema 2020-12 metadata. Tree/group presentation data moves to catalog resources and shared Dock presentation snapshots.

Catalog snapshots, catalog resources, `/api/tools`, Dock model metadata, Tools tab previews, search, and schema-copy paths use `ToolCatalogManifest` and `ToolCatalogSnapshotService` as the shared catalog fact path. This reduces drift between client discovery, HTTP diagnostics, and editor UI previews.

Tool-call results now reserve `structuredContent` for tools whose `tools/list` entries advertise output schemas, while keeping text JSON content available for all clients. This keeps discovery metadata and call results aligned for strict MCP clients.

The v2.0 line also splits many large root domain implementations into focused executors while keeping public facades where compatibility requires them. Audio, animation, signal, TileMap, UI, filesystem, node, project, resource, scene, group, geometry, material, lighting, navigation, particle, physics, shader, debug, and editor domains all move toward smaller implementation units.

### ✅ Compatibility and Validation

This release includes guardrails for the refactor rather than only feature text. Validation now covers public tool removals, root monolith closure, catalog facts, optional capability advertisement, changelog structure, release-note wording, Roslyn runtime bundle shape, clean Asset Library installs, safe bridge writes, and MCP 2025-11-25 conformance contracts.

Runtime contracts now cover JSON-RPC cancellation notifications, bounded non-editor tool-call timeouts, editor automation watchdog release, and the direct `ToolCatalogManifest` catalog path.

Compatibility is deliberately explicit: older discovery calls and legacy transports are documented as compatibility paths, while the default client guidance points to Resources, Prompts, canonical Tools, Streamable HTTP, and newline stdio.

### 📦 Upgrade Notes

- Existing clients should prefer `resources/list`, `resources/read`, `resources/templates/list`, `prompts/list`, `prompts/get`, and canonical action tools over legacy public discovery tools.
- HTTP clients should send `MCP-Protocol-Version: 2025-11-25`, handle `Mcp-Session-Id`, and advertise `Accept: application/json, text/event-stream`.
- Stdio launchers should use newline-delimited JSON-RPC unless they intentionally opt into the legacy `Content-Length` compatibility mode.
- C# semantic workflows should rely on the shipped framework-dependent Roslyn runtime files instead of compiling plugin Roslyn source inside the host project, and require the .NET 8 runtime.
- Settings restores cached update refs and exact comparisons at startup without contacting GitHub. Refresh List updates only the selected channel, and one-click update requests remote comparison only when no exact local/cache result is available.
- Antigravity users can use the Config tab to detect and open the app, copy the Godot MCP configuration, and write or remove the `godot-mcp` entry in `.gemini/config/mcp_config.json`.
