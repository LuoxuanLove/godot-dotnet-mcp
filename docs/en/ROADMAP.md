# Roadmap

This document describes the product direction for Godot .NET MCP. It is a planning document, not a release promise, and it cannot replace issue-level design. As implementation constraints, test results, and user feedback become clearer, the version scope may change.

## Product Positioning

Godot .NET MCP is an editor-native MCP plugin for Godot 4.6+ .NET projects. In the 1.x line, its identity is:

- the MCP server runs directly inside the Godot editor
- it provides live editor, project, scene, runtime, diagnostics, screenshot, C# structure, resource, and tool-extension context
- it exposes high-level `system_*` workflows instead of forcing the Agent to deal with too many low-level atomic tools
- it keeps setup simple and avoids making the core plugin experience depend on extra always-on background services
- it lets the Agent verify work through diagnostics, runtime evidence, and editor state, not just file edits

This project should not compete on raw tool count. It should compete on semantic quality, setup-aware guidance, C# and .NET project understanding, editor-state accuracy, runtime validation, and a stable public MCP surface.

## v1.x Direction

The 1.x line should keep improving the editor-native plugin structure while turning Godot .NET MCP into an evidence-first workflow platform for Agents. The first goal is to help the Agent discover the right capabilities, make focused changes, verify them in Godot, and report trustworthy evidence.

### v1.4.0 Protocol Refactor

v1.4.0 follows the [protocol refactor plan](process/v1.4.0-protocol-refactor-plan.md): context, state, and catalogs move to Resources; workflow guidance stays in Prompts; and Tools narrow to action and computational workflow entries. The target baseline is MCP 2025-11-25, with `127.0.0.1:3000/mcp` as the default Streamable HTTP endpoint, newline-delimited stdio as the default stdio mode, and schema/metadata/UI catalog adaptation handled as explicit gates. The work is intentionally split into PR-sized refactor axes with removal guards and migration contracts.

The current execution checklist is tracked in the [v1.4.0 refactor progress tracker](process/v1.4.0-refactor-progress-tracker.md).

### Capability Discovery and Tool Governance

- Strengthen `system_help` and the tool catalog resources so the Agent can choose tools by task instead of guessing from a large flat list
- Make tool groups and profiles clearer, including core, runtime, DAP, editor UI, visual, plugin, and user-extension capabilities
- Expose setup-gated states, such as the project not running, runtime control unavailable, DAP endpoint unavailable, editor foreground required, or user tools missing
- Keep the high-level `system_*` entry points as the public workflow layer, while keeping the low-level executors as implementation details
- Treat public tool names, parameters, return fields, and protocol facts as the stable API surface for the 1.x workflow

### Closed-Loop Runtime Validation

- Organize the current project run, runtime control, runtime step, screenshot, editor log, and runtime-diagnosis tools into a clearer validation workflow
- Support evidence-driven reports that explain what ran, which markers matched, which screenshots or runtime states were captured, whether errors occurred, and whether cleanup finished
- Avoid treating a successful startup as proof that behavior was validated. Runtime validation should separate startup, interaction, diagnosis, and proof
- Expand contract and harness coverage for marker validation, runtime-event handling, screenshot availability, stop and cleanup behavior, and error reporting

### C# and Godot Binding Depth

- Deepen Roslyn support for Godot .NET project structure, exported members, partial classes, signals, NodePath usage, resources, PackedScene, and generated project metadata checks
- Improve the connection between C# diagnostics, Godot scene and resource references, editor-visible bindings, and runtime errors
- Make the managed C# debugger boundary explicit. The Godot DAP tools can support the Godot debugger workflow, but managed C# breakpoints may still need a dedicated .NET debugger
- Prefer practical binding, resource, and build diagnostics over broad but shallow code-analysis claims

### User Extensions as a Project Capability Pack

- Improve the `custom_tools/` scaffolding, compatibility checks, hot-load safety, audit output, and recovery guidance
- Help the Agent create project-specific `user_*` tools without changing the plugin source
- Document the expected user-tool schema, return shape, dry-run mode, validation expectations, and fault-isolation rules
- Make the Tools page and prompt guides present user extensions as a first-class capability while keeping them clearly separate from built-in tools

### Demonstrable Workflows

The 1.x line should include reproducible examples that show how the plugin solves real Godot .NET problems end to end, such as:

- discovering, fixing, and revalidating C# export or NodePath binding problems
- diagnosing and repairing broken scene or resource references
- tracing runtime failures through logs, diagnostics, screenshots, and focus-aware fixes
- safely scaffolding, loading, auditing, and using a user extension

These examples should emphasize repeatability and evidence, not marketing breadth.

### Stability and Public Schema Discipline

- Keep the established `system_*` identity and avoid unnecessary breaking changes
- Prefer adding fields instead of removing or renaming them
- Keep protocol facts, tool schema, resources, prompts, localization strings, docs, changelog, and tests in sync
- When public behavior must change, provide a clear migration note

### Editor UX and Agent UX

- Keep the Dock focused on service health, current context, tool discovery, configuration, update state, and actionable diagnostics
- Improve the screenshot-based verification path for editor UI work
- Keep lowering setup friction for supported MCP clients while making the current installation and configuration state visible
- Keep the user-facing plugin UI and tool descriptions fully localized

### Diagnostics and Evidence Quality

- Improve project-state summaries for large projects without requiring a full file enumeration
- Expand scene dependencies, resource references, binding audits, runtime logs, and performance snapshots into readable evidence summaries
- Keep failure reports specific. They should explain what failed, why the current session cannot perform the action, and which setup step would unblock it

### Test and Release Reliability

- Keep expanding headless harness, editor probe, contract, localization, and release verification coverage
- Keep Asset Library installation verification aligned with the exported plugin contents
- Make sure release notes and the changelog describe user-visible capabilities and important internal verification changes, not implementation logs

## v2.0 Direction

v2.0 is the right stage to explore structural extensions beyond the 1.x editor-native plugin boundary. The main area to explore is an optional external or headless companion mode.

### Optional External or Headless Companion

Only consider a v2.0 companion if it solves real workflows that the editor-native plugin cannot cover well. Possible goals include:

- checking `.tscn`, `.tres`, `.csproj`, solution files, and C# source without opening the editor UI
- running builds, restores, static audits, resource-reference checks, and binding checks in local automation or CI-style environments
- starting Godot in a controlled headless or runtime-validation mode when live editor context is not needed
- providing a lower-friction path for remote or automated Agent sessions
- upgrading to live editor context when an editor-plugin session is available

This companion must not weaken the core plugin experience. The editor plugin should remain the authoritative source for live editor state, selected nodes, Dock state, editor screenshots, editor logs, and editor UI control.

### v2.0 Structure Principles

- Keep the 1.x editor-native plugin as the stable mode, not as a soon-to-be-removed transition path
- Any companion must be optional, explicit, and capability-gated. It must not become a hidden required background process
- Define a strict protocol boundary between editor-live capabilities and headless or static capabilities
- Avoid duplicating tool semantics across modes unless the result shape and limitations are clearly documented
- Keep user trust through write operations that are previewable, auditable, and, where possible, recoverable

### Deeper .NET Runtime and Debugging Story

If the Godot and .NET debugging boundaries allow it, v2.0 can also explore a deeper .NET workflow:

- stronger mapping from managed exceptions to C# source, scenes, and resources
- richer MSBuild and SDK compatibility diagnostics
- a clearer split between Godot DAP debugging and managed .NET debugging responsibilities
- a more precise mapping from runtime failures to project files, scene bindings, and exported members

## Non-Goals

- Do not treat larger raw tool count as the success metric
- Do not expose arbitrary local code execution as the default user-visible capability
- Do not replace a dedicated .NET IDE debugger with vague debugging claims
- Do not make an external companion a required dependency for the 1.x editor-native workflow
- Do not embed project-specific business tools into the plugin repository; project-specific capabilities should live in user extensions
- Do not treat this document as a committed release schedule
