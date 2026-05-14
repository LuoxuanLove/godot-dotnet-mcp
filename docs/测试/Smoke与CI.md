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
├─ actions-bot-relay.yml
├─ dotnet-build.yml
├─ draft-release-notes.yml
├─ lint-workflows.yml
├─ pr-policy.yml
├─ publish-plugin.yml
└─ validate-plugin.yml
```

---

## 3. 当前进度

- Plugin headless harness 已接入 CI 的 required subset
- 多个合约测试 case 仍可被 harness 发现，但不等于当前硬门禁
- `plugin_entrypoint_contracts` 通过 editor probe 运行，退出时的 editor shutdown warning 在 harness 中按非致命噪音处理
- PR 目标分支、快速 .NET build、发布 tag 版本一致性和下一版 draft release 已进入 workflow 管理
- `actions-bot-relay` 可用 `github-actions[bot]` 从维护者提供的 patch 创建短分支和 PR

---

## 4. 当前 CI 状态

当前工作流：

- `.github/workflows/actions-bot-relay.yml`
- `.github/workflows/dotnet-build.yml`
- `.github/workflows/draft-release-notes.yml`
- `.github/workflows/lint-workflows.yml`
- `.github/workflows/pr-policy.yml`
- `.github/workflows/publish-plugin.yml`
- `.github/workflows/validate-plugin.yml`

当前包含：

1. `actions-bot-relay`: 手动接收 base64 patch，由 `github-actions[bot]` 创建 `actions-bot/*` 分支和指向 `dev` 的 PR
2. `pr-policy`: 阻止错误目标分支 PR，只允许 PR 指向 `dev`
3. `dotnet-build`: 快速构建插件 Roslyn library、harness runner 和 fixture，并运行 refactor guardrails
4. `lint-workflows`: 对 `.github/workflows/**` 运行 `actionlint`
5. `validate-plugin-harness`: 下载 Godot 4.6 并运行 plugin headless harness required subset（以 `scripts/test_plugin_side_roslyn.ps1` 中的 `$RequiredCases` 为准）
6. `publish-plugin`: tag 发布前执行版本一致性 preflight，并创建不含包资产的 GitHub Release
7. `draft-release-notes`: `dev` 更新后创建或刷新 `next` draft release，作为下一版说明草稿

`validate-plugin.yml` 只保留重型 Godot harness，并继续暴露稳定的 `validate-plugin-harness` check 名称。`pr-policy.yml` 负责 PR 目标分支检查，`dotnet-build.yml` 负责快速 .NET build 和 guardrails。`actions-bot-relay` 创建 PR 后会显式触发 `dotnet-build.yml` 和 `validate-plugin.yml`，并在 workflow 文件变化时显式触发 `lint-workflows.yml`。远程 `dev` 分支应配置 GitHub branch ruleset，并把 `validate-plugin-harness` 设为 required check；需要更严格时可把 `dotnet-build` 也加入 required checks；`pr-policy` 主要提供早期反馈，不建议替代 `validate-plugin-harness`。`validate-plugin.yml` 与 `dotnet-build.yml` 均包含 `merge_group` 触发，便于未来接入 merge queue。

`validate-plugin-harness` 执行 `scripts/test_plugin_side_roslyn.ps1` 时会输出各 build、case 与 guardrails 阶段耗时；在 GitHub Actions 中还会写入 Job Summary，便于定位慢阶段或慢 case。

---

## 5. 当前门禁边界

### 已经是硬门禁的部分

- workflow YAML syntax lint（仅 workflow 文件变更时）
- PR 目标分支检查，错误目标分支会失败并提示改投 `dev`
- dotnet bridge library、harness runner 与 fixture build
- refactor guardrails
- plugin headless harness required subset
- tag 发布前的 `plugin.cfg`、tag 和中英文 changelog 版本一致性检查
- 远程 `dev` 合并前应要求 PR、`validate-plugin-harness` 通过并基于最新 `dev` 重新验证；当前 ruleset 不要求 approving review

### 仍是软门禁或环境依赖的部分

- `tests/godot_plugin_harness` 支持 `--allow-skip-missing-godot`，但 CI 入口 `scripts/test_plugin_side_roslyn.ps1` 要求真实 Godot 可执行文件；其余可发现 case 不自动进入 CI 硬门禁
- `actions-bot-relay` 依赖仓库 Settings 允许 GitHub Actions 创建 pull request；如果禁用该权限，workflow 会在创建 PR 时失败
- `actions-bot-relay` 只应用维护者提供的 patch，不负责生成或理解需求；patch 内容仍需由维护者审查
- `next` draft release 只辅助维护发布说明，不代表正式发布，也不上传包资产
- Agent 可创建、提交和按授权推送短分支，但合并远程 `dev` 只能由作者在 GitHub PR 页面手动确认并执行；Agent 不得本地合并后推送 `dev` 或绕过 required checks
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

当前 harness 与 CI 已经形成分层闭环：`pr-policy` 提前拦截错误目标分支，`dotnet-build` 提供快速 .NET build 和 guardrail 反馈，`validate-plugin-harness` 保持稳定 required check 名称并运行重型 Godot harness，`next` draft release 用于维护下一版说明草稿，`actions-bot-relay` 用于在不新增账号的前提下让 `github-actions[bot]` 成为 PR 创建和推送 actor。
