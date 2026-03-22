# Godot .NET MCP Plugin
[![Latest Release](https://img.shields.io/github/v/release/LuoxuanLove/godot-dotnet-mcp?label=release)](https://github.com/LuoxuanLove/godot-dotnet-mcp/releases/latest)
[![中文 README](https://img.shields.io/badge/README-%E4%B8%AD%E6%96%87-1677ff)](README.zh-CN.md)

> This plugin is the Godot editor-side companion for `Central Server`. It exposes live editor tools, maintains attach state, and provides local diagnostics inside `MCPDock`.

![Godot .NET MCP Tools](asset_library/preview-tools-en.png)

## Plugin Role In v1.0

- Executes editor-required `system_*` tools from the live Godot process.
- Attaches to `Central Server` and keeps heartbeat / detach lifecycle data.
- Shows local server, attach, install, and diagnostics state in `MCPDock`.
- Hosts `user_*` custom tools from `custom_tools/`.

The plugin is no longer the recommended public MCP server entry point. External clients should connect to `Central Server`, not directly to the plugin runtime.

## Install Into A Godot Project

Copy this directory into your project:

```text
addons/godot_dotnet_mcp
```

Then:

1. Open the project in Godot.
2. Enable `Godot .NET MCP` in `Project Settings > Plugins`.
3. Open `MCPDock`.
4. Use the `Server` tab to inspect or bootstrap the local `Central Server`.

## What The Plugin Provides

- Live project inspection and editor-state tools such as `system_project_state`.
- Runtime diagnostics such as `system_runtime_diagnose`.
- Scene, script, symbol, and C# binding analysis tools.
- Local custom tool loading from `custom_tools/`.

## Custom Tools

Create `.gd` files under:

```text
addons/godot_dotnet_mcp/custom_tools/
```

Each tool file should implement:

- `handles()`
- `get_tools()`
- `execute()`

All exposed tool names must use the `user_` prefix.

## Refactor Notes

- v1.0 is moving toward `Central Server` as the only public MCP host.
- The embedded plugin-side HTTP transport is transitional and should be treated as an internal host-to-plugin channel.
- The plugin README and architecture docs will keep being updated during the refactor until the user explicitly confirms completion.

## Docs

- [README.zh-CN.md](README.zh-CN.md)
- [../../README.md](../../README.md)
- [../../docs/架构/服务与路由.md](../../docs/架构/服务与路由.md)
- [../../docs/架构/安装与发布.md](../../docs/架构/安装与发布.md)
