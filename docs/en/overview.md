# Godot.NET MCP Documentation Overview

This documentation set explains the full technical implementation of `addons/godot_dotnet_mcp`, covering:

- plugin entry, lifecycle, runtime services, and protocol routing
- the shared source of protocol and version facts used by the plugin and host
- Dock UI scenes, tab scripts, layout, and data flow
- the tool system, domain split, system layer, persistence, localization, and user extension features
- test modules, the plugin headless harness, and CI guardrails
- the directory tree, key file responsibilities, and common persistence formats

There are four main reader groups:

- people who want to install and use the plugin in the Godot editor
- developers who maintain `plugin.gd`, `plugin/runtime/*`, `ui/*`, and `tools/*`
- collaborators who maintain tests, smoke checks, CI guardrails, and regression coverage
- collaborators who need a fast way to understand the directory structure, file responsibilities, and troubleshooting entry points

---

## Recommended Reading Order

### If you want to understand the overall architecture

1. [architecture/overview.md](architecture/overview.md)
2. [architecture/lifecycle-and-wiring.md](architecture/lifecycle-and-wiring.md)
3. [architecture/runtime-services.md](architecture/runtime-services.md)
4. [appendix/directory-tree-and-file-responsibilities.md](appendix/directory-tree-and-file-responsibilities.md)

### If you want to maintain the UI and interaction layer

1. [interface/overview.md](interface/overview.md)
2. [interface/tools-page.md](interface/tools-page.md)
3. [interface/server-and-config-pages.md](interface/server-and-config-pages.md)
4. [architecture/configuration-and-ui.md](architecture/configuration-and-ui.md)

### If you want to maintain the tool system and runtime capabilities

1. [modules/tool-system.md](modules/tool-system.md)
2. [modules/tool-domain-index.md](modules/tool-domain-index.md)
3. [modules/core-implementation.md](modules/core-implementation.md)
4. [architecture/runtime-services.md](architecture/runtime-services.md)

### If you want to troubleshoot configuration, profile, or persistence issues

1. [appendix/configuration-and-persistence.md](appendix/configuration-and-persistence.md)
2. [architecture/configuration-and-ui.md](architecture/configuration-and-ui.md)
3. [modules/core-implementation.md](modules/core-implementation.md)

### If you want to maintain encoding and Windows PowerShell compatibility

1. [appendix/encoding-rules.md](appendix/encoding-rules.md)
2. [appendix/configuration-and-persistence.md](appendix/configuration-and-persistence.md)
3. [architecture/installation-and-release.md](architecture/installation-and-release.md)

### If you want to understand the test system and quality gates

1. [testing/overview.md](testing/overview.md)
2. [testing/plugin-headless-testing.md](testing/plugin-headless-testing.md)
3. [testing/smoke-and-ci.md](testing/smoke-and-ci.md)

---

## Common Workflows

### 1. Start the local MCP server

1. Enable the plugin in Godot.
2. Open `MCPDock > Home`.
3. Check the port, auto-start, log level, and language.
4. Click Start, or keep auto-start enabled.
5. Connect the client through `http://127.0.0.1:3000/mcp` or the current port.

See [architecture/configuration-and-ui.md](architecture/configuration-and-ui.md), [interface/server-and-config-pages.md](interface/server-and-config-pages.md), and [architecture/runtime-services.md](architecture/runtime-services.md) for the details.

### 2. Adjust tool exposure and presets

1. Open `MCPDock > Tools`.
2. Choose a builtin profile or a custom profile.
3. Enable or disable tools through the `domain -> category -> tool` tree.
4. Watch the enabled count and make sure it matches `disabled_tools` and the current preset.
5. Use import or export if you want to share or replay the current tool set.

See [interface/tools-page.md](interface/tools-page.md), [modules/tool-system.md](modules/tool-system.md), and [appendix/configuration-and-persistence.md](appendix/configuration-and-persistence.md) for the details.

### 3. View and write client connection settings

1. Open `MCPDock > Config`.
2. Pick the target client platform.
3. Check the current service address, generated text, and target path.
4. Use write if you want to save it locally, or copy if you want to handle it manually.

See [interface/server-and-config-pages.md](interface/server-and-config-pages.md), [architecture/configuration-and-ui.md](architecture/configuration-and-ui.md), and [appendix/configuration-and-persistence.md](appendix/configuration-and-persistence.md) for the details.

### 4. Troubleshoot C# export bindings and scene issues

1. Use `script_inspect` or `script_exports` to read script exports.
2. Use `scene_bindings` to inspect binding state in the current scene or a specific scene.
3. Use `scene_audit` to get a structured issue list.
4. If needed, use `node_query`, `scene_hierarchy`, and `script_references` to trace node paths and script references.

See [modules/script-and-scene-analysis.md](modules/script-and-scene-analysis.md), [modules/dotnet-support.md](modules/dotnet-support.md), and [modules/tool-domain-index.md](modules/tool-domain-index.md) for the details.

### 5. Manage User tools and audits

1. Use `plugin_evolution_list_user_tools` to list the current User tools.
2. Use `plugin_evolution_scaffold_user_tool` for a dry-run scaffold preview.
3. When the result looks good, pass `authorized=true` to create it.
4. Use `plugin_evolution_user_tool_audit` to review authorization and deletion records.
5. If you want the `User` category to appear in the Dock, use `plugin_developer_user_visibility`.

See [modules/user-extensions.md](modules/user-extensions.md), [modules/core-implementation.md](modules/core-implementation.md), and [modules/tool-domain-index.md](modules/tool-domain-index.md) for the details.

### 6. Run the test matrix and regression checks

1. Use `tests/godot_plugin_harness` to run the plugin headless harness.
2. When you need to investigate environment dependency problems, add the real Godot headless path.

See [testing/overview.md](testing/overview.md), [testing/plugin-headless-testing.md](testing/plugin-headless-testing.md), and [testing/smoke-and-ci.md](testing/smoke-and-ci.md) for the details.

---

## Documentation Structure

### [architecture/](architecture/)

Describes plugin layering, lifecycle, runtime services, protocol routing, config generation, and the boundary between logic and UI.

| Document | Contents |
|---|---|
| [architecture/overview.md](architecture/overview.md) | Plugin position, layer structure, core object relationships, and responsibility boundaries |
| [architecture/lifecycle-and-wiring.md](architecture/lifecycle-and-wiring.md) | `plugin.gd` lifecycle, Dock assembly, Autoloads, and reload coordination |
| [architecture/runtime-services.md](architecture/runtime-services.md) | `plugin/runtime/*`, service control, tool loading, diagnostics, and request flow |
| [architecture/services-and-routing.md](architecture/services-and-routing.md) | HTTP and MCP routing, tool registration, protocol responses, and error shapes |
| [architecture/configuration-and-ui.md](architecture/configuration-and-ui.md) | Dock tab responsibilities, settings persistence, config generation, and UI scaling |
| [architecture/installation-and-release.md](architecture/installation-and-release.md) | Installation paths, enable steps, and pre-release checks |

### [interface/](interface/)

Describes the Dock scene structure, tab script implementations, data flow, layout, and interaction strategy.

| Document | Contents |
|---|---|
| [interface/overview.md](interface/overview.md) | Composition of `mcp_dock.tscn` and the three tab scenes, signal bridging, and model dispatch |
| [interface/tools-page.md](interface/tools-page.md) | Tree structure, search, presets, preview, divider, and shadow implementation in `tools_tab.tscn/.gd` |
| [interface/server-and-config-pages.md](interface/server-and-config-pages.md) | State display, responsive layout, and dynamic card building in `server_tab.gd` and `config_tab.gd` |

### [modules/](modules/)

Describes the tool system, system layer, core services, user extension mechanism, script and scene analysis flow, and Godot.NET support boundaries.

| Document | Contents |
|---|---|
| [modules/core-implementation.md](modules/core-implementation.md) | Relationships between `localization/`, `plugin/config/`, `plugin/runtime/`, `custom_tools/`, and shared helper modules |
| [modules/tool-system.md](modules/tool-system.md) | Tool grouping, major tool families, call patterns, and return contracts |
| [modules/tool-domain-index.md](modules/tool-domain-index.md) | Tool domain directories, executors, shared root scripts, and representative tool index |
| [modules/system-tool-layer.md](modules/system-tool-layer.md) | Public builtin system tool documentation, Atomic Bridge, impl file layering, and User tool extension |
| [modules/user-extensions.md](modules/user-extensions.md) | User tool interface rules, loading, `plugin_evolution` tools, authorization, and audit records |
| [modules/script-and-scene-analysis.md](modules/script-and-scene-analysis.md) | Analysis flow for `script_*`, `scene_bindings`, and `scene_audit` |
| [modules/dotnet-support.md](modules/dotnet-support.md) | C# static analysis scope, export detection, scene binding checks, and boundaries |

### [testing/](testing/)

Describes the three-layer test system, how it runs, known coupling points, stability risks, and CI gate strategy.

| Document | Contents |
|---|---|
| [testing/overview.md](testing/overview.md) | Test structure, current status, known boundaries, and overall direction |
| [testing/plugin-headless-testing.md](testing/plugin-headless-testing.md) | Fixtures, cases, current issues, and next steps for the `Godot Headless Harness` |
| [testing/smoke-and-ci.md](testing/smoke-and-ci.md) | CI integration, current gate status, and future layering strategy |

### [appendix/](appendix/)

Provides the directory tree, key file responsibilities, persistence formats, and supporting indexes.

| Document | Contents |
|---|---|
| [appendix/directory-tree-and-file-responsibilities.md](appendix/directory-tree-and-file-responsibilities.md) | Project directory structure, core file list, and responsibilities by directory |
| [appendix/configuration-and-persistence.md](appendix/configuration-and-persistence.md) | `user://` data, profile files, import and export JSON, client config merge rules, and language resources |
| [appendix/encoding-rules.md](appendix/encoding-rules.md) | UTF-8 and UTF-8 with BOM rules, PowerShell 5.1 read and write constraints, and repo encoding policy |

---

## Documentation Maintenance Rules

- The docs default to the latest implementation merged into `dev`; do not keep the old dynamic Dock assembly story.
- When tool return fields, setting keys, profile formats, client config templates, or permission boundaries change, update the matching section too.
- When UI scene structure, split containers, control names, or tab behavior change, update the related documents under [interface/](interface/).
- When runtime services, Autoloads, reload flow, self-diagnostic fields, or server lifecycle change, update [architecture/lifecycle-and-wiring.md](architecture/lifecycle-and-wiring.md) and [architecture/runtime-services.md](architecture/runtime-services.md).
- When adding a new tool domain, moving executor directories, removing old root entry points, or adding User tool scaffolding, update [modules/tool-domain-index.md](modules/tool-domain-index.md) and [appendix/directory-tree-and-file-responsibilities.md](appendix/directory-tree-and-file-responsibilities.md).
- When the test matrix, plugin harness, smoke structure, or CI gate strategy changes, update the related docs under [testing/](testing/).
- When encoding rules, script read and write behavior, or Windows PowerShell compatibility changes, update [appendix/encoding-rules.md](appendix/encoding-rules.md).
