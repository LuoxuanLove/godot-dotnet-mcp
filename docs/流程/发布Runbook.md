# 发布 Runbook

本文档记录 Godot .NET MCP 的发布前检查与远程发布流程。它只描述插件自身发布，不包含 Mechoes、OrbitPilot 或本地工作区同步流程。

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
2. 确认 PR 只包含当前发布目标范围，未夹带其它修复或历史未合并提交。
3. 确认公开文档不包含本地路径、Mechoes / OrbitPilot 上下文、跨仓库同步脚本流程或 zip 包安装说明。
4. 运行或确认 CI 已通过：

```powershell
.\scripts\test_plugin_side_roslyn.ps1 -GodotPath "<Godot Editor Path>"
```

5. 如修改了 `.github/workflows/**`，确认 `lint-workflows` 通过。
6. 如推送正式发布 tag，确认 tag 使用 `plugin-v*`，且 tag 版本与 `plugin.cfg` 和中英文 changelog 一致。

---

## 3. 远程发布流程

1. 从最新 `origin/dev` 创建发布短分支，例如 `release/v1.0.0-pre3`。
2. 完成版本、变更记录和公开文档收口。
3. 推送短分支并创建指向 `dev` 的 PR。
4. 等待 `validate-plugin-harness` 和相关 workflow 检查通过。
5. 由维护者在 GitHub PR 页面手动确认并合并。
6. 检查 `next` draft release 内容是否可作为正式发布说明基础。
7. 在合并后的 `dev` 上创建并推送 `plugin-v*` tag，或手动触发 `publish-plugin` workflow 进行验证。
8. `publish-plugin` 会在 tag 发布前检查版本一致性和已存在 release；检查通过后创建 GitHub Release，不上传 zip / sha256 等本地包资产。

---

## 4. 失败处理

- CI 失败时，修复应回到短分支并重新推送，不直接修改 `dev`。
- 发布说明错误时，优先编辑 GitHub Release 正文；如果源文档或 changelog 错误，再开短分支修正。
- tag 错误时，由维护者决定是否删除远程 tag；Agent 不擅自删除或重写发布 tag。
- `next` draft release 内容错误时，可重新运行 `draft-release-notes`；如规则本身错误，应通过短分支 PR 修改 workflow。
