# Agent 与 Bot 流程

本文档约束 Agent 或 bot 参与 Godot .NET MCP 开发时的 GitHub 工作方式。

---

## 1. 身份原则

- 推荐使用独立 machine user 或 GitHub App 作为 Agent 推送和创建 PR 的 GitHub actor。
- 如果不使用额外账号，可使用 `actions-bot-relay` 让 `github-actions[bot]` 从维护者提供的 patch 创建短分支和 PR。
- 仅修改 git commit author 不能改变 GitHub 的 PR author 或 latest push actor。
- Bot 权限应最小化，通常只需要分支推送、PR 创建/更新和读取仓库内容。

---

## 2. 分支与 PR

- Agent 从最新 `origin/dev` 创建语义明确的短分支：`feature/*`、`fix/*`、`docs/*`、`chore/*`、`hotfix/*` 或 `release/*`。
- Agent 可在验证通过后提交并推送当前短分支。
- 每个短分支和 PR 必须只包含该分支目标范围内的修改。
- 如果发现夹带其它任务、其它修复或历史未合并提交，应拆分为独立 PR，或从最新 `origin/dev` 重建干净分支。
- 所有 PR 必须指向 `dev`；`pr-policy` 会对错误目标分支给出失败反馈。
- `actions-bot-relay` 创建的短分支必须使用 `actions-bot/*` 前缀。

---

## 3. 完成定义与返修闭环

公开工具行为、UI 结构、生命周期语义、CI/workflow 行为或发布内容发生变化时，开发完成定义必须同时覆盖实现、契约测试、文档和变更记录。代码能运行不代表闭环完成；如果相关测试或文档仍描述旧路径、旧字段或旧语义，该 PR 仍处于返修状态。

Agent 在提交或更新 PR 前必须完成以下检查：

- 受影响的 contract tests 已同步表达当前真实契约；旧测试因旧路径或旧语义失败时，应优先修正测试契约，而不是在最终说明中标注为无关失败。
- `docs/`、`README*`、工具说明、协议事实源和 `CHANGELOG*` 中与本次公开行为相关的内容已同步；无需更新时，PR 回报必须说明原因。
- Review、Cubic、Codex 或人工复核发现的测试/文档缺口视为阻塞返修项，必须在同一 PR 中处理到 resolved、outdated 或明确由维护者裁决。
- 验证记录应列出实际运行的目标测试、构建或 harness case；只读检查通过不能替代受影响契约测试。

---

## 4. 合并边界

- Agent 不直接推送 `dev`。
- Agent 不本地合并后推送 `dev`。
- Agent 不绕过 required checks。
- Agent 不合并 GitHub PR；远程 `dev` 合并只能由维护者在 GitHub PR 页面手动确认并执行。

---

## 5. GitHub Actions Bot Relay

`actions-bot-relay` 是不引入额外 machine user 时的中转方案：维护者或 Agent 先生成基于最新 `dev` 的 unified patch，再手动触发 workflow，由 `github-actions[bot]` 应用 patch、提交、推送 `actions-bot/*` 分支并创建或更新指向 `dev` 的 PR。

使用前提：仓库 Settings > Actions > General 中必须允许 GitHub Actions 创建和批准 pull requests；该 workflow 只依赖默认 `GITHUB_TOKEN`，不需要 PAT。

输入要求：

- `patch_base64`: base64 编码后的 unified git patch；受 `workflow_dispatch` 输入大小限制，只适合小到中等规模的改动。
- `pr_title`: PR 标题。
- `pr_body`: PR 正文，必须说明修改范围和验证计划。
- `commit_message`: 提交信息。
- `branch_name`: 可选，必须为空或使用 `actions-bot/*` 前缀。
- `base_branch`: 固定为 `dev`。

执行边界：

- workflow 只接受 patch，不执行任意用户脚本。
- workflow 会主动触发 `dotnet-build.yml` 和 `validate-plugin.yml`；如果 patch 修改 `.github/workflows/**`，还会触发 `lint-workflows.yml`。
- 因为 `GITHUB_TOKEN` 触发的 push/PR 事件不会像普通用户 push 一样自动触发所有 workflow，relay 必须显式触发验证 workflow。
- 维护者仍需在 GitHub PR 页面审查、批准并合并。

---

## 6. 自动化边界

- 自动生成、自动刷新或定时维护类变更只能通过短分支 PR 落地，不直接写入 `dev`。
- 自动化 workflow 可以生成或更新 `next` draft release 作为下一版说明草稿，但不得创建正式发布、上传 zip / sha256 / 本地构建产物，或替代维护者发布判断。
- 正式发布 tag、远程 tag 删除、release 正文纠错和已存在 release 的处理由维护者裁决；Agent 不擅自重写发布历史。
- 不采用 npm / Bun 包发布、OIDC trusted publisher、CLA Assistant、强推主分支或 PAT 驱动的自主合并流程。

---

## 7. PR 回报要求

Agent 创建或更新 PR 时，应说明：

- 修改范围和目标分支。
- 是否包含 changelog / 文档更新。
- 已执行的验证命令和结果。
- 是否需要同步到 Mechoes。
- 剩余的维护者手动动作。