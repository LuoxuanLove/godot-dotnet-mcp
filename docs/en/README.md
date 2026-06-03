<div align="center">
  <a href="#godot-net-mcp"><img src="../../asset_library/hero.svg" alt="GODOT .NET MCP - Editor-native MCP bridge for Godot .NET" width="960"></a>
</div>

<p align="center"><a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/releases/latest"><img alt="Latest Stable" src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.github.com%2Frepos%2FLuoxuanLove%2Fgodot-dotnet-mcp%2Freleases%2Flatest&amp;query=%24.tag_name&amp;label=stable&amp;color=f59e0b&amp;style=flat-square&amp;labelColor=24292f"></a> <a href="https://godotengine.org/"><img alt="Godot 4.6+" src="https://img.shields.io/badge/Godot-4.6%2B-478cbf?style=flat-square&amp;labelColor=24292f"></a> <a href="https://dotnet.microsoft.com/"><img alt=".NET 8" src="https://img.shields.io/badge/.NET-8-512bd4?style=flat-square&amp;labelColor=24292f"></a> <a href="https://godotengine.org/asset-library/asset/4923"><img alt="Godot Asset Library 4923" src="https://img.shields.io/badge/Godot%20Asset%20Library-4923-478cbf?style=flat-square&amp;labelColor=24292f"></a> <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-22c55e?style=flat-square&amp;labelColor=24292f"></p>


| Home | Tools | Config |
|---|---|---|
| ![Home dashboard](../../asset_library/home-en.png) | ![Tools browser](../../asset_library/tools-en.png) | ![Client config](../../asset_library/config-en.png) |

# Godot .NET MCP

Godot .NET MCP is an in-editor MCP plugin for Godot 4.6+ .NET projects. It runs inside the Godot editor and exposes live project context to MCP-compatible clients, including editor state, the current scene, selected nodes, runtime information, diagnostics, and screenshots.

The MCP server is built into the plugin. Enable the plugin and start the server from the Dock. You do not need any extra background process.

## Why it exists

A Godot project is more than a pile of `.tscn`, `.tres`, and script files.

The scene you are viewing, the node you selected, the editor output, the live game view and runtime state, recent errors, and plugin settings all affect how a change should be made. Godot .NET MCP gathers that in-editor context and gives it to MCP clients, so they do not have to guess the project state from a directory listing.

If most of your work happens in the Godot editor and the running game, not just in code files, this plugin is useful.

## Highlights

|       | Feature | What it does |
| :---: | :--- | :--- |
| 🎛️ | **Runs with the editor** | The MCP server is provided directly by the Godot plugin, so no extra background process is needed. |
| 🚀 | **Low-friction setup** | Install it from the Godot Asset Library, generate connection settings for common MCP clients, and update the plugin from GitHub sources. |
| 🎮 | **Live Godot editor context** | Gives your agent the current scene, selected nodes, Dock state, logs, runtime info, diagnostic summaries, and editor screenshots. |
| 🌳 | **Scene, resource, and binding diagnostics** | Helps inspect scene trees, resource references, dependency graphs, scene structure issues, and C# export binding state. |
| ▶️ | **Game runtime support** | Start and stop scenes, inspect runtime diagnostics, send input, and capture live runtime frames. |
| 🔎 | **Roslyn-based C# support** | Reads C# script structure through the built-in Roslyn syntax layer, including classes, base types, methods, enums, and exported members. |
| 🐞 | **Godot DAP debugging** | Reads breakpoints, threads, stack traces, and output events through Godot DAP, and supports pause, continue, and step operations. Managed C# breakpoints still need a separate .NET debugger. |
| 📚 | **MCP Resources and Prompts** | Provides project resources, diagnostic reads, and common Godot workflow prompt guides. |
| 🧰 | **Tool extensions** | Optionally hot-load `user_*` GDScript tools from `custom_tools/` so a project can add its own MCP abilities. |

## Installation

### Install from the Godot Asset Library

1. Open your project in Godot.
2. Open the `AssetLib` tab.
3. Search for `Godot .NET MCP`.
4. Install the plugin.
5. Go to `Project Settings > Plugins` and enable `Godot .NET MCP`.
6. Open `MCPDock` and start the server from `Home`.

### Copy from source

Copy the plugin source directory into your Godot project:

```text
addons/godot_dotnet_mcp
```

Then enable the plugin in `Project Settings > Plugins`.

## First use

1. Install and enable the plugin in a Godot 4.6+ .NET project.
2. Open `MCPDock`.
3. Start the MCP server from `Home`.
4. Generate or copy the configuration for your MCP client from the Config page.
5. Return to the client and connect to the server so it can read the current Godot project state.

## Documentation

- [Change Log](CHANGELOG.md)
- [Roadmap](ROADMAP.md)
- [Documentation Overview](overview.md)
- [Server and Config Pages](interface/server-and-config-pages.md)
- [Tools Page](interface/tools-page.md)
- [Release Runbook](process/release-runbook.md)

## Author's Note

Although I am still a student, I care a lot about making games. I once wrote an entire rhythm game by hand on my own, and to be honest, fighting code details and debugging can be painful.

In the AI era, everything changed and code became cheap. After discovering ideas like agents and MCP, I felt excited and hoped AI could quickly turn my ideas into reality and handle design, development, validation, and everything else on its own.

I decided to write this MCP plugin myself and use it to build my game. This plugin will be tested in real projects by me, and I will keep fixing the bugs and rough edges for you.

Even though 100% of this project was generated directly by AI, I still built strict automated checks, development rules, and release flow so AI-written code gets validated before it reaches a real release.

After reading this far, why not try Godot .NET MCP? I will keep studying the best ideas out there, bring them back here, and turn this into the tightest connection between your agent and your game project.

Does that sound arrogant? Maybe. If you have a better idea, send a PR. It is welcome.

## License

MIT. See LICENSE.
