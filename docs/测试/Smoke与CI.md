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
2. Run plugin headless harness required subset（以 `scripts/test_plugin_side_roslyn.ps1` 中的 `$RequiredCases` 为准）

`validate-plugin.yml` 在 PR、`dev`、`feature/**`、`fix/**`、`docs/**`、`chore/**`、`hotfix/**` 与 `release/**` 分支推送时运行。远程 `dev` 分支应配置 GitHub branch ruleset，并把 `validate-plugin-harness` 设为 required check。

---

## 5. 当前门禁边界

### 已经是硬门禁的部分

- dotnet bridge library build
- plugin headless harness required subset
- 远程 `dev` 合并前应要求 PR、`validate-plugin-harness` 通过并基于最新 `dev` 重新验证；当前 ruleset 不要求 approving review

### 仍是软门禁或环境依赖的部分

- `tests/godot_plugin_harness` 支持 `--allow-skip-missing-godot`，但 CI 入口 `scripts/test_plugin_side_roslyn.ps1` 要求真实 Godot 可执行文件；其余可发现 case 不自动进入 CI 硬门禁
- Agent 可创建、提交和按授权推送短分支，但合并远程 `dev` 只能由作者在 GitHub PR 页面手动批准并执行；Agent 不得本地合并后推送 `dev` 或绕过 required checks
- 每个 PR 应只包含对应短分支目标范围内的修改；若夹带其他修复或历史未合并提交，应拆成独立 PR 或从最新 `origin/dev` 重建干净分支

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
