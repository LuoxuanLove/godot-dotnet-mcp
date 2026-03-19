# Godot .NET MCP
[![Latest Release](https://img.shields.io/github/v/release/LuoxuanLove/godot-dotnet-mcp?label=release)](https://github.com/LuoxuanLove/godot-dotnet-mcp/releases/latest) [![Chinese README](https://img.shields.io/badge/README-%E4%B8%AD%E6%96%87-1677ff)](README.zh-CN.md)

> An MCP server plugin running inside the Godot editor 鈥?agents read live project state, manipulate scenes and scripts directly, and diagnose C# bindings without any external process.

![Godot .NET MCP Tools](asset_library/preview-tools-en.png)

## What It Is

An MCP endpoint embedded in the Godot editor process. Call `intelligence_project_state` to get a real snapshot of the open project 鈥?scene count, script count, errors, run state 鈥?then `intelligence_project_advise` for specific, actionable recommendations. From there, use scene, script, node, or resource tools to make targeted changes.

The Intelligence layer (15 built-in tools) is the intended starting point for agents. It provides project-level snapshots, scene analysis, script structure inspection, C# binding auditing, and symbol search 鈥?all reading from the live editor, not disk snapshots.

For plugin-side runtime introspection, use `plugin_runtime_state` instead of a separate self-check tool. `action=get_lsp_diagnostics_status` is the detailed LSP diagnostics status entry; Intelligence tools only expose lightweight health summaries, including `project_state(include_runtime_health=true)` for `lsp_diagnostics` and `tool_loader` status.

For GDScript diagnostics, `intelligence_script_analyze(include_diagnostics=true)` returns structure data immediately and fills LSP diagnostics in the background from the saved file content on disk. The first call may return `pending`; later calls return the cached result. Unsaved editor buffer changes are not included yet.

To extend the tool set: place a `.gd` file in `custom_tools/` implementing `handles / get_tools / execute`, with all tool names prefixed `user_`. The plugin picks it up automatically. `plugin_evolution` tools handle scaffolding, auditing, and removal from the Dock or via MCP.

## Why This Plugin

- **Editor-native**: Runs inside the Godot process. Scene queries, script reads, and property changes reflect the actual live editor state.
- **Godot.NET first**: C# binding inspection (`intelligence_bindings_audit`), exported member analysis, and `.cs` script patching are built in.
- **Intelligence-first**: `intelligence_project_state` 鈫?`intelligence_project_advise` 鈫?targeted action is the intended workflow. No need to guess which atomic tool to start with.
- **User-extensible**: `custom_tools/` scripts are loaded as first-class tools with no plugin rebuild. `plugin_evolution` manages the lifecycle.

## Requirements

- Godot `4.6+`
- Godot Mono / .NET build recommended
- An MCP client such as:
  - Claude Code
  - Codex CLI
  - Gemini CLI
  - Claude Desktop
  - Cursor

## Installation

### Option 1: Copy the plugin directory

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

### Option 2: Use Git submodule

The repository root contains `addons/godot_dotnet_mcp/` inside it (not at root level). When adding as a submodule, clone to a parent folder:

```bash
git submodule add https://github.com/LuoxuanLove/godot-dotnet-mcp.git _godot-dotnet-mcp
```

The plugin is located at `_godot-dotnet-mcp/addons/godot_dotnet_mcp/`. Copy or symlink that directory into your project's `addons/`. For a simpler setup, use Option 3.

### Option 3: Use the release package

Download the latest package from:

```text
https://github.com/LuoxuanLove/godot-dotnet-mcp/releases
```

Extract it so the final structure is:

```text
addons/godot_dotnet_mcp
```

Then enable it as described in Option 1.

## Quick Start

### 1. Start the local service

After enabling the plugin, the service can start automatically from saved settings, or start manually from `MCPDock > Server`.

Health check:

```text
GET http://127.0.0.1:3000/health
```

Tool list:

```text
GET http://127.0.0.1:3000/api/tools
```

MCP endpoint:

```text
POST http://127.0.0.1:3000/mcp
```

### 2. Connect a client

Open `MCPDock > Config`, choose a target platform, then inspect or copy the generated output.

- Desktop clients show JSON config, target path, and write actions
- CLI clients show the generated command text
- `Claude Code` additionally supports `user / project` scope switching

Recommended order:

1. Select the target client.
2. Confirm the generated endpoint and config content.
3. Use `Write Config` if you want the plugin to update the target file.
4. Use `Copy` if you want to apply the config manually.

### 3. Verify the connection

Confirm that:

- `/health` returns normally and includes `tool_loader_status` so empty or degraded tool registries are explicit
- `/api/tools` returns the current visible MCP tool list for this permission level, including `plugin_runtime_*` when available; visibility filtering is fail-closed
- your MCP client can connect to `http://127.0.0.1:3000/mcp`

### 4. Read the latest project runtime state

Use `intelligence_runtime_diagnose` to read structured runtime information 鈥?errors, compile issues, and performance data 鈥?from the most recent editor-run session. Works after the project stops.

## Path Conventions

- Resource paths use `res://`
- Node paths should normally be relative to the current scene root, for example `Player/Camera2D`
- `/root/...` style paths are also supported
- Write operations are expected to be readable back after execution

## Docs

- [README.zh-CN.md](README.zh-CN.md)
- [CHANGELOG.md](CHANGELOG.md)
- [CHANGELOG.zh-CN.md](CHANGELOG.zh-CN.md)
- [docs/妯″潡/Intelligence宸ュ叿灞?md](docs/%E6%A8%A1%E5%9D%97/Intelligence%E5%B7%A5%E5%85%B7%E5%B1%82.md)
- [docs/妯″潡/宸ュ叿绯荤粺.md](docs/%E6%A8%A1%E5%9D%97/%E5%B7%A5%E5%85%B7%E7%B3%BB%E7%BB%9F.md)
- [docs/妯″潡/鐢ㄦ埛鎵╁睍.md](docs/%E6%A8%A1%E5%9D%97/%E7%94%A8%E6%88%B7%E6%89%A9%E5%B1%95.md)
- [docs/鏋舵瀯/鏈嶅姟涓庤矾鐢?md](docs/%E6%9E%B6%E6%9E%84/%E6%9C%8D%E5%8A%A1%E4%B8%8E%E8%B7%AF%E7%94%B1.md)
- [docs/鏋舵瀯/閰嶇疆涓庣晫闈?md](docs/%E6%9E%B6%E6%9E%84/%E9%85%8D%E7%BD%AE%E4%B8%8E%E7%95%8C%E9%9D%A2.md)
- [docs/鏋舵瀯/瀹夎涓庡彂甯?md](docs/%E6%9E%B6%E6%9E%84/%E5%AE%89%E8%A3%85%E4%B8%8E%E5%8F%91%E5%B8%83.md)

## Current Boundaries

- Runtime debug readback supports structured project-side bridge events and editor debugger session state; it does not mirror the native Godot Output / Debugger panels 1:1
- `intelligence_runtime_diagnose` is the recommended tool for reading runtime state
- The latest captured session state and basic lifecycle events remain readable after the project stops; real-time observation still requires the project to be running
- Capabilities that depend on live editor state should be validated in a real project workflow
