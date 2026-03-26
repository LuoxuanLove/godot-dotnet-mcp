# Host 契约测试

本文档说明 `tests/host_contracts/` 当前的职责、结构、覆盖范围和后续重构方向。

---

## 目标

Host 契约测试的目标不是验证全部集成链路，而是验证 `Central Server` 作为唯一对外 MCP 入口时，对外暴露的关键契约是否稳定，包括：

- 工具目录是否按 `workspace / system / dotnet` 正常暴露
- 项目注册和项目解析是否正常
- 编辑器会话和生命周期错误模型是否符合预期
- `centralHostSession` 与生命周期相关 payload 是否保持稳定

---

## 当前文件结构

```text
tests/host_contracts/
├─ HostContracts.csproj
├─ Program.cs
├─ ContractHarness.cs
├─ ContractAssertions.cs
├─ ContractPayloadSupport.cs
└─ ContractHttpSupport.cs
```

当前职责分布如下：

| 文件 | 作用 |
|---|---|
| `Program.cs` | 用例入口、执行顺序、结果汇总 |
| `ContractHarness.cs` | 创建临时 Central home、构建测试 Host、注册项目、附着 mock editor |
| `ContractAssertions.cs` | 断言 helper，负责 payload 中的字段校验 |
| `ContractPayloadSupport.cs` | payload 序列化、attach request 构造与临时端口辅助 |
| `ContractHttpSupport.cs` | Host contracts 专用 HTTP 请求辅助 |
| `HostContracts.csproj` | 引用 `central_server` 与 `host_shared`，作为独立执行入口 |

---

## 当前覆盖范围

截至 `2026-03-26`，当前已覆盖 `8` 个用例：

1. `tool_catalog_exposes_workspace_system_dotnet`
2. `system_project_state_returns_editor_required_when_auto_launch_disabled`
3. `workspace_project_open_editor_returns_missing_executable_guidance`
4. `workspace_project_close_editor_reports_editor_lifecycle_unsupported`
5. `workspace_project_close_editor_force_reports_editor_force_unavailable`
6. `workspace_project_restart_editor_reattaches_when_lifecycle_available`
7. `workspace_project_restart_editor_reports_attach_timeout_when_reattach_missing`
8. `workspace_project_close_editor_succeeds_when_lifecycle_available`

这些用例覆盖的重点是：

- 工具目录结构
- 编辑器缺席时的错误分支
- 缺失可执行文件时的 guidance
- lifecycle capability 缺失时的错误模型
- graceful restart / close 的主路径
- restart 后 attach timeout 的错误路径

---

## 当前实现特点

### 1. 它更接近“轻量集成契约测试”

`ContractHarness.cs` 当前会显式组装：

- `CentralConfigurationService`
- `EditorProcessService`
- `ProjectRegistryService`
- `EditorSessionService`
- `EditorSessionCoordinator`
- `EditorLifecycleCoordinator`
- `CentralToolDispatcher`

这意味着当前 Host contracts 并不是完全 isolated 的单元测试，而是通过最小 Host 组合验证对外契约。

### 2. 它已经有独立支撑层

相比早期把所有逻辑塞回入口文件的方式，当前结构已经更合理：

- `Program.cs` 不再同时承担 harness、assertion 和全部 fixture
- 断言逻辑与入口逻辑已经分开
- mock editor attach 已通过 `ContractHarness` 封装

---

## 当前已知边界

### 1. 已从 smoke support 解耦，但仍保留轻量集成特征

当前 suite 已经不再直接依赖：

- `SmokeAssertionSupport`
- `SmokePayloadSupport`
- `SmokeHttpSupport`

这意味着 Host contracts 与 smoke 现在已经有了独立支撑层。  
但当前 suite 的价值仍然更接近：

- 面向对外契约的 Host 侧轻量集成测试

这不是问题本身，但后续继续扩充时，仍建议把 host、fixture、payload assertion 的层级进一步明确。

---

## 运行方式

推荐命令：

```powershell
dotnet run --project .\tests\host_contracts\HostContracts.csproj -c Release
```

当前返回为统一 JSON 汇总，便于：

- 本地快速验证
- CI 直接读取退出码
- 失败时通过 case name 定位具体契约断点

---

## 下一步重构方向

### 1. 继续收口独立的 Host test host

目标结构：

- `CentralServerTestHost`
- `HostPayloadAssertions`
- `HostAttachFixtures`
- `HostScenarioCases`

当前结果：

- `tests/host_contracts` 已不再直接引用 `Smoke*Support`
- smoke 与 contract 已经拥有各自的支撑层

后续目标：

- 继续让 `ContractHarness.cs` 更接近 `CentralServerTestHost`
- 让 fixture / assertion / payload helper 边界更清晰

### 2. 扩充覆盖范围

优先补充：

- `workspace_project_open_editor` attach timeout
- auto-launch 负例
- `editor_already_running_external`
- 更多 `centralHostSession` 载荷字段完整性检查

### 3. 继续压缩编排文件职责

后续要求：

- `Program.cs` 只做 case 编排和输出
- 复杂 fixture 创建不再继续追加到入口文件

---

## 结论

当前 Host contract tests 已经能为 Host 编排层重构提供基本护栏，而且已经完成与 smoke support 的第一轮解耦。  
下一步最重要的是继续把 host / fixture / payload support 再分层，然后再扩更多 case。
