# Roadmap

<p align="center"><a href="ROADMAP.md">English</a> | <a href="i18n/ko/ROADMAP.md">한국어</a> | <a href="i18n/ja/ROADMAP.md">日本語</a> | <a href="i18n/zh-CN/ROADMAP.md">简体中文</a></p>

This roadmap describes the intended product direction for Godot .NET MCP. It is a planning document, not a release promise or a substitute for issue-level design. Version scope may change as implementation constraints, testing results, and user feedback become clearer.

## Product Positioning

Godot .NET MCP is an editor-native MCP plugin for Godot 4.6+ .NET projects. Its 1.x identity remains:

- run the MCP service directly inside the Godot editor;
- provide live editor, project, scene, runtime, diagnostic, screenshot, C# structure, resource, and tool-extension context;
- expose high-level `system_*` workflows instead of overwhelming agents with low-level atomic tools;
- keep setup direct and avoid requiring a separate always-on background server for the core plugin experience;
- make agent work verifiable through diagnostics, runtime evidence, and editor state rather than file edits alone.

The project should not compete on raw tool count. It should compete on semantic quality, setup-aware guidance, C#/.NET project understanding, editor-state accuracy, runtime validation, and stable public MCP surfaces.

## v1.x Development Direction

The 1.x line should make Godot .NET MCP an agent-guided, evidence-first workflow platform while continuing to refine the editor-native plugin architecture. The priority is to help agents discover the right capability, make a focused change, validate it through Godot, and report credible evidence.

### Capability Discovery and Tool Governance

- Strengthen `system_help` and tool catalog resources so agents can choose tools by task instead of guessing from a large flat list.
- Make tool groups and profiles clearer, including core, runtime, DAP, editor UI, visual, plugin, and user-extension capabilities.
- Surface setup-gated states such as project not running, runtime control unavailable, DAP endpoint unavailable, editor foreground required, or user tools missing.
- Keep high-level `system_*` entries as the public workflow layer while preserving low-level executors as internal implementation details.
- Treat public tool names, parameters, return fields, and protocol facts as stable API surfaces for 1.x workflows.

### Closed-Loop Runtime Validation

- Turn existing project run, runtime control, runtime step, screenshot, editor log, and runtime diagnosis tools into clearer validation workflows.
- Support evidence-oriented reports that explain what ran, which markers matched, what screenshots or runtime states were captured, whether errors appeared, and whether cleanup happened.
- Avoid treating a successful launch as a successful behavior check; runtime validation should preserve the distinction between startup, interaction, diagnostics, and proof.
- Expand contract and harness coverage for marker validation, runtime event handling, screenshot availability, stop/cleanup behavior, and error reporting.

### C# and Godot Binding Depth

- Deepen Roslyn-backed inspection for Godot .NET project structures, exported members, partial classes, signals, NodePath usage, resources, packed scenes, and generated project metadata.
- Improve the connection between C# diagnostics, Godot scene/resource references, editor-visible bindings, and runtime errors.
- Keep managed C# debugging boundaries explicit: Godot DAP tools can support Godot debugger workflows, while managed C# breakpoints may still require a dedicated .NET debugger.
- Prefer practical binding, resource, and build-diagnostic workflows over broad but shallow code analysis claims.

### User Extensions as Project Capability Packs

- Improve `custom_tools/` scaffolding, compatibility checks, hot-load safety, audit output, and recovery guidance.
- Help agents create project-specific `user_*` tools without modifying plugin source code.
- Document expected schemas, return structures, dry-run patterns, validation expectations, and failure isolation for user tools.
- Make the Tools page and prompt guidance show user extensions as first-class but clearly separated from built-in tools.

### Demonstrable Workflows

The 1.x line should include reproducible examples that show the plugin solving real Godot .NET problems end to end, such as:

- a C# export or NodePath binding issue found, patched, and revalidated;
- a broken scene/resource reference diagnosed and repaired;
- a runtime failure traced through logs, diagnostics, screenshots, and a focused fix;
- a user extension scaffolded, loaded, audited, and used safely.

These examples should emphasize repeatability and evidence over marketing breadth.

### Stability and Public Schema Discipline

- Preserve established `system_*` tool identities and avoid unnecessary breaking changes.
- Add fields rather than removing or renaming fields when possible.
- Keep protocol facts, tool schemas, resources, prompts, localized descriptions, docs, changelogs, and tests synchronized.
- Maintain clear migration notes when public behavior must change.

### Editor UX and Agent UX

- Keep the Dock focused on service health, current context, tool discoverability, configuration, update status, and actionable diagnostics.
- Improve screenshot-backed UI verification paths for editor UI work.
- Continue reducing setup friction for supported MCP clients while making the current installation/configuration state visible.
- Keep localization complete for user-facing plugin surfaces and tool descriptions.

### Diagnostics and Evidence Quality

- Improve project-state summaries for large projects without forcing full file enumeration.
- Expand scene dependency, resource reference, binding audit, runtime log, and performance snapshots into readable evidence summaries.
- Keep failure reports specific: explain what failed, why the current session cannot perform an action, and which setup step would unblock it.

### Test and Release Reliability

- Continue growing headless harness, editor probe, contract, localization, and release validation coverage.
- Keep Asset Library install validation aligned with exported plugin contents.
- Ensure release notes and changelogs describe user-visible capability and important internal validation changes without becoming implementation logs.

## v2.0 Development Direction

v2.0 is the right horizon for architectural expansion beyond the 1.x editor-native plugin boundary. The main exploration area is an optional external or headless companion mode.

### Optional External or Headless Companion

A v2.0 companion should be considered only if it solves real workflows that the editor-native plugin cannot cover well. Possible goals include:

- inspect `.tscn`, `.tres`, `.csproj`, solution files, and C# sources without requiring the editor UI to be open;
- run build, restore, static audit, resource reference, and binding checks in local automation or CI-style environments;
- start Godot in controlled headless or runtime validation modes when editor live context is not required;
- provide a lower-friction path for remote or automated agent sessions;
- upgrade to live editor context when an editor plugin session is available.

This companion must not weaken the core plugin experience. The editor plugin should remain the authoritative source for live editor state, selected nodes, Dock state, editor screenshots, editor logs, and editor UI control.

### v2.0 Architecture Principles

- Keep the 1.x editor-native plugin as a stable mode, not a deprecated stepping stone.
- Make any companion optional, explicit, and capability-gated; it should not become a hidden required background process.
- Define a strict protocol boundary between editor-live capabilities and headless/static capabilities.
- Avoid duplicating tool semantics across modes unless the result shape and limitations are clearly documented.
- Preserve user trust by making write operations previewable, auditable, and reversible where feasible.

### Deeper .NET Runtime and Debugging Story

v2.0 may also explore deeper .NET-oriented workflows if the Godot and .NET debugging/tooling boundaries make them practical:

- stronger managed exception correlation to C# source, scenes, and resources;
- richer MSBuild and SDK compatibility diagnostics;
- better separation between Godot DAP debugging and managed .NET debugging responsibilities;
- more precise mapping from runtime failures to project files, scene bindings, and exported members.

## Non-Goals

- Do not chase a larger raw tool count as a success metric.
- Do not expose arbitrary local code execution as a default user-facing capability.
- Do not replace dedicated .NET IDE debuggers with vague debugging claims.
- Do not make an external companion mandatory for the 1.x editor-native workflow.
- Do not embed project-specific business tools into the plugin repository; project-specific capabilities belong in user extensions.
- Do not treat this roadmap as a committed release schedule.