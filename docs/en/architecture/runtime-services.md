# Runtime Services

This document explains how `plugin/runtime/`, `plugin/config/`, and the tool loader work together, and how requests flow from the HTTP entry point into a concrete executor.

---

## Service Layers

The current runtime is roughly split into four layers:

```text
EditorPlugin assembly layer
  ├─ plugin.gd
  ├─ plugin/plugin_dock_coordinator.gd
  ├─ plugin/plugin_runtime_coordinator.gd
  └─ plugin/plugin_action_router.gd

State and config layer
  ├─ plugin/runtime/plugin_runtime_state.gd
  ├─ plugin/config/settings_store.gd
  └─ plugin/config/client_config_service.gd

Presentation and Dock model layer
  ├─ plugin/presenters/dock_model_service.gd
  ├─ plugin/presenters/dock_presenter.gd
  └─ plugin/presenters/client_config_presenter.gd

Service and diagnostics layer
  ├─ plugin/runtime/server_runtime_controller.gd
  ├─ plugin/runtime/mcp_http_server.gd
  ├─ plugin/runtime/mcp_http_connection_state.gd
  ├─ plugin/runtime/mcp_http_request_decoder.gd
  ├─ plugin/runtime/mcp_protocol_facts.gd
  ├─ plugin/runtime/mcp_tool_loader_supervisor.gd
  ├─ plugin/runtime/mcp_tool_rpc_router.gd
  ├─ plugin/runtime/mcp_resources_service.gd
  ├─ plugin/runtime/mcp_prompts_service.gd
  ├─ plugin/runtime/mcp_editor_lifecycle_endpoint.gd
  ├─ plugin/runtime/mcp_tools_api_service.gd
  ├─ plugin/runtime/tool_presentation_service.gd
  ├─ plugin/runtime/mcp_stdio_server.gd
  ├─ tools/shared/gdscript_lsp_diagnostics_service.gd
  ├─ plugin/runtime/plugin_reload_coordinator.gd
  ├─ plugin/runtime/mcp_runtime_bridge.gd (Autoload, main-project runtime event channel)
  ├─ plugin/runtime/mcp_runtime_command_service.gd
  ├─ plugin/runtime/mcp_runtime_reply_service.gd
  ├─ plugin/runtime/mcp_runtime_fallback_store.gd
  ├─ plugin/runtime/mcp_editor_debugger_bridge.gd
  ├─ plugin/runtime/runtime_control_service.gd
  ├─ plugin/runtime/mcp_runtime_control_session_selector.gd
  ├─ plugin/runtime/mcp_runtime_control_error_mapper.gd
  ├─ plugin/runtime/mcp_runtime_control_reply_resolver.gd
  ├─ tools/shared/mcp_runtime_debug_store.gd
  └─ plugin/runtime/plugin_self_diagnostic_store.gd

Tool loading and execution layer
  ├─ tools/core/tool_loader.gd
  ├─ tools/core/tool_lsp_diagnostics_adapter.gd
  ├─ tools/tool_manifest.gd
  ├─ tools/tool_registry.gd
  ├─ tools/<category>/executor.gd
  └─ tools/*_tools.gd (only the remaining legacy domains and shared root-level scripts)
```

---

## State and Config Layer

### `plugin_runtime_state.gd`

This object is now a lightweight runtime state container. It mainly stores:

- the current settings dictionary
- the current custom profile cache
- UI state fields such as CLI scope, Config platform, and tab state
- mutable runtime fields only, not schema, profile directories, or persistence details

It no longer owns the static contract for the profile catalog or settings schema.

### `plugin_runtime_state_service.gd`

Responsible for:

- initializing settings from `PluginRuntimeState.build_default_settings()`
- orchestrating runtime state load and save
- loading custom profiles
- normalizing `current_cli_scope`, `current_config_platform`, `needs_initial_tool_profile_apply`, and other state fields
- separating bootstrap and persistence details from `plugin.gd`

### `plugin_runtime_coordinator.gd`

Responsible for:

- stop, configure, and start orchestration for `user_tool_watch_service.gd`
- wiring the user tool watcher refresh callback into the explicit callback on `plugin_action_router.gd`
- installing, projecting, and diagnosing stale instances for the runtime bridge Autoload
- the install and uninstall lifecycle of `MCPEditorDebuggerBridge`

### `plugin_dock_coordinator.gd`

Responsible for:

- Dock scene creation, mounting, and destruction
- stale Dock cleanup and duplicate instance detection
- `FileDialog` node creation and cleanup, plus callback wiring
- central Dock signal wiring

It keeps `plugin.gd` from directly owning the full Dock lifecycle.

### `plugin_action_router.gd`

Responsible for:

- mapping Dock, Config, Server, and User Tool UI events into the correct feature entry points
- acting as the forwarding layer for `plugin.gd`, including show-message and confirmation flows, Dock refresh, and all action handlers
- providing an explicit callback entry for `user_tool_watch_service.gd`
- collecting user tool catalog refresh and runtime reload helpers into one collaborator

### `mcp_http_connection_state.gd`

Responsible for:

- connection arrays, pending data, processing state, and request statistics
- moving the transport bookkeeping that used to live inside `mcp_http_server.gd` into a separate helper
- giving `mcp_http_server.gd` a stable state boundary

### `mcp_http_request_decoder.gd`

Responsible for:

- `Content-Length` body decoding
- chunked body decoding
- trailing data retention
- waiting-state return values for incomplete headers, body, or chunked body

It keeps `mcp_http_server.gd` from carrying HTTP body parsing details directly.

### `tool_profile_catalog.gd`

Responsible for:

- builtin tool profiles
- custom profile storage directory

### `settings_store.gd`

Responsible for:

- reading and saving plugin settings
- reading and saving custom profiles
- renaming and deleting profiles
- importing and exporting tool configuration JSON

Current persistence boundary:

- `user://godot_dotnet_mcp/settings.json`
- `user://godot_dotnet_mcp/profiles/*.json`
- any user-specified import or export JSON path

---

## Service and Diagnostics Layer

### `server_runtime_controller.gd`

This is the proxy layer between `plugin.gd` and `MCPHttpServer`. It is responsible for:

- creating and mounting the server node
- rebuilding the controller and server node during `soft_reload_plugin`
- starting, stopping, and restarting the server
- syncing settings and the disabled tool list to the server
- emitting `server_started`, `server_stopped`, and `request_received` back to the entry point
- recording phase timings during startup or reload so slow operations can be diagnosed later

It exists so `plugin.gd` no longer needs to deal with TCP server details directly.

### `mcp_http_server.gd`

This is the embedded HTTP and MCP service node. It is responsible for:

- listening on the TCP port
- receiving HTTP requests
- parsing JSON-RPC and MCP request bodies
- delegating path routing to `mcp_http_request_router.gd`
- delegating JSON-RPC method routing to `mcp_json_rpc_router.gd`
- reading `protocolVersion`, `toolSchemaVersion`, and `serverInfo` from `mcp_protocol_facts.gd`
- delegating `/health`, JSON-RPC responses, HTTP response writing, and JSON sanitization to `mcp_http_response_service.gd`
- delegating editor lifecycle close and restart confirmation and deferred execution to `mcp_editor_lifecycle_action_service.gd`
- delegating editor lifecycle state snapshot building to `mcp_editor_lifecycle_state_builder.gd`
- delegating `tools/list`, `tools/call`, tool name resolution, and result normalization to `mcp_tool_rpc_router.gd`
- delegating `resources/list`, `resources/templates/list`, and `resources/read` to `mcp_resources_service.gd`
- delegating `prompts/list` and `prompts/get` to `mcp_prompts_service.gd`
- tracking connection count, request count, and latest request method and time
- delegating tool loader lifecycle, self-healing, and status summaries to `mcp_tool_loader_supervisor.gd`
- delegating editor lifecycle request parsing and action dispatch to `mcp_editor_lifecycle_endpoint.gd`
- delegating `/api/tools` snapshot building to `mcp_tools_api_service.gd`
- recording timing for service bundle, tool loader registration and performance, and TCP listen during reinitialize and start
- bridging tool access state directly to `tool_loader.gd` through `get_tool_access_provider()`
- holding `runtime_control_service.gd` so `system_runtime_*` has an editor-side runtime command coordination entry point

### `mcp_resources_service.gd` and `mcp_prompts_service.gd`

These two services provide native MCP Resources and Prompts surfaces without going through the tool execution path:

- `mcp_resources_service.gd` exposes three JSON resources, project info, diagnostics summary, and tool catalog, and reads project files through the `scene/{path}`, `script/{path}`, and `resource/{path}` templates.
- `mcp_prompts_service.gd` exposes six prompts, `godot.project_orientation`, `godot.content_authoring`, `godot.debug_triage`, `godot.reference_integrity`, `godot.runtime_validation`, and `godot.editor_ui_control`, so the MCP client can start from consistent guidance for project orientation, content authoring, diagnostics triage, reference integrity fixes, runtime validation, and editor UI actions. Each prompt only returns MCP `messages` and does not execute tools.
- `system_help` returns a `prompt_guides` summary so the client can discover the prompts through `prompts/list` and then fetch the parameterized workflow text with `prompts/get`.
- The HTTP JSON-RPC path uses `mcp_json_rpc_method_service.gd` to call these services, and the stdio path uses the same service so both transports return the same structure.

### `mcp_tool_loader_supervisor.gd`

Responsible for:

- owning the current `MCPToolLoader`
- tool loader initialize, rebuild, and recovery
- disabled tool synchronization
- loader health classification
- loader summary and status views
- bringing the tool loader performance summary back into the registration summary so `mcp_http_server.gd` can record phase-level diagnostic timing
- narrowing `mcp_http_server.gd` so it no longer mixes protocol handling with loader lifecycle

### `mcp_tool_rpc_router.gd`

Responsible for:

- `tools/list`
- `tools/call`
- tool name resolution
- tool result normalization
- narrowing `mcp_http_server.gd` so it no longer mixes top-level method dispatch with tool-call semantics

### `mcp_editor_lifecycle_endpoint.gd`

Responsible for:

- parsing the `POST` body of `/api/editor/lifecycle`
- validating the `action` field
- dispatching `status`, `close`, and `restart`
- providing a stable structural boundary for the editor lifecycle bridge

It currently serves two cases:

- lifecycle request handling inside `mcp_http_server.gd`
- stable contract checks for editor lifecycle structure in plugin headless tests

### `mcp_tools_api_service.gd`

Responsible for:

- building the `/api/tools` snapshot
- collecting `tools`
- collecting `domain_states`
- collecting `tool_loader_status`
- collecting the performance summary

It separates HTTP top-level routing from tool snapshot assembly.

### `tool_presentation_service.gd`

Responsible for:

- building a unified Tool Presentation Model from the public tools, visible category tools, domain state, and disabled tools
- generating `toolTree`, `toolGroups`, `toolMetadataByName`, and `presentationVersion`
- giving `/api/tools`, MCP `tools/list`, stdio `tools/list`, and the Dock Tools page the same domain, category, high-level tool, atomic, and action structure
- adding non-breaking display metadata like `groupPath` and `treeChildren` while keeping the flat `tools[]` contract

### `mcp_http_request_router.gd`

Responsible for:

- `POST /mcp`
- `GET /health`
- `GET /api/tools`
- `GET /api/editor/lifecycle`
- `POST /api/editor/lifecycle`
- allowlist-controlled `OPTIONS` CORS preflight

It separates TCP and HTTP transport from path-level request dispatch.

### `mcp_json_rpc_router.gd`

Responsible for:

- `initialize`
- `tools/list`
- `tools/call`
- `ping`
- notifications with no response
- method-not-found error modeling

It separates MCP request body parsing from JSON-RPC method-level dispatch.

### `mcp_http_response_service.gd`

Responsible for:

- JSON-RPC success and error response building
- `/health` snapshot assembly
- unified projection of `server_name`, `server_version`, `protocol_version`, and `tool_schema_version`
- exact-Origin CORS preflight responses
- HTTP response writing
- JSON serialization cleanup

It separates transport logic from response formatting and health projection.

The HTTP service no longer blindly adds `Access-Control-Allow-Origin: *` to all responses. `mcp_http_transport_service.gd` passes decoded headers into the router, and `mcp_http_request_router.gd` first validates Host, Origin, and POST `Content-Type`: local CLI and desktop clients without `Origin` continue to use direct loopback access; the default Host allows loopback and also allows the currently listened host so explicit non-default local or LAN addresses keep working; browser requests with `Origin` must exactly match the allowlist in `GODOT_DOTNET_MCP_ALLOWED_CORS_ORIGINS`, and only then will the same Origin be echoed back with `Vary: Origin`. Any cross-origin request that is not explicitly allowed returns `403`, and a non-CORS `OPTIONS` request returns `405` with the matching `Allow` header.

### `mcp_editor_lifecycle_action_service.gd`

Responsible for:

- the confirmation semantics for editor lifecycle `close` and `restart`
- building the accepted payload
- deferred shutdown and finalization execution
- coordinating the save-scene pre-action with deferred shutdown and finalization

It separates lifecycle request acceptance from lifecycle action execution.

### `mcp_editor_lifecycle_state_builder.gd`

Responsible for:

- building the editor lifecycle state snapshot
- projecting `openScenes`, `dirtyScenes`, and `currentScenePath`
- assembling lifecycle hints

It separates lifecycle route and action acceptance from editor state snapshot gathering.

### `mcp_stdio_server.gd`

This is the stdio transport that shares the same `MCPToolLoader` with the HTTP server. It is responsible for:

- reading stdin and writing stdout through `Content-Length` frames
- reusing the same tool definitions, disabled tools, and visible tool set
- sharing the same protocol and version facts with the HTTP transport through `mcp_protocol_facts.gd`
- working in parallel with the HTTP transport when `transport_mode = stdio / both`

### `mcp_protocol_facts.gd`

Responsible for:

- reading the single protocol source of truth from `mcp_protocol_facts.json`
- providing `protocol_version`
- providing `tool_schema_version`
- providing `server_name`
- providing `server_version`
- providing the canonical error code dictionary

It brings the plugin HTTP and stdio transport protocol and version fields into one formal source of truth instead of hardcoded constants.

### `gdscript_lsp_diagnostics_service.gd`

This is the background scheduling layer for GDScript LSP diagnostics. It is responsible for...
