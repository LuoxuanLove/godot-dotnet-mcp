<div align="center">
  <a href="#godot-net-mcp"><img src="asset_library/hero.svg" alt="GODOT .NET MCP - Editor-native MCP bridge for Godot .NET" width="960"></a>
</div>

<p align="center"><a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/releases/latest"><img alt="Latest Stable" src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.github.com%2Frepos%2FLuoxuanLove%2Fgodot-dotnet-mcp%2Freleases%2Flatest&amp;query=%24.tag_name&amp;label=stable&amp;color=f59e0b&amp;style=flat-square&amp;labelColor=24292f"></a> <a href="https://godotengine.org/"><img alt="Godot 4.6+" src="https://img.shields.io/badge/Godot-4.6%2B-478cbf?style=flat-square&amp;labelColor=24292f"></a> <a href="https://dotnet.microsoft.com/"><img alt=".NET 8" src="https://img.shields.io/badge/.NET-8-512bd4?style=flat-square&amp;labelColor=24292f"></a> <a href="https://godotengine.org/asset-library/asset/4923"><img alt="Godot Asset Library 4923" src="https://img.shields.io/badge/Godot%20Asset%20Library-4923-478cbf?style=flat-square&amp;labelColor=24292f"></a> <a href="LICENSE"><img alt="License: Apache-2.0" src="https://img.shields.io/badge/license-Apache--2.0-22c55e?style=flat-square&amp;labelColor=24292f"></a></p>

<p align="center"><a href="README.md">English</a> | <a href="docs/zh-CN/说明.md">简体中文</a> | <a href="docs/ja/はじめに.md">日本語</a> | <a href="docs/ko/소개.md">한국어</a></p>

| Home | Tools | Resources | Prompts | Config | Settings |
|---|---|---|---|---|---|
| ![Home dashboard](asset_library/home-en.png) | ![Tool browser](asset_library/tools-en.png) | MCP resource catalog | MCP workflow prompts | ![Client configuration](asset_library/config-en.png) | Plugin settings |

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
| 🎛️ | **Editor-native MCP service** | Runs inside the Godot editor and exposes live project, editor, and runtime state without a separate background service. |
| 🚀 | **Setup, updates, and clients** | Installs from the Godot Asset Library, generates client configuration, manages plugin updates, and reports client capability guidance from the Dock. |
| 🧭 | **Semantic editor automation** | Gives agents high-level workflows for settings, Inspector properties, menus, popups, controls, and UI waits before falling back to mouse-style input. |
| 🪟 | **Evidence-aware editor context** | Captures editor, control, popup, active-dialog, and runtime surfaces with metadata that explains targets, fallbacks, and observed state. |
| 🌳 | **Project understanding and diagnostics** | Inspects scenes, resources, dependencies, input/export configuration, C# script structure, diagnostics, and binding consistency before editing. |
| ▶️ | **Runtime lifecycle and debugging** | Starts and stops runtime sessions, waits for validation markers, inspects runtime errors, sends input, captures frames, and reads Godot DAP state. |
| 📚 | **Discoverable MCP workflows** | Provides localized resources, prompt guides, tool catalog search, activity diagnostics, and help surfaces so clients can choose the right tool path. |
| 🧰 | **Extensible User tools** | Hot-loads project-defined GDScript tools, reports public tool names and compatibility diagnostics, and keeps custom capabilities visible to MCP clients. |

## Installation

### From the Godot Asset Library

1. Open your project in Godot.
2. Open the `AssetLib` tab.
3. Search for `Godot .NET MCP`.
4. Install the plugin.
5. Go to `Project Settings > Plugins` and enable `Godot .NET MCP`.
6. Open `MCPDock` and start the service from `Home`.

### Direct Copy

Copy the installable addon contents into your Godot project. Use the Asset Library download or a prepared installable addon tree, not a raw repository checkout; the raw source tree contains internal bridge projects such as `dotnet_bridge/` that are intentionally kept out of a host project compile surface. Keep `plugin/runtime/roslyn_runtime/` in the copied addon so C# semantic tools retain their isolated Roslyn runtime bundle:

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

- [简体中文说明](docs/zh-CN/说明.md)
- [日本語ドキュメント](docs/ja/はじめに.md)
- [한국어 문서](docs/ko/소개.md)
- [Changelog](docs/en/CHANGELOG.md)
- [Documentation overview](docs/en/overview.md)
- [Server and Config pages](docs/en/interface/server-and-config-pages.md)
- [Release runbook](docs/en/process/release-runbook.md)

## Author's Note

Although I am only a student, I am deeply passionate about making games. I once wrote an entire rhythm game project by myself the old-fashioned way. To be honest, wrestling with code details and debugging was painful.

In the AI era, everything changed, and code became cheap. After discovering great concepts like agents and MCP, I was ecstatic. I wanted AI to turn my ideas into reality simply and quickly, and to autonomously complete design, development, validation, and everything else.

So I decided to write this MCP plugin myself, and to use it personally while building my own game. This great plugin will be battle-tested by me in real work; I will hit the pitfalls first, polish it, and fix it for you.

Even though 100% of this project's code is generated directly by AI, I have prepared the strictest automated checks, development flow, and release flow I can, so AI-written code is verified as much as possible before it enters an official version.

After reading all this, why not try Godot .NET MCP? I will keep studying the market, stealing the strongest ideas, and updating them here; it will become the tightest connection between your agent and your game project.

Does that sound arrogant? Maybe. If you have a more badass implementation idea, send a PR. You are very welcome!

## License

Apache-2.0. See [LICENSE](LICENSE).
