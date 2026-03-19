# Changelog

## 0.5.0 - 2026-03-19

### Added

- 新增 GDScript 异步诊断链路：`intelligence_script_analyze(include_diagnostics=true)` 会先返回脚本结构，再基于已保存到磁盘的脚本内容在后台补齐 `diagnostics`；首次调用可能返回 `pending`。
- 新增运行态健康摘要与详细自检分层：
  - `plugin_runtime_state(action=get_lsp_diagnostics_status)` 作为唯一详细 LSP 自检入口，返回 `loader / service / client`
  - `intelligence_project_state(include_runtime_health=true)` 返回轻量 `lsp_diagnostics` 健康摘要
- 新增 `stdio` transport（`plugin/runtime/mcp_stdio_server.gd`），支持标准 `Content-Length` 帧的 stdin/stdout MCP 通道。
- 扩展结构化修改能力：
  - `intelligence_scene_patch` 新增 `rename_node`、`update_property`
  - `intelligence_script_patch` 新增 `replace_method_body`、`delete_member`、`rename_member`
  - `intelligence_runtime_diagnose` 新增 `include_gd_errors`

### Changed

- `intelligence_script_analyze(include_diagnostics=true)` 改为“结构信息即时返回，LSP 诊断后台补齐”的模式，不再同步阻塞等待 `publishDiagnostics`。
- `/api/tools`、MCP `tools/list` 与 Dock Tools 页统一基于同一份“当前可见工具集合”生成；兼容别名继续可调用，但不再作为主展示入口。
- GDScript LSP diagnostics service 统一由 `tool_loader` 持有并跨 `reload_domain`、`reload_all_domains`、`soft_reload_plugin` 接管生命周期，减少旧实例残留和热重载漂移。
- 运行态文档与对外说明统一收口到 `plugin_runtime_state`、`intelligence_project_state` 与最新路由行为。

### Fixed

- 修复 `soft_reload_plugin` 后偶发出现的“HTTP 服务仍在线，但工具注册表为空”问题；现在会重建 server/controller 与 tool loader，恢复 `/health`、`/api/tools` 和 `tools/call` 的一致性。
- 修复 Tools 页树形折叠状态在递归展开/收起过程中的持久化错位问题，根节点与 `atomic` 层现在会随统一状态模型正确回填，不再出现回弹或需要重复 Shift 点击的情况。

## 0.4.0 - 2026-03-17

### Added

- 新增 Intelligence 工具层，提供 15 个面向项目推理和操作的高层工具，分为四类：
  - **项目级（6 个）**：`intelligence_project_state`、`intelligence_project_advise`、`intelligence_project_configure`、`intelligence_project_run`、`intelligence_project_stop`、`intelligence_runtime_diagnose`
  - **场景级（3 个）**：`intelligence_scene_validate`、`intelligence_scene_analyze`、`intelligence_scene_patch`
  - **脚本级（3 个）**：`intelligence_bindings_audit`、`intelligence_script_analyze`、`intelligence_script_patch`
  - **索引级（3 个）**：`intelligence_project_index_build`、`intelligence_project_symbol_search`、`intelligence_scene_dependency_graph`
- 新增 Atomic Bridge 调度层，把 Intelligence 工具与底层原子工具解耦，支持工具链组合调用。
- 新增用户自定义工具接入规范：`custom_tools/` 目录下的脚本需要使用 `user_*` 前缀，并实现 `handles()` / `get_tools()` / `execute()` 接口，可通过 bridge 共享调度能力。
- 新增插件目录写保护机制（`PLUGIN_PROTECTED_PATHS`），防止工具对插件自身文件的非授权修改。
- 补充 9 种语言（de/en/es/fr/ja/pt/ru/zh_cn/zh_tw）的 Intelligence 工具本地化文案。

### Changed

- 重构 `Tools` 页工具树：顶层直接展示 Intelligence 工具，每个工具下可展开查看依赖的原子工具链，原子工具还可以进一步展开到 Action 子节点。
- 新增工具树 `Shift+点击` 递归展开/折叠，以及右键上下文菜单（复制工具名 / Schema / 删除用户工具）。
- 全面优化 `MCPDebugBuffer` 日志系统：统一 source 命名规范，`_log()` 支持等级参数（trace/debug/info/warning/error），并在 `tool_loader`、`intelligence`、`atomic_bridge`、`impl_*` 各层补齐关键日志点。
- 将仓库目录结构调整为符合 Godot Asset Library 规范的 `addons/godot_dotnet_mcp/` 布局，并添加 `.gitattributes` 控制 ZIP 分发内容。

### Removed

- 移除 `Tools` 页 Profile 预设管理 UI（Profile 下拉、保存/删除 Profile 对话框），Profile 管理由 `plugin_developer_*` 工具组通过 MCP 完成。
- 暂时移除 `Tools` 页用户工具管理 UI；用户工具的创建、删除与恢复目前统一通过 `plugin_evolution_*` 工具组完成，后续版本会继续补回 UI 管理入口。

### Fixed

- 修复全量 MCP 工具中 `array` 类型定义缺少 `items` 属性导致的 `Invalid schema` 错误，涉及 `node_call`、`undo_redo`、`group`、`signal`、`collision_shape` 等工具。
- 修复 `editor_status` 和 `node_transform` 工具对非法参数类型静默通过的问题，增强输入校验的鲁棒性。

## 0.3.0 - 2026-03-12

### Added

- 新增 Godot .NET / C# 工作流能力：`.csproj` 解析、模板化 C# 脚本写入、跨文件脚本引用索引，以及 `dotnet restore/build` 结构化诊断。
- 新增运行时与插件自身的结构化诊断链路，覆盖运行时错误上下文、编译错误定位联动、插件自检摘要、错误时间线与健康状态查询。
- 新增用户工具治理能力，包括脚手架版本化与兼容性检查、审计过滤与会话标识、删除前备份与最近一次恢复入口。
- 新增工具调用统计回读，可按调用次数和最近调用时间查看工具使用情况。
- 新增工具配置导入导出能力，支持 profile 和 disabled tools 的 JSON round-trip。
- 新增完整技术文档体系，补齐架构、界面、模块和附录分层文档。

### Changed

- 收口 Dock 内插件自检的展示位置，统一放到 `Server` 页开头，减少跨页重复信息。
- 重构 `Tools` 页的树形交互和信息层次，收口搜索、tooltip、状态标记、预览面板、拖动分界和 profile 操作链路。
- 补齐分类、工具说明和提示信息的多语言内容，减少非英文环境下的未翻译标识暴露。
- 对 `README`、中文说明和安装发布文档做了同步收口，使首次接入、安装和配置流程更直接。

### Fixed

- 修复 `Tools` 页在折叠和重建过程中出现的 `Tree blocked / 空实体` 报错，减少 Dock 使用时的中断和连锁错误。

### Known Limitations

- 当前主项目调试回读更适合读取结构化状态和基础生命周期信息，仍不是 Godot 原生 Output / Debugger 面板的全量镜像。
- 如果项目中已经存在同名 `MCPRuntimeBridge` Autoload，插件不会强行覆盖该设置，相关运行时回读能力会表现为未接入状态。

## 0.2.0 - 2026-03-11

### Added

- 新增主项目运行时回读能力，可在 Godot 编辑器启动和停止主项目后，通过 `debug_runtime_bridge` 查看最近一次调试会话状态与基础生命周期事件。
- 新增更完整的插件治理能力，包括运行时控制、自进化工具管理、开发者工具入口，以及对应的内嵌使用指南。
- 新增插件权限级别与授权边界，方便在稳定使用、自进化扩展和开发调试之间做清晰隔离。
- 新增 `User` 分类相关管理能力，便于发现、审查和清理用户侧扩展工具。

### Changed

- 重新整理工具分组与插件分类，降低单一工具入口承载过多 action 的问题，整体可发现性和可读性更好。
- 收口 Dock 界面布局和文案，重点优化 Server、Config、Tools 页签在窄宽度下的可用性与信息层次。
- 补齐新增分类、工具说明和提示信息的多语言内容，减少非英文环境下的未翻译标识暴露。
- 对 `README`、中文说明和安装发布文档做了同步收口，使首次接入、安装和配置流程更直接。

### Fixed

- 修复兼容执行器聚合器导致的 `plugin` 重复注册问题，保留细粒度的 `plugin_runtime`、`plugin_evolution`、`plugin_developer` 入口。
- 修复 `tool_loader` 在继承脚本热重载不完整时导致的工具域漏加载问题，恢复 `script` 域及相关扩展工具的稳定发现。
- 修复插件启停和运行时重载过程中 HTTP transport 被提前中断的问题，软重载现在延迟执行。

## 0.1.0 - 2026-03-11

### Added

- 首个正式对外发布版本。
- Dock 化配置界面与工具 profile 管理。
- 75 个顶层 MCP 工具。
- 场景、节点、资源、脚本、动画、材质、TileMap、导航、物理、音频、UI 等能力域。
- Godot .NET / C# 场景绑定分析与导出成员审计。
- TileSet 最小闭环：`create_empty`、`assign_to_tilemap`。
- 调试事件缓冲区与基础诊断回读工具。
- 受控临时场景目录与场景保存链路收口。
- 继承感知的资源类型过滤。
- 安装与发布打包文档。

### Known Limitations

- `/root/...` 路径兼容补丁已落地，但最终黑盒行为仍取决于插件重载后的稳定性确认。
