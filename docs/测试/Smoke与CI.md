# Smoke 与 CI

本文档说明当前测试结构、CI 接入状态和后续门禁策略方向。

---

## 1. Smoke 的定位

插件 headless harness 验证插件运行时的工具装载和路由行为，不依赖外部进程或第三方测试框架；CI 只硬门禁 `scripts/test_plugin_side_roslyn.ps1` 指定的 required subset。

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
└─ validate-plugin.yml
```

---

## 3. 当前进度

- Plugin headless harness 已接入 CI 的 required subset
- 多个合约测试 case 仍可被 harness 发现，但不等于当前硬门禁
- `plugin_entrypoint_contracts` 通过 editor probe 运行，退出时的 editor shutdown warning 在 harness 中按非致命噪音处理

---

## 4. 当前 CI 状态

当前工作流：

- `.github/workflows/validate-plugin.yml`

当前包含：

1. Build plugin Roslyn library
2. Run plugin headless harness required subset（`scripts/test_plugin_side_roslyn.ps1` 中当前维护的 15 个 case）

---

## 5. 当前门禁边界

### 已经是硬门禁的部分

- dotnet bridge library build
- plugin headless harness required subset

### 仍是软门禁或环境依赖的部分

- plugin harness 在无 Godot 可执行文件时允许跳过；其余可发现 case 不自动进入 CI 硬门禁

---

## 6. 推荐运行方式

### 本地 plugin harness

```powershell
dotnet run --project .\tests\godot_plugin_harness\GodotPluginHarness.csproj -c Release -- --godot-path "<Godot Editor Path>"
```

`plugin_entrypoint_contracts` 通过 editor probe 运行时，需要显式提供 Godot 编辑器可执行文件，而不是 console 版：

```powershell
dotnet run --project .\tests\godot_plugin_harness\GodotPluginHarness.csproj -c Release -- --godot-path "<Godot Editor Path>"
```

---

## 7. 结论

当前 harness 与 CI 已经形成基础闭环，门禁边界也已清晰：required subset 走 CI，editor probe 作为环境依赖 case 单独验证。
