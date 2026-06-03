# System Tool Layer

The system tool layer is the plugin’s high-level tool entry. It exposes the public system tools in one place so the Agent can read the MCP capability guide, project state, editor state, runtime status, editor UI, editor Output, scenes, scripts, and symbols, and also get actionable suggestions and patch entry points.

The default `system` profile only enables this layer. It is meant for first understanding the context and then choosing the right high-level `system_*` tool. The lower-level atomic tools are only shown as internal implementation links.

---

## File Structure

```text
tools/system/
├─ executor.gd
├─ atomic_bridge.gd
├─ impl_help.gd
├─ impl_editor.gd
├─ impl_runtime.gd
├─ impl_dap.gd
├─ impl_scene.gd
├─ impl_index.gd
├─ lsp_client.gd
├─ impl_project.gd
└─ impl_script.gd
```

---

## Builtin Tools

### Capability Guide
- `system_help`: returns an Agent-oriented MCP capability guide, recommended start order, screenshot-first hints, hidden-control enumeration hints, runtime automation capability notes, and the current tool schema version

After connection, start by calling `system_help` or reading the tool docs to confirm the current schema version. When the task involves Dock, tabs, popups, layout, button visibility, or focus switching, prefer `system_editor_control(action=activate_ui)` to activate the target UI through the Godot API, then use `system_editor_control(action=capture_editor)` to get an editor screenshot. If visible-control enumeration cannot find the target, retry with `include_hidden=true`.

### Project Level
- `system_project_state`: project snapshot with file counts, recent errors, running state, and `runtime_capabilities`; supports compact reads and segmented reads
- `system_editor_state`: editor session snapshot for main screen, focus, Inspector, FileSystem, runtime summary, and capabilities
- `system_runtime_diagnose`: runtime errors, compile errors, and performance snapshot
- `system_project_configure`: read and write project settings, input maps, and Autoloads
- `system_project_files`: high-level project file-tree entry with directory listing, create and delete directory, file read, copy, move, delete, selection, scan, and reimport support
- `system_project_run`: run the main scene or a selected scene. Without markers it returns immediately and uses `timeout_ms` only for auto-stop. With markers it waits for structured runtime-bridge events and uses the bounded wait flow
- `system_project_stop`: stop the current project run
- `system_plugin_reload`: read freshness or schedule a full plugin disable and enable lifecycle reload
- `system_plugin_update`: read version, fingerprint, and source ref, choose update source, start ref discovery or sync, and poll sync and reload progress

These tools are currently carried by `tools/system/impl_project.gd`, and they aggregate lower-level `project_*`, `editor_*`, and `debug_*` atomic tools through `atomic_bridge.gd`.

### Editor UI Level
- `system_editor_control`: main-screen switching, full-window screenshots, control enumeration, coordinate mapping, focus, activation, local clicks, and popup interaction
- `system_editor_log`: read Output, filter errors and warnings, and clear Output

### Runtime Automation Level
- `system_runtime_control`: query, enable, or disable the runtime-control safety gate for the current debugger session
- `system_runtime_step`: unified runtime I/O entry for step, capture, and input

### DAP Debugging Level
- `system_dap_debugger`: connect to the built-in Godot DAP endpoint and drive settings, initialize, launch, attach, configuration done, threads, breakpoints, pause, continue, step, stack traces, output, terminate, and disconnect

### Scene Level
- `system_scene_validate`
- `system_scene_analyze`
- `system_scene_tree`
- `system_scene_patch`

### Script Level
- `system_bindings_audit`
- `system_script_analyze`
- `system_script_patch`

### Project Resource Audit Level
- `system_resource_reference_audit`

### Index Level
- `system_project_symbol_search`
- `system_scene_dependency_graph`

---

## Workflow Advice

Recommended order:

```text
system_editor_state / system_project_state
  -> system_project_files / system_scene_analyze / system_script_analyze / system_runtime_diagnose
  -> system_scene_tree / system_scene_patch / system_script_patch / the matching high-level system tool
```

If the goal is runtime automation inside the editor, the recommended order becomes:

```text
system_project_run
  -> system_runtime_control(action=enable)
  -> system_runtime_step(action=step)
  -> system_runtime_step(action=capture / input)
```

If the goal is control discovery and interaction inside the editor UI, use:

```text
system_editor_state
  -> system_editor_control(action=activate_ui)
  -> system_editor_control(action=list_controls)
  -> system_editor_control(action=get_control / capture_control)
  -> system_editor_control(action=focus_control / activate_control / click_control / right_click_control / set_control_text)
```

---

## Relationship to Atomic Tools

System tools do not directly implement every low-level action. Instead, they combine scene, script, project, file-system, debug, and DAP atomic executors through `atomic_bridge.gd`.

The benefits are:
- high-level workflows stay stable
- lower-level executors keep their fine-grained power and can still appear as implementation links in the Tools tree
- write protection can be enforced centrally at the Atomic Bridge layer

---

## Write Protection

`atomic_bridge.gd` intercepts write actions and checks whether the target path is inside the plugin directory. By default, system tools cannot write directly to:

```text
res://addons/godot_dotnet_mcp/
```

If you really need to change the plugin’s own files, use the `plugin_developer` tools and explicit authorization.

---

## User Tool Extension

`executor.gd` also scans:

```text
res://addons/godot_dotnet_mcp/custom_tools/
```

Scripts that implement `handles()`, `get_tools()`, and `execute()`, and that return tool names starting with `user_`, are added into the same tool tree.

This lets the `system` and `user` high-level tool groups appear side by side in the same UI.