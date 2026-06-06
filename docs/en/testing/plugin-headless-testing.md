# Plugin Headless Testing

This document describes the current structure, coverage, and known boundaries of the `Godot Headless Harness`.

---

## Goal

The goals of the plugin-side test system are:

- do not introduce third-party frameworks such as `gdUnit` or `GUT`
- run `headless Godot` directly from the repository-owned fixture project
- verify the key behavior of plugin runtime, tool loading, routing, and system impls
- provide a fast regression surface for runtime refactors

---

## Current File Layout

```text
tests/godot_plugin_harness/
├─ GodotPluginHarness.csproj
└─ Program.cs

tests/godot_plugin_harness_fixture/
├─ project.godot
└─ tests/
   ├─ headless_suite_runner.gd
   ├─ runtime_bridge_contract_test.gd
   ├─ runtime_control_contract_test.gd
   ├─ runtime_control_request_coordinator_contract_test.gd
   ├─ runtime_control_reply_resolver_contract_test.gd
   ├─ runtime_fallback_store_contract_test.gd
   ├─ runtime_reply_service_contract_test.gd
   ├─ user_tool_service_contract_test.gd
   ├─ script_tool_executor_contract_test.gd
   ├─ script_edit_service_contract_test.gd
   ├─ node_tool_executor_contract_test.gd
   ├─ animation_tool_executor_contract_test.gd
   ├─ physics_tool_executor_contract_test.gd
   ├─ scene_tool_executor_contract_test.gd
   ├─ debug_tool_executor_contract_test.gd
   ├─ editor_tool_executor_contract_test.gd
   ├─ lighting_tool_executor_contract_test.gd
   ├─ geometry_tool_executor_contract_test.gd
   ├─ filesystem_tool_executor_contract_test.gd
   ├─ project_tool_executor_contract_test.gd
   ├─ material_tool_executor_contract_test.gd
   ├─ ui_tool_executor_contract_test.gd
   ├─ particle_tool_executor_contract_test.gd
   ├─ resource_tool_executor_contract_test.gd
   ├─ shader_tool_executor_contract_test.gd
   ├─ tilemap_tool_executor_contract_test.gd
   ├─ signal_tool_executor_contract_test.gd
   ├─ group_tool_executor_contract_test.gd
   ├─ audio_tool_executor_contract_test.gd
   ├─ navigation_tool_executor_contract_test.gd
   ├─ plugin_dock_coordinator_contract_test.gd
   ├─ plugin_runtime_coordinator_contract_test.gd
   ├─ plugin_self_diagnostic_store_contract_test.gd
   ├─ client_config_serializer_contract_test.gd
   ├─ client_config_inspection_service_contract_test.gd
   ├─ client_config_file_transaction_contract_test.gd
   ├─ client_config_launcher_adapter_contract_test.gd
   ├─ http_server_contract_test.gd
   ├─ http_request_router_contract_test.gd
   ├─ http_request_decoder_contract_test.gd
   ├─ http_response_service_contract_test.gd
   ├─ json_rpc_router_contract_test.gd
   ├─ editor_lifecycle_action_service_contract_test.gd
   ├─ editor_lifecycle_state_builder_contract_test.gd
   ├─ system_project_executor_contract_test.gd
   ├─ system_script_executor_contract_test.gd
   ├─ system_runtime_impl_contract_test.gd
   ├─ system_index_impl_contract_test.gd
   ├─ tool_loader_contract_test.gd
   ├─ tools_tab_rendering_contract_test.gd
   ├─ editor_lifecycle_endpoint_contract_test.gd
   └─ plugin_entrypoint_contract_test.gd
```

Responsibilities:

| File | Purpose |
|---|---|
| `Program.cs` | Copies the fixture and addon into a temporary stage root, starts Godot, collects stdout and stderr, parses suite JSON, and records stage copy, stage build, and Godot runtime timing |
| `project.godot` | Minimal test project |
| `headless_suite_runner.gd` | Suite entry point, executes cases one by one, and aggregates the results |
| Each `*_contract_test.gd` | Single-case file, split by component |

---

## Current Coverage

The harness discovers cases automatically. The following list shows representative cases only. CI hard-gates only the required subset:

| Case | Goal |
|---|---|
| `runtime_bridge_invalid_action_fallback` | Verify the fallback reply of `mcp_runtime_bridge` for an invalid action |
| `runtime_control_contracts` | Verify the state and parameter error model of `runtime_control_service` when no session is armed |
| `runtime_control_request_coordinator_contracts` | Verify request round-tripping, pending request cleanup, and session-lost invalidation in `mcp_runtime_control_request_coordinator` |
| `runtime_control_reply_resolver_contracts` | Verify normalization and error mapping of fallback replies in `mcp_runtime_control_reply_resolver` |
| `runtime_fallback_store_contracts` | Verify persistence, trimming, and read semantics of `mcp_runtime_fallback_store` |
| `runtime_reply_service_contracts` | Verify success and error payloads, `runtime_context`, `runtime_state`, and hints in `mcp_runtime_reply_service` |
| `user_tool_watch_service_contracts` | Verify that `user_tool_watch_service.gd` refreshes external user tools through an explicit callback |
| `user_tool_service_contracts` | Verify scaffold creation, directory scanning, compatibility reports, runtime diagnostics, failed-load reporting, deletion, restore, and audit in `user_tool_service.gd` |
| `script_tool_executor_contracts` | Verify the catalog, stable executor entry, and representative `read / inspect / references / edit_gd` paths after the script domain split |
| `script_edit_service_contracts` | Verify that script editing facade split keeps GDScript semantic requests routed through Godot LSP only, while the plugin keeps `*EditHelper` text-edit helpers; the official C# semantic source is plugin-local Roslyn; empty C# method scaffolds use explicit `NotImplementedException` guard bodies |
| `node_tool_executor_contracts` | Verify the catalog, stable executor entry, and representative `query / lifecycle / property / metadata / visibility` paths after the node domain split |
| `animation_tool_executor_contracts` | Verify the catalog, stable executor entry, and representative `player / animation / track / tween / animation_tree / state_machine / blend_space / blend_tree` paths after the animation domain split |
| `physics_tool_executor_contracts` | Verify the catalog, stable executor entry, and representative `physics_body / collision_shape / physics_joint / physics_query` paths after the physics domain split |
| `scene_tool_executor_contracts` | Verify the catalog, stable executor entry, and representative `management / hierarchy / run / bindings / audit` paths after the scene domain split |
| `debug_tool_executor_contracts` | Verify the catalog, stable executor entry, and representative `log_buffer / runtime_bridge / dotnet / performance / class_db` paths after the debug domain split |
| `editor_tool_executor_contracts` | Verify the catalog, stable executor entry, and representative `status / screenshot / settings / undo_redo / notification / ui_control / popup / inspector / filesystem / plugin` paths after the editor domain split |
| `lighting_tool_executor_contracts` | Verify the catalog, stable executor entry, and representative `light / environment / sky` paths after the lighting domain split |
| `geometry_tool_executor_contracts` | Verify the catalog, stable executor entry, and representative `csg / gridmap / multimesh` paths after the geometry domain split |
| `filesystem_tool_executor_contracts` | Verify the catalog, stable executor entry, and representative `directory / file_read / file_write / file_manage / json / search` paths after the filesystem domain split, and assert that old root files are deleted |
| `project_tool_executor_contracts` | Verify the catalog, stable executor entry, and representative `info / dotnet / settings / input / autoload` paths after the project domain split, and assert that old root files are deleted |
| `material_tool_executor_contracts` | Verify the catalog, stable executor entry, and representative `material / mesh / parameter` paths after the material domain split, and assert that old root files are deleted |
| `ui_tool_executor_contracts` | Verify the catalog, stable executor entry, and representative `theme / control / layout / focus` paths after the UI domain split, and assert that old root files are deleted |
| `particle_tool_executor_contracts` | Verify the catalog, stable executor entry, and representative `particles / particle_material` paths after the particle domain split, and assert that old root files are deleted |
| `resource_tool_executor_contracts` | Verify the catalog, stable executor entry, and representative `query / create / file_ops / texture` paths after the resource domain split, and assert that old root files are deleted |
| `shader_tool_executor_contracts` | Verify the catalog, stable executor entry, and representative `shader / shader_material` paths after the shader domain split, and assert that old root files are deleted |
| `tilemap_tool_executor_contracts` | Verify the catalog, stable executor entry, and representative `tileset / tilemap` paths after the tilemap domain split, and assert that old root files are deleted |
| `signal_tool_executor_contracts` | Verify the catalog, stable executor entry, and representative `query / connect / emit` paths after the signal domain split, and assert that old root files are deleted |
| `group_tool_executor_contracts` | Verify the catalog, stable executor entry, and representative `query / operation / membership` paths after the group domain split, and assert that old root files are deleted |
| `audio_tool_executor_contracts` | Verify the catalog, stable executor entry, and representative `bus / player` paths after the audio domain split, and assert that old root files are deleted |
| `navigation_tool_executor_contracts` | Verify the catalog, stable executor entry, and representative `map / region / agent` paths after the navigation domain split, and assert that old root files are deleted |
| `plugin_dock_coordinator_contracts` | Verify the high-level Dock create, remove, recreate, Dock signal wiring, Dock instance counting, and `FileDialog` cleanup behavior of `plugin_dock_coordinator.gd` |
| `plugin_runtime_coordinator_contracts` | Verify runtime bridge Autoload, debugger bridge install and uninstall, and root instance detection when no scene tree exists |
| `plugin_self_diagnostic_store_contracts` | Verify slow-operation codes, `phase_timings`, `slowest_phase`, and the slowest phase output in copied diagnostics text |
| Config write/remove contracts | Verify write and remove preflight, transaction, backup, rollback, and result reporting through `config_tab_action_service.gd` and `client_config_service.gd` |
| `client_config_serializer_contracts` | Verify config container keys, config parsing, and confirmation semantics |
| `client_config_inspection_service_contracts` | Verify `inspect / preflight` state classification |
| `client_config_file_transaction_contracts` | Verify merge, remove, backup, and `opencode` blocking writes |
| `client_config_launcher_adapter_contracts` | Verify CLI invocation and Windows command-line wrapping |
| `http_server_contracts` | Verify `mcp_http_server` lifecycle, `tools/list`, `tools/call` structural contracts, and malformed `params` / `arguments` JSON-RPC boundaries |
| `http_request_router_contracts` | Verify path routing, `GET /mcp` 405, default cross-origin denial, explicit CORS allowlist, Host and Content-Type validation, and `404` semantics |
| `http_request_decoder_contracts` | Verify `Content-Length` and chunked body decoding, header retention, waiting states, and trailing data retention |
| `http_response_service_contracts` | Verify JSON-RPC construction, `/health` projection, exact-Origin CORS responses, and JSON cleanup |
| `json_rpc_router_contracts` | Verify `initialize`, notification no-response semantics, and method-not-found behavior |
| `json_rpc_request_service_contracts` | Verify parse errors, request-object validation, non-object `params` rejection, request emission, and router forwarding |
| `mcp_resources_prompts_contracts` | Verify MCP resources/prompts discovery, resource read safety, oversized resource rejection, prompt truncation metadata, and HTTP/stdio error boundaries |
| `editor_lifecycle_action_service_contracts` | Verify confirmation semantics, accepted payload, and scheduling behavior |
| `editor_lifecycle_state_builder_contracts` | Verify default state, scene ordering, and hint projection |
| `system_project_executor_contracts` | Verify the tool exposure, runtime-health aggregation, and project-level routing of `impl_project.gd` as the current project-level system aggregator |
| `system_editor_control_contracts` | Verify the high-level editor UI router that delegates `set_main_screen`, `activate_ui`, `capture_editor`, `list_controls`, `wait_for_ui`, menu, `capture_control`, and `popup` actions to the correct atomic tools |
| `system_settings_dialog_contracts` | Verify the settings-like dialog workflow that opens Project Settings or Editor Settings, waits for visibility, searches candidate rows, focuses results, captures evidence, and closes through the expected atomic tools |
| `system_script_executor_contracts` | Verify `impl_script.gd` as the current script-level system aggregator, and verify that `system_script_analyze` reads Godot LSP diagnostics through the real `tool_loader -> tool_lsp_diagnostics_adapter -> gdscript_lsp_diagnostics_service` path |
| `system_runtime_impl_contracts` | Verify the state, capture annotations, and parameter handling in `impl_runtime.gd` |
| `system_plugin_update_contracts` | Verify current version and status reads, update source selection, ref discovery, and sync routing in `system_plugin_update` |
| `system_index_impl_contracts` | Verify the refresh path from built to `stale_refreshed` in `impl_index.gd` |
| `stdio_tool_activity_contracts` | Verify stdio `tools/call` preserves loader activity summaries and strips top-level `_mcp_context` before concrete tool execution |
| `tool_activity_registry_contracts` | Verify activity registry running/recent/get state transitions, execution order, scope hints, and agent-context sanitization |
| `tool_loader_contracts` | Verify loader initialization and disabled-tool shrinking under the default tool access provider |
| `tool_rpc_router_contracts` | Verify tool list presentation, successful tool calls, missing tool name errors, and non-object `arguments` validation |
| `server_tab_model_projection_contracts` | Verify the status overview, self-diagnostic summary, runtime-state projection, and log and language option model |
| `tool_lsp_diagnostics_adapter_contracts` | Verify configure, tick, reset, release, and runtime bridge binding semantics in `tool_lsp_diagnostics_adapter.gd` |
| `gdscript_lsp_diagnostics_service_contracts` | Verify request replacement, cache hits, clear, and debug snapshot behavior in `gdscript_lsp_diagnostics_service.gd` |
| `lsp_client_contracts` | Verify initialize, `publishDiagnostics` frame parsing, timeout, connection failure, and `cancel / retry / failed-then-restart` recovery |
| `lsp_service_access_contracts` | Verify that `mcp_http_server.gd` and `mcp_stdio_server.gd` only expose the loader-owned GDScript diagnostics service instead of creating or falling back to a singleton themselves |
| `tools_tab_rendering_contracts` | Verify TreeItem rendering, tree interaction, context menu, Dock-local popup coordinate contract, and preview return flow in `tools_tab.gd` |
| `editor_lifecycle_endpoint_contracts` | Verify request parsing and action dispatch in `mcp_editor_lifecycle_endpoint.gd` |
| `plugin_entrypoint_contracts` | Verify the real runtime entry lifecycle of `plugin.gd` during `_enter_tree` and `_exit_tree`, including Autoload, debugger bridge, Dock attach and detach, and server controller assembly; this case runs as an editor probe |

Current measured state:

- suite: pass
- harness `stderr` still includes editor exit noise, but `plugin_entrypoint_contracts` is allowed by the harness in editor probe mode
- `tool_loader_status=ready`
- `category_count=26`
- `tool_count=115`
- `exposed_tool_count=18`

---

## Current Key Implementation Points

### 1. `Program.cs` builds a temporary real environment

The harness does not run directly in the repository directory. Instead it copies the fixture and addon into a temporary stage root, starts Godot there, runs `res://tests/headless_suite_runner.gd`, and records the harness-launched `dotnet build` and the headless Godot PID in `.tmp/godot_plugin_harness/processes/<runId>.json`.

Benefits:

- the test environment stays close to the real assembly path
- the working directory is not polluted directly
- failures can keep the stage root around when `--keep-stage-root` is used
- process cleanup only targets harness-owned temporary processes recorded in the registry

### 2. The suite supports single-case and multi-case runs

`headless_suite_runner.gd` supports case-level start and end logs, single-case filters, multi-case selection, per-case and suite duration output, per-case cleanup hooks, and suite-level final cleanup.

This is useful for debugging hangs, performance problems, and cleanup issues.

### 3. The headless path has a default tool access provider

A bare `MCPHttpServer.new()` on a headless path with no plugin parent creates a default tool access provider so the loader can still load tool directories and expose tool state.

### 4. The first stable testing seams are already in place

The plugin side already includes the HTTP, JSON-RPC, editor lifecycle, runtime fallback, runtime reply, runtime control, user tool, Config workflow, Dock, tool loader, and runtime bridge seams listed above.

That means the headless contract tests no longer depend directly on production underscore method names.

---

## Current Boundary

### 1. The tests no longer depend on private method names, but the seams can still be split further

`http_server_contract_test.gd` and `runtime_bridge_contract_test.gd` now go through public test entry points. That significantly reduces the risk that internal method renames or splits break the tests first.

### 2. The current shape is still a mix of structural contracts and local fakes

That is the real test shape at this stage.

---

## Current Runtime Command

Recommended command:

```powershell
dotnet run --project .\tests\godot_plugin_harness\GodotPluginHarness.csproj -c Release -- --godot-path "<Godot Editor Path>"
```

Common extra options:

- `--keep-stage-root`
- `--cases case_a,case_b`
- `--cleanup-stale-processes`

Current output includes:

- suite success and success-marker detection
- stage root
- result and `duration_ms` for each case
- total suite duration and phase timings
- Godot exit code
- exit cleanup diagnostics
- stderr summary

If a regular headless suite sees `ObjectDB instances leaked at exit` or `resources still in use at exit`, the harness still fails and keeps the compatibility reason `reason=godot_exit_leaks_detected`. It also reports `suiteSuccess`, `successMarkerDetected`, `exitCleanupWarningMarkers`, `exitCleanupWarningPolicy`, `exitCleanupWarningFailure`, `failureClasses`, and `primaryFailureClass`, so exit cleanup warnings stay distinguishable from case-logic failures. The editor probe mode still ignores editor exit noise and marks it with `exitCleanupWarningPolicy=ignored_editor_probe`.

## Conclusion

The plugin headless harness is ready and has already found and helped fix real runtime issues. The current focus is to keep the testing seams and cleanup boundaries stable.
