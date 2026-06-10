# v2 Bridge 升级契约

v2 Companion bridge 契约要求 editor-live 状态始终以 Godot 编辑器插件为权威来源。Project session 可以在未打开编辑器时继续提供 static/headless analysis，但在匹配的 editor bridge 报告 online 状态前，不得暴露选中节点、Inspector 状态、Dock 状态、截图或运行时验证。

## Bridge 状态

- `disabled`：bridge 被明确设为不可用。
- `offline`：project session 没有活动 editor bridge。
- `online`：editor bridge 已连接到同一个项目，并报告非空 `editor_session_id`。
- `version_mismatch`：editor bridge 存在，但对当前 Companion 契约版本不可信。

## 升级规则

- Static/headless session 启动时不具备 live editor 能力。
- Editor-live 升级必须同时满足 `state = online`、匹配的 `project_id`、非空 `editor_session_id`，以及兼容的 `plugin_version`。
- Offline、disabled 或 version-mismatch 状态必须保持 `supports_live_editor_state = false`。
- Bridge status schema 本身不得启动进程、打开端口或拉起编辑器。

## 工具作用域

所有消费 bridge status 的工具调用都必须同时携带 `project_id` 与 `session_id`。来自一个项目的 bridge status 不能升级另一个项目的 session。
