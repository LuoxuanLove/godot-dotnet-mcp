# Godot .NET MCP 插件
[![最新版本](https://img.shields.io/github/v/release/LuoxuanLove/godot-dotnet-mcp?label=%E6%9C%80%E6%96%B0%E7%89%88%E6%9C%AC)](https://github.com/LuoxuanLove/godot-dotnet-mcp/releases/latest)
[![English README](https://img.shields.io/badge/README-English-24292f)](README.md)

> 这个插件是 `Central Server` 在 Godot 编辑器内的配套代理，负责实时编辑器工具执行、attach 会话维持，以及 `MCPDock` 中的本地诊断展示。

![Godot .NET MCP 工具预览](asset_library/preview-tools-cn.png)

## v1.0 中的插件定位

- 在 Godot 进程内执行实时 `system_*` 工具。
- 附着到 `Central Server`，维持 heartbeat / detach 生命周期。
- 在 `MCPDock` 中展示本地服务、附着状态、安装信息和诊断信息。
- 托管 `custom_tools/` 下的 `user_*` 自定义工具。

插件不再是推荐的公开 MCP 主入口。外部客户端应该连接 `Central Server`，而不是直接连接插件运行时。

## 安装到 Godot 项目

把当前目录复制到项目中：

```text
addons/godot_dotnet_mcp
```

然后：

1. 用 Godot 打开项目。
2. 在 `Project Settings > Plugins` 中启用 `Godot .NET MCP`。
3. 打开 `MCPDock`。
4. 在 `Server` 页签中查看或引导本地 `Central Server`。

## 插件提供的能力

- 实时项目快照和编辑器状态工具，例如 `system_project_state`。
- 运行时诊断工具，例如 `system_runtime_diagnose`。
- 场景、脚本、符号和 C# 绑定分析能力。
- 来自 `custom_tools/` 的本地自定义工具加载。

## 自定义工具

在下列目录中创建 `.gd` 文件：

```text
addons/godot_dotnet_mcp/custom_tools/
```

每个工具脚本需要实现：

- `handles()`
- `get_tools()`
- `execute()`

对外暴露的工具名必须统一使用 `user_` 前缀。

## 重构说明

- v1.0 正在向“`Central Server` 唯一公开入口”收口。
- 插件内嵌的 HTTP transport 目前属于过渡实现，应视为 Host 与插件之间的内部通道。
- 在你明确确认重构结束之前，插件 README 和架构文档会持续同步更新。

## 文档入口

- [README.md](README.md)
- [../../README.zh-CN.md](../../README.zh-CN.md)
- [../../docs/架构/服务与路由.md](../../docs/架构/服务与路由.md)
- [../../docs/架构/安装与发布.md](../../docs/架构/安装与发布.md)
