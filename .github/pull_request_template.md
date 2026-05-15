## Summary

- 

## Scope

- Repository: `godot-dotnet-mcp`
- Target branch: `dev`
- Change type: <!-- fix / feature / docs / ci / chore / hotfix -->

## Root Cause / Why

<!-- For fixes, explain the root cause. For docs/process changes, explain why the workflow needs to change. -->

## Changes

- 

## Verification

<!-- List exact commands or MCP/Godot checks run. -->

```powershell
# Example:
.\scripts\test_plugin_side_roslyn.ps1 -GodotPath "<Godot Editor Path>"
```

## Changelog / Docs / Mechoes Sync

- CHANGELOG.md: <!-- updated / not required because ... -->
- CHANGELOG.zh-CN.md: <!-- updated / not required because ... -->
- Docs: <!-- updated / not required because ... -->
- Mechoes sync: <!-- required / not required because ... -->

## Risk / Process Impact

<!-- For workflow, release, branch, bot, or process changes, describe the impact and mitigation. Otherwise state "None beyond the scoped change." -->

## Checklist

- [ ] PR only contains the target branch scope; unrelated fixes are split out
- [ ] `CHANGELOG.md` and `CHANGELOG.zh-CN.md` are updated, or this PR explains why no changelog is needed
- [ ] Public docs avoid local workspace paths, Mechoes/OrbitPilot context, zip packages, and local release artifacts
- [ ] If plugin source changed, Mechoes sync need is stated in the PR summary
- [ ] Agent-created changes were pushed to a short branch, not directly to `dev`
- [ ] Agent will not merge this PR or push `dev`; the owner merges from the GitHub PR page

## Related Issues

<!-- Closes # -->
