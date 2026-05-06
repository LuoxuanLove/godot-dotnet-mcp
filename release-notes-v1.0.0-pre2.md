# Godot .NET MCP v1.0.0-pre2

`v1.0.0-pre2` 是 Godot .NET MCP 的第二个 1.0 预发布版本，继续补强 System 工具层、编辑器与运行时自动化、客户端接入配置、插件内 Roslyn 支持、用户工具热重载、本地化 Dock UI 与发布验证流程。

本版本变更范围如下。

## Added

- 新增 `system_editor_control` 的控件本地左键 / 右键点击、弹窗元数据和多坐标系映射支持，让 Agent 更可靠地定位并操作编辑器 UI。
- `system_project_state` 与 `system_editor_state` 新增更清晰的运行时能力报告，并增强 `system_project_run` 失败上下文，便于判断项目启动、运行时控制和截图能力是否就绪。
- 新增 `system_plugin_reload(action="full_reload_plugin")`、健康状态检查和 Tools 页本地化说明，Agent 可重载插件并确认当前运行实例已匹配已安装文件。
- 在 `/health`、`system_editor_state` 与 `system_project_state` 中新增编辑器会话标识，便于 Agent 区分当前 MCP 编辑器会话与其他 Godot 进程。
- 新增 `system_resource_reference_audit`，并增强 `system_scene_validate` 的 UID / fallback path 提示，用于发现 `.tscn` / `.tres` 陈旧引用和 C# custom Resource 脚本不匹配等 `dotnet build` 通过后仍可能存在的加载风险。

## Changed

- 将运行时截图与输入入口合并到 `system_runtime_step(action=step|capture|input)`，让公开运行时自动化工具保持高层粒度，同时在工具树中保留内部原子工具关联。

## Fixed

- 修复从 `custom_tools/` 加载的 User 工具未进入 MCP `tools/list` 的问题，现在客户端可直接发现并调用这些用户工具，而不只是能在 Tools 页状态中看到。
- 修复插件显示与使用的 MCP server 端口：当 Settings 中显式配置了 `3001` 等非默认端口时，多 Godot 编辑器会话下也会保持该配置，不再被继承的服务环境变量覆盖。
- 修复 Config 页代码块复制按钮：鼠标悬停在生成的配置内容上时按钮保持可见，并且周期性 UI 刷新不会再导致复制按钮隐藏或复制动作丢失。
- 修复 Tools 页工具树语言刷新：切换 Dock 语言后，工具、内部节点和 action 标签会立即刷新，无需完全重启插件。
- 修复 `system_script_patch` / `edit_gd add_variable` 的 GDScript 变量默认值处理：`default_value` 现在会正确写入脚本文件，并可被 `system_script_analyze` 统计和报告。
- 修复完整插件重载后的工具刷新问题，重新连接后即可看到新增的 System 工具和 schema 变化。
- 修复本地 HTTP 服务的 CORS 处理：默认不再向任意来源开放跨源访问，同时已配置的浏览器客户端仍可通过来源校验。
- 修复资源引用审计：当 UID 目标和 fallback path 都缺失时会正确报告错误，并避免把普通 `.tscn` C# 节点脚本误判为 custom Resource 脚本。
