# Godot .NET MCP
[![最新版本](https://img.shields.io/github/v/release/LuoxuanLove/godot-dotnet-mcp?label=%E6%9C%80%E6%96%B0%E7%89%88%E6%9C%AC)](https://github.com/LuoxuanLove/godot-dotnet-mcp/releases/latest) [![English README](https://img.shields.io/badge/README-English-24292f)](README.md)

> 运行在 Godot 编辑器进程内的 MCP 插件——Agent 直接读取活的项目状态、操作场景与脚本、诊断 C# 绑定，无需任何外部进程。

## 这是什么

嵌入 Godot 编辑器进程的 MCP 服务端。调用 `intelligence_project_state` 获取当前项目的真实快照——场景数、脚本数、错误统计、运行状态——再用 `intelligence_project_advise` 获取具体可执行的改进建议。之后根据建议，用场景、脚本、节点或资源工具做精准修改。

Intelligence 层（15 个内置工具）是 Agent 的推荐起点，覆盖项目快照、场景分析、脚本结构检查、C# 绑定审计与符号搜索，读取的是活的编辑器状态，而不是磁盘上的文件快照。

如需扩展工具集：在 `custom_tools/` 中放置 `.gd` 文件，实现 `handles / get_tools / execute`，工具名统一以 `user_` 开头。插件自动发现并加载。`plugin_evolution` 工具组负责脚手架、审计和删除。

## 为什么用这个插件

- **运行在编辑器内部**：在 Godot 进程中运行，场景查询、脚本读取和属性修改直接反映编辑器的真实状态。
- **Godot.NET 优先**：C# 绑定检查（`intelligence_bindings_audit`）、导出成员分析、`.cs` 脚本修补均内置，不是附加功能。
- **Intelligence 优先**：`intelligence_project_state` → `intelligence_project_advise` → 具体操作，是设计好的工作流，不需要猜从哪个原子工具入手。
- **可用户扩展**：`custom_tools/` 中的脚本作为一等工具加载，无需重建插件。`plugin_evolution` 管理全生命周期。

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

### 方式二：作为 Git Submodule

仓库根目录内含 `addons/godot_dotnet_mcp/`（v0.4 后重组，插件不再在仓库根部）。添加子模块时，克隆到父级目录：

```bash
git submodule add https://github.com/LuoxuanLove/godot-dotnet-mcp.git _godot-dotnet-mcp
```

插件位于 `_godot-dotnet-mcp/addons/godot_dotnet_mcp/`，将该目录复制或符号链接到项目的 `addons/` 下即可。如需更简单的方式，推荐使用方式三。

### 方式三：使用发布包

从 GitHub Releases 页面下载最新发布包：

```text
https://github.com/LuoxuanLove/godot-dotnet-mcp/releases
```

解压后保持目录结构为：

```text
addons/godot_dotnet_mcp
```

再按"方式一"启用即可。

## 快速开始

### 1. 启动本地服务

启用插件后，服务可根据已保存设置自动启动，也可在 `MCPDock > Server` 中手动启动。

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

- 桌面端显示 JSON 配置、目标路径和写入操作
- CLI 客户端显示对应命令文本
- `Claude Code` 额外支持 `user / project` 作用域切换

推荐顺序：

1. 选择目标客户端。
2. 确认服务地址和生成内容。
3. 需要自动落地时使用 `Write Config`。
4. 只想手动处理时使用 `Copy`。

### 3. 验证连接

建议确认：

- `/health` 返回正常
- `/api/tools` 能返回工具列表
- MCP 客户端能够连接到 `http://127.0.0.1:3000/mcp`

### 4. 读取最近一次主项目运行状态

使用 `intelligence_runtime_diagnose` 读取最近一次由编辑器启动的运行时信息——错误、编译问题、性能数据。主项目停止后仍可读取。

## 路径约定

- 资源路径统一使用 `res://`
- 节点路径默认推荐相对当前场景根节点，例如 `Player/Camera2D`
- 也支持 `/root/...` 风格路径
- 工具写操作默认要求"写后可读回"

## 文档

- [README.md](README.md)
- [CHANGELOG.md](CHANGELOG.md)
- [docs/概述.md](docs/%E6%A6%82%E8%BF%B0.md)
- [docs/模块/Intelligence工具层.md](docs/%E6%A8%A1%E5%9D%97/Intelligence%E5%B7%A5%E5%85%B7%E5%B1%82.md)
- [docs/模块/工具系统.md](docs/%E6%A8%A1%E5%9D%97/%E5%B7%A5%E5%85%B7%E7%B3%BB%E7%BB%9F.md)
- [docs/模块/用户扩展.md](docs/%E6%A8%A1%E5%9D%97/%E7%94%A8%E6%88%B7%E6%89%A9%E5%B1%95.md)
- [docs/架构/服务与路由.md](docs/%E6%9E%B6%E6%9E%84/%E6%9C%8D%E5%8A%A1%E4%B8%8E%E8%B7%AF%E7%94%B1.md)
- [docs/架构/配置与界面.md](docs/%E6%9E%B6%E6%9E%84/%E9%85%8D%E7%BD%AE%E4%B8%8E%E7%95%8C%E9%9D%A2.md)
- [docs/架构/安装与发布.md](docs/%E6%9E%B6%E6%9E%84/%E5%AE%89%E8%A3%85%E4%B8%8E%E5%8F%91%E5%B8%83.md)

## 当前边界

- 当前调试回读支持主项目运行时桥接事件与编辑器调试会话状态，但不是 Godot 原生 Output / Debugger 面板的 1:1 文本镜像
- 读取运行时状态推荐使用 `intelligence_runtime_diagnose`
- 最近一次捕获的会话状态与生命周期事件在主项目停止后仍可读取；若要观察实时新增事件，仍需保持主项目运行
- 依赖编辑器实时状态的能力建议在真实项目工作流中做一次验证
