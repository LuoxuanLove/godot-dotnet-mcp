# 插件 Headless 测试

本文档说明 `Godot Headless Harness` 当前的结构、覆盖范围、已知问题与后续方向。

---

## 目标

插件侧测试的目标是：

- 不引入 `gdUnit`、`GUT` 等第三方框架
- 直接基于仓库内建 fixture 工程运行 `headless Godot`
- 验证插件运行时、工具装载、路由和系统 impl 的关键行为
- 为插件运行时重构提供快速回归面

---

## 当前文件结构

```text
tests/godot_plugin_harness/
├─ GodotPluginHarness.csproj
└─ Program.cs

tests/godot_plugin_harness_fixture/
├─ project.godot
└─ tests/
   ├─ headless_suite_runner.gd
   ├─ runtime_bridge_contract_test.gd
   ├─ runtime_control_contract_test.gd
   ├─ http_server_contract_test.gd
   ├─ http_request_router_contract_test.gd
   ├─ http_response_service_contract_test.gd
   ├─ json_rpc_router_contract_test.gd
   ├─ editor_lifecycle_action_service_contract_test.gd
   ├─ editor_lifecycle_state_builder_contract_test.gd
   ├─ system_runtime_impl_contract_test.gd
   ├─ system_index_impl_contract_test.gd
   └─ tool_loader_contract_test.gd
```

职责分布如下：

| 文件 | 作用 |
|---|---|
| `Program.cs` | 复制 fixture 与 addon 到临时 stage root，启动 headless Godot，收集 stdout/stderr，解析 suite JSON |
| `project.godot` | 最小测试工程 |
| `headless_suite_runner.gd` | suite 入口，逐 case 执行并汇总结果 |
| 各 `*_contract_test.gd` | 单 case 文件，按模块拆分验证 |

---

## 当前覆盖范围

截至 `2026-03-26`，当前有 `11` 个 case：

| 用例 | 目标 |
|---|---|
| `runtime_bridge_invalid_action_fallback` | 验证 `mcp_runtime_bridge` 对非法 action 的 fallback reply |
| `runtime_control_contracts` | 验证 `runtime_control_service` 在无 session 时的状态和参数错误模型 |
| `http_server_contracts` | 验证 `mcp_http_server` 的 lifecycle、`tools/list`、`tools/call` 结构契约 |
| `http_request_router_contracts` | 验证 `mcp_http_request_router` 的 path 分发、`GET /mcp` 405、CORS 与 404 语义 |
| `http_response_service_contracts` | 验证 `mcp_http_response_service` 的 JSON-RPC 构造、`/health` 投影与 JSON 清洗 |
| `json_rpc_router_contracts` | 验证 `mcp_json_rpc_router` 的 initialize、notification 无响应与 method-not-found 语义 |
| `editor_lifecycle_action_service_contracts` | 验证 `mcp_editor_lifecycle_action_service` 的确认语义、accepted payload 与调度行为 |
| `editor_lifecycle_state_builder_contracts` | 验证 `mcp_editor_lifecycle_state_builder` 的默认状态、scene 排序与 hint 投影 |
| `system_runtime_impl_contracts` | 验证 `impl_runtime.gd` 的状态、capture 注解和参数处理 |
| `system_index_impl_contracts` | 验证 `impl_index.gd` 的 built -> stale_refreshed 刷新路径 |
| `tool_loader_contracts` | 验证默认 permission provider 下的 loader 初始化和 disabled tool 收缩 |

当前实测状态：

- suite：`11/11` 通过
- `tool_loader_status=ready`
- `category_count=26`
- `tool_count=118`
- `exposed_tool_count=18`

---

## 当前重要实现点

### 1. `Program.cs` 负责构建临时真实环境

当前 harness 不是在原仓库目录中直接跑，而是：

1. 复制 `tests/godot_plugin_harness_fixture/`
2. 复制 `addons/godot_dotnet_mcp/`
3. 在新的临时 `stageRoot` 中启动 Godot
4. 运行 `res://tests/headless_suite_runner.gd`

这样做的好处是：

- 测试环境更接近真实装配路径
- 不直接污染工作目录
- 失败时可通过 `--keep-stage-root` 保留现场排查

### 2. suite 已支持单 case 运行

`headless_suite_runner.gd` 当前支持：

- case 级开始/结束日志
- 通过环境变量筛选单 case
- 逐 case `cleanup_case()` 钩子

这对排查卡死、性能问题和资源清理问题很有帮助。

### 3. headless 路径已修复默认 permission provider 缺失问题

先前 bare `MCPHttpServer.new()` 在无插件父节点的 headless 路径下，没有 permission provider，导致：

- `tool_loader_status=no_visible_tools`

当前已经通过默认 fallback provider 修复，因此 headless 路径可以真实装载工具目录并暴露工具状态。

### 4. 已补第一轮稳定测试 seam

当前插件侧已经加入以下测试 seam：

- `mcp_editor_lifecycle_endpoint.gd`
- `mcp_editor_lifecycle_action_service.gd`
- `mcp_editor_lifecycle_state_builder.gd`
- `mcp_http_request_router.gd`
- `mcp_http_response_service.gd`
- `mcp_json_rpc_router.gd`
- `mcp_tools_api_service.gd`
- `mcp_http_server.gd` 的公共测试入口
- `mcp_runtime_bridge.gd` 的公共 command capture / fallback 入口

这意味着当前 headless contract tests 已经不再直接依赖生产代码中的下划线方法名。

---

## 当前已知问题

### 1. 已摆脱私有方法名耦合，但 seam 仍可继续独立

当前 `http_server_contract_test.gd` 与 `runtime_bridge_contract_test.gd` 已经改为走公共测试入口。  
这显著降低了“内部方法改名或拆分导致测试先碎”的风险。

不过当前 seam 仍然主要挂在 `mcp_http_server.gd` 与 `mcp_runtime_bridge.gd` 上，后续仍建议继续往更独立的 helper 模块收口。

### 2. 退出阶段仍有资源清理告警

当前 suite 成功退出时，Godot 仍会输出：

- `ObjectDB instances leaked at exit`
- `resources still in use at exit`

这说明：

- fixture 生命周期
- 节点释放顺序
- fallback 文件清理
- 资源引用释放

仍然没有完全收口。

当前已经新增第一轮统一 cleanup 钩子，用于：

- 每个 case 执行后显式 cleanup
- 额外推进两帧，给 `queue_free` / deferred cleanup 收尾
- 清理 runtime fallback 文件
- 释放测试中显式创建的临时 `Node`

但截至本轮，退出告警数量没有明显下降，说明剩余问题更接近脚本资源缓存、tool loader 图谱或 GDScript 运行时持有，而不只是简单的测试尾巴未扫净。

### 3. 当前仍偏“结构契约 + 局部 fake”混合模式

这是当前阶段可以接受的折中，但后续应继续往“稳定 seam + 明确 fixture”方向收口。

---

## 当前运行方式

推荐命令：

```powershell
dotnet run --project .\tests\godot_plugin_harness\GodotPluginHarness.csproj -c Release -- --godot-path "<Godot Console Path>"
```

常用附加选项：

- `--allow-skip-missing-godot`
- `--keep-stage-root`

当前返回内容包括：

- suite success
- stage root
- 每个 case 的结果
- stderr 摘要

---

## 下一步重构方向

### 1. 继续把 `mcp_http_server.gd` seam 从节点内部往外收口

建议目标：

- `McpRequestRouter`
- `EditorLifecycleEndpoint`
- `EditorLifecycleActionService`
- `ToolListResponseBuilder`
- `JsonRpcRouter`
- `HttpResponseService`
- `EditorLifecycleStateBuilder`

当前已经完成“从私有方法名迁移到公共测试入口”的第一步。  
下一步目标是让 lifecycle、tools snapshot 和 JSON-RPC 入口更自然地落在独立 helper 上。

### 2. 继续把 `mcp_runtime_bridge.gd` seam 从 bridge 节点内部往外收口

建议目标：

- `RuntimeCommandAdapter`
- `RuntimeFallbackStore`
- `RuntimeReplyAssembler`

当前已经完成 command capture / fallback 入口的公共化。  
下一步目标是让 fallback 与 reply 行为可以更独立地测试，而不必总通过 bridge 节点本身。

### 3. 补更多负例

优先补充：

- `tool_loader` reload
- permission 切换边界
- `runtime_session_lost`
- `runtime_control` enable / disable / step 的更多失败路径
- 更贴近 transport 的 HTTP 请求路径

### 4. 收口清理链

后续需要建立统一 teardown helper，处理：

- 节点移除
- `queue_free`
- fallback 事件文件
- 临时资源
- 测试状态清理

---

## 结论

插件 headless harness 已经可用，而且已经真实发现并推动修复过运行时问题。  
当前它的主要短板不是“没有测试”，而是“测试 seam 虽已起步但仍可继续独立、清理边界还不够干净”。
