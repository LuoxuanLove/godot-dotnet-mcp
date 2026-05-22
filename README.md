<div align="center">
  <a href="#godot-net-mcp"><img src="asset_library/hero.svg" alt="GODOT .NET MCP - Editor-native MCP bridge for Godot .NET" width="960"></a>
</div>

<p align="center"><a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/releases/latest"><img alt="Latest Stable" src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.github.com%2Frepos%2FLuoxuanLove%2Fgodot-dotnet-mcp%2Freleases%2Flatest&amp;query=%24.tag_name&amp;label=stable&amp;color=f59e0b&amp;style=flat-square&amp;labelColor=24292f"></a> <a href="https://godotengine.org/"><img alt="Godot 4.6+" src="https://img.shields.io/badge/Godot-4.6%2B-478cbf?style=flat-square&amp;labelColor=24292f"></a> <a href="https://dotnet.microsoft.com/"><img alt=".NET 8" src="https://img.shields.io/badge/.NET-8-512bd4?style=flat-square&amp;labelColor=24292f"></a> <a href="https://godotengine.org/asset-library/asset/4923"><img alt="Godot Asset Library 4923" src="https://img.shields.io/badge/Godot%20Asset%20Library-4923-478cbf?style=flat-square&amp;labelColor=24292f"></a> <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-22c55e?style=flat-square&amp;labelColor=24292f"></a></p>

<p align="center"><a href="README.md">English</a> | <a href="README.zh-CN.md">中文</a></p>

| Home | Tools | Config |
|---|---|---|
| ![Home dashboard](asset_library/home-en.png) | ![Tool browser](asset_library/tools-en.png) | ![Client configuration](asset_library/config-en.png) |

# Godot .NET MCP

Godot .NET MCP is an in-editor MCP plugin for Godot 4.6+ .NET projects. It runs directly inside the Godot editor and provides real-time project context to MCP-capable clients, including editor state, the current scene, selected nodes, run information, diagnostics, and screenshots.

The MCP service is built into the Godot plugin. Enable the plugin and start the service from the Dock; you do not need to run any extra background process.

## Why It Exists

A Godot project is more than a pile of `.tscn`, `.tres`, and script files.

The scene you are looking at, the currently selected node, editor output, game runtime view and state, recent errors, and plugin configuration all affect what a change should look like. Godot .NET MCP collects that in-editor context and provides it to MCP clients, so they no longer have to guess the project state from a directory snapshot alone.

If your work mostly happens in the Godot editor and the game runtime, not just in code files, this plugin will be useful.

## Highlights

|       | Feature | What it does |
| :---: | :--- | :--- |
| 🎛️ | **In-editor local MCP plugin** | The MCP service is provided directly by the Godot plugin, with no extra background process required. |
| 🚀 | **Simple installation** | Install it from the Godot Asset Library, or copy the `addons/godot_dotnet_mcp/` source files into your project. |
| 🎮 | **Live Godot editor context** | Provides your agent with the current scene, selected nodes, Dock state, logs, run information, and editor screenshots. |
| 🌳 | **Scene and resource workflows** | Helps inspect scene trees, resource references, dependencies, and scene structure issues. |
| ▶️ | **Game runtime support** | Starts and stops scenes, inspects runtime diagnostics, performs input, and captures game runtime views. |
| 🔎 | **Roslyn-based C# support** | Uses the plugin's internal Roslyn syntax checks to read C# scripts, focusing on structure recognition and diagnostic boundaries. |
| ⚙️ | **Client configuration** | Generates or copies connection settings for common MCP clients from the plugin config page, and opens the current project with one click. |
| 🧰 | **User extensions** | Optionally hot-loads `user_*` GDScript tools from `custom_tools/`. |

## Installation

### From the Godot Asset Library

1. Open your project in Godot.
2. Open the `AssetLib` tab.
3. Search for `Godot .NET MCP`.
4. Install the plugin.
5. Go to `Project Settings > Plugins` and enable `Godot .NET MCP`.
6. Open `MCPDock` and start the service from `Home`.

### From Source

Copy the plugin source directory into your Godot project:

```text
addons/godot_dotnet_mcp
```

Then enable it from `Project Settings > Plugins`.

## First Use

1. Install and enable the plugin in a Godot 4.6+ .NET project.
2. Open `MCPDock`.
3. Start the MCP service from `Home`.
4. Generate or copy your MCP client configuration from the config page.
5. Return to the client and connect to the service, then let it read the current Godot project state.

## Documentation

- [中文 README](README.zh-CN.md)
- [Changelog](CHANGELOG.md)
- [Documentation overview](docs/概述.md)
- [Installation and release](docs/架构/安装与发布.md)
- [User extensions](docs/模块/用户扩展.md)

## Author's Note

Although I am only a student, I am deeply passionate about making games. I once wrote an entire rhythm game project by myself the old-fashioned way. To be honest, wrestling with code details and debugging was painful.

In the AI era, everything changed, and code became cheap. After discovering great concepts like agents and MCP, I was ecstatic. I wanted AI to turn my ideas into reality simply and quickly, and to autonomously complete design, development, validation, and everything else.

After briefly trying some other Godot MCPs, I gave up on them. Faced with my ever-changing game development needs, existing MCPs felt like screwdrivers that could only tighten fixed screws. They were nowhere near enough.

So I decided to write this MCP plugin myself, and to use it personally while building my own game. This great plugin will be battle-tested by me in real work; I will hit the pitfalls first, polish it, and fix it for you.

Try Godot .NET MCP. It will become the tightest connection between your agent and your game project.

As an aside, great open-source projects like oh-my-openagent are what I admire and strive to catch up with. Its authors used AI to build a magnificent palace, then polished every detail with a rigorous workflow. I learned a lot by studying the oh-my-openagent workflow.

At the same time, I am also using opencode + oh-my-openagent to develop this plugin. 100% of this project's code was generated directly by AI. I actually do not understand GDScript. But I promise: this README was personally reviewed and heavily rewritten by me.

Does that sound arrogant? Maybe. If you have a more badass implementation idea, send a PR. You are very welcome!

## License

MIT. See [LICENSE](LICENSE).
