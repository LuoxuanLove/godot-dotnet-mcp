# Godot .NET MCP v1.0.0-pre1

`v1.0.0-pre1` 是一次令人兴奋的预发布：Godot .NET MCP 正在让 Agent 真正理解并操作 Godot 编辑器。

该版本带来一批关键能力，把项目状态、编辑器 UI、场景与脚本、运行时输入 / 截图、日志诊断、客户端配置和用户自定义工具整合成更完整的工作流。它继续坚持一个核心开发哲学：提供真实可用的编辑器工具，而不是让 Agent 只读文件后猜测。

该版本变更范围较大，包含新的工具体系、Dock 交互、插件内 Roslyn 支持、运行时自动化、截图 / 缓存维护、客户端一键配置、用户工具热重载、多语言界面、headless 验证和发布打包流程。请注意：这是 **pre-release**，并且与过去版本存在不兼容变更；从旧版本升级时，建议先删除旧插件目录，再安装新的插件包。

## Added

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

## Changed

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

## Removed

- 移除旧的公开 `intelligence_*` 工具名。大多数工作流现在改用对应的 `system_*` 工具，例如 `system_project_state`、`system_runtime_diagnose`、`system_scene_analyze`、`system_script_analyze` 和 `system_bindings_audit`。
- 移除独立的 `intelligence_project_advise` 建议工具。Agent 现在应通过 `system_help`、`system_project_state`、`system_editor_state`、诊断工具、场景 / 脚本分析工具先观察状态，再自行选择下一步工具。
- 移除低层原子工具域作为主要公开工作流入口。场景、脚本、编辑器、运行时、文件系统、动画、节点、资源、调试等底层能力仍作为高层工具和工具页树背后的内部实现保留。
- 移除旧的公开 Intelligence 工具树和对应文档页，统一改为 System 工具树与 `docs/模块/System工具层.md`。
- 移除旧的权限级别界面和主页高级权限设置，用户不再需要手动选择能力等级。
- 移除作为独立公开日志级别的 `trace`；旧输入仍作为兼容别名归并到 `debug`。
- 移除旧的 `user://` 根级缓存布局作为当前存储模型。插件管理的截图、运行时数据、日志、profile 和配置交换文件现在统一放在 `user://godot_dotnet_mcp/` 下，并通过显式维护工具处理旧文件清理。
- 移除随包分发中的旧脚本工具总入口和 Intelligence 分发器文件；相关能力已拆入 System 工具层和脚本服务实现。

## Fixed

- 修复高层 `system_*` 工具在 HTTP 和 stdio 两种通道中的路由一致性，让同一批公开工具能通过两种连接方式使用。
- 修复插件重载和 Dock 重建流程，重载后能更可靠地保留设置、刷新 Dock 模型并展示诊断状态。
- 修复运行时服务关闭和端口复用问题，降低重载后端口仍被占用导致服务启动失败的概率。
- 修复 `system_project_run` 的超时处理，需要时可以自动停止运行过久的场景。
- 修复工具层重组后 GDScript 诊断和脚本编辑辅助链路的访问问题。
- 修复用户工具新增、修改、删除、恢复，以及删除最后一个用户工具后的清理流程，工具页无需重启 Godot 就能回到正确状态。
- 修复工具元数据、分类、清单和展示信息不一致的问题，让工具页与 MCP 工具列表保持对齐。
- 修复多处 headless 验证和契约测试覆盖缺口，让 CI 能覆盖更多插件运行时、界面展示和工具执行器行为。
