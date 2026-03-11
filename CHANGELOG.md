# Changelog

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

- 当前调试回读仍基于插件缓冲区，不是直接读取 Godot 原生 Output / Debugger 面板
- 节点 `/root/...` 路径兼容补丁已落地，但仍待插件重载后的最终黑盒确认
