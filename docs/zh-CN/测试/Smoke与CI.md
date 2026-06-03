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
├─ publish-release.yml
├─ publish-plugin.yml
├─ validate-plugin.yml
└─ version-policy.yml
```

---

## 3. 当前进度

- Plugin headless harness 已接入 CI 的 required subset
- 多个合约测试 case 仍可被 harness 发现，但不等于当前硬门禁
- `plugin_entrypoint_contracts` 通过 editor probe 运行，退出时的 editor shutdown warning 在 harness 中按非致命噪音处理
- PR 目标分支、公开版本元数据策略、快速 .NET build、发布 tag 版本一致性和下一版 draft release 已进入 workflow 管理
- `actions-bot-relay` 可用 `github-actions[bot]` 从维护者提供的 patch 创建短分支和 PR

---

## 4. 当前 CI 状态

当前工作流：

- `.github/workflows/actions-bot-relay.yml`
- `.github/workflows/dotnet-build.yml`
- `.github/workflows/draft-release-notes.yml`
- `.github/workflows/lint-workflows.yml`
- `.github/workflows/pr-policy.yml`
- `.github/workflows/publish-release.yml`
- `.github/workflows/publish-plugin.yml`
- `.github/workflows/validate-plugin.yml`
- `.github/workflows/version-policy.yml`

当前包含：

1. `actions-bot-relay`: 手动接收 base64 patch，由 `github-actions[bot]` 创建 `actions-bot/*` 分支和指向 `dev` 的 PR，并在 PR 正文追加 base/head SHA、changed paths、diffstat、触发者、run URL 与验证 workflow 链接
2. `pr-policy`: 阻止错误目标分支 PR，只允许 PR 指向 `dev`，并校验标题、摘要和测试说明等客观 PR 字段
3. `version-policy`: 以受信任的 `dev` 侧 workflow 和脚本校验 PR 公开版本元数据，阻止非 `release/*` 分支提前修改插件版本
4. `dotnet-build`: 快速构建插件 Roslyn library、harness runner 和 fixture，并运行 refactor guardrails
5. `lint-workflows`: 对 `.github/workflows/**` 运行 `actionlint`
6. `validate-plugin-harness`: 下载 Godot 4.6 并运行 plugin harness required subset（以 `scripts/test_plugin_side_roslyn.ps1` 中的 `$RequiredCases` 为准）；普通 headless case 批量运行，少量需要隔离的 headless case 与 editor probe case 单独运行
7. `publish-release`: 手动一键发布入口，只使用 GitHub Actions 的 `Use workflow from` 选择 `dev` 来源，默认先 dry-run 校验版本、发布说明、构建与 harness；同版本同提交的近期成功 dry-run 记录可在正式运行时跳过重复 build 与 harness 检查
8. `publish-plugin`: `v*` tag 发布前先校验 tag 版本、`dev` 可达性和发布说明源文件，再运行构建 / harness，并用两层发布说明正文创建 GitHub Release
9. `draft-release-notes`: `dev` 更新后用同一渲染脚本创建或刷新 `next` draft release，作为下一版正式正文预览

`validate-plugin.yml` 只保留重型 Godot harness，并继续暴露稳定的 `validate-plugin-harness` check 名称。`pr-policy.yml` 负责 PR 目标分支检查和轻量 PR standards，`dotnet-build.yml` 负责快速 .NET build 和 guardrails。普通同仓库短分支 PR 依赖 `pull_request` 入口验证；`push` 只保留 `dev`，避免同一提交同时触发短分支 `push` 与 `pull_request.synchronize` 重复运行。`actions-bot-relay` 创建 PR 后会显式触发 `dotnet-build.yml`、`validate-plugin.yml` 和 `version-policy.yml`，并在 workflow 文件变化时显式触发 `lint-workflows.yml`。远程 `dev` 分支应配置 GitHub branch ruleset，并把 `validate-plugin-harness` 设为 required check；需要更严格时可把 `dotnet-build` 也加入 required checks；`pr-policy` 主要提供早期反馈，不建议替代 `validate-plugin-harness`。`validate-plugin.yml` 与 `dotnet-build.yml` 均包含 `merge_group` 触发，便于未来接入 merge queue。

`dotnet-build.yml` 和 `validate-plugin.yml` 只会对同一 PR 的新运行启用 concurrency cancellation，避免同一 PR 的旧 build 或 harness 继续占用 runner。`dev` push、`workflow_dispatch`、`merge_group`、tag、release 等非 PR 运行会使用唯一的 run id 作为 concurrency group，因此不会互相取消。`dotnet-build` job 的 timeout 为 30 分钟，`validate-plugin-harness` job 的 timeout 为 90 分钟，check 名称保持不变。

重型 harness 入口会输出总耗时以及 build、case list、批量 headless、隔离 headless、隔离 editor probe、逐 case 和 guardrails 阶段的 timing summary；在 GitHub Actions 中还会追加到 Step Summary，便于定位慢 case 或慢阶段。
`dotnet-build.yml` 和 `scripts/test_plugin_side_roslyn.ps1` 的 .NET build 阶段会识别符合 `CS2012`、Godot `.godot/mono/temp` 路径以及文件占用 / 安全软件扫描信号的失败，并输出 `transient_file_lock` 诊断。该诊断表示临时构建产物可能被短暂锁定，不代表源码编译错误；脚本只给出重跑与安全软件排除项建议，不会自动重试、删除 `.godot` 或终止进程。


Harness JSON 报告会区分 suite 成功标记与 Godot 退出清理警告：普通 headless suite 发现 `ObjectDB instances leaked at exit` 或 `resources still in use at exit` 时仍作为失败处理，但会输出 `suiteSuccess`、`successMarkerDetected`、`exitCleanupWarningMarkers`、`exitCleanupWarningPolicy` 与 `failureClass=exit_cleanup_warning`，便于判断失败来自退出清理而不是 case 逻辑。

`dotnet-build.yml`、`validate-plugin.yml`、`publish-release.yml` 与 `publish-plugin.yml` 使用 `windows-2025` 托管 runner，并通过 `global.json` 将 .NET SDK 选择限制在 .NET 8 feature band；workflow 会先输出 `dotnet --info` 与 `dotnet --list-sdks`，如果未选中 .NET 8 SDK 则直接失败。`dotnet-build.yml` 与 `validate-plugin.yml` 都缓存 NuGet 全局包目录，缓存键覆盖 `Directory.Build.props`、项目文件、props/targets、`global.json`、集中包管理文件和 lock file。`publish-release.yml` 额外保存同版本同提交的 dry-run 验证记录，用于正式发布时跳过重复 build 与 harness；`validate-plugin.yml` 还缓存 Godot 4.6 mono Windows 解压目录，缓存命中后仍会查找非 console Godot 可执行文件，缺失时重新下载并解压，避免坏缓存静默通过。

`validate-plugin-harness` 失败时会保留 `.tmp/godot_plugin_harness` 并上传 7 天 artifact，供维护者下载 stage root、process registry 等失败现场；成功运行仍会清理该目录。

---

## 5. 本地与远端验证分层

PR 验证分为本地预检、远端 CI 和 review 门禁三层。三层职责不同，不能互相替代：

1. 本地预检用于尽早发现确定性问题。能取得 Godot 编辑器路径时，优先运行受影响的 harness 或脚本；修改 workflow 时，应先检查 YAML 和脚本语法。
2. 远端 CI 是合并前的客观门禁。`dotnet-build`、`validate-plugin-harness`、`pr-policy` 和按需运行的 `lint-workflows` 必须以最新 head 的结果为准。
3. Review 门禁覆盖 CI 不易发现的问题。human、Cubic、Codex 或其它 review 工具提出的问题必须回复并 resolve；Cubic 结果必须覆盖最新 head commit。

推荐记录方式：

```text
Local:
- <command or editor/plugin validation> -> <result>

Remote:
- pr-policy -> <result or relay metadata / maintainer review path>
- dotnet-build -> <result>
- validate-plugin-harness -> <result>
- lint-workflows -> <result or not applicable>

Review:
- conversations -> <resolved / pending>
- Cubic latest head -> <covered / pending / issues found>
```

如果本地缺少 Godot 编辑器或其它必要环境，应在 PR 正文说明未运行的具体检查，并等待等价远端 CI 结果；不能用“未运行”替代验证结论。

---

## 6. 当前门禁边界

### 已经是硬门禁的部分

- workflow YAML syntax lint（仅 workflow 文件变更时）
- PR 目标分支和轻量 PR standards 检查，错误目标分支会失败并提示改投 `dev`，缺少必要 PR 字段时会提示补充
- dotnet bridge library、harness runner 与 fixture build
- refactor guardrails
- plugin headless harness required subset
- tag 发布前的 `plugin.cfg`、tag 和英文 changelog 与简体中文 changelog 版本一致性检查
- tag 发布前的 `docs/zh-CN/流程/release-notes/release-notes-v*.md` 存在性和版本一致性检查
- 远程 `dev` 合并前应要求 PR、`validate-plugin-harness` 通过并基于最新 `dev` 重新验证；当前 ruleset 不要求 approving review

### 仍是软门禁或环境依赖的部分

- `tests/godot_plugin_harness` 支持 `--allow-skip-missing-godot`，但 CI 入口 `scripts/test_plugin_side_roslyn.ps1` 要求真实 Godot 可执行文件；其余可发现 case 不自动进入 CI 硬门禁
- `actions-bot-relay` 依赖仓库 Settings 允许 GitHub Actions 创建 pull request；如果禁用该权限，workflow 会在创建 PR 时失败
- `actions-bot-relay` 只应用维护者提供的 patch，不负责生成或理解需求；patch 内容仍需由维护者审查。relay 追加的元数据只用于辅助审查，不替代验证结果或人工判断
- `next` draft release 只辅助维护发布说明，不代表正式发布；它应预览手写摘要、changelog 明细和 commit summary 的最终正文结构
- Agent 可创建、提交和按授权推送短分支，但合并远程 `dev` 只能由作者在 GitHub PR 页面手动确认并执行；Agent 不得本地合并后推送 `dev` 或绕过 required checks
- 每个 PR 应只包含对应短分支目标范围内的修改；若夹带其他修复或历史未合并提交，应拆成独立 PR 或从最新 `origin/dev` 重建干净分支

---

## 7. 推荐运行方式

### 本地 plugin harness

```powershell
dotnet run --project .\tests\godot_plugin_harness\GodotPluginHarness.csproj -c Release -- --godot-path "<Godot Path>"
```

需要复现 CI required subset 时，直接运行脚本入口；脚本会把普通 headless case 合并为一次 batch，并把少量需要隔离的 headless case 与 editor probe case 单独运行：

```powershell
.\scripts\test_plugin_side_roslyn.ps1 -GodotPath "<Godot Path>"
```

---

## 8. 结论

当前 harness、CI 与 review 门禁已经形成分层闭环：`pr-policy` 提前拦截错误目标分支，`dotnet-build` 提供快速 .NET build 和 guardrail 反馈，`validate-plugin-harness` 保持稳定 required check 名称并运行重型 Godot harness，`next` draft release 用于维护下一版说明草稿，`actions-bot-relay` 用于在不新增账号的前提下让 `github-actions[bot]` 成为 PR 创建和推送 actor。
