# Agent and Bot Workflow

This document defines the GitHub workflow for Agents or bots that participate in Godot .NET MCP development.

---

## 1. Identity Principles

- Use a separate machine user or GitHub App as the GitHub actor for pushing and creating PRs when possible
- If you do not want an extra account, use `actions-bot-relay` so `github-actions[bot]` can create short branches and PRs from a patch provided by the maintainer
- Changing the git commit author alone does not change the GitHub PR author or the latest push actor
- Keep bot permissions minimal. Usually only branch push, PR create or update, and repository read access are needed

---

## 2. Branches and PRs

- Create a short branch from the latest `origin/dev` with a clear name, such as `feature/*`, `fix/*`, `docs/*`, `chore/*`, `hotfix/*`, or `release/*`
- After validation passes, the Agent may commit and push the current short branch
- Each short branch and PR must contain only the changes that belong to that branch’s target scope
- If other tasks, other fixes, or unmerged history are mixed in, split them into separate PRs or rebuild a clean branch from the latest `origin/dev`
- All PRs must target `dev`; `pr-policy` will fail PRs that target the wrong branch
- Short branches created by `actions-bot-relay` must use the `actions-bot/*` prefix

---

## 3. PR Body Requirements

Use a concise PR template that only keeps the public information a maintainer needs to read quickly:

- `Summary` - 1 to 3 bullets that explain the result and goal of the PR
- `Changes` - the actual reviewable edits
- `Screenshots` - only when the change affects UI or visuals
- `Testing` - the local commands, CI checks, or editor and plugin validation that were actually run
- `Related Issues` - linked issues, if any

The stricter branch, changelog, review, Cubic, and merge rules live in this workflow document and the CI gates, not in the PR template body. Use Conventional Commits for the PR title, for example `fix(scope): short description`.

---

## 4. Definition of Done and Repair Loop

When public tool behavior, UI structure, lifecycle semantics, CI or workflow behavior, or release content changes, the definition of done must cover implementation, contract tests, docs, and changelog together. Code that builds is not enough. If related tests or docs still describe an old path, old field, or old meaning, the PR is still in repair.

Before submitting or updating a PR, the Agent must finish these checks:

- The affected contract tests have been updated to reflect the real contract; if old tests fail because they still describe the old path or old meaning, fix the test contract first instead of calling it unrelated failure in the final report
- `docs/`, `README*`, tool docs, protocol facts, and `CHANGELOG*` that relate to the public behavior in this PR are in sync; `CHANGELOG*` must cover important `Documentation` and `Internal` changes, such as release note source files, docs and i18n updates, runbook changes, CI and harness behavior, policy checks, protocol facts, and validation coverage changes. A pure version metadata bump is not a separate entry
- Review, Cubic, Codex, or human feedback that finds test or doc gaps must be handled in the same PR and marked resolved, outdated, or explicitly decided by the maintainer
- Validation records must list the actual test, build, or harness cases that ran. A read-only check is not a substitute for the affected contract tests

---

## 5. PR Completion Gates

A PR may be reported as ready for maintainer merge only when all of the following are true:

1. The PR targets `dev` and has been rechecked against the current verifiable `dev`
2. For normal PRs, `pr-policy` passes and the title and body contain the required objective fields. For `actions-bot-relay` PRs that do not trigger this check naturally, the relay metadata, the explicitly triggered validation workflow, and maintainer review must cover that confirmation
3. `dotnet-build` passes
4. `validate-plugin-harness` passes
5. If `.github/workflows/**` was changed, `lint-workflows` passes
6. All human, Cubic, Codex, or other review conversations are replied to and resolved. Invalid issues should be explained, valid issues should be fixed
7. Cubic covers the latest head commit, and the latest result has no blocking issues
8. `CHANGELOG*`, public docs, validation records, and the actual scope of changes are aligned, and important `Documentation` or `Internal` changes are reflected in the changelog. If a doc did not need updating, explain the plugin-side reason in the PR body

If any gate is not met, the PR can only be reported as needing repair or validation, not as complete.

---

## 6. Repair Iteration Discipline

Each PR repair pass should address only the current failing gate or the specific issues raised by reviewers. Avoid adding new scope during a validation loop.

Recommended order:

1. Read the failing check, review thread, or latest Cubic result
2. Decide whether the issue is valid. If it is, fix it locally. If not, reply with the reason
3. Update only the directly related tests, docs, or changelog
4. Commit and push the short branch
5. Revalidate the latest head through CI and review gates

Old CI, old review, or old Cubic results after a code change are not proof of completion.

---

## 7. Merge Boundary

- The Agent does not push directly to `dev`
- The Agent does not merge locally and then push `dev`
- The Agent does not bypass required checks
- The Agent does not merge GitHub PRs. Only the maintainer may confirm and merge on the GitHub PR page

---

## 8. GitHub Actions Bot Relay

`actions-bot-relay` is the fallback when you do not want an extra machine user. The maintainer or Agent first prepares a unified patch based on the latest `dev`, then manually triggers the workflow. `github-actions[bot]` applies the patch, commits it, pushes an `actions-bot/*` branch, and creates or updates a PR targeting `dev`.

Prerequisite: repository Settings > Actions > General must allow GitHub Actions to create and approve pull requests. The workflow only uses the default `GITHUB_TOKEN`, not a PAT.

Input requirements:

- `patch_base64`: a base64 encoded unified git patch. Because of `workflow_dispatch` input limits, it is only suitable for small to medium changes
- `pr_title`: PR title
- `pr_body`: PR body. It must use the concise template and satisfy the objective fields required by `pr-policy`
- `commit_message`: commit message
- `branch_name`: optional, and must be empty or use the `actions-bot/*` prefix
- `base_branch`: fixed to `dev`

Execution boundaries:

- The workflow accepts only patches. It does not run arbitrary user scripts
- The workflow explicitly triggers `dotnet-build.yml`, `validate-plugin.yml`, and the trusted `version-policy.yml`. If the patch changes `.github/workflows/**`, it also triggers `lint-workflows.yml`
- A normal short-branch push is not the automatic validation entry for a PR. The relay still uses `workflow_dispatch` to validate the bot branch explicitly
- Because pushes and PRs triggered by `GITHUB_TOKEN` do not automatically start every workflow the same way as a normal user push, the relay must explicitly trigger validation workflows
- The maintainer still needs to review, approve, and merge on the GitHub PR page

---

## 9. Automation Boundary

- Automatically generated, automatically refreshed, or scheduled maintenance changes can only land through a short-branch PR. They do not go directly into `dev`
- Automation workflows may generate or refresh the `next` draft release as the next release-note draft, but they must not create a formal release, upload zip or sha256 assets, or replace the maintainer’s release judgment
- Formal release tags, remote tag deletion, release-body corrections, and handling of an existing release are maintainer decisions. The Agent must not rewrite release history on its own
- Do not use npm or Bun publishing, OIDC trusted publisher, CLA Assistant, force-pushing the main branch, or PAT-driven auto-merge flows

---

## 10. PR Reporting Requirements

When the Agent creates or updates a PR, it should report:

- the scope of the change and the target branch
- whether the changelog or docs were updated
- the validation commands and results that were run
- the current CI, review conversation, and Cubic status
- any remaining manual actions the maintainer must perform
