# Changelog

## 0.4.0 - 2026-03-17

### Added

- 新增 Intelligence 工具层，提供 15 个面向项目全链路理解与操作的高层工具，分为四类：
  - **项目级（6 个）**：`intelligence_project_state`（项目快照）、`intelligence_project_advise`（诊断建议）、`intelligence_project_configure`（配置管理）、`intelligence_project_run`（运行项目）、`intelligence_project_stop`（停止项目）、`intelligence_runtime_diagnose`（运行时诊断）
  - **场景级（3 个）**：`intelligence_scene_validate`（场景验证）、`intelligence_scene_analyze`（深度分析）、`intelligence_scene_patch`（结构化修改）
  - **脚本级（3 个）**：`intelligence_bindings_audit`（C# 绑定审计）、`intelligence_script_analyze`（脚本深度分析）、`intelligence_script_patch`（脚本结构化修改）
  - **索引级（3 个）**：`intelligence_project_index_build`（构建项目索引）、`intelligence_project_symbol_search`（符号搜索）、`intelligence_scene_dependency_graph`（场景依赖图）
- 新增 Atomic Bridge 调度层，将 Intelligence 工具与底层原子工具解耦，支持工具链组合调用。
- 新增用户自定义工具接入规范：自定义工具放置于 `custom_tools/` 目录，须以 `user_*` 前缀命名并实现 `handles()` / `get_tools()` / `execute()` 接口，可通过 bridge 共享调度能力。
- 新增插件目录写保护机制（`PLUGIN_PROTECTED_PATHS`），阻止工具对插件自身文件的非授权修改。
- 补充 9 种语言（de/en/es/fr/ja/pt/ru/zh_cn/zh_tw）的 Intelligence 工具本地化文案。

### Changed

- 重构 `Tools` 页工具树：顶层直接展示 Intelligence 工具，每个工具下可展开查看所依赖的原子工具链路，原子工具可进一步展开至 Action 叶节点。
- 新增工具树 Shift+点击递归展开/折叠，以及右键上下文菜单（复制工具名 / Schema / 删除用户工具）。
- 移除工具树中旧有的 Profile 预设管理 UI（Profile 下拉、保存/删除 Profile 对话框），精简交互路径。
- 全面优化 MCPDebugBuffer 日志系统：统一 source 命名规范，`_log()` 支持等级参数（trace/debug/info/warning/error），在 tool_loader、intelligence、atomic_bridge、impl_* 各层补充关键日志点。
- 将仓库目录结构调整为符合 Godot Asset Library 规范的 `addons/godot_dotnet_mcp/` 布局，并添加 `.gitattributes` 控制 ZIP 分发内容。

### Fixed

- 修复全量 MCP 工具中 `array` 类型定义缺失 `items` 属性导致的 `Invalid schema` 错误，涉及 `node_call`、`undo_redo`、`group`、`signal`、`collision_shape` 等工具。
- 修复 `editor_status` 和 `node_transform` 工具对非法参数类型静默通过的问题，增强输入校验鲁棒性。

## 0.3.0 - 2026-03-12

### Added

- 新增 Godot .NET / C# 工作流能力：`.csproj` 解析、模板化 C# 脚本写入、跨文件脚本引用索引，以及 `dotnet restore/build` 结构化诊断。
- 新增运行时与插件自身的结构化诊断链路，覆盖运行时错误上下文、编译错误定位联动、插件自检摘要、错误时间线与健康状态查询。
- 新增用户工具治理能力，包括脚手架版本化与兼容检查、审计过滤与会话标识、删除前备份与最近一次恢复入口。
- 新增工具调用统计回读，可按调用次数和最近调用时间查看工具使用情况。
- 新增工具配置导入导出能力，支持 profile 与 disabled tools 的 JSON round-trip。
- 新增完整技术文档体系，补齐架构、界面、模块与附录分层文档。

### Changed

- 收口 Dock 内插件自检摘要的展示位置，统一放到 `Server` 页开头，减少跨页重复信息。
- 重构 `Tools` 页的树形交互与信息层次，收口搜索、tooltip、状态标记、预览面板、拖动分界与 profile 操作链路。
- 收口多语言资源与本地化服务，补齐 `v0.3` 新增功能所需键值。
- 将对外版本提升到 `0.3.0`，同步插件元数据与运行时返回版本。

### Fixed

- 修复兼容执行器带来的聚合 `plugin` 重复注册问题，保留细粒度 `plugin_runtime`、`plugin_evolution`、`plugin_developer` 入口。
- 修复 `tool_loader` 对继承脚本热重载不完整导致的工具域漏载问题，恢复 `script` 域与相关扩展工具的稳定发现。
- 修复插件启停与运行时重载过程中 HTTP transport 被提前中断的问题，软重载与 server restart 现改为延迟调度执行。

## 0.2.0 - 2026-03-11

### Added

- 新增主项目运行时回读能力，可在 Godot 编辑器启动和停止主项目后，通过 `debug_runtime_bridge` 查看最近一次调试会话状态与基础生命周期事件。
- 新增更完整的插件治理能力，包括运行时控制、自进化工具管理、开发者工具入口，以及对应的内置使用指引。
- 新增插件权限级别与授权边界，便于在稳定使用、自进化扩展和开发调试之间做清晰隔离。
- 新增 `User` 分类相关管理能力，方便发现、审查和清理用户侧扩展工具。

### Changed

- 重新整理工具分组与插件分类，降低单一工具入口承载过多 action 的问题，整体可发现性和可读性更好。
- 收口 Dock 端界面布局与文案，重点优化 Server、Config、Tools 页签在窄宽度下的可用性与信息层次。
- 补齐新增分类、工具说明和提示信息的多语言内容，减少非英文环境下的未翻译标识暴露。
- 对 `README`、中文说明和安装发布文档做了同步收口，使首次接入、安装和配置流程更直接。

### Fixed

- 修复 `Tools` 页签在折叠和重建过程中出现的 `Tree blocked / 空实例` 报错，减少 Dock 使用时的中断和连锁错误。

### Known Limitations

- 当前主项目调试回读更适合读取结构化状态与基础生命周期信息，仍不是 Godot 原生 Output / Debugger 面板的全文镜像。
- 若项目中已有同名 `MCPRuntimeBridge` Autoload，插件不会强行覆盖该设置，相关运行时回读能力会表现为未接入状态。

## 0.1.0 - 2026-03-11

### Added

- 首个正式对外发布版本。
- Dock 化配置界面与工具 profile 管理。
- 75 个顶层 MCP 工具。
- 场景、节点、资源、脚本、动画、材质、TileMap、导航、物理、音频、UI 等能力域。
- Godot .NET / C# 场景绑定分析与导出成员审计。
- TileSet 最小闭环：`create_empty`、`assign_to_tilemap`。
- 调试事件缓冲区与基础诊断读取工具。
- 受控临时场景目录与场景保存链路收口。
- 继承感知的资源类型过滤。
- 安装与发布文档及 zip 发布包。

### Known Limitations

- 节点 `/root/...` 路径兼容补丁已落地，但仍待插件重载后的最终黑盒确认。
