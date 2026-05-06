# Godot .NET MCP

[![Latest Stable](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.github.com%2Frepos%2FLuoxuanLove%2Fgodot-dotnet-mcp%2Freleases%2Flatest&query=%24.tag_name&label=stable&color=orange)](https://github.com/LuoxuanLove/godot-dotnet-mcp/releases/latest) [![Latest Pre-release](https://img.shields.io/badge/pre--release-v1.0.0--pre2-orange)](https://github.com/LuoxuanLove/godot-dotnet-mcp/releases) [![中文 README](https://img.shields.io/badge/README-%E4%B8%AD%E6%96%87-1677ff)](README.zh-CN.md)

> A Godot 4.6+ editor plugin that exposes the live Godot editor through MCP: project state, scene editing, script analysis, runtime control, screenshots, logs, and client setup from inside the editor itself.

Godot .NET MCP is built for clients that need the current editor state instead of file snapshots alone. It provides MCP tools for reading project health, inspecting scenes, editing scripts, controlling play mode, capturing screenshots, and setting up clients. C# analysis stays self-contained through a plugin-internal Roslyn syntax layer, with no external host process required.

![Godot .NET MCP Tools](asset_library/tools-en.png)

## Why it exists

Godot editor work often depends on state that is not fully represented by files: the active scene, current dock state, runtime errors, editor UI, client configuration, screenshots, and whether a tool is available in the running session. Godot .NET MCP exposes those states and operations as explicit MCP tools so clients can inspect the editor before changing scenes, scripts, resources, or runtime state.

## Highlights

- **Editor-native MCP service**: the local MCP service runs inside Godot, so tools observe the current editor session instead of a stale copy of the project.
- **Inspect before editing**: agents can first read the open project, active editor state, recent errors, and available tools, then move into files, scenes, scripts, runtime diagnostics, or UI control.
- **Godot .NET support**: plugin-internal Roslyn powers C# syntax diagnostics, C# file reading/patching, `.csproj` support, solution/project inspection, and C# scene binding audits.
- **Visual editor awareness**: agents can capture the editor, inspect visible or hidden controls, and activate docks, bottom panels, controls, and popups through Godot editor APIs.
- **Runtime automation loop**: run/stop scenes, enable runtime control, inject inputs, capture frames, and use `system_runtime_step` for input-wait-capture workflows.
- **One-click client setup**: the Config page helps connect common CLI and desktop agents, showing detected paths, config targets, generated JSON, and install/remove actions where supported.
- **User-extensible tools**: drop `user_*` GDScript tools into `custom_tools/`; the plugin discovers and hot-reloads them without rebuilding the plugin.

## Screenshots

| Home | Tools | Config |
|---|---|---|
| ![Home dashboard](asset_library/home-en.png) | ![Tool browser](asset_library/tools-en.png) | ![Client configuration](asset_library/config-en.png) |

The Home page shows service health, service address, connection activity, self-diagnostics, reload controls, port, log level, and language. The Tools page lists available tools, enabled state, and tool descriptions. The Config page generates client setup for desktop and CLI clients, including detected paths and copyable configuration.

## What agents can do

### Understand the project and editor

- `system_help` returns the current capability guide, recommended first steps, screenshot guidance, hidden-control hints, and schema facts.
- `system_project_state` summarizes project health, file counts, runtime state, recent errors, compile errors, and optional runtime health.
- `system_editor_state` aggregates the editor workspace, Inspector/FileSystem selection, project runtime summary, and runtime-control state.
- `system_plugin_reload` provides the stable Agent-callable plugin lifecycle reload and freshness check used after syncing addon files.

### Work with files, scenes, and scripts

- `system_project_files` covers common project FileSystem operations.
- `system_resource_reference_audit` scans `.tscn` / `.tres` UID + fallback path consistency and C# custom Resource script references, including risks that can remain after `dotnet build` succeeds.
- `system_scene_validate`, `system_scene_analyze`, `system_scene_tree`, and `system_scene_patch` inspect and edit scenes through structured workflows.
- `system_script_analyze`, `system_script_patch`, and `system_bindings_audit` inspect GDScript/C# structure and C# scene bindings.
- `system_project_symbol_search` and `system_scene_dependency_graph` provide indexed project lookup and scene dependency views.

### Operate the editor and runtime

- `system_editor_control` activates workspaces, docks, bottom panels, controls, popups, captures the editor UI, reports UI coordinate mapping, and can dispatch control-local left/right clicks.
- `system_editor_log` reads, filters, or clears the editor Output panel.
- `system_project_run`, `system_project_stop`, `system_runtime_diagnose`, `system_runtime_control`, and `system_runtime_step(action=step|capture|input)` provide scene execution, runtime diagnostics, screenshots, and scripted input loops.
- `system_project_state(include_runtime_health=true)` and `system_editor_state` expose `runtime_capabilities` so agents can distinguish read-only project access from the ability to start, control, or capture a runtime session.
- `system_userdata_maintenance` lists and cleans plugin-managed editor/runtime capture caches under `user://godot_dotnet_mcp/` with dry-run previews by default.

## Requirements

- Godot `4.6+` with .NET support.
- A Godot project with .NET scripting enabled when C# analysis is needed.
- An MCP-capable client. The Config page currently targets common clients including Claude Code, Codex, Gemini CLI, OpenCode, Qwen Code, Claude Desktop, Cursor, Trae, Windsurf, Cline, Roo Code, and Cherry Studio.

## Installation

### Godot Asset Library

Open your project in Godot, go to the `AssetLib` tab, search for `Godot .NET MCP`, and click `Install`. You can also open its [Godot Asset Library page](https://godotengine.org/asset-library/asset/4923). After installation, your Godot project should contain:

```text
addons/godot_dotnet_mcp
```

Go to `Project Settings > Plugins`, enable `Godot .NET MCP`, open `MCPDock`, and start the service from the `Home` tab.

### Source workflow

For development or local testing, copy `addons/godot_dotnet_mcp/` from this repository into the target Godot project's `addons/` directory, then enable the plugin in the same way. Copying files only updates the disk copy: an already-running Godot editor keeps the old plugin instance until you call `system_plugin_reload(action="full_reload_plugin")` or disable and re-enable the plugin. Check `/health`, `system_plugin_reload(action="get_freshness")`, or `plugin_runtime_state(action="get_self_health")` for `freshness.needs_lifecycle_reload` when validating a synced addon.

## Quick start

1. Enable the plugin and open `MCPDock > Home`.
2. Confirm the service address, usually `http://127.0.0.1:3000/mcp`.
3. Open `MCPDock > Config`, choose your client, and copy or write the generated configuration.
4. From the agent, call `system_help` first.
5. Use `system_project_state` or `system_editor_state` before editing.

Basic checks:

```text
GET  http://127.0.0.1:3000/health
GET  http://127.0.0.1:3000/api/tools
POST http://127.0.0.1:3000/mcp
```

Security note: the local HTTP server does not return wildcard CORS headers by default. CLI and desktop MCP clients that connect directly to `127.0.0.1` do not need CORS. Browser-based clients must be explicitly allowlisted with the `GODOT_DOTNET_MCP_ALLOWED_CORS_ORIGINS` environment variable, using comma-separated exact origins such as `http://localhost:5173`.

## Architecture in one minute

Godot .NET MCP is a self-contained Godot editor plugin. The HTTP server, MCP JSON-RPC routing, tool registry, runtime state, client configuration, UI model, localization, and Roslyn syntax support all live inside `addons/godot_dotnet_mcp/`.

The tools exposed to agents are intentionally task-oriented. Instead of asking users to pick low-level editor operations, the plugin groups common work such as checking project state, editing scenes, reading logs, capturing screenshots, and controlling runtime sessions into stable tools. Detailed implementation links remain available in the Tools page for users who want to inspect how each tool is wired.

The C# layer uses Roslyn's official syntax tree APIs in a syntax-first mode: it extracts useful structure from `CSharpSyntaxTree` without loading a full SemanticModel or project workspace. That keeps the plugin portable, lightweight, and aligned with the Godot editor runtime.

## Custom tools

Create user tools under:

```text
addons/godot_dotnet_mcp/custom_tools/
```

Each `.gd` file should expose `handles()`, `get_tools()`, and `execute()`. Tool names must use the `user_` prefix. Valid tools appear alongside System tools in the Tools page and MCP tool list.

## Documentation

- [中文 README](README.zh-CN.md)
- [Changelog](CHANGELOG.md)
- [Documentation overview](docs/概述.md)
- [Architecture overview](docs/架构/概述.md)
- [System tool layer](docs/模块/System工具层.md)
- [Tool system](docs/模块/工具系统.md)
- [User extensions](docs/模块/用户扩展.md)
- [Installation and release](docs/架构/安装与发布.md)

## Current status

`v1.0.0-pre2` is the current pre-release, covering the System tool layer, editor/runtime automation, client setup, plugin-internal Roslyn support, user-tool hot reload, localized Dock UI, and release validation work. See [CHANGELOG.md](CHANGELOG.md) for version-by-version details.
