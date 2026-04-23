# 系统工具层
系统工具层是插件的高层工具入口，统一暴露当前公开的系统工具，用于读取项目状态、汇总编辑器态、驱动编辑器界面与运行态、读取和清理编辑器 Output、分析场景与脚本、建立符号索引，并为 Agent 提供可执行的建议与补丁入口。

默认 `system` 预设只启用这一层，适合先理解上下文，再决定是否下钻到底层原子工具。

---

## 文件结构

```text
tools/system/
├─ executor.gd         # 调度器：初始化 system 子域执行器并统一路由 execute / execute_async
├─ atomic_bridge.gd    # 原子桥：call_atomic() 调用下层原子 executor，附带写保护逻辑
├─ impl_editor.gd      # 编辑器 UI 控制聚合入口（1 个公开工具）
├─ impl_runtime.gd     # 运行时控制 / 统一截图 / 输入 / step（4 个公开工具）
├─ impl_scene.gd       # 场景级工具实现（3 个）
├─ impl_index.gd       # 索引与搜索实现（2 个公开工具 + 内部索引缓存）
├─ lsp_client.gd       # Godot LSP 客户端，供 system/script 与脚本编辑服务调用
├─ impl_project.gd     # 项目级与编辑器态聚合工具实现（6 个公开工具）
└─ impl_script.gd      # 脚本与绑定审计工具实现（3 个公开工具）
```

---

## 内置工具

### 项目级
- `system_project_state`：汇总当前项目状态，包括文件计数、最近错误和运行状态。
- `system_editor_state`：统一聚合当前编辑器主屏幕、Inspector、FileSystem、项目运行摘要与 runtime control 状态。
- `system_runtime_diagnose`：收集运行时错误、编译错误与性能快照。
- `system_project_configure`：读写项目设置、输入映射与自动加载配置。
- `system_project_run`：运行主场景或指定场景。
- `system_project_stop`：停止当前运行中的项目。

这些工具当前由 `tools/system/impl_project.gd` 统一承载，并通过 `atomic_bridge.gd` 聚合底层 `project_*`、`editor_*` 与 `debug_*` 原子工具。

### 编辑器界面级
- `system_editor_control`：统一封装编辑器主屏幕切换、整窗截图、可见控件枚举、单控件截图、焦点移动、按钮类控件激活，以及可见弹窗的最小安全交互。
- `system_editor_log`：以高层入口读取当前 Output 面板、按错误/警告过滤输出，并清空 Output 面板。

这组工具当前由 `tools/system/impl_editor.gd` 承载，并通过 `atomic_bridge.gd` 聚合底层 `editor_status`、`editor_screenshot`、`editor_ui_control`、`editor_popup` 与 `editor_log` 原子工具，适合作为 Agent 处理编辑器界面和 Output 面板任务时的稳定入口。

### 运行时自动化级
- `system_runtime_control`：查询、启用或关闭当前编辑器调试会话的 runtime control 安全闸。
- `system_runtime_capture`：统一截图入口；默认抓取单帧，传 `frame_count > 1` 时按 `interval_frames` 抓取低频多帧序列。
- `system_runtime_input`：注入 `InputMap action` 或原始键盘输入，支持 `press/release/tap/hold`。
- `system_runtime_step`：标准化封装“输入 -> 等待若干帧 -> 截图 -> 返回状态”闭环。

### 场景级
- `system_scene_validate`：做场景完整性检查与依赖缺失检测。
- `system_scene_analyze`：分析节点、脚本、绑定和结构问题。
- `system_scene_patch`：以结构化方式修改 `.tscn` 内容。

### 脚本级
- `system_bindings_audit`：审计 C# `[Export]` / `[Signal]` 绑定与场景引用一致性。
- `system_script_analyze`：分析 `.gd` 或 `.cs` 的结构、导出与引用；其中 GDScript 语义诊断只经由 Godot LSP。
- `system_script_patch`：以成员级方式补丁脚本内容。

这些工具当前由 `tools/system/impl_script.gd` 统一承载，并通过 `atomic_bridge.gd` 聚合底层 `script_*`、`scene_*` 与 `filesystem_*` 原子工具。

### 索引级
- `system_project_symbol_search`：基于内部项目索引搜索类、脚本和场景符号；首次调用会懒构建索引，长会话中文件变化时会自动重建，必要时仍可 `refresh_index=true` 强制刷新。
- `system_scene_dependency_graph`：生成场景依赖图；同样复用内部项目索引，支持自动失效重建与按需刷新。

运行时自动化工具的边界固定为：

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
  -> system_scene_analyze / system_script_analyze / system_runtime_diagnose
  -> system_scene_patch / system_script_patch / 具体原子工具
```

这条链路适合先获取全局上下文，再进入局部修改，避免一开始就落到过细的原子操作上。

如果目标是编辑器内运行态自动化，推荐顺序改为：

```text
system_project_run
  -> system_runtime_control(action=enable)
  -> system_runtime_step
  -> system_runtime_capture / system_runtime_input
```

其中 `system_runtime_step` 是长期主闭环；更复杂的循环应由 Agent 或客户端在外层多次调用完成。

如果目标是编辑器界面内的控件查找与交互，推荐顺序改为：

```text
system_editor_state
  -> system_editor_control(action=list_controls)
  -> system_editor_control(action=get_control / capture_control)
  -> system_editor_control(action=focus_control / activate_control / set_control_text)
```

其中 `system_editor_control` 优先负责安全、可回读的界面动作；更复杂的多步 UI 流程仍由 Agent 在外层自行编排。

---

## 与原子工具的关系

系统工具不会直接实现所有底层操作，而是通过 `atomic_bridge.gd` 组合调用场景、脚本、项目、文件系统、调试等原子 executor。

好处是：
- 上层工作流更稳定，便于 Agent 先理解问题再采取行动。
- 下层 executor 仍保持细粒度能力，可在需要时直接调用。
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
