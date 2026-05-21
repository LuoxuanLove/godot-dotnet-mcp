# Godot .NET MCP v1.0.0-pre3

## 运行时诊断 + 发布流程加固

`v1.0.0-pre3` 聚焦让编辑器与运行时自动化失败“说清楚原因”。运行日志 marker、前台窗口限制、服务监听失败、headless 截图限制、空项目扫描、工具上下文覆盖和启动自诊断现在都会给出更明确的证据，不再轻易退化成泛化的插件错误。

### 运行时执行证据

`system_project_run` 新增可选 runtime bridge marker 校验，支持 success / failure marker 匹配、超时处理、marker 模式自动停止，并用 fake runtime events 覆盖契约测试。marker 读取改用 shared runtime bridge events 与 event-id 游标，高日志量或运行前重复 marker 文本不再遮蔽真正的匹配结果。

### 编辑器与工具稳定性

项目启动期间的 runtime bridge 消息不再触发 Godot `Invalid message received` 输出；editor-interface 覆盖辅助函数避免 GDScript VM 内部错误；TileMap 工具脚本可在注册期间正常实例化；运行时截图在 headless 或 dummy 渲染后端下会返回结构化 skipped 结果。

### 可执行的失败诊断

自诊断现在会指出启动或重载中最慢的阶段；MCP server 监听失败会区分端口占用、绑定被拒绝和 Windows 保留 / 排除 TCP 端口；项目文件枚举会把可疑空扫描报告为诊断，而不是误判为资源审计 clean。

### 发布与 CI 纪律

预发布线现在具备更强的发布说明自动化、`next` 草稿预览、tag / version / changelog preflight、workflow lint、PR policy 反馈、托管 .NET SDK 选择、harness 耗时汇总、缓存覆盖和 CI 失败证据保留。

### 兼容性说明

- 最低目标仍为 Godot 4.6 + .NET 支持。
- 安装方式仍为 Godot Asset Library 安装，或直接复制 `addons/godot_dotnet_mcp/` 源文件。
- 这是预发布版本，适合希望提前使用最新运行时诊断、编辑器自动化稳定性与发布流程加固的用户。
