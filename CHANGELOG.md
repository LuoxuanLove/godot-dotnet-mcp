# Changelog

## 0.2.0 - 2026-03-11

### Added

- 新增主项目运行时回读能力，可在 Godot 编辑器启动和停止主项目后，通过 `debug_runtime_bridge` 查看最近一次调试会话状态与基础生命周期事件
- 新增更完整的插件治理能力，包括运行时控制、自进化工具管理、开发者工具入口，以及对应的内置使用指南
- 新增插件权限级别与授权边界，便于在稳定使用、自进化扩展和开发调试之间做清晰隔离
- 新增 `User` 分类相关管理能力，方便发现、审查和清理用户侧扩展工具

### Changed

- 重新整理工具分组与插件分类，降低单一工具入口承载过多 action 的问题，整体可发现性和可读性更好
- 收口 Dock 端界面布局与文案，重点优化 Server、Config、Tools 页签在窄宽度下的可用性与信息层次
- 补齐新增分类、工具说明和提示信息的多语言内容，减少非英文环境下的未翻译标识暴露
- 对 README、中文说明和安装发布文档做了同步收口，使首次接入、安装和配置流程更直接

### Fixed

- 修复 `Tools` 页签在折叠和重建过程中出现的 `Tree blocked / 空实例` 报错，减少 Dock 使用时的中断和连锁错误

### Known Limitations

- 当前主项目调试回读更适合读取结构化状态与基础生命周期信息，仍不是 Godot 原生 Output / Debugger 面板的全文镜像
- 若项目中已有同名 `MCPRuntimeBridge` Autoload，插件不会强行覆盖该设置，相关运行时回读能力会表现为未接入状态

## 0.1.0 - 2026-03-11

### Added

- 首个正式对外发布版本
- Dock 化配置界面与工具 profile 管理
- 75 个顶层 MCP 工具
- 场景、节点、资源、脚本、动画、材质、TileMap、导航、物理、音频、UI 等能力域
- Godot.NET / C# 场景绑定分析与导出成员审计
- TileSet 最小闭环：`create_empty`、`assign_to_tilemap`
- 调试事件缓冲区
- `debug_log.get_recent`
- `debug_log.get_errors`
- `debug_log.clear_buffer`
- `debug_profiler.get_summary`
- 受控临时场景目录与场景保存链路收口
- 继承感知的资源类型过滤
- 安装与发布文档
- zip 发布包

### Known Limitations

- 节点 `/root/...` 路径兼容补丁已落地，但仍待插件重载后的最终黑盒确认
