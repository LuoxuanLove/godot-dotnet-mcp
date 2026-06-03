# Smoke and CI

This document explains the current test structure, CI integration status, and the direction of future gating.

---

## 1. Smoke Positioning

The plugin headless harness validates tool loading and routing behavior inside the plugin runtime and does not rely on external processes or third-party test frameworks. CI only hard-gates the required subset specified by `scripts/test_plugin_side_roslyn.ps1`.

---

## 2. Current Structure

Current related files:

```text
tests/
├─ godot_plugin_harness/
│  └─ GodotPluginHarness.csproj
└─ godot_plugin_harness_fixture/
   └─ tests/
      └─ *.gd  (contract tests)

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

## 3. Current Progress

- The plugin headless harness is part of the CI required subset
- Multiple contract-test cases can still be discovered by the harness, but they are not all part of the hard gate yet
- `plugin_entrypoint_contracts` runs through editor probe mode, and the editor shutdown warning at exit is treated as non-fatal noise in the harness
- PR target-branch policy, public version metadata policy, fast .NET build, release tag version consistency, and the next draft release are all already managed by workflows
- `actions-bot-relay` can let `github-actions[bot]` create short branches and PRs from a maintainer-provided patch

---

## 4. Current CI State

Current workflows:

- `.github/workflows/actions-bot-relay.yml`
- `.github/workflows/dotnet-build.yml`
- `.github/workflows/draft-release-notes.yml`
- `.github/workflows/lint-workflows.yml`
- `.github/workflows/pr-policy.yml`
- `.github/workflows/publish-release.yml`
- `.github/workflows/publish-plugin.yml`
- `.github/workflows/validate-plugin.yml`
- `.github/workflows/version-policy.yml`

Current coverage:

1. `actions-bot-relay`: accepts a manually provided base64 patch, creates an `actions-bot/*` branch and a PR targeting `dev` with `github-actions[bot]`, and appends base and head SHA, changed paths, diffstat, trigger actor, run URL, and validation-workflow links to the PR body
2. `pr-policy`: blocks PRs that target the wrong branch, only allowing PRs that point to `dev`, and validates objective fields such as the title, summary, and testing notes
3. `version-policy`: checks public version metadata through trusted `dev`-side workflows and scripts, and blocks non-`release/*` branches from bumping plugin versions too early
4. `dotnet-build`: runs a fast build of the plugin Roslyn library, the harness runner, and the fixture, and also runs refactor guardrails
5. `lint-workflows`: runs `actionlint` on `.github/workflows/**`
6. `validate-plugin-harness`: downloads Godot 4.6 and runs the plugin-harness required subset, based on `$RequiredCases` in `scripts/test_plugin_side_roslyn.ps1`. Normal headless cases run in a batch, while a few isolated headless cases and the editor probe case run separately
7. `publish-release`: manual one-click release entry, which only uses GitHub Actions `Use workflow from` with `dev` as the source, defaults to `dry_run=true`, and validates version, release notes, build, and harness. A recent successful dry-run record for the same version and commit can skip repeated build and harness checks during the real run
8. `publish-plugin`: before a `v*` tag release, validates the tag version, `dev` reachability, and release-note source file, then runs build and harness, and finally creates a GitHub Release using the two-layer release-note body
9. `draft-release-notes`: after `dev` moves forward, creates or refreshes the `next` draft release with the same rendering script so it acts as a preview of the next formal release body

`validate-plugin.yml` now keeps only the heavy Godot harness and still exposes the stable `validate-plugin-harness` check name. `pr-policy.yml` handles PR target-branch checks and light PR standards. `dotnet-build.yml` handles the fast .NET build and guardrails. Normal same-repo short-branch PRs rely on the `pull_request` entry. `push` is kept only for `dev`, so the same commit does not trigger both short-branch `push` and `pull_request.synchronize` runs. After `actions-bot-relay` creates a PR, it explicitly triggers `dotnet-build.yml`, `validate-plugin.yml`, and `version-policy.yml`, and explicitly triggers `lint-workflows.yml` when the workflow files change. The remote `dev` branch should have a GitHub branch ruleset and should mark `validate-plugin-harness` as a required check. If you want stricter gating, you can also add `dotnet-build` as a required check. `pr-policy` mainly provides early feedback and should not replace `validate-plugin-harness`. Both `validate-plugin.yml` and `dotnet-build.yml` include `merge_group` triggers so merge-queue integration can be added later.

`dotnet-build.yml` and `validate-plugin.yml` only use concurrency cancellation for a new run on the same PR. This prevents old builds or harness runs from holding runners for the same PR. Non-PR runs such as `dev` pushes, `workflow_dispatch`, `merge_group`, tags, and releases use a unique run ID as the concurrency group, so they do not cancel each other. The `dotnet-build` job timeout is 30 minutes, and the `validate-plugin-harness` job timeout is 90 minutes. The check names stay the same.

The heavy harness entry prints total duration plus timing summaries for build, case listing, batched headless, isolated headless, isolated editor probe, per-case, and guardrail stages. In GitHub Actions it is also appended to Step Summary, which helps track slow cases or slow stages.
`dotnet-build.yml` and the `.NET build` stage in `scripts/test_plugin_side_roslyn.ps1` detect failures that match `CS2012`, the Godot `.godot/mono/temp` path, and file-lock or antivirus-scan signals, and they output a `transient_file_lock` diagnosis. That diagnosis means a temporary build artifact may have been locked briefly, not that the source code is broken. The script only suggests rerunning and adding antivirus exclusions. It does not retry automatically, delete `.godot`, or terminate processes.

The harness JSON report distinguishes suite success markers from Godot exit cleanup warnings. If a normal headless suite sees `ObjectDB instances leaked at exit` or `resources still in use at exit`, it still fails, but it also outputs `suiteSuccess`, `successMarkerDetected`, `exitCleanupWarningMarkers`, `exitCleanupWarningPolicy`, and `failureClass=exit_cleanup_warning`, so you can tell whether the failure came from exit cleanup rather than case logic.

`dotnet-build.yml`, `validate-plugin.yml`, `publish-release.yml`, and `publish-plugin.yml` use the `windows-2025` hosted runner and rely on `global.json` to lock SDK selection to the .NET 8 feature band. The workflows first print `dotnet --info` and `dotnet --list-sdks`, and they fail immediately if the .NET 8 SDK is not selected. `dotnet-build.yml` and `validate-plugin.yml` both cache the NuGet global package directory. The cache key covers `Directory.Build.props`, project files, props and targets, `global.json`, centralized package management files, and lock files. `publish-release.yml` additionally stores a successful dry-run record for the same version and commit so the real release can skip repeated build and harness checks. `validate-plugin.yml` also caches the Godot 4.6 mono Windows extraction directory. Even after a cache hit, it still looks for the non-console Godot executable. If the executable is missing, it downloads and extracts again, so a bad cache does not pass silently.

If `validate-plugin-harness` fails, `.tmp/godot_plugin_harness` is kept and a 7-day artifact is uploaded so maintainers can download the stage root, process registry, and other failure context. Successful runs still clean up that directory.

---

## 5. Local and Remote Validation Layers

PR validation is split into three layers: local preflight, remote CI, and review gates. The three layers have different jobs and cannot replace each other:

1. Local preflight is for catching deterministic issues early. When the Godot editor path is available, run the affected harness or script first. When a workflow changes, check YAML and script syntax first
2. Remote CI is the objective gate before merge. `dotnet-build`, `validate-plugin-harness`, `pr-policy`, and `lint-workflows` when needed must all be judged by the latest head
3. Review gates cover issues that CI misses. Human, Cubic, Codex, and other review-tool comments must be replied to and resolved. Cubic must cover the latest head commit

Recommended reporting format:

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

If the local machine does not have Godot or another required environment, the PR body should say exactly which checks were not run and wait for an equivalent remote CI result. “Not run” is not a validation result.

---

## 6. Current Gate Boundaries

### Already hard-gated

- workflow YAML syntax lint, but only when workflow files change
- PR target branch and light PR standards checks. Wrong-target PRs fail and are told to retarget `dev`, and missing required PR fields are called out
- dotnet bridge library, harness runner, and fixture build
- refactor guardrails
- plugin headless harness required subset
- version consistency checks for `plugin.cfg`, tag, the English changelog, and the Simplified Chinese changelog before tag release
- existence and version consistency checks for `docs/流程/release-notes/release-notes-v*.md` before tag release
- before merging to remote `dev`, the PR and `validate-plugin-harness` should pass and the latest `dev` should be revalidated. The current ruleset does not require an approving review

### Still soft-gated or environment-dependent

- `tests/godot_plugin_harness` supports `--allow-skip-missing-godot`, but the CI entry `scripts/test_plugin_side_roslyn.ps1` requires a real Godot executable. Other discoverable cases do not automatically enter the CI hard gate
- `actions-bot-relay` depends on repository settings that allow GitHub Actions to create pull requests. If that permission is disabled, the workflow fails while creating the PR
- `actions-bot-relay` only applies the patch provided by the maintainer. It does not generate or interpret requirements. The extra metadata it appends is only for review help and never replaces validation or human judgment
- `next` draft releases only help maintain the release notes. They are not formal releases, and they should preview the final hand-written summary, changelog details, and commit summary
- the Agent may create, commit, and push short branches when authorized, but only the maintainer can confirm and merge remote `dev` on GitHub. The Agent must not merge locally and then push `dev`, or bypass required checks
- each PR should contain only the scope of the corresponding short branch. If it picks up unrelated fixes or unmerged history, split it into separate PRs or rebuild a clean branch from the latest `origin/dev`

---

## 7. Recommended Run Mode

### Local plugin harness

```powershell
dotnet run --project .\tests\godot_plugin_harness\GodotPluginHarness.csproj -c Release -- --godot-path "<Godot Path>"
```

To reproduce the CI required subset, run the script entry point directly. The script batches the normal headless cases into one batch and runs the few isolated headless cases and the editor probe case separately:

```powershell
.\scripts\test_plugin_side_roslyn.ps1 -GodotPath "<Godot Path>"
```

---

## 8. Conclusion

The harness, CI, and review gates now form a layered closed loop. `pr-policy` blocks the wrong target branch early, `dotnet-build` gives fast .NET build and guardrail feedback, `validate-plugin-harness` keeps a stable required check name while running the heavy Godot harness, `next` draft release keeps the next release note draft up to date, and `actions-bot-relay` lets `github-actions[bot]` create and push PRs without adding a new account.