# Godot .NET MCP

[![最新正式版](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.github.com%2Frepos%2FLuoxuanLove%2Fgodot-dotnet-mcp%2Freleases%2Flatest&query=%24.tag_name&label=%E6%AD%A3%E5%BC%8F%E7%89%88&color=orange)](https://github.com/LuoxuanLove/godot-dotnet-mcp/releases/latest) [![最新预发布版](https://img.shields.io/github/v/release/LuoxuanLove/godot-dotnet-mcp?include_prereleases&filter=*-pre*&label=%E9%A2%84%E5%8F%91%E5%B8%83%E7%89%88&color=orange)](https://github.com/LuoxuanLove/godot-dotnet-mcp/releases?q=prerelease%3Atrue) [![English README](https://img.shields.io/badge/README-English-24292f)](README.md)

> 一个用于 Godot 4.6+ 的编辑器 MCP 插件。启用后，支持 MCP 的客户端可以读取当前编辑器状态、操作场景和脚本、查看日志与截图，并使用插件生成的配置连接到本地服务。

Godot .NET MCP 运行在 Godot 编辑器内部，读取的是正在打开的项目和编辑器状态。它提供项目状态、场景、脚本、运行、截图、日志和客户端配置相关的 MCP 工具；C# 分析由插件内 Roslyn 语法层完成，不需要外部宿主进程。

![Godot .NET MCP 工具页](asset_library/tools-cn.png)

## 为什么需要它

Godot 项目不只有磁盘上的 `.tscn` 和脚本文件。很多问题还取决于当前打开的场景、Dock 状态、运行时报错、编辑器界面、客户端配置、截图结果，以及插件工具是否已经在当前会话中可用。Godot .NET MCP 将这些信息整理成可调用的 MCP 工具，方便客户端在修改场景、脚本、资源或运行状态前先读取真实编辑器状态。

## 亮点

- **编辑器内 MCP 服务**：本地 MCP 服务运行在 Godot 内部，工具读取的是当前编辑器会话，而不是过期的磁盘快照。
- **先读取状态，再进行修改**：客户端可以先读取当前项目、编辑器状态、最近错误和可用工具，再进入文件、场景、脚本、运行诊断或界面控制。
- **Godot .NET 支持**：插件内 Roslyn 支持 C# 语法诊断、C# 文件读取与补丁修改、`.csproj` 读写、解决方案 / 项目信息检查，以及 C# 场景绑定审计。
- **可视化编辑器状态**：客户端可以截取编辑器界面、枚举可见或隐藏控件，并通过 Godot 编辑器 API 激活 Dock、底部面板、控件和弹窗。
- **运行时自动化**：支持运行 / 停止场景、启用运行时控制、注入输入、捕获画面，并通过 `system_runtime_step` 完成“输入 -> 等待 -> 截图”的循环。
- **一键客户端接入**：配置页面面向常见 CLI 与桌面客户端，展示检测到的路径、配置目标、生成的 JSON，以及可用的一键安装 / 移除动作。
- **用户工具扩展**：将 `user_*` GDScript 工具放入 `custom_tools/`，插件即可自动发现和热重载，无需重建插件。

## 截图

| 主页 | 工具 | 配置 |
|---|---|---|
| ![主页仪表盘](asset_library/home-cn.png) | ![工具浏览](asset_library/tools-cn.png) | ![客户端配置](asset_library/config-cn.png) |

主页展示服务健康、服务地址、连接活动、自检结果、重载控制、端口、日志级别与语言。工具页列出可用工具、启用状态和工具说明。配置页为桌面端与 CLI 客户端生成接入配置，并显示检测到的路径与可复制内容。

## 主要功能

### 理解项目与编辑器

- `system_help` 返回当前能力说明、建议起手顺序、截图提示、隐藏控件提示与工具结构版本信息。
- `system_project_state` 汇总项目健康、文件数量、运行状态、最近错误、编译错误和可选运行时健康摘要。
- `system_editor_state` 聚合当前编辑器工作区、Inspector / FileSystem 选择、项目运行摘要和运行时控制状态。
- `system_plugin_reload` 提供插件重载和文件一致性检查，适合在更新 addon 文件后确认当前编辑器实例是否已刷新。

### 操作文件、场景与脚本

- `system_project_files` 覆盖常见项目文件树操作。
- `system_resource_reference_audit` 扫描 `.tscn` / `.tres` 的 UID、fallback path 和 C# 自定义 Resource 脚本引用，包括 `dotnet build` 通过后仍可能存在的资源加载风险。
- `system_scene_validate`、`system_scene_analyze`、`system_scene_tree`、`system_scene_patch` 用结构化方式检查和修改场景。
- `system_script_analyze`、`system_script_patch`、`system_bindings_audit` 检查 GDScript / C# 结构和 C# 场景绑定。
- `system_project_symbol_search`、`system_scene_dependency_graph` 提供项目符号搜索和场景依赖图。

### 控制编辑器与运行时

- `system_editor_control` 可激活工作区、Dock、底部面板、控件、弹窗，截取编辑器界面，返回 UI 坐标映射，并派发控件本地坐标左键 / 右键点击。
- `system_editor_log` 可读取、筛选或清空编辑器输出面板。
- `system_project_run`、`system_project_stop`、`system_runtime_diagnose`、`system_runtime_control`、`system_runtime_step(action=step|capture|input)` 覆盖场景运行、运行时诊断、截图和脚本化输入。
- `system_project_state(include_runtime_health=true)` 与 `system_editor_state` 会返回 `runtime_capabilities`，用于区分当前会话是否能启动项目、控制运行时或截取运行时画面。
- `system_userdata_maintenance` 可列出和清理 `user://godot_dotnet_mcp/` 下由插件管理的编辑器 / 运行时截图缓存，默认先预览再清理。

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

如果用于开发或本地调试，将本仓库中的 `addons/godot_dotnet_mcp/` 复制到目标 Godot 项目的 `addons/` 目录，再按同样方式启用插件。复制文件只会更新磁盘副本：已经运行中的 Godot 编辑器仍会保留旧插件实例，直到调用 `system_plugin_reload(action="full_reload_plugin")` 或在插件设置中禁用后重新启用。验证同步后的 addon 时，可通过 `/health`、`system_plugin_reload(action="get_freshness")` 或 `plugin_runtime_state(action="get_self_health")` 确认当前运行实例是否需要重载。

## 快速开始

1. 启用插件并打开 `MCPDock > 主页`。
2. 确认服务地址，通常是 `http://127.0.0.1:3000/mcp`。
3. 打开 `MCPDock > 配置`，选择客户端，复制或写入生成的配置。
4. 客户端连接后先调用 `system_help` 查看当前能力说明。
5. 修改前优先调用 `system_project_state` 或 `system_editor_state`。

基础检查：

```text
GET  http://127.0.0.1:3000/health
GET  http://127.0.0.1:3000/api/tools
POST http://127.0.0.1:3000/mcp
```

安全说明：本地 HTTP 服务默认不返回 wildcard CORS headers。直接连接 `127.0.0.1` 的 CLI 与桌面 MCP 客户端不需要 CORS；浏览器型客户端必须通过 `GODOT_DOTNET_MCP_ALLOWED_CORS_ORIGINS` 环境变量显式加入 allowlist，多个精确 origin 用英文逗号分隔，例如 `http://localhost:5173`。

## 一分钟架构说明

Godot .NET MCP 是一个自包含的 Godot 编辑器插件。HTTP 服务、MCP JSON-RPC 路由、工具注册表、运行时状态、客户端配置、UI model、本地化和 Roslyn 语法支持都位于 `addons/godot_dotnet_mcp/` 中。

插件对外提供的工具按任务组织，而不是要求使用者直接组合底层编辑器操作。检查项目状态、修改场景、读取日志、截图、控制运行时等常见工作都整理成稳定工具；需要了解实现细节时，可以在工具页查看每个工具背后的关联信息。

C# 层使用 Roslyn 官方语法树 API，并采用 syntax-first 方式：从 `CSharpSyntaxTree` 提取有用的语法结构，不加载完整 SemanticModel，也不加载项目级 Workspace。这样可以让插件保持轻量、可分发，并贴近 Godot 编辑器运行时。

## 自定义工具

用户工具放在：

```text
addons/godot_dotnet_mcp/custom_tools/
```

每个 `.gd` 文件应实现 `handles()`、`get_tools()`、`execute()`，工具名必须使用 `user_` 前缀。合法工具会和内置 System 工具一起显示在工具页与 MCP 工具列表中。

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

最新已发布预发布版本是 `v1.0.0-pre3`，重点是运行时诊断、编辑器自动化稳定性与发布流程加固。完整版本记录见 [CHANGELOG.zh-CN.md](CHANGELOG.zh-CN.md)。
