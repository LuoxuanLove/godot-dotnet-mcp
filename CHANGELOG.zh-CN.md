# 变更日志

## Unreleased

### Added

- 新增已完成的 `.NET MCP Bridge` 首批能力：包含独立 .NET 8 Bridge 进程、stdio MCP 通道、Windows 自包含发布配置、Bridge-first 插件安装，以及 C# / `.csproj` 读写工具链。
- 新增 `custom_tools/` 外部落盘自动唤醒：将合法用户工具脚本直接放入 `res://addons/godot_dotnet_mcp/custom_tools/` 后，无需重启 Godot 即可被发现。
- 新增 User Tool 运行时状态预览：`Tools` 预览中可查看运行时域、版本、状态、待重载、最近错误、发现来源和最近刷新原因。

### Changed

- 完成 User Tool 热重载架构收口：用户工具现在按“单脚本 runtime slot”管理，不再混入 `system` 执行器生命周期。
- 统一 User Tool 刷新流程：显式拆分为注册表刷新、运行时重载与 UI 重建三个阶段。
- 调整 `Tools` 页统计口径：只统计系统高层工具与 User Tool，不再把内部原子工具计入可见总数。
- `Tools` 树继续保留 `系统` 与 `用户` 两个根节点。
- 对外 MCP 工具继续收敛为 15 个 `system_*` 高层工具，原子工具仅保留为内部依赖。
- 优化自检展示：区分“最近操作”和“最近告警”，并提供可恢复告警的清除入口。

### Fixed

- 修复 User Tool 运行时生命周期：外部新增、修改、删除、恢复脚本时，无需重启即可正确生效。
- 修复空 `user` 域清理：删除最后一个 User Tool 后，运行时会正确回到 `uninitialized`。

## 0.5.0 - 2026-03-19

### Added

- 新增异步 GDScript 诊断：`system_script_analyze(include_diagnostics=true)` 会先返回脚本结构，再基于已保存到磁盘的文件在后台补齐 `diagnostics`；首次调用可能返回 `pending`。
- 新增运行时健康摘要与详细自检分层：
  - `plugin_runtime_state(action=get_lsp_diagnostics_status)` 作为唯一详细 LSP 自检入口，返回 `loader / service / client`
  - `system_project_state(include_runtime_health=true)` 返回轻量 `lsp_diagnostics` 健康摘要
- 新增 `stdio` 传输层（`plugin/runtime/mcp_stdio_server.gd`），支持标准 `Content-Length` 帧的 stdin/stdout MCP 通道。
- 扩展结构化编辑能力：
  - `system_scene_patch` 新增 `rename_node` 与 `update_property`
  - `system_script_patch` 新增 `replace_method_body`、`delete_member`、`rename_member`
  - `system_runtime_diagnose` 新增 `include_gd_errors`

### Changed

- `system_script_analyze(include_diagnostics=true)` 改为“结构先返回、诊断后补齐”的模式，不再阻塞等待 `publishDiagnostics`。
- `/api/tools`、MCP `tools/list` 与 Dock Tools 统一基于同一份可见工具集生成；兼容别名仍可调用，但不再作为主展示入口。
- GDScript LSP diagnostics 服务由 `tool_loader` 统一持有，并跨 `reload_domain`、`reload_all_domains`、`soft_reload_plugin` 接管生命周期，减少旧实例残留。
- 运行时说明与对外文档统一围绕 `plugin_runtime_state`、`system_project_state` 和当前路由行为收口。

### Fixed

- 修复 `soft_reload_plugin` 偶发出现的“HTTP 服务仍在线但工具注册表为空”问题；现在会一起重建 server/controller 与 tool loader，保持 `/health`、`/api/tools` 与 `tools/call` 一致。
- 修复 Tools 树在递归展开/折叠后的状态回填错乱；根节点与 `atomic` 层现在会按统一状态模型正确恢复，不再反复回弹。

## 0.4.0 - 2026-03-17

### Added

- 新增 System 工具层，提供 15 个面向项目级推理与操作的高层工具，分为四类：
  - **Project（6）**：`system_project_state`、`system_project_advise`、`system_project_configure`、`system_project_run`、`system_project_stop`、`system_runtime_diagnose`
  - **Scene（3）**：`system_scene_validate`、`system_scene_analyze`、`system_scene_patch`
  - **Script（3）**：`system_bindings_audit`、`system_script_analyze`、`system_script_patch`
  - **Index（3）**：`system_project_index_build`、`system_project_symbol_search`、`system_scene_dependency_graph`
- 新增 Atomic Bridge 调度层，用于连接 System 工具与底层原子工具并支持工具链组合。
- 新增用户自定义工具集成：放置在 `custom_tools/` 下的工具需要使用 `user_*` 前缀，并实现 `handles()`、`get_tools()` 与 `execute()`。
- 新增插件目录写保护（`PLUGIN_PROTECTED_PATHS`），防止插件自有文件被未授权修改。
- 新增 9 种语言的 System 文档本地化：de/en/es/fr/ja/pt/ru/zh_cn/zh_tw。

### Changed

- 重构 `Tools` 页树结构：顶层直接显示 System 工具，每个工具可展开查看其依赖的原子工具链，原子工具还可继续展开到 Action 节点。
- 新增 `Shift` 递归展开/折叠，以及右键菜单（复制工具名、Schema、删除用户工具）。
- 重构 `MCPDebugBuffer` 日志系统：统一 source 命名、增加日志级别（`trace/debug/info/warning/error`），并补齐 `tool_loader`、`system`、`atomic_bridge`、`impl_*` 的关键日志点。
- 仓库目录重组为 Godot Asset Library 规范的 `addons/godot_dotnet_mcp/` 布局，并新增 `.gitattributes` 控制发布 ZIP 内容。

### Removed

- 移除 `Tools` 页 Profile 预设管理 UI；Profile 管理迁移到 `plugin_developer_*` 工具组中通过 MCP 完成。
- 暂时移除 `Tools` 页用户工具管理 UI；用户工具的创建、删除与恢复目前统一通过 `plugin_evolution_*` 工具组完成，后续版本可能恢复独立 UI。

### Fixed

- 修复多项 MCP 工具在 `array` 类型参数缺少 `items` 定义时触发的 `Invalid schema` 错误，涉及 `node_call`、`undo_redo`、`group`、`signal`、`collision_shape` 等工具。
- 修复 `editor_status` 与 `node_transform` 对非法参数类型过于宽松的问题，增强输入校验鲁棒性。

## 0.3.0 - 2026-03-12

### Added

- 新增 Godot .NET / C# 工作流支持：`.csproj` 解析、模板化 C# 脚本写入、跨文件脚本引用索引，以及基于 `dotnet restore/build` 的结构化诊断。
- 新增运行时与插件自检能力，覆盖运行时错误上下文、编译错误定位、插件自检摘要、错误时间线与健康查询。
- 新增用户工具治理能力，包括脚手架版本化与兼容性检查、审计过滤与会话标识、删除前备份与最近恢复入口。
- 新增工具使用统计，可查看调用次数与最近调用时间。
- 新增工具配置导入导出，支持 profile 与 disabled tools 的 JSON 往返。
- 新增完整技术文档体系，覆盖架构、界面、模块与附录。

### Changed

- 将 Dock 中的插件自检摘要统一移动到 `Server` 页顶部，减少跨页重复信息。
- 重构 `Tools` 页的树形交互与信息层次，收口搜索、tooltip、状态标记、预览面板、拖动分隔与 profile 操作链路。
- 补齐新增分类、工具说明与提示的本地化资源。
- 将公开版本号提升到 `0.3.0`，并同步插件元数据与运行时版本字符串。

### Fixed

- 修复兼容执行器聚合导致的重复插件注册，保留 `plugin_runtime`、`plugin_evolution`、`plugin_developer` 三个独立入口。
- 修复继承脚本热重载不完整导致的工具域加载缺失，恢复 `script` 域及其扩展工具的稳定发现。
- 修复插件启停与运行时重载期间 HTTP 传输中断的问题，将软重载改为延迟调度。

## 0.2.0 - 2026-03-11

### Added

- 新增主项目运行时回读能力，可通过 `debug_runtime_bridge` 追踪 Godot 编辑器启动/停止后的调试会话状态。
- 新增更完整的插件治理层，包括运行时控制、自动化工具管理、开发者入口与使用引导。
- 新增插件权限级别与授权边界，用于区分稳定使用、自我扩展与开发调试。
- 新增 `User` 分类管理支持，便于发现、审计与清理用户侧扩展工具。

### Changed

- 重新整理工具分组与插件分类，减少单个工具入口暴露过多动作的问题，提升可发现性。
- 简化 Dock 界面布局与文档，重点优化 `Server`、`Config`、`Tools` 在窄宽度下的可用性。
- 补充更多分类、工具说明与提示的多语言内容，减少未翻译标记。
- 同步 `README`、中文 README 与发布文档，使首次接入、安装与配置流程保持一致。

### Fixed

- 修复兼容执行器聚合器导致的 `plugin` 重复注册，保留 `plugin_runtime`、`plugin_evolution`、`plugin_developer` 入口。
- 修复 `tool_loader` 未完整热重载继承脚本时导致的工具域漏加载，恢复 `script` 域及相关扩展工具的稳定发现。
- 修复插件启停与运行时重载过程中 HTTP 传输被提前中断的问题，将软重载改为延迟执行。

### Known Limitations

- 当前运行时回读更适合读取结构化状态与生命周期信息，而不是完整镜像 Godot 原生 Output / Debugger 面板。
- 如果项目中已存在同名 `MCPRuntimeBridge` Autoload，插件不会强制覆盖该设置，相关运行时回读会显示为未安装。

## 0.1.0 - 2026-03-11

### Added

- 首个公开发布版本。
- 基于 Dock 的配置界面与工具 Profile 管理。
- 75 个顶层 MCP 工具。
- 场景、节点、资源、脚本、动画、材质、TileMap、导航、物理、音频与 UI 能力。
- Godot .NET / C# 场景绑定分析与导出成员审计。
- TileSet 最小闭环支持：`create_empty` 与 `assign_to_tilemap`。
- 调试事件缓冲与基础运行时诊断回读工具。
- 受控的临时场景目录与场景保存链路。
- 继承感知的资源类型过滤。
- 安装与发布打包文档。

### Known Limitations

- `/root/...` 路径兼容已做补丁，但最终行为仍依赖插件重载后的稳定性。
