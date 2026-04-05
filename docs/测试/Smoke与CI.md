# Smoke 与 CI

本文档说明当前测试结构、CI 接入状态和后续门禁策略方向。

---

## 1. Smoke 的定位

插件 headless harness 验证插件运行时的工具装载和路由行为，不依赖外部进程或第三方测试框架。

---

## 2. 当前结构

当前相关文件：

```text
tests/
├─ godot_plugin_harness/
│  └─ GodotPluginHarness.csproj
└─ godot_plugin_harness_fixture/
   └─ tests/
      └─ *.gd  (合约测试)

.github/workflows/
└─ validate-refactor.yml
```

---

## 3. 当前进度

- Plugin headless harness 已接入 CI
- 多个合约测试 case 已覆盖运行时、工具路由、HTTP 传输层

---

## 4. 当前 CI 状态

当前工作流：

- `.github/workflows/validate-refactor.yml`

当前包含：

1. Build dotnet bridge library
2. Run plugin headless harness

---

## 5. 当前门禁边界

### 已经是硬门禁的部分

- dotnet bridge library build
- plugin headless harness

### 仍是软门禁或环境依赖的部分

- plugin harness 在无 Godot 可执行文件时允许跳过

---

## 6. 后续演进方向

### 1. 测试矩阵分层

建议把 CI 语义明确为：

| 层级 | 建议内容 |
|---|---|
| `Fast Required` | dotnet build、plugin harness 中无环境依赖部分 |
| `Environment Required` | real Godot headless harness |

### 2. Guardrail 扩展

后续 guardrail 不应只检查源码区与产物区边界，还应逐步补入：

- 测试矩阵完整性检查
- 超大测试文件阈值检查

---

## 7. 推荐运行方式

### 本地 plugin harness

```powershell
dotnet run --project .\tests\godot_plugin_harness\GodotPluginHarness.csproj -c Release -- --godot-path "<Godot Console Path>"
```

或允许跳过缺失的 Godot：

```powershell
dotnet run --project .\tests\godot_plugin_harness\GodotPluginHarness.csproj -c Release -- --allow-skip-missing-godot
```

---

## 8. 结论

当前 harness 与 CI 已经形成基础闭环。  
下一步最重要的不是继续堆更多脚本，而是把测试的门禁语义收紧成明确的分层策略。
