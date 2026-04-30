# Godot .NET MCP

[![最新正式版](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.github.com%2Frepos%2FLuoxuanLove%2Fgodot-dotnet-mcp%2Freleases%2Flatest&query=%24.tag_name&label=%E6%AD%A3%E5%BC%8F%E7%89%88&color=orange)](https://github.com/LuoxuanLove/godot-dotnet-mcp/releases/latest) [![最新预发布版](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.github.com%2Frepos%2FLuoxuanLove%2Fgodot-dotnet-mcp%2Freleases%3Fper_page%3D1&query=%24%5B0%5D.tag_name&label=%E9%A2%84%E5%8F%91%E5%B8%83%E7%89%88&color=orange)](https://github.com/LuoxuanLove/godot-dotnet-mcp/releases) [![English README](https://img.shields.io/badge/README-English-24292f)](README.md)

> 一个面向 Godot 4.6+ 的编辑器 MCP 插件，让 AI Agent 可以在 Godot 编辑器内部读取项目状态、编辑场景、分析脚本、控制运行时、截图、读取日志并完成客户端接入配置。

Godot .NET MCP 面向的不是“只看文件然后猜”的 Agent，而是需要真正进入 Godot 编辑器工作流的 Agent。它让 Agent 能直接读取项目健康状态、检查场景、修改脚本、控制运行、截图、读取日志并配置 MCP 客户端；C# 分析由插件内 Roslyn 语法层完成，不需要外部宿主进程。

![Godot .NET MCP 工具页](asset_library/tools-cn.png)

## 为什么需要它

AI 编程 Agent 在 Godot 中要真正可靠，不能只读 `.tscn` 和脚本文件。它还需要知道当前打开的场景、Dock 状态、运行时报错、编辑器界面、客户端配置、截图结果，以及工具实际是否可用。Godot .NET MCP 的目标，是把这些用户真正关心的编辑器任务变成 Agent 可以安全调用的工具。

这个项目的设计哲学很直接：提供真实的编辑器工具，而不是伪装成“分析能力”的固定结论。Agent 应先观察项目与编辑器状态，再选择最小、最安全的操作。README 只讲用户能得到什么；内部实现细节留给工具页和技术文档。

## 亮点

- **编辑器内 MCP 服务端**：HTTP MCP 端点运行在 Godot 内部，工具读取的是当前编辑器会话，而不是过期的磁盘快照。
- **先看清项目，再动手修改**：Agent 可以先读取当前项目、编辑器状态、最近错误和可用工具，再进入文件、场景、脚本、运行时诊断或 UI 控制。
- **Godot .NET 支持**：插件内 Roslyn 支持 C# 语法诊断、C# 文件读取与补丁修改、`.csproj` 读写、解决方案 / 项目信息检查，以及 C# 场景绑定审计。
- **可视化编辑器感知**：Agent 可以截取编辑器界面、枚举可见或隐藏控件、通过 Godot API 激活 Dock 和底部面板；除非用户明确授权，不需要系统级鼠标自动化。
- **运行时自动化闭环**：支持运行 / 停止场景、启用 runtime control、注入输入、捕获画面，并通过 `system_runtime_step` 完成“输入 -> 等待 -> 截图”的循环。
- **一键客户端接入**：配置页面向常见 CLI 与桌面 Agent，展示检测到的路径、配置目标、生成的 JSON，以及可用的一键安装 / 移除动作。
- **用户工具扩展**：将 `user_*` GDScript 工具放入 `custom_tools/`，插件即可自动发现和热重载，无需重建插件。

## 截图

| 主页 | 工具 | 配置 |
|---|---|---|
| ![主页仪表盘](asset_library/home-cn.png) | ![工具浏览](asset_library/tools-cn.png) | ![客户端配置](asset_library/config-cn.png) |

主页展示服务健康、MCP 端点、连接活动、自检结果、重载控制、端口、日志级别与语言。工具页让用户搜索可用的 Agent 工具、查看启用状态，并理解每个工具能做什么。配置页为桌面端与 CLI Agent 生成接入配置，并显示检测到的路径与可复制内容。

## Agent 能做什么

### 理解项目与编辑器

- `system_help` 返回当前能力说明、推荐起手顺序、截图优先提示、隐藏控件提示与 schema 信息。
- `system_project_state` 汇总项目健康、文件数量、运行状态、最近错误、编译错误和可选运行时健康摘要。
- `system_editor_state` 聚合当前编辑器工作区、Inspector / FileSystem 选择、项目运行摘要和 runtime-control 状态。

### 操作文件、场景与脚本

- `system_project_files` 覆盖常见项目文件树操作。
- `system_scene_validate`、`system_scene_analyze`、`system_scene_tree`、`system_scene_patch` 用结构化方式检查和修改场景。
- `system_script_analyze`、`system_script_patch`、`system_bindings_audit` 检查 GDScript / C# 结构和 C# 场景绑定。
- `system_project_symbol_search`、`system_scene_dependency_graph` 提供项目符号搜索和场景依赖图。

### 控制编辑器与运行时

- `system_editor_control` 可激活工作区、Dock、底部面板、控件、弹窗，并截取编辑器界面。
- `system_editor_log` 可读取、筛选或清空编辑器 Output 面板。
- `system_project_run`、`system_project_stop`、`system_runtime_diagnose`、`system_runtime_control`、`system_runtime_capture`、`system_runtime_input`、`system_runtime_step` 覆盖场景运行、运行时诊断、截图和脚本化输入。
- `system_userdata_maintenance` 可列出和清理 `user://godot_dotnet_mcp/` 下由插件管理的编辑器 / 运行时截图缓存，默认先 dry-run 预览。

## 环境要求

- Godot `4.6+`，需要 .NET 支持。
- 如果需要 C# 分析，目标 Godot 项目需启用 .NET 脚本支持。
- 一个支持 MCP 的客户端。配置页当前覆盖常见客户端，包括 Claude Code、Codex、Gemini CLI、OpenCode、Qwen Code、Claude Desktop、Cursor、Trae、Windsurf、Cline、Roo Code 与 Cherry Studio。

## 安装

### Godot 插件商城

用 Godot 打开目标项目，进入 `AssetLib` 页签，搜索 `Godot .NET MCP` 并点击 `Install`。也可以打开 [Godot 插件商城页面](https://godotengine.org/asset-library/asset/4923)。安装完成后，Godot 项目中应包含：

```text
addons/godot_dotnet_mcp
```

然后进入 `Project Settings > Plugins`，启用 `Godot .NET MCP`，打开 `MCPDock`，在 `主页` 页签启动服务。

### 源码方式

如果用于开发或本地调试，将本仓库中的 `addons/godot_dotnet_mcp/` 复制到目标 Godot 项目的 `addons/` 目录，再按同样方式启用插件。

## 快速开始

1. 启用插件并打开 `MCPDock > 主页`。
2. 确认服务端点，通常是 `http://127.0.0.1:3000/mcp`。
3. 打开 `MCPDock > 配置`，选择客户端，复制或写入生成的配置。
4. Agent 连接后先调用 `system_help`。
5. 修改前优先调用 `system_project_state` 或 `system_editor_state`。

基础检查：

```text
GET  http://127.0.0.1:3000/health
GET  http://127.0.0.1:3000/api/tools
POST http://127.0.0.1:3000/mcp
```

## 一分钟架构说明

Godot .NET MCP 是一个自包含的 Godot 编辑器插件。HTTP 服务、MCP JSON-RPC 路由、工具注册表、运行时状态、客户端配置、UI model、本地化和 Roslyn 语法支持都位于 `addons/godot_dotnet_mcp/` 中。

对 Agent 暴露的工具刻意按任务组织，而不是把底层编辑器操作直接丢给用户选择。检查项目状态、修改场景、读取日志、截图、控制运行时这些常见工作都被整理成稳定工具；想了解实现细节的用户，可以在工具页查看每个工具背后的关联信息。

C# 层使用 Roslyn 官方语法树 API，并采用 syntax-first 方式：从 `CSharpSyntaxTree` 提取有用的语法结构，不加载完整 SemanticModel，也不加载项目级 Workspace。这样可以让插件保持轻量、可分发，并贴近 Godot 编辑器运行时。

## 自定义工具

用户工具放在：

```text
addons/godot_dotnet_mcp/custom_tools/
```

每个 `.gd` 文件应实现 `handles()`、`get_tools()`、`execute()`，工具名必须使用 `user_` 前缀。合法工具会和 System 工具一起显示在工具页与 MCP 工具列表中。

## 文档

- [English README](README.md)
- [更新日志](CHANGELOG.zh-CN.md)
- [文档概述](docs/概述.md)
- [架构概述](docs/架构/概述.md)
- [System 工具层](docs/模块/System工具层.md)
- [工具系统](docs/模块/工具系统.md)
- [用户扩展](docs/模块/用户扩展.md)
- [安装与发布](docs/架构/安装与发布.md)

## 当前状态

`v1.0.0-pre2` 是当前未发布的预发布目标版本，延续 System 工具层、编辑器 / 运行时自动化、客户端接入配置、插件内 Roslyn 支持、用户工具热重载、本地化 Dock UI 与发布验证。完整版本记录见 [CHANGELOG.zh-CN.md](CHANGELOG.zh-CN.md)。
