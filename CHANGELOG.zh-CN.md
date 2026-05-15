# 变更日志

## Unreleased

目标版本：`1.0.0-pre3`。

### Added

- 为 `system_project_run` 新增可选 runtime bridge 日志 marker 校验，支持 success / failure marker 匹配、超时处理、marker 模式默认自动停止，并通过 fake runtime events 补充契约覆盖。
- 新增 Tools 页弹窗坐标语义的契约覆盖与 UI 文档，覆盖真实右键路径，并明确 Dock 浮层定位所使用的 local / canvas / viewport / screen 坐标边界。

### Changed

- 为快速 .NET build 和重型插件 harness workflow 新增仅限 PR 的并发取消与 job timeout，同时保持非 PR 运行行为和 check 名称不变。
- 为重型插件 harness 脚本新增 timing 输出和可选 GitHub Step Summary 汇总，便于在 CI 中定位较慢 case 或阶段。
- 扩展 `validate-plugin` 对文档、杂项、hotfix 与 release 短分支的触发覆盖，并记录受保护 `dev` 的 PR 门禁要求。
- 新增 GitHub PR / Issue 模板、workflow lint 和发布 / Agent runbook，以约束更严格的短分支流程。
- 更新插件发布工作流：只执行验证并创建 GitHub Release，不再产出 zip 包资产。
- 新增非 `dev` 目标 PR 的 CI 反馈、发布 preflight 检查、`next` 草稿发布说明自动化，并强化 issue 诊断表单。
- 新增 `actions-bot-relay` workflow，使 `github-actions[bot]` 可在不引入额外 machine user 的前提下提交基于 patch 的短分支 PR。
- 将 PR 目标分支策略和快速 .NET build 检查从重型 Godot harness 中拆出，同时保留 `validate-plugin-harness` check 名称。

### Fixed

- 修复运行时调试桥消息格式，避免项目启动发送 runtime event / log / reply 时在 Godot 输出中出现 `Invalid message received` 错误。
- 修复 `system_project_run` marker 校验读取 live shared runtime bridge 事件，并避免新运行事件与运行前 marker 文本相同时被过滤掉。
- 修复工具上下文辅助函数，避免使用 editor interface 覆盖对象执行工具时触发 Godot GDScript VM 内部错误。
- 修复 `system_project_state` 与 `system_resource_reference_audit` 的项目文件枚举：空扫描现在会返回可疑诊断，不再被误判为资源审计 clean。
- 修复 TileMap 工具脚本解析问题，使 TileMap 工具域可在 MCP 工具注册期间正常实例化。

## 1.0.0-pre2 - 2026-05-06

### Added

- 新增 `system_editor_control` 的控件本地左键 / 右键点击、弹窗元数据和多坐标系映射支持，让 Agent 更可靠地定位并操作编辑器 UI。
- `system_project_state` 与 `system_editor_state` 新增更清晰的运行时能力报告，并增强 `system_project_run` 失败上下文，便于判断项目启动、运行时控制和截图能力是否就绪。
- 新增 `system_plugin_reload(action="full_reload_plugin")`、健康状态检查和 Tools 页本地化说明，Agent 可重载插件并确认当前运行实例已匹配已安装文件。
- 在 `/health`、`system_editor_state` 与 `system_project_state` 中新增编辑器会话标识，便于 Agent 区分当前 MCP 编辑器会话与其他 Godot 进程。
- 新增 `system_resource_reference_audit`，并增强 `system_scene_validate` 的 UID / fallback path 提示，用于发现 `.tscn` / `.tres` 陈旧引用和 C# custom Resource 脚本不匹配等 `dotnet build` 通过后仍可能存在的加载风险。

### Changed

- 将运行时截图与输入入口合并到 `system_runtime_step(action=step|capture|input)`，让公开运行时自动化工具保持高层粒度，同时在工具树中保留内部原子工具关联。

### Fixed

- 修复从 `custom_tools/` 加载的 User 工具未进入 MCP `tools/list` 的问题，现在客户端可直接发现并调用这些用户工具，而不只是能在 Tools 页状态中看到。
- 修复插件显示与使用的 MCP server 端口：当 Settings 中显式配置了 `3001` 等非默认端口时，多 Godot 编辑器会话下也会保持该配置，不再被继承的服务环境变量覆盖。
- 修复 Config 页代码块复制按钮：鼠标悬停在生成的配置内容上时按钮保持可见，并且周期性 UI 刷新不会再导致复制按钮隐藏或复制动作丢失。
- 修复 Tools 页工具树语言刷新：切换 Dock 语言后，工具、内部节点和 action 标签会立即刷新，无需完全重启插件。
- 修复 `system_script_patch` / `edit_gd add_variable` 的 GDScript 变量默认值处理：`default_value` 现在会正确写入脚本文件，并可被 `system_script_analyze` 统计和报告。
- 修复完整插件重载后的工具刷新问题，重新连接后即可看到新增的 System 工具和 schema 变化。
- 修复本地 HTTP 服务的 CORS 处理：默认不再向任意来源开放跨源访问，同时已配置的浏览器客户端仍可通过来源校验。
- 修复资源引用审计：当 UID 目标和 fallback path 都缺失时会正确报告错误，并避免把普通 `.tscn` C# 节点脚本误判为 custom Resource 脚本。

## 1.0.0-pre1 - 2026-04-28

### Added

- 新增基于 Roslyn 的内部 .NET Bridge 支持库，把早期 C# 工作流扩展为 C# 诊断、C# 文件读取与补丁修改、`.csproj` 读写，以及解决方案 / 项目信息检查。
- 新增 `system_help`，Agent 连接后可以直接了解插件能力、推荐起手步骤、截图优先提示、隐藏控件枚举提示和当前工具 schema 信息。
- 新增 `system_editor_state`、`system_editor_log`，并扩展 `system_editor_control`：Agent 可以检查编辑器状态、读取或清空 Output、激活 Dock 和底部面板、处理弹窗，并截取编辑器界面。
- 新增 `system_project_files` 与 `system_scene_tree`，分别覆盖项目文件树操作和当前编辑场景树操作。
- 新增运行时自动化工具：`system_runtime_control`、`system_runtime_capture`、`system_runtime_input` 和 `system_runtime_step`，用于运行时会话控制、脚本化输入、截图，以及“输入 -> 等待 -> 截图”的闭环。
- 编辑器截图和运行时截图现在可以指定输出目录；新增 `system_userdata_maintenance`，可列出并清理插件管理的截图 / 缓存文件，默认先预览再清理。
- 新增 `custom_tools/` 用户工具自动发现和热重载：把合法脚本放进 `res://addons/godot_dotnet_mcp/custom_tools/` 后，无需重启 Godot 就能被插件发现，并在工具页显示来源、状态、待重载和最新错误。
- 配置页新增更多客户端的一键配置与安装检测，覆盖 Claude Code CLI、Codex CLI/Desktop、Gemini CLI、OpenCode Desktop、Windsurf、Cline、Roo Code、Qwen Code 和 Cherry Studio。
- 新增统一的工具元数据，让 Dock 工具页和 MCP 工具清单使用同一套名称、说明、分类、动作和内部关联信息。
- 新增服务版本和工具 schema 信息的协议事实文件，方便 Agent 和客户端识别版本变化。
- 补齐 Home、配置页、工具页、用户工具、自检诊断和工具说明等新界面的多语言文案。
- 新增 Godot headless 插件测试框架，扩展大量工具执行器与运行时服务契约测试，并补充发布前验证和打包工作流。

### Changed

- 重新整理 Dock 的 Home、配置页和工具页。第一个页签现在叫 `主页`，服务状态、端点、完全重载和插件自检都集中放在这里。
- 配置页改得更直观：支持的客户端会显示更明确的安装、移除、打开动作，并在可用时显示具体安装位置。
- 工具页改为统一的树状展示，高层 System 工具和 User Tool 都有一致的本地化名称、说明、动作节点、数量统计和内部实现关联。
- 将上一版 Intelligence 中的项目、场景、脚本、运行时诊断和索引工作流迁移为 `system_*` 工具名。
- 面向 Agent 的核心 MCP 公开面收敛到高层 `system_*` 工具；底层工具保留在插件内部。
- 原来的 Intelligence 工具层重命名并整理为 System 工具层，与公开的 `system_*` API 名称保持一致。
- 将大型工具执行器拆分为更小的编辑器、脚本、动画、运行时、System、User、共享服务和各类工具域服务，便于维护和测试。
- 将运行时 / 服务端内部拆成更清晰的 HTTP、JSON-RPC、stdio、工具路由、重载、自检和运行时控制服务，不再集中在一个庞大的 server 文件里。
- 扩展 stdio 路由，让高层 `system_*` 工具和 HTTP 客户端走同一套公开工具链路。
- 重做插件启动、重载、Dock 协调、运行时状态、自检诊断和设置投影，让插件重载后更容易恢复并报告真实状态。
- 用户工具加载流程拆成“发现工具、刷新目录、重新加载工具脚本、刷新界面”几步，状态变化更清楚。
- 对外日志级别收敛为 `debug`、`info`、`warning`、`error`。
- 基于 tag 到 tag 的 git 对比重建变更日志，使每个版本只记录相对于上一版本实际发布的变化。
- README 以及架构、模块、界面、测试、发布、持久化、编码规范等文档已同步到 v1.0 插件形态。

### Removed

- 移除旧的公开 `intelligence_*` 工具名。大多数工作流现在改用对应的 `system_*` 工具，例如 `system_project_state`、`system_runtime_diagnose`、`system_scene_analyze`、`system_script_analyze` 和 `system_bindings_audit`。
- 移除独立的 `intelligence_project_advise` 建议工具。Agent 现在应通过 `system_help`、`system_project_state`、`system_editor_state`、诊断工具、场景 / 脚本分析工具先观察状态，再自行选择下一步工具。
- 移除低层原子工具域作为主要公开工作流入口。场景、脚本、编辑器、运行时、文件系统、动画、节点、资源、调试等底层能力仍作为高层工具和工具页树背后的内部实现保留。
- 移除旧的公开 Intelligence 工具树和对应文档页，统一改为 System 工具树与 `docs/模块/System工具层.md`。
- 移除旧的权限级别界面和主页高级权限设置，用户不再需要手动选择能力等级。
- 移除作为独立公开日志级别的 `trace`；旧输入仍作为兼容别名归并到 `debug`。
- 移除旧的 `user://` 根级缓存布局作为当前存储模型。插件管理的截图、运行时数据、日志、profile 和配置交换文件现在统一放在 `user://godot_dotnet_mcp/` 下，并通过显式维护工具处理旧文件清理。
- 移除随包分发中的旧脚本工具总入口和 Intelligence 分发器文件；相关能力已拆入 System 工具层和脚本服务实现。

### Fixed

- 修复高层 `system_*` 工具在 HTTP 和 stdio 两种通道中的路由一致性，让同一批公开工具能通过两种连接方式使用。
- 修复插件重载和 Dock 重建流程，重载后能更可靠地保留设置、刷新 Dock 模型并展示诊断状态。
- 修复运行时服务关闭和端口复用问题，降低重载后端口仍被占用导致服务启动失败的概率。
- 修复 `system_project_run` 的超时处理，需要时可以自动停止运行过久的场景。
- 修复工具层重组后 GDScript 诊断和脚本编辑辅助链路的访问问题。
- 修复用户工具新增、修改、删除、恢复，以及删除最后一个用户工具后的清理流程，工具页无需重启 Godot 就能回到正确状态。
- 修复工具元数据、分类、清单和展示信息不一致的问题，让工具页与 MCP 工具列表保持对齐。
- 修复多处 headless 验证和契约测试覆盖缺口，让 CI 能覆盖更多插件运行时、界面展示和工具执行器行为。

## 0.5.0 - 2026-03-19

### Added

- 新增异步 GDScript 诊断：`intelligence_script_analyze(include_diagnostics=true)` 会先返回脚本结构，再基于已保存到磁盘的文件在后台补齐 `diagnostics`；首次调用可能返回 `pending`。
- 新增运行时健康摘要与详细自检分层：
  - `plugin_runtime_state(action=get_lsp_diagnostics_status)` 作为唯一详细 LSP 自检入口，返回 `loader / service / client`
  - `intelligence_project_state(include_runtime_health=true)` 返回轻量 `lsp_diagnostics` 健康摘要
- 新增 `stdio` 传输层（`plugin/runtime/mcp_stdio_server.gd`），支持标准 `Content-Length` 帧的 stdin/stdout MCP 通道。
- 扩展结构化编辑能力：
  - `intelligence_scene_patch` 新增 `rename_node` 与 `update_property`
  - `intelligence_script_patch` 新增 `replace_method_body`、`delete_member`、`rename_member`
  - `intelligence_runtime_diagnose` 新增 `include_gd_errors`

### Changed

- `intelligence_script_analyze(include_diagnostics=true)` 改为“结构先返回、诊断后补齐”的模式，不再阻塞等待 `publishDiagnostics`。
- `/api/tools`、MCP `tools/list` 与 Dock Tools 统一基于同一份可见工具集生成；兼容别名仍可调用，但不再作为主展示入口。
- GDScript LSP diagnostics 服务由 `tool_loader` 统一持有，并跨 `reload_domain`、`reload_all_domains`、`soft_reload_plugin` 接管生命周期，减少旧实例残留。
- 运行时说明与对外文档统一围绕 `plugin_runtime_state`、`intelligence_project_state` 和当前路由行为收口。

### Fixed

- 修复 `soft_reload_plugin` 偶发出现的“HTTP 服务仍在线但工具注册表为空”问题；现在会一起重建 server/controller 与 tool loader，保持 `/health`、`/api/tools` 与 `tools/call` 一致。
- 修复 Tools 树在递归展开/折叠后的状态回填错乱；根节点与 `atomic` 层现在会按统一状态模型正确恢复，不再反复回弹。

## 0.4.0 - 2026-03-17

### Added

- 新增 Intelligence 工具层，提供 15 个面向项目级推理与操作的高层工具，分为四类：
  - **Project（6）**：`intelligence_project_state`、`intelligence_project_advise`、`intelligence_project_configure`、`intelligence_project_run`、`intelligence_project_stop`、`intelligence_runtime_diagnose`
  - **Scene（3）**：`intelligence_scene_validate`、`intelligence_scene_analyze`、`intelligence_scene_patch`
  - **Script（3）**：`intelligence_bindings_audit`、`intelligence_script_analyze`、`intelligence_script_patch`
  - **Index（3）**：`intelligence_project_index_build`、`intelligence_project_symbol_search`、`intelligence_scene_dependency_graph`
- 新增 Atomic Bridge 调度层，用于连接 Intelligence 工具与底层原子工具并支持工具链组合。
- 新增用户自定义工具集成：放置在 `custom_tools/` 下的工具需要使用 `user_*` 前缀，并实现 `handles()`、`get_tools()` 与 `execute()`。
- 新增插件目录写保护（`PLUGIN_PROTECTED_PATHS`），防止插件自有文件被未授权修改。
- 新增 9 种语言的 Intelligence 文档本地化：de/en/es/fr/ja/pt/ru/zh_cn/zh_tw。

### Changed

- 重构 `Tools` 页树结构：顶层直接显示 Intelligence 工具，每个工具可展开查看其依赖的原子工具链，原子工具还可继续展开到 Action 节点。
- 新增 `Shift` 递归展开/折叠，以及右键菜单（复制工具名、Schema、删除用户工具）。
- 重构 `MCPDebugBuffer` 日志系统：统一 source 命名、增加日志级别（`trace/debug/info/warning/error`），并补齐 `tool_loader`、`intelligence`、`atomic_bridge`、`impl_*` 的关键日志点。
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
- 新增插件权限级别与授权边界，用于区分稳定使用、自动化扩展和开发调试能力。
- 新增 `User` 分类管理支持，便于发现、审计与清理用户侧扩展工具。

### Changed

- 重新整理工具分组与插件分类，减少单个工具入口暴露过多动作的问题，提升可发现性。
- 简化 Dock 界面布局与文档，重点优化 `Server`、`Config`、`Tools` 在窄宽度下的可用性。
- 补充更多分类、工具说明与提示的多语言内容，减少未翻译标记。
- 同步 `README`、中文 README 与发布文档，使首次接入、安装与配置流程保持一致。

### Fixed

- 修复 `Tools` 页在折叠和重建过程中出现的 `Tree blocked` / 空实例报错，减少 Dock 使用时的中断和连锁错误。

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
