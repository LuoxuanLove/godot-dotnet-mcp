# Godot .NET MCP

`Godot .NET MCP` 是一个运行在 Godot 编辑器内的 MCP 插件，面向 Godot 4 与 Godot.NET 工作流，提供稳定、可组合、可验证的编辑器工具入口，便于 Claude Code、Codex、Gemini CLI 等客户端直接操作项目。

当前正式发布版本：`v0.1.0`

## 特性

- 运行在 Godot 编辑器进程内，不依赖额外守护进程
- 提供 HTTP + MCP 协议入口，默认地址为 `http://127.0.0.1:3000/mcp`
- 提供 76 个顶层工具，覆盖场景、节点、资源、脚本、插件运行时、动画、材质、TileMap、导航、物理、音频、UI 等能力域
- 支持 Godot.NET / C# 场景绑定审计、导出成员分析与脚本检查
- 提供 Dock UI，可管理端口、语言、工具 profile、CLI 配置与客户端接入信息
- 支持工具禁用、配置复制、一键写入客户端配置
- 支持插件级完整重载，行为尽量贴近 Godot 项目设置中的“关闭再启用插件”
- 已补齐最小 TileSet 闭环与插件调试缓冲区回读能力

## 环境要求

- Godot `4.6+`
- 建议使用 Godot Mono / .NET 版本
- 用于接入的 MCP 客户端，例如：
  - Claude Code
  - Codex CLI
  - Gemini CLI
  - Claude Desktop
  - Cursor

## 安装

### 方式一：直接复制插件目录

将本插件放到你的 Godot 项目内：

```text
addons/godot_dotnet_mcp
```

目录就位后：

1. 用 Godot 打开项目。
2. 进入 `Project Settings > Plugins`。
3. 启用 `Godot .NET MCP`。
4. 在右侧 Dock 中打开 `MCPDock`。
5. 确认端口后启动服务。

### 方式二：作为 Git Submodule

```bash
git submodule add https://github.com/LuoxuanLove/godot-dotnet-mcp.git addons/godot_dotnet_mcp
git submodule update --init --recursive
```

如果是首次克隆主项目：

```bash
git clone --recurse-submodules <your-project-repo>
```

### 方式三：使用发布包

可从 GitHub Releases 页面下载发布包：

```text
https://github.com/LuoxuanLove/godot-dotnet-mcp/releases
```

解压后保持目录结构为：

```text
addons/godot_dotnet_mcp
```

再按“方式一”启用即可。

## 快速开始

### 1. 启动本地服务

启用插件后，默认会根据配置自动启动服务。也可以在 `MCPDock > 服务器` 中手动启动。

健康检查：

```text
GET http://127.0.0.1:3000/health
```

工具列表：

```text
GET http://127.0.0.1:3000/api/tools
```

MCP 主入口：

```text
POST http://127.0.0.1:3000/mcp
```

### 2. 将客户端接到 Godot

打开 `MCPDock > 配置` 后，可先选择 Agent 平台，再查看或复制对应内容：

- Claude Desktop 配置
- Cursor 配置
- Gemini 配置
- Claude Code 命令
- Codex CLI 命令

默认服务地址为：

```json
{
  "url": "http://127.0.0.1:3000/mcp"
}
```

配置页推荐按以下顺序使用：

1. 先在顶部 `Agent 平台` 下拉中选择目标客户端。
2. 如果选中的是 `Claude Desktop`、`Cursor` 或 `Gemini`，页面会显示对应配置文件路径、当前生成的 JSON 文本，以及“写入配置”“复制”按钮。
3. 如果选中的是 `Claude Code` 或 `Codex`，页面会切换为 CLI 命令视图；其中 `Claude Code` 额外提供 `user / project` 作用域切换。
4. 写入前先确认服务地址、配置内容和目标路径；不希望直接改本机配置时，可只使用“复制”按钮。

配置页的按钮行为如下：

- `写入配置`：只更新目标配置文件中的 `mcpServers.godot-mcp` 节点，不覆盖其它服务器配置。
- `复制`：复制当前平台对应的 JSON 或 CLI 命令文本。
- `作用域`：仅影响 `Claude Code` 命令生成，不影响桌面端 JSON 配置内容。

### 3. 验证是否工作

建议先调用以下工具：

- `scene_management`
- `node_query`
- `project_info`
- `script_inspect`
- `scene_audit`

## 典型能力

### 场景与节点

- 打开、保存、另存场景
- 创建场景与节点
- 读取节点树、属性、变换、可见性、元数据
- 调用节点方法、管理生命周期

### 资源与脚本

- 枚举、搜索、读取资源
- 读取纹理、脚本、依赖关系
- 创建或编辑 GDScript
- 提取 GDScript / C# 元数据、导出字段与符号

### Godot.NET / 绑定审计

- 分析 C# 脚本导出成员
- 审查 `.tscn` 中的绑定缺失
- 生成结构化 `scene_audit` 问题列表

### 编辑器与调试

- 读取编辑器状态、设置、文件系统、插件状态
- 写入调试日志并回读最近事件 / 错误事件
- 获取可由插件侧读取的 profiler 摘要

### 插件运行时

- 查看各工具 domain 的加载状态、来源和版本
- 单独热重载某个 domain，无需重启 MCP 服务
- 重载全部 hot-reloadable domain 并回读最近一次重载摘要

### 高级域

- 动画、AnimationTree、StateMachine
- Material、Shader、Lighting、Particle
- TileMap / TileSet
- Navigation、Physics、Audio、UI Theme / Control

## 路径约定

- 资源路径统一使用 `res://`
- 节点路径默认推荐使用“相对当前场景根节点”的路径，例如 `Player/Camera2D`
- 当前版本也兼容 `/root/...` 风格路径
- 工具写操作默认要求“写后可读回”

## 仓库迁移说明

- GitHub 仓库名已收口为 `godot-dotnet-mcp`
- Godot 内的安装目录保持不变，仍然使用 `addons/godot_dotnet_mcp`
- 如果你是从旧仓库地址迁移，请更新 submodule URL 后执行：

```bash
git submodule sync --recursive
git submodule update --init --recursive
```

## 项目结构

- `plugin.cfg`：Godot 插件清单
- `plugin.gd`：插件入口与 Dock 装配
- `plugin/runtime/mcp_http_server.gd`：HTTP / MCP 服务实现
- `tools/`：按能力域拆分的工具执行器与共享 helper
- `ui/`：Dock 场景与页签脚本
- `localization/`：本地化资源
- `docs/`：用户与开发文档
- `release/`：发布包输出目录

## 文档

- [CHANGELOG.md](CHANGELOG.md)
- [docs/概述.md](docs/概述.md)
- [docs/架构/服务与路由.md](docs/架构/服务与路由.md)
- [docs/架构/配置与界面.md](docs/架构/配置与界面.md)
- [docs/模块/工具系统.md](docs/模块/工具系统.md)

## 当前边界

- 当前调试回读能力基于插件调试缓冲区，不是直接读取 Godot 原生 Output / Debugger 面板
- 目标是提供稳定、自动化友好的编辑器操作入口，不是完整覆盖 Godot 全部 API

## 版本与发布

- 版本变更见 [CHANGELOG.md](CHANGELOG.md)
- 二进制发布包见 GitHub Releases 页面
- 安装说明见 [docs/架构/安装与发布.md](docs/架构/安装与发布.md)

## 作者

- 作者：落萱_Love

## 许可证

本项目采用 [MIT License](LICENSE)。
