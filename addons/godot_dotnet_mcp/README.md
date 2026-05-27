# Godot .NET MCP
[![Latest Stable](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.github.com%2Frepos%2FLuoxuanLove%2Fgodot-dotnet-mcp%2Freleases%2Flatest&query=%24.tag_name&label=stable&color=orange)](https://github.com/LuoxuanLove/godot-dotnet-mcp/releases/latest) [![Chinese README](https://img.shields.io/badge/README-%E4%B8%AD%E6%96%87-1677ff)](README.zh-CN.md)

> An MCP server plugin running inside the Godot editor. MCP clients can read live project state, manipulate scenes and scripts, and diagnose C# bindings without any external process.

![Godot .NET MCP Tools](https://raw.githubusercontent.com/LuoxuanLove/godot-dotnet-mcp/main/asset_library/tools-en.png)

## What It Is

An MCP service embedded in the Godot editor process. Call `system_project_state` to get a real snapshot of the open project —scene count, script count, errors, run state —then use scene, script, node, or resource tools to make targeted changes based on the observed state.

The System layer is the intended starting point for agents. It provides project-level snapshots, project file-tree changes, editor-session snapshots, editor UI control, editor log access, runtime diagnostics, scene analysis, current scene-tree changes, script structure inspection, C# binding auditing, and symbol search —all reading from the live editor, not disk snapshots.

After connecting, MCP clients can also use the built-in resources and prompts surface to read project info, diagnostics, selected scene/script/resource files, and guided workflow prompts. Call `system_help` for the current capability guide and schema version. For any Dock, popup, layout, focus, or button-visibility task, prefer `system_editor_control(action=activate_ui)` and `system_editor_control(action=capture_editor)` through Godot editor APIs before acting; do not use OS mouse/window automation unless the user explicitly authorizes foreground automation. If visible control enumeration misses the target, retry `system_editor_control(action=list_controls, include_hidden=true)`. Dock-owned popup UI keeps coordinate spaces explicit: Control-local click positions must be converted through viewport or screen helpers as appropriate, and `PopupMenu.popup(Rect2i)` receives screen coordinates rather than local or canvas-global positions.

For plugin-side runtime introspection, use `plugin_runtime_state` instead of a separate self-check tool. `action=get_lsp_diagnostics_status` is the detailed LSP diagnostics status entry; System tools only expose lightweight health summaries, including `project_state(include_runtime_health=true)` for `self_diagnostics`, `lsp_diagnostics`, and `tool_loader` status.

For GDScript diagnostics, `system_script_analyze(include_diagnostics=true)` returns structure data immediately and fills LSP diagnostics in the background from the saved file content on disk. The first call may return `pending`; later calls return the cached result. Unsaved editor buffer changes are excluded.

To extend the tool set: place a `.gd` file in `custom_tools/` implementing `handles / get_tools / execute`, with all tool names prefixed `user_`. The plugin picks it up automatically. `plugin_evolution` tools handle scaffolding, auditing, and removal from the Dock or via MCP.

## Why This Plugin

- **Editor-native**: Runs inside the Godot process. Scene queries, script reads, and property changes reflect the actual live editor state.
- **Godot.NET first**: C# binding inspection (`system_bindings_audit`), exported member analysis, and `.cs` script patching are built in.
- **Inspect before editing**: agents can first read project health, editor state, recent errors, and available tools, then move into files, scenes, scripts, runtime diagnostics, or UI control.
- **User-extensible**: `custom_tools/` scripts are loaded as first-class tools with no plugin rebuild. `plugin_evolution` manages the lifecycle.

## Requirements

- Godot `4.6+`
- Godot Mono / .NET build recommended
- An MCP client such as:
  - Claude Code
  - Codex CLI
  - Gemini CLI
  - OpenCode
  - Qwen Code
  - Claude Desktop
  - Cursor
  - Trae
  - Windsurf
  - Cline
  - Roo Code
  - Cherry Studio

## Installation

### Option 1: Install from Godot Asset Library

Open your project in Godot, go to the `AssetLib` tab, search for `Godot .NET MCP`, and click `Install`. You can also open its Godot Asset Library page:

```text
https://godotengine.org/asset-library/asset/4923
```

After installation, the final structure should be:

```text
addons/godot_dotnet_mcp
```

Then:

1. Open the project in Godot.
2. Go to `Project Settings > Plugins`.
3. Enable `Godot .NET MCP`.
4. Open `MCPDock` from the right-side dock.
5. Confirm the port and start the service.

### Option 2: Copy source files directly

Place the plugin in your Godot project:

```text
addons/godot_dotnet_mcp
```

Then:

1. Open the project in Godot.
2. Go to `Project Settings > Plugins`.
3. Enable `Godot .NET MCP`.
4. Open `MCPDock` from the right-side dock.
5. Confirm the port and start the service.

## Quick Start

### 1. Start the local service

After enabling the plugin, the service can start automatically from saved settings, or start manually from `MCPDock > Home`.

Health check:

```text
GET http://127.0.0.1:3000/health
```

Tool list:

```text
GET http://127.0.0.1:3000/api/tools
```

MCP service address:

```text
POST http://127.0.0.1:3000/mcp
```

### 2. Connect a client

Open `MCPDock > Config`, choose a target platform, then inspect or copy the generated output.

- Desktop clients show JSON config, target path, and write/remove actions
- CLI clients show the generated command text plus one-click add/remove when the upstream CLI supports it
- `Claude Code` additionally supports `user / project` scope switching
- `Gemini CLI` supports the same `user / project` scope switching pattern through its active `settings.json`
- Installed clients show an explicit `Installed to` status with the concrete config path or CLI scope.

Recommended order:

1. Select the target client.
2. Confirm the generated service address and config content.
3. Use `Write Config` if you want the plugin to update the target file.
4. Use `Copy` if you want to apply the config manually.

### 3. Verify the connection

Confirm that:

- `/health` returns normally and includes `tool_loader_status` so empty or degraded tool registries are explicit
- `/api/tools` returns the current high-level MCP tool list; internal lower-level tools remain visible in the Dock tool tree as implementation details where applicable
- your MCP client can connect to `http://127.0.0.1:3000/mcp`

### 4. Read the latest project runtime state

Use `system_runtime_diagnose` to read structured runtime information —errors, compile issues, and performance data —from the most recent editor-run session. Works after the project stops.

## Path Conventions

- Resource paths use `res://`
- Node paths should normally be relative to the current scene root, for example `Player/Camera2D`
- `/root/...` style paths are also supported
- Write operations are expected to be readable back after execution

## Docs

- [README.zh-CN.md](README.zh-CN.md)
- Release notes are maintained in the repository root as `CHANGELOG.md` and `CHANGELOG.zh-CN.md`.
- [docs/模块/System工具层.md](docs/%E6%A8%A1%E5%9D%97/System%E5%B7%A5%E5%85%B7%E5%B1%82.md)
- [docs/模块/工具系统.md](docs/%E6%A8%A1%E5%9D%97/%E5%B7%A5%E5%85%B7%E7%B3%BB%E7%BB%9F.md)
- [docs/模块/用户扩展.md](docs/%E6%A8%A1%E5%9D%97/%E7%94%A8%E6%88%B7%E6%89%A9%E5%B1%95.md)
- [docs/架构/服务与路由.md](docs/%E6%9E%B6%E6%9E%84/%E6%9C%8D%E5%8A%A1%E4%B8%8E%E8%B7%AF%E7%94%B1.md)
- [docs/架构/配置与界面.md](docs/%E6%9E%B6%E6%9E%84/%E9%85%8D%E7%BD%AE%E4%B8%8E%E7%95%8C%E9%9D%A2.md)
- [docs/架构/安装与发布.md](docs/%E6%9E%B6%E6%9E%84/%E5%AE%89%E8%A3%85%E4%B8%8E%E5%8F%91%E5%B8%83.md)

## Current Boundaries

- Runtime debug readback supports structured project-side bridge events and editor debugger session state; it does not mirror the native Godot Output / Debugger panels 1:1
- `system_runtime_diagnose` is the recommended tool for reading runtime state
- The latest captured session state and basic lifecycle events remain readable after the project stops; real-time observation still requires the project to be running
- Capabilities that depend on live editor state should be validated in a real project workflow
