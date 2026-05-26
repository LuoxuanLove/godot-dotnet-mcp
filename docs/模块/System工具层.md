# 系统工具层
系统工具层是插件的高层工具入口，统一暴露当前公开的系统工具，用于读取 MCP 能力说明、项目状态、汇总编辑器态、驱动编辑器界面与运行态、读取和清理编辑器 Output、分析场景与脚本、建立符号索引，并为 Agent 提供可执行的建议与补丁入口。

默认 `system` 预设只启用这一层，适合先理解上下文，再选择合适的高层 `system_*` 工具；底层原子工具仅作为内部实现链路展示。

---

## 文件结构

```text
tools/system/
├─ executor.gd         # 调度器：初始化 system 子域执行器并统一路由 execute / execute_async
├─ atomic_bridge.gd    # 原子桥：call_atomic() 调用下层原子 executor，附带写保护逻辑
├─ impl_help.gd        # 连接后能力说明与 Agent 推荐工作流（1 个公开工具）
├─ impl_editor.gd      # 编辑器 UI 控制与 Output 日志聚合入口（2 个公开工具）
├─ impl_runtime.gd     # 运行时控制 / 统一运行时 I/O（2 个公开工具）
├─ impl_scene.gd       # 场景级工具实现（4 个）
├─ impl_index.gd       # 索引与搜索实现（2 个公开工具 + 内部索引缓存）
├─ lsp_client.gd       # Godot LSP 客户端，供 system/script 与脚本编辑服务调用
├─ impl_project.gd     # 项目级、编辑器态与插件 freshness / 生命周期重载 / 更新聚合工具实现（10 个公开工具）
└─ impl_script.gd      # 脚本与绑定审计工具实现（3 个公开工具）
```

---

## 内置工具

### 能力说明
- `system_help`：返回面向 Agent 的 MCP 能力说明、推荐起手顺序、编辑器截图优先提示、隐藏控件枚举提示、运行时自动化能力与当前工具 schema 版本。

连接后建议先调用 `system_help` 或读取工具说明，确认当前 schema 版本；涉及 Dock、页签、弹窗、布局、按钮可见性或焦点切换时，应优先使用 `system_editor_control(action=activate_ui)` 通过 Godot API 激活目标界面，再用 `system_editor_control(action=capture_editor)` 获取编辑器截图。插件不提供系统级鼠标 / 键盘注入、物理光标移动、强制前台或系统窗口移动能力；如果可见控件枚举找不到目标，应立即用 `include_hidden=true` 重试。

### 项目级
- `system_project_state`：汇总当前项目状态，包括文件计数、最近错误、运行状态和 `runtime_capabilities` 能力位；同时返回 `file_enumeration_status`、`valid_file_enumeration`、`file_enumeration` 与 `enumeration_diagnostics`，用于区分“项目确实没有匹配文件”和“文件枚举范围可疑”。
- `system_editor_state`：统一聚合当前编辑器主屏幕、Inspector、FileSystem、项目运行摘要、runtime control 状态与 `runtime_capabilities` 能力位。
- `system_runtime_diagnose`：收集运行时错误、编译错误与性能快照。
- `system_project_configure`：读写项目设置、输入映射与自动加载配置。
- `system_project_files`：高层项目文件树入口，支持列目录、创建/删除目录、读写/复制/移动/删除文件、选中文件、扫描与重导入。
- `system_project_run`：运行主场景或指定场景；未提供 `success_markers` / `failure_markers` 时保持立即返回，`timeout_ms` 仅调度自动停止；提供 marker 时会通过异步 MCP tool path 等待 `debug_runtime_bridge` 结构化运行时事件中的 kind / payload 文本，失败 marker 优先于成功 marker，`timeout_ms` 作为带上限的等待超时，`log_tail` 会限幅，`auto_stop` 默认通过 `scene_run stop` 停止运行态但不会杀进程。失败时返回编辑器接口、项目、场景和 runtime control 上下文，便于判断缺失的是启动能力还是运行时接管能力。
- `system_project_run(background|minimized|no_focus=true)` 当前不会尝试抢占或控制 OS 窗口；这类请求会返回 `requires_foreground_window`，并给出 headless 逻辑测试或编辑器截图等降级路径。
- `system_project_stop`：停止当前运行中的项目。
- `system_plugin_reload`：读取运行中插件实例与磁盘 / 同步状态的 freshness；或调度一次不依赖前台 UI 的插件 disable/enable 生命周期重载。该调用只表示已接受调度，重载期间 MCP transport 可能断开，完成后应重新连接并重新拉取工具清单。
- `system_plugin_update`：读取当前安装的插件版本、schema 版本、同步来源、提交与指纹信息；选择 `latest_stable`、`latest_release` 或 `custom_branch` 更新来源；启动异步引用发现和 archive 同步，并通过 `get_status` 轮询同步状态与后续 lifecycle reload 进度。网络下载、文件同步和重载均保持异步，`discover_refs` / `start_sync` 只返回是否已接受或当前不可用。

这些工具当前由 `tools/system/impl_project.gd` 统一承载，并通过 `atomic_bridge.gd` 聚合底层 `project_*`、`editor_*` 与 `debug_*` 原子工具。

`system_editor_state.editor.editor_session_identity` 与 `system_project_state.runtime_capabilities.editor_context.editor_session_identity` 会暴露当前承载 MCP 的编辑器会话只读标识，包括 `session_id`、`pid`、启动参数、项目路径、headless/editor 状态，以及可用时的 MCP 服务地址。该身份固定标注 `identity_scope=current_editor_process`、`external_validation_process=false`、`safe_to_terminate=false`，用于帮助 Agent 把当前 MCP 编辑器会话与测试 harness 等外部验证进程区分开，而不是作为进程清理指令。

### 编辑器界面级
- `system_editor_control`：统一封装编辑器主屏幕切换、基于 Godot API 的无感 Dock/插件页签/底部面板激活、整窗截图、可见控件枚举、单控件截图、坐标映射、焦点移动、按钮类控件激活、控件本地坐标左键 / 右键点击，以及可见弹窗的最小安全交互。点击动作通过 Godot `Viewport` / `Control` 内部事件派发，不移动用户物理鼠标，也不接管系统窗口。
- `system_editor_log`：以高层入口读取当前 Output 面板、按错误/警告过滤输出，并清空 Output 面板。

这组工具当前由 `tools/system/impl_editor.gd` 承载，并通过 `atomic_bridge.gd` 聚合底层 `editor_status`、`editor_screenshot`、`editor_ui_control`、`editor_popup` 与 `editor_log` 原子工具，适合作为 Agent 处理编辑器界面和 Output 面板任务时的稳定入口。

### 运行时自动化级
- `system_runtime_control`：查询、启用或关闭当前编辑器调试会话的 runtime control 安全闸。
- `system_runtime_step`：统一运行时 I/O 入口；`action=step` 标准化封装“输入 -> 等待若干帧 -> 截图 -> 返回状态”闭环，`action=capture` 提供单帧 / 低频多帧截图，`action=input` 注入 `InputMap action` 或原始键盘输入。

默认截图、运行时事件、User Tool 审计日志和 profile 均收敛在 `user://godot_dotnet_mcp/` 分层目录下。插件启动不会自动清理缓存；需要查看或整理当前截图缓存时，由 Agent 显式调用 `system_userdata_maintenance(action=list_capture_cache)` 或 `system_userdata_maintenance(action=cleanup_capture_cache, dry_run=true)` 预览，再用 `dry_run=false` 应用。当前截图缓存清理会跳过 symlink、Windows junction 与 reparse point。需要整理历史遗留根级文件时，调用 `system_userdata_maintenance(action=cleanup_legacy_cache, dry_run=true)` 预览，再用 `dry_run=false` 应用。

### 场景级
- `system_scene_validate`：做场景完整性检查、依赖缺失检测，并在发现 `uid://...::::res://...` 依赖时提示 UID 缓存或 fallback 路径陈旧风险。
- `system_scene_analyze`：分析节点、脚本、绑定和结构问题。
- `system_scene_tree`：高层当前编辑场景树入口，支持获取/选择节点、添加/移除/重命名/重设父节点/排序节点、挂载脚本、读写属性与移动节点。
- `system_scene_patch`：以结构化方式修改 `.tscn` 内容。

### 脚本级
- `system_bindings_audit`：审计 C# `[Export]` / `[Signal]` 绑定与场景引用一致性。
- `system_script_analyze`：分析 `.gd` 或 `.cs` 的结构、导出与引用；其中 GDScript 语义诊断只经由 Godot LSP。
- `system_script_patch`：以成员级方式补丁脚本内容。

这些工具当前由 `tools/system/impl_script.gd` 统一承载，并通过 `atomic_bridge.gd` 聚合底层 `script_*`、`scene_*` 与 `filesystem_*` 原子工具。

### 项目资源审计级
- `system_resource_reference_audit`：扫描项目内 `.tscn` / `.tres` 文本资源，检查 `ExtResource` 的 UID 与 fallback path 是否能被当前资源数据库解析，并检查 `.tres` 中 C# custom `Resource` 脚本路径、`script_class`、文件名 / 类名和直接基类风险。该工具会把问题标记为 `dotnet_build_may_pass`，用于区分“C# 构建通过但场景 / 资源引用仍不一致”的加载风险。C# 资源脚本会优先读取 Roslyn `types[]`，依次按 `.tres` 的 `script_class`、脚本文件名和 `Resource` 基类证据解析类名；只有缺少可用 `types[]` 证据时，才退回到 `script_inspect` 的顶层类信息，避免把有效的 `[GlobalClass] Resource` 脚本误报为 unresolved。`script = ExtResource("...")` 的引用会先与所有已声明的 `ExtResource id` 匹配，再区分 `resource_script_ext_resource_missing`（id 未声明）和 `resource_script_ext_resource_not_script`（id 已声明但不是 Script 类型）。项目级扫描若没有枚举到任何 `.tscn` / `.tres`，会返回 `scan_status=invalid_scan_scope`、`valid_scan_scope=false`、`scan_warning_count` 与 `enumeration_diagnostics`，表示结果不可证明资源引用 clean；显式传入单个 `.tscn` / `.tres` 路径时则返回 `scan_status=explicit_path`。

### 索引级
- `system_project_symbol_search`：基于内部项目索引搜索类、脚本和场景符号；首次调用会懒构建索引，长会话中文件变化时会自动重建，必要时仍可 `refresh_index=true` 强制刷新。
- `system_scene_dependency_graph`：生成场景依赖图；同样复用内部项目索引，支持自动失效重建与按需刷新。

运行时自动化工具的边界固定为：

- `system_project_state`、`system_editor_state`、`system_scene_validate` 等只读工具可用，不代表 `system_project_run`、`system_runtime_control` 或 `system_runtime_step(action=capture)` 可用；Agent 应先读取 `runtime_capabilities.can_start_project`、`can_control_runtime`、`can_capture_runtime`、`headless_logic_ok`、`visible_capture_required`、`can_run_without_focus`、`no_focus_launch_supported`、`foreground_window_policy`、`foreground_window_fallbacks` 和 `blocking_reasons`。
- `system_project_run` 的 marker 等待只读取 runtime bridge 结构化日志事件，不是通用 stdout 捕获，也不定义项目专属 PASS / FAIL 约定；marker 参数、等待时间、轮询间隔和日志尾部数量都有固定限幅。
- 仅支持通过 Godot 编辑器启动的运行态。
- 默认关闭，必须先调用 `system_runtime_control(action=enable)`。
- 控制权限只对当前 debugger session 生效，不持久化。
- 项目停止、会话断开、插件重载后会自动失效。
- 失败响应统一保留 `error` / `message` 主字段，并按来源补充 `data.editor_context`、`data.runtime_context`、`data.runtime_state`、`data.hint`。

---

## 工作流建议

推荐顺序：

```text
system_editor_state / system_project_state
  -> system_project_files / system_scene_analyze / system_script_analyze / system_runtime_diagnose
  -> system_scene_tree / system_scene_patch / system_script_patch / 对应高层 system 工具
```

这条链路适合先获取全局上下文，再进入局部修改，避免一开始就落到过细的原子操作上。

如果目标是编辑器内运行态自动化，推荐顺序改为：

```text
system_project_run
  -> system_runtime_control(action=enable)
  -> system_runtime_step(action=step)
  -> system_runtime_step(action=capture / input)
```

其中 `system_runtime_step(action=step)` 是长期主闭环；更复杂的循环应由 Agent 或客户端在外层多次调用完成。

如果目标是编辑器界面内的控件查找与交互，推荐顺序改为：

```text
system_editor_state
	-> system_editor_control(action=activate_ui)
	-> system_editor_control(action=list_controls)
	-> system_editor_control(action=get_control / capture_control)
	-> system_editor_control(action=focus_control / activate_control / click_control / right_click_control / set_control_text)
```

其中 `activate_ui` 负责按 dock 标题、底部面板标题/路径、插件语义路径（如 `MCPDock/config`、`MCPDock/tools`）或 TabContainer 路径切换界面，成功后返回可见性与可选截图信息；`click_control` / `right_click_control` 使用 `local_x` / `local_y` 的 Control 本地坐标并返回 viewport、screen、截图与编辑器窗口只读边界信息的换算信息；更复杂的多步 UI 流程仍由 Agent 在外层自行编排。

---

## 与原子工具的关系

系统工具不会直接实现所有底层操作，而是通过 `atomic_bridge.gd` 组合调用场景、脚本、项目、文件系统、调试等原子 executor。

好处是：
- 上层工作流更稳定，便于 Agent 先理解问题再采取行动。
- 下层 executor 仍保持细粒度能力，供高层工具通过 Atomic Bridge 复用，并在 Tools 树中作为实现链路展示。
- 写保护可以集中在 Atomic Bridge 层统一执行。

---

## 写保护

`atomic_bridge.gd` 会拦截写入型 action，并检查目标路径是否位于插件目录下。默认情况下，系统工具不能直接写入：

```text
res://addons/godot_dotnet_mcp/
```

如果确需修改插件自身文件，应改用 `plugin_developer` 工具并显式授权。

---

## 用户工具扩展

`executor.gd` 在初始化内置 impl 之外，还会扫描：

```text
res://addons/godot_dotnet_mcp/custom_tools/
```

满足以下条件的脚本会被纳入同一工具树：
- 实现 `handles()`
- 实现 `get_tools()`
- 实现 `execute()`
- 工具名以 `user_` 开头

这样可以让“系统 / 用户”两类高层工具在同一套 UI 中并列展示。
