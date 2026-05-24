# 发布 Runbook

本文档记录 Godot .NET MCP 的发布前检查与远程发布流程。它只描述插件自身发布，不包含仓库外项目或本地工作区流程。

---

## 1. 发布原则

- `dev` 是稳定集成分支；发布前所有变更必须先通过短分支 PR 合入 `dev`。
- 发布由维护者手动触发或推送 `plugin-v*` tag 触发，Agent 不直接合并或推送 `dev`。
- 发布安装方式只保留 Godot Asset Library 安装和直接复制 `addons/godot_dotnet_mcp/` 源文件两种路径。
- 不制作、上传或记录 zip 包、发布包、本地打包产物及其安装流程。
- `next` draft release 仅作为下一版发布说明草稿，不是正式发布，也不附带包资产。

---

## 2. 发布前检查

1. 确认 `addons/godot_dotnet_mcp/plugin.cfg` 版本、`CHANGELOG.md`、`CHANGELOG.zh-CN.md` 和公开文档一致。
2. 确认对应版本的 `release-notes-v*.md` 存在，且内容为面向用户的手写发布叙事；workflow 会校验 changelog 版本段落并追加 commit summary。
3. 确认 `next` draft release 已按正式发布格式刷新，并可作为正式 GitHub Release 正文预览。
4. 确认 PR 只包含当前发布目标范围，未夹带其它修复或历史未合并提交。
5. 确认公开文档不包含本地路径、跨仓库工作区上下文、同步脚本流程或本地构建产物安装说明。
6. 运行或确认 CI 已通过：

```powershell
.\scripts\test_plugin_side_roslyn.ps1 -GodotPath "<Godot Editor Path>"
```

7. 如修改了 `.github/workflows/**`，确认 `lint-workflows` 通过。
8. 如推送正式发布 tag，确认 tag 使用 `plugin-v*`，且 tag 版本与 `plugin.cfg`、中英文 changelog 和对应 `release-notes-v*.md` 一致。

---

## 3. 发布说明格式

正式 GitHub Release 正文由 `scripts/render_release_notes.ps1` 生成，保持两层结构：

1. 手写摘要层：来自 `release-notes-v<version>.md`，用于说明版本主题、关键亮点、兼容性提示和升级判断。
2. 自动摘要层：workflow 先校验 `CHANGELOG.zh-CN.md` 中的目标版本或 `Unreleased` 段落，再追加最近 commit summary。

编写手写摘要时应遵循：

- 以用户可理解的主题组织内容，不复述 commit 列表。
- 明确说明运行时、编辑器、诊断、CI 或发布流程变化对使用者的影响。
- 只描述插件自身能力、安装、验证和发布信息。
- 不记录本地构建产物、临时包、校验和或额外安装路径。

`draft-release-notes` 会在 `dev` 更新后用同一脚本刷新 `next` draft release；正式 `plugin-v*` tag 发布时，`publish-plugin` 会用同一脚本生成最终正文。

---

## 4. 远程发布流程

1. 从最新 `origin/dev` 创建发布短分支，例如 `release/v1.0.0`。
2. 完成版本、变更记录、`release-notes-v*.md` 和公开文档收口。
3. 推送短分支并创建指向 `dev` 的 PR。
4. 等待 `validate-plugin-harness` 和相关 workflow 检查通过。
5. 由维护者在 GitHub PR 页面手动确认并合并。
6. 手动运行或等待 `draft-release-notes` 刷新 `next` draft release，并检查正文是否符合正式发布格式。
7. 优先手动触发 `publish-release` workflow，先保持 `dry_run=true` 验证版本、tag、发布说明和构建检查。
8. dry run 通过并确认发布内容后，重新运行 `publish-release`，将 `dry_run` 设为 `false`；workflow 会在 `dev` 当前提交上创建新的 `plugin-v*` tag，生成正式 GitHub Release，并删除已消费的 `next` draft release。
9. 如需沿用旧入口，也可以在合并后的 `dev` 上创建并推送 `plugin-v*` tag，或手动触发 `publish-plugin` workflow 进行验证。
10. `publish-release` 和 `publish-plugin` 都会在发布前检查版本一致性、发布说明源文件和已存在 release；检查通过后创建 GitHub Release，不上传本地包资产。

`publish-release` 只执行发布收尾：不会提交版本号变更、不会合并 PR、不会推送 `dev`、不会覆盖或删除正式 tag，也不会制作或上传 zip / package 资产。若 tag 或 GitHub Release 已存在，workflow 会失败并要求选择新版本或人工处理。

---

## 5. 失败处理

- CI 失败时，修复应回到短分支并重新推送，不直接修改 `dev`。
- 发布说明错误时，优先编辑 GitHub Release 正文；如果源文档或 changelog 错误，再开短分支修正。
- tag 错误时，由维护者决定是否删除远程 tag；Agent 不擅自删除或重写发布 tag。
- `next` draft release 内容错误时，优先修正 `release-notes-v*.md` 或 changelog 后重新运行 `draft-release-notes`；如渲染规则本身错误，应通过短分支 PR 修改 workflow 或脚本。
