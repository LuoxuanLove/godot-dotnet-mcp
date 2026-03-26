# Smoke 与 CI

本文档说明当前 smoke 测试结构、CI 接入状态和后续门禁策略方向。

---

## 1. Smoke 的定位

`Central Server smoke` 不是为了覆盖全部逻辑，而是保留真实链路主线，用于验证：

- 编辑器 attach
- 已附着 session reuse
- lifecycle 能力分支
- auto-launch 主线
- 运行时主线与关键负例

它是当前测试体系中最接近真实运行现场的一层。

---

## 2. 当前结构

当前相关文件：

```text
central_server/
├─ SmokeSystemSessionRunner.cs
├─ SmokeSystemSessionReuseScenario.cs
├─ SmokeSystemSessionAutoLaunchScenario.cs
└─ smoke/
   ├─ MockEditorMcpServer.cs
   ├─ SmokeAssertionSupport.cs
   ├─ SmokeHttpSupport.cs
   └─ SmokePayloadSupport.cs

scripts/
└─ smoke_central_server_system_session.ps1
```

当前职责划分：

| 文件 | 作用 |
|---|---|
| `SmokeSystemSessionRunner.cs` | CLI 入口、公共参数解析、场景分派 |
| `SmokeSystemSessionReuseScenario.cs` | reuse session 主线与 lifecycle 相关分支 |
| `SmokeSystemSessionAutoLaunchScenario.cs` | auto-launch、runtime 与重新附着相关分支 |
| `MockEditorMcpServer.cs` | mock editor host |
| `SmokeAssertionSupport.cs` | smoke 专用断言 |
| `SmokeHttpSupport.cs` | HTTP 请求支撑 |
| `SmokePayloadSupport.cs` | payload 构造与提取支撑 |
| `smoke_central_server_system_session.ps1` | 脚本编排入口 |

---

## 3. 当前进度

截至 `2026-03-26`：

- `SmokeSystemSessionRunner.cs` 已完成两轮拆分
- 主文件已降到 `659` 行
- `reuse session` smoke 当前稳定可跑
- `validate-refactor.yml` 已接入 reuse smoke

当前 smoke 已经不再是“所有逻辑堆在单个超大 runner”中，但还没有完成第三轮拆分。

---

## 4. 当前问题

### 1. 场景文件仍偏厚

当前：

- `SmokeSystemSessionReuseScenario.cs`
- `SmokeSystemSessionAutoLaunchScenario.cs`

都仍然持有较长的顺序化编排逻辑。  
主要问题不是功能错误，而是后续继续加 case 时，维护成本会偏高。

### 2. smoke 与 Host contract support 仍有边界交叉

当前 Host contracts 仍复用了一部分 smoke support，这说明 smoke support 仍在扮演“临时共享测试底座”的角色。

### 3. auto-launch 仍属于更强环境依赖场景

reuse smoke 当前已经稳定进入 CI，而 auto-launch 相关链路仍更适合作为：

- 专用 runner 验收
- 发布前环境依赖验证

---

## 5. 当前 CI 状态

当前工作流：

- `.github/workflows/validate-refactor.yml`

当前包含：

1. Build central server
2. Build host shared library
3. Run host contract tests
4. Run plugin headless harness
5. Run reuse session smoke
6. Validate refactor guardrails

这意味着：

- 快测层已经成形
- smoke 已经不再完全依赖人工执行
- 测试体系已经进入正式 CI 主线

---

## 6. 当前门禁边界

### 已经接近硬门禁的部分

- Host build
- Host contracts
- reuse smoke

### 仍是软门禁或环境依赖的部分

- plugin harness 在无 Godot 可执行文件时允许跳过
- real auto-launch smoke 尚未作为默认强门禁

这说明当前 CI 策略已经有雏形，但还没有把“环境依赖测试”和“必须通过测试”彻底分层。

---

## 7. 后续演进方向

### 1. Smoke 第三轮拆分

建议继续拆成：

- `fixture setup`
- `lifecycle assertions`
- `runtime assertions`
- `cleanup orchestration`

### 2. 测试矩阵分层

建议把 CI 语义明确为：

| 层级 | 建议内容 |
|---|---|
| `Fast Required` | Host build、Host contracts、plugin harness 中无环境依赖部分 |
| `Integration Required` | reuse smoke |
| `Environment Required` | real Godot headless、real auto-launch smoke |

### 3. Guardrail 扩展

后续 guardrail 不应只检查源码区与产物区边界，还应逐步补入：

- 测试矩阵完整性检查
- 超大测试文件阈值检查

### 4. auto-launch 验收专用化

`real auto-launch smoke` 更适合放在：

- 专用 Windows runner
- 发布前验收阶段

而不是直接和无环境依赖快测层混在一起。

---

## 8. 推荐运行方式

### 本地复用 smoke

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\smoke_central_server_system_session.ps1 -SkipBuild
```

### 本地 plugin harness

```powershell
dotnet run --project .\tests\godot_plugin_harness\GodotPluginHarness.csproj -c Release -- --godot-path "<Godot Console Path>"
```

### 本地 Host contracts

```powershell
dotnet run --project .\tests\host_contracts\HostContracts.csproj -c Release
```

---

## 9. 结论

当前 smoke 与 CI 已经形成基础闭环，但仍处在“从可运行走向可维护”的阶段。  
下一步最重要的不是继续堆更多脚本，而是把 smoke 场景继续拆细，并把 CI 的门禁语义收紧成明确的分层策略。
