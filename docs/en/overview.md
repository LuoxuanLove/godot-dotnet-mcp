# Godot .NET MCP Documentation Overview

This documentation set focuses on the public plugin experience: installation, editor UI usage, MCP client setup, release flow, tests, and operational reference material.

Use these entry points when you need a fast path through the docs:

- [README.md](README.md): product overview, installation options, and first connection steps.
- [ROADMAP.md](ROADMAP.md): planned plugin direction and version themes.
- [CHANGELOG.md](CHANGELOG.md): shipped changes by release.
- [interface/overview.md](interface/overview.md): Dock layout and editor-facing UI behavior.
- [process/release-runbook.md](process/release-runbook.md): release checklist and version-source rules.
- [testing/overview.md](testing/overview.md): validation layers and CI expectations.
- [appendix/encoding-rules.md](appendix/encoding-rules.md): repository encoding policy and Windows PowerShell cautions.

## Recommended Reading

### Install And Connect

1. [README.md](README.md)
2. [interface/server-and-config-pages.md](interface/server-and-config-pages.md)
3. [appendix/configuration-and-persistence.md](appendix/configuration-and-persistence.md)

### Use The Dock

1. [interface/overview.md](interface/overview.md)
2. [interface/server-and-config-pages.md](interface/server-and-config-pages.md)
3. [interface/tools-page.md](interface/tools-page.md)

### Prepare A Release

1. [process/release-runbook.md](process/release-runbook.md)
2. [process/release-notes/release-notes-v1.2.1.md](process/release-notes/release-notes-v1.2.1.md)
3. [CHANGELOG.md](CHANGELOG.md)

### Validate Changes

1. [testing/overview.md](testing/overview.md)
2. [testing/plugin-headless-testing.md](testing/plugin-headless-testing.md)
3. [testing/smoke-and-ci.md](testing/smoke-and-ci.md)

## Documentation Structure

| Area | Purpose |
|---|---|
| Root pages | Product overview, roadmap, changelog, and this navigation page |
| [interface/](interface/) | Dock pages, interaction behavior, and user-visible editor UI |
| [process/](process/) | Contributor workflow, release runbook, and release-note source |
| [testing/](testing/) | Harness, smoke checks, and CI validation expectations |
| [appendix/](appendix/) | Encoding rules, persistence formats, and directory responsibilities |

## Maintenance Rules

- Keep each locale complete and self-contained.
- Do not link from one locale tree to another locale tree.
- Keep file and folder names in the language of that locale.
- Avoid unfinished draft wording in published docs.
- Update this page when the public documentation shape changes.
