# Agent 与 Bot 流程

本文档约束 Agent 或 bot 参与 Godot .NET MCP 开发时的 GitHub 工作方式。

---

## 1. 身份原则

- 推荐使用独立 machine user 或 GitHub App 作为 Agent 推送和创建 PR 的 GitHub actor。
- 仅修改 git commit author 不能改变 GitHub 的 PR author 或 latest push actor。
- Bot 权限应最小化，通常只需要分支推送、PR 创建/更新和读取仓库内容。

---

## 2. 分支与 PR

- Agent 从最新 `origin/dev` 创建语义明确的短分支：`feature/*`、`fix/*`、`docs/*`、`chore/*`、`hotfix/*` 或 `release/*`。
- Agent 可在验证通过后提交并推送当前短分支。
- 每个短分支和 PR 必须只包含该分支目标范围内的修改。
- 如果发现夹带其它任务、其它修复或历史未合并提交，应拆分为独立 PR，或从最新 `origin/dev` 重建干净分支。
- 所有 PR 必须指向 `dev`；`validate-plugin` 会对错误目标分支给出失败反馈。

---

## 3. 合并边界

- Agent 不直接推送 `dev`。
- Agent 不本地合并后推送 `dev`。
- Agent 不绕过 required checks。
- Agent 不合并 GitHub PR；远程 `dev` 合并只能由维护者在 GitHub PR 页面手动确认并执行。

---

## 4. 自动化边界

- 自动生成、自动刷新或定时维护类变更只能通过短分支 PR 落地，不直接写入 `dev`。
- 自动化 workflow 可以生成或更新 `next` draft release 作为下一版说明草稿，但不得创建正式发布、上传 zip / sha256 / 本地构建产物，或替代维护者发布判断。
- 正式发布 tag、远程 tag 删除、release 正文纠错和已存在 release 的处理由维护者裁决；Agent 不擅自重写发布历史。
- 不采用 npm / Bun 包发布、OIDC trusted publisher、CLA Assistant、强推主分支或 PAT 驱动的自主合并流程。

---

## 5. PR 回报要求

Agent 创建或更新 PR 时，应说明：

- 修改范围和目标分支。
- 是否包含 changelog / 文档更新。
- 已执行的验证命令和结果。
- 是否需要同步到 Mechoes。
- 剩余的维护者手动动作。
