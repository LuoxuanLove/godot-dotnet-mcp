# Godot .NET MCP
[![Latest Stable](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.github.com%2Frepos%2FLuoxuanLove%2Fgodot-dotnet-mcp%2Freleases%2Flatest&query=%24.tag_name&label=stable&color=orange)](https://github.com/LuoxuanLove/godot-dotnet-mcp/releases/latest) [![Chinese Docs](https://img.shields.io/badge/docs-%E4%B8%AD%E6%96%87-1677ff)](https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/dev/docs/zh-CN/%E8%AF%B4%E6%98%8E.md)

> An MCP server plugin running inside the Godot editor. MCP clients can read live project state, manipulate scenes and scripts, and diagnose C# bindings without any external process.

![Godot .NET MCP Tools](https://raw.githubusercontent.com/LuoxuanLove/godot-dotnet-mcp/refs/heads/dev/asset_library/tools-en.png)

## What It Is

An MCP service embedded in the Godot editor process. Call `system_project_state` to get a real snapshot of the open project —scene count, script count, errors, run state —then use scene, script, node, or resource tools to make targeted changes based on the observed state.

The System layer is the intended starting point for agents. It provides project-level snapshots, project file-tree changes, editor-session snapshots, editor UI control, editor log access, runtime diagnostics, scene analysis, current scene-tree changes, script structure inspection, C# binding auditing, and symbol search —all reading from the live editor, not disk snapshots.

After connecting, MCP clients can also use the built-in resources and prompts surface to read project info, diagnostics, selected scene/script/resource files, and guided workflow prompts. Call `system_help` for the current capability guide and schema version. For any Dock, popup, layout, focus, or button-visibility task, prefer semantic workflow tools first, then `system_editor_control(action=activate_ui)` and other control-level operations through Godot editor APIs. For visual checks, prefer `system_editor_evidence(action=capture, surface=auto/editor/control/popup/active_dialog)` so the screenshot metadata explains the captured surface, target, fallback, and degradation state; do not use OS mouse/window automation unless the user explicitly authorizes foreground automation. If visible control enumeration misses the target, retry `system_editor_control(action=list_controls, include_hidden=true)`. Dock-owned popup UI keeps coordinate spaces explicit: Control-local click positions must be converted through viewport or screen helpers as appropriate, and `PopupMenu.popup(Rect2i)` receives screen coordinates rather than local or canvas-global positions.

For plugin-side runtime introspection, use `plugin_runtime_state` instead of a separate self-check tool. `action=get_lsp_diagnostics_status` is the detailed LSP diagnostics status entry; System tools only expose lightweight health summaries, including `project_state(include_runtime_health=true)` for `self_diagnostics`, `lsp_diagnostics`, and `tool_loader` status.

For GDScript diagnostics, `system_script_analyze(include_diagnostics=true)` returns structure data immediately and fills LSP diagnostics in the background from the saved file content on disk. The first call may return `pending`; later calls return the cached result. Unsaved editor buffer changes are excluded.

To extend the tool set: place a `.gd` file in `custom_tools/` implementing `handles / get_tools / execute`. User tools are exposed publicly with the `user_` MCP prefix; inside `get_tools()`, prefer declaring the logical name without that public domain prefix. The plugin picks it up automatically. `plugin_evolution` tools handle scaffolding, auditing, and removal from the Dock or via MCP.

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

- [简体中文说明](https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/dev/docs/zh-CN/%E8%AF%B4%E6%98%8E.md)
- Release notes and changelogs are maintained under [`docs/en/CHANGELOG.md`](https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/dev/docs/en/CHANGELOG.md), [`docs/zh-CN/变更日志.md`](https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/dev/docs/zh-CN/%E5%8F%98%E6%9B%B4%E6%97%A5%E5%BF%97.md), [`docs/ja/変更履歴.md`](https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/dev/docs/ja/%E5%A4%89%E6%9B%B4%E5%B1%A5%E6%AD%B4.md), and [`docs/ko/변경-로그.md`](https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/dev/docs/ko/%EB%B3%80%EA%B2%BD-%EB%A1%9C%EA%B7%B8.md).
- [docs/en/overview.md](https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/dev/docs/en/overview.md)
- [docs/en/interface/server-and-config-pages.md](https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/dev/docs/en/interface/server-and-config-pages.md)
- [docs/en/interface/tools-page.md](https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/dev/docs/en/interface/tools-page.md)
- [docs/en/process/release-runbook.md](https://github.com/LuoxuanLove/godot-dotnet-mcp/blob/dev/docs/en/process/release-runbook.md)

## Current Boundaries

- Runtime debug readback supports structured project-side bridge events and editor debugger session state; it does not mirror the native Godot Output / Debugger panels 1:1
- `system_runtime_diagnose` is the recommended tool for reading runtime state
- The latest captured session state and basic lifecycle events remain readable after the project stops; real-time observation still requires the project to be running
- Capabilities that depend on live editor state should be validated in a real project workflow
