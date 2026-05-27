# Godot .NET MCP
[![最新正式版](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.github.com%2Frepos%2FLuoxuanLove%2Fgodot-dotnet-mcp%2Freleases%2Flatest&query=%24.tag_name&label=%E6%AD%A3%E5%BC%8F%E7%89%88&color=orange)](https://github.com/LuoxuanLove/godot-dotnet-mcp/releases/latest) [![English README](https://img.shields.io/badge/README-English-24292f)](README.md)

> 运行在 Godot 编辑器进程内的 MCP 插件。支持 MCP 的客户端可读取当前项目状态、操作场景与脚本、诊断 C# 绑定，无需任何外部进程。

![Godot .NET MCP 工具页](https://raw.githubusercontent.com/LuoxuanLove/godot-dotnet-mcp/main/asset_library/tools-cn.png)

## 这是什么

嵌入 Godot 编辑器进程的 MCP 服务。调用 `system_project_state` 获取当前项目的真实快照——场景数、脚本数、错误统计、运行状态——再根据观察到的问题，用场景、脚本、节点或资源工具做精准修改。

System 工具层是推荐起点，覆盖项目快照、项目文件树修改、编辑器会话快照、编辑器界面控制、编辑器日志访问、运行时诊断、场景分析、当前场景树修改、脚本结构检查、C# 绑定审计与符号搜索，读取的是当前编辑器状态，而不是磁盘上的文件快照。

连接后，MCP 客户端还可以通过内置 Resources 与 Prompts 读取服务能力元数据、以 JSON 查看当前工具目录，并获取项目起手或工具发现引导 prompt。可先调用 `system_help` 获取当前能力说明与工具结构版本。凡涉及 Dock、弹窗、布局、焦点或按钮可见性，优先通过 Godot 编辑器 API 使用 `system_editor_control(action=activate_ui)` 与 `system_editor_control(action=capture_editor)`；除非用户明确授权前台自动化，否则不要使用系统级鼠标/窗口控制。若可见控件枚举找不到目标，应使用 `system_editor_control(action=list_controls, include_hidden=true)` 重试。Dock 自建弹窗 UI 需要明确区分坐标空间：Control 本地点击坐标应按场景转换为 viewport 或 screen 坐标，`PopupMenu.popup(Rect2i)` 必须接收 screen 坐标，而不是 local 或 canvas global 坐标。

插件侧运行态细节仍推荐通过 `plugin_runtime_state` 获取；其中 `action=get_lsp_diagnostics_status` 是详细 LSP 自检入口，而 `system_project_state(include_runtime_health=true)` 只返回轻量 `self_diagnostics`、`lsp_diagnostics` 与 `tool_loader` 健康摘要。

如需扩展工具集：在 `custom_tools/` 中放置 `.gd` 文件，实现 `handles / get_tools / execute`，工具名统一以 `user_` 开头。插件自动发现并加载。`plugin_evolution` 工具组负责脚手架、审计和删除。

## 为什么用这个插件

- **运行在编辑器内部**：在 Godot 进程中运行，场景查询、脚本读取和属性修改直接反映编辑器的真实状态。
- **Godot.NET 优先**：C# 绑定检查（`system_bindings_audit`）、导出成员分析、`.cs` 脚本修补均内置，不是附加功能。
- **先读取状态，再进行修改**：客户端可以先读取项目健康、编辑器状态、最近错误和可用工具，再进入文件、场景、脚本、运行诊断或界面控制。
- **可用户扩展**：`custom_tools/` 中的脚本作为一等工具加载，无需重建插件。`plugin_evolution` 管理全生命周期。

## 环境要求

- Godot `4.6+`
- 建议使用 Godot Mono / .NET 版本
- 可接入的 MCP 客户端，例如：
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

## 安装

### 方式一：从 Godot 插件商城安装

用 Godot 打开目标项目，进入 `AssetLib` 页签，搜索 `Godot .NET MCP` 并点击 `Install`。也可以打开 Godot 插件商城页面：

```text
https://godotengine.org/asset-library/asset/4923
```

安装完成后目录结构应为：

```text
addons/godot_dotnet_mcp
```

然后：

1. 用 Godot 打开项目。
2. 进入 `Project Settings > Plugins`。
3. 启用 `Godot .NET MCP`。
4. 在右侧 Dock 中打开 `MCPDock`。
5. 确认端口后启动服务。

### 方式二：直接复制源文件

将插件放到你的 Godot 项目内：

```text
addons/godot_dotnet_mcp
```

然后：

1. 用 Godot 打开项目。
2. 进入 `Project Settings > Plugins`。
3. 启用 `Godot .NET MCP`。
4. 在右侧 Dock 中打开 `MCPDock`。
5. 确认端口后启动服务。

## 快速开始

### 1. 启动本地服务

启用插件后，服务可根据已保存设置自动启动，也可在 `MCPDock > 主页` 中手动启动。

健康检查：

```text
GET http://127.0.0.1:3000/health
```

工具列表：

```text
GET http://127.0.0.1:3000/api/tools
```

MCP 服务地址：

```text
POST http://127.0.0.1:3000/mcp
```

### 2. 连接客户端

打开 `MCPDock > Config`，选择目标平台后查看或复制生成结果。

- 桌面端显示 JSON 配置、目标路径，以及写入 / 移除操作
- CLI 客户端显示对应命令文本，并在上游 CLI 支持时提供一键添加 / 移除
- `Claude Code` 额外支持 `user / project` 作用域切换
- `Gemini CLI` 同样按当前 `settings.json` 作用域支持 `user / project` 切换
- 已安装的客户端会明确显示“已安装到”具体配置路径或 CLI 作用域。

推荐顺序：

1. 选择目标客户端。
2. 确认服务地址和生成内容。
3. 需要自动落地时使用 `Write Config`。
4. 只想手动处理时使用 `Copy`。

### 3. 验证连接

建议确认：

- `/health` 返回正常
- `/api/tools` 能返回工具列表
- `system_help` 返回当前能力说明，并包含编辑器截图优先提示与隐藏控件枚举提示
- MCP 客户端能够连接到 `http://127.0.0.1:3000/mcp`

### 4. 读取最近一次项目运行状态

使用 `system_runtime_diagnose` 读取最近一次由编辑器启动的运行时信息——错误、编译问题、性能数据。项目停止后仍可读取。

## 路径约定

- 资源路径统一使用 `res://`
- 节点路径默认推荐相对当前场景根节点，例如 `Player/Camera2D`
- 也支持 `/root/...` 风格路径
- 工具写操作默认要求"写后可读回"

## 文档

- [README.md](README.md)
- [CHANGELOG.md](CHANGELOG.md)
- [docs/概述.md](docs/%E6%A6%82%E8%BF%B0.md)
- [docs/模块/System工具层.md](docs/%E6%A8%A1%E5%9D%97/System%E5%B7%A5%E5%85%B7%E5%B1%82.md)
- [docs/模块/工具系统.md](docs/%E6%A8%A1%E5%9D%97/%E5%B7%A5%E5%85%B7%E7%B3%BB%E7%BB%9F.md)
- [docs/模块/用户扩展.md](docs/%E6%A8%A1%E5%9D%97/%E7%94%A8%E6%88%B7%E6%89%A9%E5%B1%95.md)
- [docs/架构/服务与路由.md](docs/%E6%9E%B6%E6%9E%84/%E6%9C%8D%E5%8A%A1%E4%B8%8E%E8%B7%AF%E7%94%B1.md)
- [docs/架构/配置与界面.md](docs/%E6%9E%B6%E6%9E%84/%E9%85%8D%E7%BD%AE%E4%B8%8E%E7%95%8C%E9%9D%A2.md)
- [docs/架构/安装与发布.md](docs/%E6%9E%B6%E6%9E%84/%E5%AE%89%E8%A3%85%E4%B8%8E%E5%8F%91%E5%B8%83.md)

## 当前边界

- 当前调试回读支持项目运行时桥接事件与编辑器调试会话状态，但不是 Godot 原生输出 / 调试器面板的 1:1 文本镜像
- 读取运行时状态推荐使用 `system_runtime_diagnose`
- 最近一次捕获的会话状态与生命周期事件在项目停止后仍可读取；若要观察实时新增事件，仍需保持项目运行
- 依赖编辑器实时状态的能力建议在真实项目工作流中做一次验证
