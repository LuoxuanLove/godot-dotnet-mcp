# Godot .NET MCP
[![Chinese README](https://img.shields.io/badge/README-%E4%B8%AD%E6%96%87-1677ff)](README.zh-CN.md)

> This project is aimed at an AI-native Godot editor experience, not just another MCP server wrapper.
> Its real leverage comes from letting agents understand live Godot projects, scene structure, scripts, and editor state directly, rather than only forwarding commands into the engine.
[![Latest Release](https://img.shields.io/github/v/release/LuoxuanLove/godot-dotnet-mcp?label=release)](https://github.com/LuoxuanLove/godot-dotnet-mcp/releases/latest)
[![Download ZIP](https://img.shields.io/badge/download-latest%20zip-2ea44f)](https://github.com/LuoxuanLove/godot-dotnet-mcp/releases/latest/download/godot-dotnet-mcp-0.3.0.zip)

`Godot .NET MCP` is an editor-native, self-evolving MCP plugin for Godot 4 and Godot.NET. It runs inside the editor, exposes live project capabilities to MCP clients, and can grow User tools through explicit authorization.

Current public version: `v0.3.0`

## What It Is

It is an MCP endpoint that runs inside the Godot editor, not a detached daemon.

It gives agents live access to the real project context, and extends itself through authorized User tools instead of hidden background automation.

## Why This Plugin

- **Godot.NET first**: it is designed for general Godot projects, but treats Godot.NET and C# scene bindings, exported members, and script inspection as first-class capabilities.
- **Editor-native**: no extra background service is required; startup, configuration, and debugging stay close to the editor lifecycle.
- **Extensible**: tool loading is split by domain and supports hot reload, custom tool discovery, and incremental capability growth.
- **Self-evolving**: the plugin can scaffold, load, audit, and remove authorized User tools without writing into builtin categories.
- **Built for real client integration**: the focus is not a demo endpoint, but a usable connection path for MCP clients through profiles, config generation, copy, and write flows.

## Key Features

- HTTP + MCP endpoint, defaulting to `http://127.0.0.1:3000/mcp`
- Dock UI for port, language, tool profile, and client configuration management
- Platform-specific config generation for desktop and CLI clients
- Config copy and one-click write flows
- Full plugin reload and domain-level hot reload
- Coverage across the main Godot editor workflows for project, scene, script, and resource operations
- Custom tool script discovery, loading, invocation, and cleanup
- Runtime bridge readback through `debug_runtime_bridge`, including debugger session state and the latest captured project lifecycle events

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

Place the plugin in your Godot project as:

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

```bash
git submodule add https://github.com/LuoxuanLove/godot-dotnet-mcp.git addons/godot_dotnet_mcp
git submodule update --init --recursive
```

For a fresh clone:

```bash
git clone --recurse-submodules <your-project-repo>
```

### Option 3: Use the release package

Download the latest package from:

```text
https://github.com/LuoxuanLove/godot-dotnet-mcp/releases
```

Extract it so the final structure remains:

```text
addons/godot_dotnet_mcp
```

Then enable it as described in Option 1.

## Quick Start

### 1. Start the local service

After enabling the plugin, the service can start automatically from saved settings, or you can start it manually from `MCPDock > Server`.

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

- `/health` returns normally
- `/api/tools` returns the tool list
- your MCP client can connect to `http://127.0.0.1:3000/mcp`

### 4. Read the latest project runtime state

Use `debug_runtime_bridge` to read structured runtime information from the last editor-run project session.

- `get_sessions` returns the latest debugger session state even after the project has stopped
- `get_recent` returns the latest captured lifecycle events such as `enter_tree`, `ready`, `close_requested`, and `exit_tree`
- the project does not need to stay running to read the most recent captured session and lifecycle events

## Path Conventions

- Resource paths use `res://`
- Node paths should normally be relative to the current scene root, for example `Player/Camera2D`
- `/root/...` style paths are also supported in the current version
- Write operations are expected to be readable back after execution

## Repository Migration

- The GitHub repository name is `godot-dotnet-mcp`
- The Godot installation directory stays `addons/godot_dotnet_mcp`
- If you are migrating from an older repository URL, update the submodule URL and run:

```bash
git submodule sync --recursive
git submodule update --init --recursive
```

## Docs

- [README.zh-CN.md](README.zh-CN.md)
- [CHANGELOG.md](CHANGELOG.md)
- [docs/架构/服务与路由.md](docs/%E6%9E%B6%E6%9E%84/%E6%9C%8D%E5%8A%A1%E4%B8%8E%E8%B7%AF%E7%94%B1.md)
- [docs/架构/配置与界面.md](docs/%E6%9E%B6%E6%9E%84/%E9%85%8D%E7%BD%AE%E4%B8%8E%E7%95%8C%E9%9D%A2.md)
- [docs/架构/安装与发布.md](docs/%E6%9E%B6%E6%9E%84/%E5%AE%89%E8%A3%85%E4%B8%8E%E5%8F%91%E5%B8%83.md)
- [docs/模块/工具系统.md](docs/%E6%A8%A1%E5%9D%97/%E5%B7%A5%E5%85%B7%E7%B3%BB%E7%BB%9F.md)
- [docs/模块/自进化系统.md](docs/%E6%A8%A1%E5%9D%97/%E8%87%AA%E8%BF%9B%E5%8C%96%E7%B3%BB%E7%BB%9F.md)

## Current Boundaries

- Runtime debug readback now supports structured project-side bridge events and editor debugger session state, but it still does not mirror the native Godot Output / Debugger panels 1:1
- The correct MCP tool name for this capability is `debug_runtime_bridge`
- The latest captured session state and basic lifecycle events remain readable after the project stops, but real-time observation still requires the project to be running
- Capabilities that depend on live editor state should still be validated in a real project workflow
