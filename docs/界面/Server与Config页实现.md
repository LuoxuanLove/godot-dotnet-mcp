# Server 与 Config 页实现

本文档说明 `Server` 页和 `Config` 页的场景脚本职责、动态布局逻辑和配置生成方式。

---

## `Server` 页

### 目标职责

`Server` 页负责：

- 展示当前服务状态与端点
- 展示连接数、请求数和最近请求
- 修改端口、自动启动、日志等级、权限等级与语言
- 启动、重启、停止内嵌 server
- 触发完整插件重载
- 展示插件自身诊断摘要

### 控制器职责

`server_tab.gd` 主要做三件事：

1. 读取 model 并填充状态文本
2. 重建日志等级、权限等级与语言下拉
3. 把按钮与设置操作转成 signal

### 响应式布局

`server_tab.gd` 当前保留了比 `Tools` 页更多的运行时布局控制，原因是它本身依赖：

- `GridContainer`
- 诊断卡片
- 多列设置区域

这些控件在不同宽度下需要切换为更紧凑的排列方式。

### 自诊断卡片

Server 页头部的自诊断卡片展示数据来自：

- `plugin_runtime_state.get_self_health`
- `plugin_runtime_state.get_self_errors`
- `plugin_runtime_state.get_self_timeline`

这块内容不放在 Dock 顶部公共区域，而是跟随 `Server` 页展示，以避免其他页签承载无关信息。

---

## `Config` 页

### 目标职责

`Config` 页负责：

- 平台切换
- 桌面端客户端配置展示
- CLI 命令展示
- Claude Code 作用域切换
- 一键写入配置
- 复制配置文本或命令

### 控制器结构

`config_tab.gd` 当前做法不是提前在 `.tscn` 中写死所有客户端卡片，而是运行时动态创建卡片。这样做的原因是：

- 平台切换后只展示当前目标客户端
- 卡片内容由 model 决定，更适合多客户端扩展
- CLI 与桌面端客户端的按钮组合不同

### 客户端卡片生成

每个客户端卡片在 `_create_client_card()` 中动态创建：

- `PanelContainer`
- `MarginContainer`
- `VBoxContainer`
- 标题、说明、路径文本、内容区、按钮区

按钮逻辑：

- 桌面端客户端：可显示 `Write Config` + `Copy`
- CLI 客户端：只显示 `Copy`

### 平台分组

`Config` 页当前将平台分为：

- `desktop`
- `cli`

同时对 Claude Code 做单独的 scope 行显示控制。

---

## 配置生成与写入链路

运行时链路如下：

```text
plugin.gd
  -> build model
  -> config_tab.gd
  -> 用户点击 Write / Copy
  -> mcp_dock.gd signal
  -> plugin.gd
  -> ClientConfigService.write_config_file()
```

写入时：

1. 先解析当前 UI 中展示的 JSON 文本。
2. 若目标文件已存在且可解析，则读取其原始配置。
3. 只操作 `mcpServers` 节点。
4. 只更新 `godot-mcp` 对应项，不覆盖其它 MCP server。

---

## `Server` 与 `Config` 页的共同约束

- 文本统一由本地化服务驱动，不依赖 Godot 自动翻译
- 动作都通过 signal 回流到 `plugin.gd`
- 页签本身不持有 `MCPHttpServer` 或 `SettingsStore` 实例
- 只读文本区优先使用 `TextEdit`

---

## 相关文件

| 路径 | 作用 |
|---|---|
| `ui/server_panel.tscn` | Server 页场景 |
| `ui/server_tab.gd` | Server 页控制器 |
| `ui/config_panel.tscn` | Config 页场景 |
| `ui/config_tab.gd` | Config 页控制器 |
| `plugin/config/client_config_service.gd` | 客户端配置生成与写入 |
| `plugin/config/config_paths.gd` | 各客户端路径与命令模板 |
