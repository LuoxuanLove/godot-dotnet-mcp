# Godot .NET MCP
[![English README](https://img.shields.io/badge/README-English-24292f)](README.md)

> 这个项目不是再做一个套在 Godot 外面的 MCP 服务壳，而是通过插件形式把 Godot 编辑器本身推进到更 AI Native 的形态。
> 目标是让 AI 在编辑器内直接理解 Godot 项目，并在授权边界内自进化扩展工具，而不只是执行命令。

[![Latest Release](https://img.shields.io/github/v/release/LuoxuanLove/godot-dotnet-mcp?label=%E6%9C%80%E6%96%B0%E7%89%88%E6%9C%AC)](https://github.com/LuoxuanLove/godot-dotnet-mcp/releases/latest)
[![Download ZIP](https://img.shields.io/badge/%E4%B8%8B%E8%BD%BD-latest%20zip-2ea44f)](https://github.com/LuoxuanLove/godot-dotnet-mcp/releases/latest/download/godot-dotnet-mcp-0.3.0.zip)

`Godot .NET MCP` 是一个运行在 Godot 编辑器内、支持自进化的 MCP 插件，面向 Godot 4 与 Godot.NET 工作流，能把真实项目上下文直接暴露给客户端，并在用户授权下扩展 User 工具。

当前正式发布版本：`v0.3.0`（v0.4.0 开发中）

## 这是什么

它是直接运行在 Godot 编辑器进程内的 MCP 服务，不是脱离编辑器状态的外部守护进程。

客户端拿到的是实时项目上下文，并且插件可以通过显式授权扩展 User 工具，而不是依赖一层脱节的外部自动化脚本。

## 为什么用这个插件

- **Godot.NET 优先**：不仅面向通用 Godot 项目，也把 Godot.NET / C# 的场景绑定、导出成员分析和脚本检查作为一等能力来设计。
- **运行在编辑器内部**：无需额外守护进程，服务直接跟随 Godot 编辑器生命周期，部署、调试和接入链路更短。
- **可扩展**：工具系统按 domain 拆分装载，支持热重载、自定义工具发现与后续能力增量扩展。
- **可自进化**：插件可以在显式授权下脚手架、加载、审计和删除 User 工具，不会写入内置分类。
- **面向真实接入**：重点不是演示接口，而是让 MCP 客户端真正接进 Godot 项目，包括 profile、配置生成、复制和写入链路。

## 关键特性

- 提供 HTTP + MCP 协议入口，默认地址为 `http://127.0.0.1:3000/mcp`
- 提供 Dock UI，可管理端口、语言、工具 profile 与客户端配置
- 支持面向桌面端和 CLI 客户端的平台化配置生成
- 支持配置复制和一键写入
- 支持插件级完整重载，以及按 domain 的局部热重载
- 覆盖 Godot 编辑器中的主要项目、场景、脚本和资源操作链路
- 支持用户自定义工具脚本发现、加载、调用与回收
- 支持通过 `debug_runtime_bridge` 回读主项目调试会话状态与最近一次运行的基础生命周期事件

## 环境要求

- Godot `4.6+`
- 建议使用 Godot Mono / .NET 版本
- 可接入的 MCP 客户端，例如：
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

然后：

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

从 GitHub Releases 页面下载最新发布包：

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

启用插件后，服务可以根据已保存配置自动启动，也可以在 `MCPDock > Server` 中手动启动。

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

### 2. 连接客户端

打开 `MCPDock > Config`，选择目标平台后查看或复制生成结果。

- 桌面端会显示 JSON 配置、目标路径和写入操作
- CLI 客户端会显示对应命令文本
- `Claude Code` 额外支持 `user / project` 作用域切换

推荐顺序：

1. 先选择目标客户端。
2. 再确认服务地址和生成内容。
3. 需要自动落地时使用 `Write Config`。
4. 只想手动处理时使用 `Copy`。

### 3. 验证连接

建议确认：

- `/health` 返回正常
- `/api/tools` 能返回工具列表
- MCP 客户端能够连接到 `http://127.0.0.1:3000/mcp`

### 4. 读取最近一次主项目运行状态

使用 `debug_runtime_bridge` 读取最近一次由编辑器启动的主项目运行时信息。

- `get_sessions` 可在主项目停止后继续返回最近一次调试会话状态
- `get_recent` 可返回最近捕获到的基础生命周期事件，例如 `enter_tree`、`ready`、`close_requested`、`exit_tree`
- 如果只是读取最近一次会话和生命周期事件，不要求主项目场景持续运行

## 路径约定

- 资源路径统一使用 `res://`
- 节点路径默认推荐使用相对当前场景根节点的路径，例如 `Player/Camera2D`
- 当前版本也兼容 `/root/...` 风格路径
- 工具写操作默认要求“写后可读回”

## 仓库迁移说明

- GitHub 仓库名为 `godot-dotnet-mcp`
- Godot 内的安装目录保持不变，仍然使用 `addons/godot_dotnet_mcp`
- 如果你是从旧仓库地址迁移，请更新 submodule URL 后执行：

```bash
git submodule sync --recursive
git submodule update --init --recursive
```

## 文档

- [README.md](README.md)
- [docs/概述.md](docs/%E6%A6%82%E8%BF%B0.md)
- [CHANGELOG.md](CHANGELOG.md)
- [docs/架构/服务与路由.md](docs/%E6%9E%B6%E6%9E%84/%E6%9C%8D%E5%8A%A1%E4%B8%8E%E8%B7%AF%E7%94%B1.md)
- [docs/架构/配置与界面.md](docs/%E6%9E%B6%E6%9E%84/%E9%85%8D%E7%BD%AE%E4%B8%8E%E7%95%8C%E9%9D%A2.md)
- [docs/架构/安装与发布.md](docs/%E6%9E%B6%E6%9E%84/%E5%AE%89%E8%A3%85%E4%B8%8E%E5%8F%91%E5%B8%83.md)
- [docs/模块/工具系统.md](docs/%E6%A8%A1%E5%9D%97/%E5%B7%A5%E5%85%B7%E7%B3%BB%E7%BB%9F.md)
- [docs/模块/自进化系统.md](docs/%E6%A8%A1%E5%9D%97/%E8%87%AA%E8%BF%9B%E5%8C%96%E7%B3%BB%E7%BB%9F.md)

## 当前边界

- 当前调试回读已支持主项目运行时桥接事件与编辑器调试会话状态，但仍不是对 Godot 原生 Output / Debugger 面板的 1:1 文本镜像
- 这条能力对应的 MCP 工具名是 `debug_runtime_bridge`
- 最近一次捕获到的会话状态和基础生命周期事件会在主项目停止后继续保留，但如果要看实时新增事件，仍需保持主项目运行
- 某些依赖编辑器实时状态的能力，仍建议在真实项目工作流中做一次黑盒确认
