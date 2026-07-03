extends RefCounted

const HttpServerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_server.gd")
const ProtocolFactsScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const RESTART_CONTRACT_PORT := 39993
const JSON_SCHEMA_2020_12_URI := "https://json-schema.org/draft/2020-12/schema"

var _server


func run_case(_tree: SceneTree) -> Dictionary:
	var shell_source_result := _verify_http_server_shell_has_no_eager_runtime_preloads()
	if not bool(shell_source_result.get("success", false)):
		return shell_source_result

	var ready_timing_result := await _verify_ready_initialize_phase_timing(_tree)
	if not bool(ready_timing_result.get("success", false)):
		return ready_timing_result

	_server = HttpServerScript.new()
	_server.initialize(0, "127.0.0.1", false)
	if _server.get("_service_bundle") != null:
		return _failure("HTTP server initialize should not create the service bundle before runtime work is requested.")

	var stable_failure_result := await _verify_service_bundle_load_failure_is_stable()
	if not bool(stable_failure_result.get("success", false)):
		return stable_failure_result

	var loader_status: Dictionary = _server.get_tool_loader_status()
	if _server.get("_service_bundle") != null:
		return _failure("HTTP server status reads should not create the service bundle before runtime work is requested.")
	var loader_required_keys := ["initialized", "healthy", "status", "tool_count", "exposed_tool_count", "category_count", "tool_load_error_count", "last_summary"]
	if not loader_status.is_empty():
		for key in loader_required_keys:
			if not loader_status.has(key):
				return _failure("Tool loader status is missing key '%s'." % key)
		if str(loader_status.get("status", "")).is_empty():
			return _failure("Tool loader status did not expose a status label.")
	if bool(loader_status.get("initialized", false)):
		return _failure("HTTP server initialize should remain lightweight and not register tools before the first tool request.")
	if int(loader_status.get("tool_count", 0)) != 0:
		return _failure("Lightweight HTTP server initialize should not scan tool definitions.")
	var light_loader_status: Dictionary = _server.peek_light_tool_loader_status()
	if _server.get("_service_bundle") != null:
		return _failure("HTTP server light status reads should not create the service bundle before runtime work is requested.")
	if not light_loader_status.is_empty():
		return _failure("HTTP server light status should remain empty before service bundle creation.")

	var rpc_initialize: Dictionary = await _server.handle_jsonrpc_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 10,
		"method": "initialize",
		"params": {}
	}))
	var rpc_initialize_result = rpc_initialize.get("result", {})
	if not (rpc_initialize_result is Dictionary):
		return _failure("JSON-RPC initialize did not return a result object.")
	if (rpc_initialize_result as Dictionary).has("toolSchemaVersion"):
		return _failure("JSON-RPC initialize should not expose non-standard toolSchemaVersion at the top level.")
	var rpc_initialize_meta = (rpc_initialize_result as Dictionary).get("_meta", {})
	if not (rpc_initialize_meta is Dictionary) or str((rpc_initialize_meta as Dictionary).get("toolSchemaVersion", "")) != ProtocolFactsScript.get_tool_schema_version():
		return _failure("JSON-RPC initialize did not expose the current tool schema version through _meta.")
	loader_status = _server.get_tool_loader_status()
	if bool(loader_status.get("initialized", false)):
		return _failure("JSON-RPC initialize should not register tools before a tool/resource request.")
	if int(loader_status.get("tool_count", 0)) != 0:
		return _failure("JSON-RPC initialize should not scan tool definitions.")

	var rpc_resources_list: Dictionary = await _server.handle_jsonrpc_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 11,
		"method": "resources/list",
		"params": {}
	}))
	if not (rpc_resources_list.get("result", {}) is Dictionary):
		return _failure("JSON-RPC resources/list did not return a result object.")
	loader_status = _server.get_tool_loader_status()
	if bool(loader_status.get("initialized", false)):
		return _failure("JSON-RPC resources/list should not register tools before a tool request.")
	if int(loader_status.get("tool_count", 0)) != 0:
		return _failure("JSON-RPC resources/list should not scan tool definitions.")

	var rpc_prompts_list: Dictionary = await _server.handle_jsonrpc_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 12,
		"method": "prompts/list",
		"params": {}
	}))
	if not (rpc_prompts_list.get("result", {}) is Dictionary):
		return _failure("JSON-RPC prompts/list did not return a result object.")
	loader_status = _server.get_tool_loader_status()
	if bool(loader_status.get("initialized", false)):
		return _failure("JSON-RPC prompts/list should not register tools before a tool request.")
	if int(loader_status.get("tool_count", 0)) != 0:
		return _failure("JSON-RPC prompts/list should not scan tool definitions.")

	var fresh_auto_start_server = HttpServerScript.new()
	fresh_auto_start_server.initialize(0, "127.0.0.1", false)
	var auto_start_summary: Dictionary = fresh_auto_start_server.reinitialize(0, "127.0.0.1", false, [], "auto_start")
	if int(auto_start_summary.get("tool_count", 0)) != 0:
		return _failure("HTTP server auto_start reinitialize should remain lightweight and not scan tools.")
	if fresh_auto_start_server.get("_service_bundle") != null:
		return _failure("HTTP server auto_start reinitialize with no disabled tools should not create the service bundle.")
	loader_status = fresh_auto_start_server.get_tool_loader_status()
	if fresh_auto_start_server.get("_service_bundle") != null:
		return _failure("HTTP server post-auto-start status reads should remain lightweight.")
	if bool(loader_status.get("initialized", false)):
		return _failure("HTTP server auto_start reinitialize should not register tools.")
	fresh_auto_start_server.dispose()
	fresh_auto_start_server.free()

	var disabled_auto_start_server = HttpServerScript.new()
	disabled_auto_start_server.initialize(0, "127.0.0.1", false)
	var disabled_auto_start_summary: Dictionary = disabled_auto_start_server.reinitialize(0, "127.0.0.1", false, [" system_project_state ", "", "system_project_state"], "auto_start")
	if int(disabled_auto_start_summary.get("tool_count", 0)) != 0:
		disabled_auto_start_server.dispose()
		disabled_auto_start_server.free()
		return _failure("HTTP server auto_start reinitialize with disabled tools should remain lightweight and not scan tools.")
	if disabled_auto_start_server.get("_service_bundle") != null:
		disabled_auto_start_server.dispose()
		disabled_auto_start_server.free()
		return _failure("HTTP server auto_start reinitialize with disabled tools should not create the service bundle.")
	var pending_disabled_tools: Array = disabled_auto_start_server.get_disabled_tools()
	if pending_disabled_tools != ["system_project_state"]:
		disabled_auto_start_server.dispose()
		disabled_auto_start_server.free()
		return _failure("HTTP server should preserve normalized pending disabled tools before service bundle creation.")
	if disabled_auto_start_server.get("_service_bundle") != null:
		disabled_auto_start_server.dispose()
		disabled_auto_start_server.free()
		return _failure("Reading pending disabled tools should not create the service bundle.")
	disabled_auto_start_server.build_tools_api_snapshot()
	if disabled_auto_start_server.is_tool_enabled("system_project_state"):
		disabled_auto_start_server.dispose()
		disabled_auto_start_server.free()
		return _failure("HTTP server should apply pending disabled tools when the runtime initializes on demand.")
	disabled_auto_start_server.dispose()
	disabled_auto_start_server.free()

	var tools_list: Dictionary = _server.build_tools_api_snapshot()
	loader_status = _server.get_tool_loader_status()
	if not bool(loader_status.get("initialized", false)):
		return _failure("Tools API access should initialize the tool loader on demand.")
	if int(loader_status.get("tool_count", 0)) <= 0:
		return _failure("Tool loader did not report any visible tools after on-demand setup.")
	if int(loader_status.get("exposed_tool_count", 0)) <= 0:
		return _failure("Tool loader did not report any exposed tools after on-demand setup.")
	if not bool(loader_status.get("healthy", false)):
		return _failure("Tool loader should be healthy when the default tool access provider is active.")
	light_loader_status = _server.peek_light_tool_loader_status()
	if light_loader_status.has("last_summary"):
		return _failure("HTTP server light status should not include the heavy last_summary payload.")
	if int(light_loader_status.get("tool_count", 0)) != int(loader_status.get("tool_count", -1)):
		return _failure("HTTP server light status should preserve scalar tool counts.")
	if float(_server.get_performance_summary().get("preload_ms", 1.0)) != 0.0:
		return _failure("On-demand tool registration should not preload every executor runtime during startup.")
	var lsp_service = _server.get_gdscript_lsp_diagnostics_service()
	var loader = _server.get_tool_loader()
	if lsp_service == null:
		return _failure("HTTP server should expose the loader-owned GDScript LSP diagnostics service.")
	if loader == null or lsp_service != loader.get_gdscript_lsp_diagnostics_service():
		return _failure("HTTP server should expose the same diagnostics service instance owned by the tool loader.")

	var invalid_json: Dictionary = _server.handle_editor_lifecycle_post(JSON.stringify([]))
	if str(invalid_json.get("error", "")) != "invalid_argument":
		return _failure("Editor lifecycle POST did not reject a non-object JSON body.")

	var missing_action: Dictionary = _server.handle_editor_lifecycle_post(JSON.stringify({}))
	if str(missing_action.get("error", "")) != "invalid_argument":
		return _failure("Editor lifecycle POST did not require an action field.")

	var unknown_action: Dictionary = _server.handle_editor_lifecycle_request("bogus", {})
	if str(unknown_action.get("error", "")) != "invalid_argument":
		return _failure("Editor lifecycle request did not reject an unknown action.")
	var unknown_data = unknown_action.get("data", {})
	if not (unknown_data is Dictionary) or str((unknown_data as Dictionary).get("hint", "")).find("status|close|restart") == -1:
		return _failure("Unknown lifecycle action response is missing a recovery hint.")

	var close_confirmation: Dictionary = _server.handle_editor_lifecycle_request("close", {})
	if str(close_confirmation.get("error", "")) != "editor_confirmation_required":
		return _failure("Lifecycle close did not require save=true confirmation.")

	var required_keys := ["tools", "domain_states", "tool_count", "exposed_tool_count", "tool_loader_status", "performance", "toolTree", "toolGroups"]
	for key in required_keys:
		if not tools_list.has(key):
			return _failure("Tools list response is missing key '%s'." % key)
	if not (tools_list.get("tools", []) is Array):
		return _failure("Tools list response did not return tools as an array.")
	if not (tools_list.get("tool_loader_status", {}) is Dictionary):
		return _failure("Tools list response did not return a tool_loader_status dictionary.")
	if (tools_list.get("tools", []) as Array).is_empty():
		return _failure("Tools list response did not return any exposed tools.")
	if not (tools_list.get("toolTree", []) is Array) or (tools_list.get("toolTree", []) as Array).is_empty():
		return _failure("Tools list response did not expose the unified tool tree.")
	if not _first_tool_has_group_path(tools_list.get("tools", [])):
		return _failure("Tools list response did not enrich flat tools with groupPath metadata.")
	for removed_tool_name in ["system_help", "system_plugin_reload", "system_plugin_update", "system_editor_log", "system_tool_catalog", "system_tool_activity", "system_scene_validate", "system_scene_analyze", "resource_manage", "debug_log"]:
		if _contains_tool_name_recursive(tools_list, removed_tool_name):
			return _failure("Tools list response should not expose removed tool %s." % removed_tool_name)

	var full_reload_summary: Dictionary = _server.reinitialize(0, "127.0.0.1", false, [], "tool_full_reload")
	if int(full_reload_summary.get("tool_count", 0)) <= 0:
		return _failure("HTTP server full reload reinitialize did not report visible tools.")
	var full_reload_tools_list: Dictionary = _server.build_tools_api_snapshot()
	for removed_tool_name in ["system_help", "system_plugin_reload", "system_plugin_update", "system_editor_log", "system_tool_catalog", "system_tool_activity", "system_scene_validate", "system_scene_analyze", "resource_manage", "debug_log"]:
		if _contains_tool_name_recursive(full_reload_tools_list, removed_tool_name):
			return _failure("HTTP server full reload should not expose removed tool %s." % removed_tool_name)

	_server.reinitialize(RESTART_CONTRACT_PORT, "127.0.0.1", false, [], "contract_restart")
	if not bool(_server.start()):
		return _failure("HTTP server should start on the fixed restart contract port.")
	_server.stop()
	if not bool(_server.start()):
		return _failure("HTTP server should restart on the same fixed port immediately after stop().")
	_server.stop()
	_server.reinitialize(0, "127.0.0.1", false, [], "contract_restore_ephemeral_port")

	var rpc_tools_list: Dictionary = await _server.handle_jsonrpc_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 1,
		"method": "tools/list",
		"params": {}
	}))
	var rpc_tools_list_result = rpc_tools_list.get("result", {})
	if not (rpc_tools_list_result is Dictionary):
		return _failure("JSON-RPC tools/list did not return a result object.")
	var rpc_tools = (rpc_tools_list_result as Dictionary).get("tools", [])
	if not (rpc_tools is Array):
		return _failure("JSON-RPC tools/list did not return tools as an array.")
	if (rpc_tools as Array).is_empty():
		return _failure("JSON-RPC tools/list did not return any exposed tools.")
	for presentation_key in ["presentationVersion", "toolTree", "toolGroups"]:
		if (rpc_tools_list_result as Dictionary).has(presentation_key):
			return _failure("JSON-RPC tools/list should not expose presentation key %s." % presentation_key)
	if _has_tool(rpc_tools, "system_help"):
		return _failure("JSON-RPC tools/list should not expose removed system_help.")
	for removed_tool_name in ["system_help", "system_plugin_reload", "system_plugin_update", "system_editor_log", "system_tool_catalog", "system_tool_activity", "system_scene_validate", "system_scene_analyze", "resource_manage", "debug_log"]:
		if _contains_tool_name_recursive(rpc_tools_list_result, removed_tool_name):
			return _failure("JSON-RPC tools/list should not expose removed public tool %s." % removed_tool_name)
	for tool_entry in rpc_tools:
		if not (tool_entry is Dictionary):
			continue
		if (tool_entry as Dictionary).has("groupPath") or (tool_entry as Dictionary).has("treeChildren"):
			return _failure("JSON-RPC tools/list should not expose presentation metadata on flat tool entries.")
		for internal_key in ["category", "domainKey", "loadState", "source", "enabled"]:
			if (tool_entry as Dictionary).has(internal_key):
				return _failure("JSON-RPC tools/list should not expose internal metadata key: %s" % internal_key)
		if not _has_json_schema_2020_12(tool_entry, "inputSchema"):
			return _failure("JSON-RPC tools/list should advertise JSON Schema 2020-12 on inputSchema.")
		if not _has_json_schema_2020_12(tool_entry, "outputSchema"):
			return _failure("JSON-RPC tools/list should advertise JSON Schema 2020-12 on outputSchema.")

	var rpc_missing_tool: Dictionary = await _server.handle_jsonrpc_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 2,
		"method": "tools/call",
		"params": {}
	}))
	var rpc_missing_tool_error: Dictionary = rpc_missing_tool.get("error", {})
	if int(rpc_missing_tool_error.get("code", 0)) != -32602:
		return _failure("JSON-RPC tools/call should reject missing tool names with -32602.")
	if str(rpc_missing_tool_error.get("message", "")).find("requires a non-empty string name") == -1:
		return _failure("JSON-RPC tools/call missing-name response should describe the invalid request shape.")

	var rpc_invalid_params: Dictionary = await _server.handle_jsonrpc_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 3,
		"method": "tools/call",
		"params": []
	}))
	if int((rpc_invalid_params.get("error", {}) as Dictionary).get("code", 0)) != -32602:
		return _failure("JSON-RPC tools/call should reject non-object params with -32602.")

	var rpc_removed_help: Dictionary = await _server.handle_jsonrpc_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 31,
		"method": "tools/call",
		"params": {
			"name": "system_help",
			"arguments": {}
		}
	}))
	var rpc_removed_help_result = rpc_removed_help.get("result", {})
	if not (rpc_removed_help_result is Dictionary) or not bool((rpc_removed_help_result as Dictionary).get("isError", false)):
		return _failure("JSON-RPC tools/call should return an error result for removed system_help legacy calls.")
	var rpc_removed_help_payload := _tool_result_payload(rpc_removed_help_result as Dictionary)
	if str(rpc_removed_help_payload.get("error", "")).find("system_help") == -1:
		return _failure("JSON-RPC system_help removal response should include the removed tool name.")
	var rpc_removed_help_data = rpc_removed_help_payload.get("data", {})
	if not (rpc_removed_help_data is Dictionary) or not (((rpc_removed_help_data as Dictionary).get("replacement_resources", []) as Array).has("godot-dotnet-mcp://guides/index")):
		return _failure("JSON-RPC system_help removal response should include replacement guide resource URIs.")

	var rpc_invalid_arguments: Dictionary = await _server.handle_jsonrpc_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 4,
		"method": "tools/call",
		"params": {
			"name": "system_help",
			"arguments": []
		}
	}))
	var rpc_invalid_arguments_error: Dictionary = rpc_invalid_arguments.get("error", {})
	if int(rpc_invalid_arguments_error.get("code", 0)) != -32602:
		return _failure("JSON-RPC tools/call should reject non-object arguments with -32602.")
	if str(rpc_invalid_arguments_error.get("message", "")).find("arguments must be an object") == -1:
		return _failure("JSON-RPC tools/call non-object arguments should describe the invalid request shape.")

	var rpc_removed_resource_manage: Dictionary = await _server.handle_jsonrpc_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 34,
		"method": "tools/call",
		"params": {
			"name": "resource_manage",
			"arguments": {"action": "create", "type": "Resource", "path": "res://Tmp/removed_resource_manage.tres"}
		}
	}))
	var rpc_removed_resource_manage_result = rpc_removed_resource_manage.get("result", {})
	if not (rpc_removed_resource_manage_result is Dictionary) or not bool((rpc_removed_resource_manage_result as Dictionary).get("isError", false)):
		return _failure("JSON-RPC tools/call should reject removed resource_manage legacy calls.")
	var rpc_removed_resource_manage_payload := _tool_result_payload(rpc_removed_resource_manage_result as Dictionary)
	if bool(rpc_removed_resource_manage_payload.get("success", true)):
		return _failure("Removed resource_manage should return a failing text JSON payload.")
	if str(rpc_removed_resource_manage_payload.get("error", "")).find("resource_manage") == -1:
		return _failure("Removed resource_manage error should include the legacy tool name.")
	if not _is_removed_resource_manage_tool(rpc_removed_resource_manage_payload, "resource_create"):
		return _failure("Removed resource_manage should expose removed_public_tool guidance and resource_create replacement.")
	for resource_file_action in ["delete", "reload"]:
		var rpc_removed_resource_file: Dictionary = await _server.handle_jsonrpc_request_async(JSON.stringify({
			"jsonrpc": "2.0",
			"id": 340,
			"method": "tools/call",
			"params": {
				"name": "resource_manage",
				"arguments": {"action": resource_file_action, "path": "res://Tmp/removed_resource_manage.tres"}
			}
		}))
		var rpc_removed_resource_file_result = rpc_removed_resource_file.get("result", {})
		if not (rpc_removed_resource_file_result is Dictionary) or not bool((rpc_removed_resource_file_result as Dictionary).get("isError", false)):
			return _failure("JSON-RPC tools/call should reject removed resource_manage %s legacy calls." % resource_file_action)
		var rpc_removed_resource_file_payload := _tool_result_payload(rpc_removed_resource_file_result as Dictionary)
		if not _is_removed_resource_manage_tool(rpc_removed_resource_file_payload, "resource_file_ops"):
			return _failure("Removed resource_manage %s should expose resource_file_ops replacement." % resource_file_action)
		var rpc_removed_resource_file_arguments := _first_replacement_arguments(rpc_removed_resource_file_payload.get("data", {}))
		if str(rpc_removed_resource_file_arguments.get("action", "")) != resource_file_action:
			return _failure("Removed resource_manage %s should preserve replacement action." % resource_file_action)
		if str(rpc_removed_resource_file_arguments.get("source", "")) != "res://Tmp/removed_resource_manage.tres":
			return _failure("Removed resource_manage %s should map path to resource_file_ops source." % resource_file_action)
		if rpc_removed_resource_file_arguments.has("path"):
			return _failure("Removed resource_manage %s should not emit schema-invalid path argument." % resource_file_action)

	var rpc_removed_debug_log: Dictionary = await _server.handle_jsonrpc_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 35,
		"method": "tools/call",
		"params": {
			"name": "debug_log",
			"arguments": {"action": "print", "message": "removed debug_log"}
		}
	}))
	var rpc_removed_debug_log_result = rpc_removed_debug_log.get("result", {})
	if not (rpc_removed_debug_log_result is Dictionary) or not bool((rpc_removed_debug_log_result as Dictionary).get("isError", false)):
		return _failure("JSON-RPC tools/call should reject removed debug_log legacy calls.")
	var rpc_removed_debug_log_payload := _tool_result_payload(rpc_removed_debug_log_result as Dictionary)
	if bool(rpc_removed_debug_log_payload.get("success", true)):
		return _failure("Removed debug_log should return a failing text JSON payload.")
	if str(rpc_removed_debug_log_payload.get("error", "")).find("debug_log") == -1:
		return _failure("Removed debug_log error should include the legacy tool name.")

	var rpc_removed_catalog: Dictionary = await _server.handle_jsonrpc_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 32,
		"method": "tools/call",
		"params": {
			"name": "system_tool_catalog",
			"arguments": {"query": "runtime"}
		}
	}))
	var rpc_removed_catalog_result = rpc_removed_catalog.get("result", {})
	if not (rpc_removed_catalog_result is Dictionary) or not bool((rpc_removed_catalog_result as Dictionary).get("isError", false)):
		return _failure("JSON-RPC tools/call should reject removed system_tool_catalog with isError=true.")
	var rpc_removed_catalog_payload := _tool_result_payload(rpc_removed_catalog_result as Dictionary)
	if bool(rpc_removed_catalog_payload.get("success", true)):
		return _failure("Removed system_tool_catalog should return a failing text JSON payload.")
	var rpc_removed_catalog_data = rpc_removed_catalog_payload.get("data", {})
	if not (rpc_removed_catalog_data is Dictionary) or str((rpc_removed_catalog_data as Dictionary).get("error_type", "")) != "removed_public_tool":
		return _failure("Removed system_tool_catalog payload should expose error_type=removed_public_tool.")
	if not (((rpc_removed_catalog_data as Dictionary).get("replacement_resources", []) as Array).has("godot-dotnet-mcp://tools/catalog/visible")):
		return _failure("Removed system_tool_catalog should point callers to catalog resources.")

	var rpc_removed_activity: Dictionary = await _server.handle_jsonrpc_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 5,
		"method": "tools/call",
		"params": {
			"name": "system_tool_activity",
			"arguments": {"action": "status"}
		}
	}))
	var rpc_removed_activity_result = rpc_removed_activity.get("result", {})
	if not (rpc_removed_activity_result is Dictionary) or not bool((rpc_removed_activity_result as Dictionary).get("isError", false)):
		return _failure("JSON-RPC tools/call should return isError=true for removed system_tool_activity.")
	var rpc_removed_activity_payload := _tool_result_payload(rpc_removed_activity_result as Dictionary)
	if bool(rpc_removed_activity_payload.get("success", true)):
		return _failure("JSON-RPC removed system_tool_activity should expose a failing text JSON payload.")
	var rpc_removed_activity_data = rpc_removed_activity_payload.get("data", {})
	if not (rpc_removed_activity_data is Dictionary) or str((rpc_removed_activity_data as Dictionary).get("error_type", "")) != "removed_public_tool":
		return _failure("JSON-RPC removed system_tool_activity should expose removed_public_tool guidance.")
	if not (((rpc_removed_activity_data as Dictionary).get("replacement_resources", []) as Array).has("godot-dotnet-mcp://activity/status")):
		return _failure("JSON-RPC removed system_tool_activity should point to activity/status.")
	for removed_plugin_case in [
		{"tool": "system_plugin_reload", "arguments": {"action": "full_reload_plugin"}, "replacement_action": "reload"},
		{"tool": "system_plugin_update", "arguments": {"action": "get_current"}, "replacement_action": "status"},
		{"tool": "system_plugin_update", "arguments": {"action": "start_sync"}, "replacement_action": "start_update"},
		{"tool": "system_plugin_update", "arguments": {"action": "discover_refs", "force_refresh": false}, "replacement_action": "refresh_update_refs"}
	]:
		var rpc_removed_plugin: Dictionary = await _server.handle_jsonrpc_request_async(JSON.stringify({
			"jsonrpc": "2.0",
			"id": 7,
			"method": "tools/call",
			"params": {
				"name": str(removed_plugin_case.get("tool", "")),
				"arguments": removed_plugin_case.get("arguments", {})
			}
		}))
		var rpc_removed_plugin_result = rpc_removed_plugin.get("result", {})
		if not (rpc_removed_plugin_result is Dictionary) or not bool((rpc_removed_plugin_result as Dictionary).get("isError", false)):
			return _failure("JSON-RPC tools/call should return isError=true for removed %s." % str(removed_plugin_case.get("tool", "")))
		var rpc_removed_plugin_payload := _tool_result_payload(rpc_removed_plugin_result as Dictionary)
		if not _is_removed_plugin_maintenance_tool(rpc_removed_plugin_payload, str(removed_plugin_case.get("tool", "")), str(removed_plugin_case.get("replacement_action", ""))):
			return _failure("JSON-RPC removed %s should point to system_plugin_maintenance." % str(removed_plugin_case.get("tool", "")))
		if str(removed_plugin_case.get("replacement_action", "")) == "refresh_update_refs":
			var rpc_removed_plugin_data = rpc_removed_plugin_payload.get("data", {})
			var replacement_args := _first_replacement_arguments(rpc_removed_plugin_data)
			if bool(replacement_args.get("force_refresh", true)):
				return _failure("JSON-RPC removed system_plugin_update discover_refs should preserve force_refresh=false.")
	for removed_scene_case in [
		{"tool": "system_scene_validate", "action": "validate"},
		{"tool": "system_scene_analyze", "action": "analyze"}
	]:
		var rpc_removed_scene: Dictionary = await _server.handle_jsonrpc_request_async(JSON.stringify({
			"jsonrpc": "2.0",
			"id": 6,
			"method": "tools/call",
			"params": {
				"name": str(removed_scene_case.get("tool", "")),
				"arguments": {"scene": "res://Main.tscn"}
			}
		}))
		var rpc_removed_scene_result = rpc_removed_scene.get("result", {})
		if not (rpc_removed_scene_result is Dictionary) or not bool((rpc_removed_scene_result as Dictionary).get("isError", false)):
			return _failure("JSON-RPC tools/call should return isError=true for removed %s." % str(removed_scene_case.get("tool", "")))
		var rpc_removed_scene_payload := _tool_result_payload(rpc_removed_scene_result as Dictionary)
		if not _is_removed_scene_tool(rpc_removed_scene_payload, str(removed_scene_case.get("tool", "")), str(removed_scene_case.get("action", ""))):
			return _failure("JSON-RPC removed %s should point to system_scene_inspect." % str(removed_scene_case.get("tool", "")))

	return {
		"name": "http_server_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_loader_status": loader_status.duplicate(true),
			"lifecycle_unknown_error": str(unknown_action.get("error", "")),
			"tools_list_keys": required_keys,
			"rpc_tools_count": (rpc_tools as Array).size()
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	if _server == null:
		return
	if _server.has_method("stop"):
		_server.stop()
	if _server.has_method("dispose"):
		_server.dispose()
	_server.free()
	_server = null
	await tree.process_frame
	await tree.process_frame


func _failure(message: String) -> Dictionary:
	return {
		"name": "http_server_contracts",
		"success": false,
		"error": message
	}


func _verify_http_server_shell_has_no_eager_runtime_preloads() -> Dictionary:
	var source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_server.gd")
	if source.is_empty():
		return _failure("HTTP server source should be readable for startup preload guard.")
	for forbidden in [
		"preload(\"res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_service_bundle.gd\")",
		"preload(\"res://addons/godot_dotnet_mcp/tools/core/tool_loader.gd\")",
		"-> MCPToolLoader"
	]:
		if source.find(forbidden) != -1:
			return _failure("HTTP server shell should not eagerly reference runtime dependency: %s" % forbidden)
	if source.find("SERVICE_BUNDLE_SCRIPT_PATH") == -1:
		return _failure("HTTP server shell should retain an explicit lazy service bundle path.")
	return {"success": true, "error": ""}


func _verify_service_bundle_load_failure_is_stable() -> Dictionary:
	var failure_server = HttpServerScript.new()
	failure_server.initialize(0, "127.0.0.1", false)
	failure_server.set("_service_bundle_script_path", "res://tests/invalid_http_service_bundle_stub.gd")

	var lifecycle_response: Dictionary = failure_server.handle_editor_lifecycle_request("status", {})
	if str(lifecycle_response.get("error", "")) != "service_unavailable":
		failure_server.dispose()
		failure_server.free()
		return _failure("Missing service bundle should return a stable lifecycle service_unavailable error.")

	var rpc_response: Dictionary = await failure_server.handle_jsonrpc_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 991,
		"method": "initialize",
		"params": {}
	}))
	failure_server.dispose()
	failure_server.free()

	var rpc_error = rpc_response.get("error", {})
	if not (rpc_error is Dictionary):
		return _failure("Missing service bundle should return a JSON-RPC error envelope.")
	if int((rpc_error as Dictionary).get("code", 0)) != -32603:
		return _failure("Missing service bundle should report JSON-RPC -32603 instead of falling through to Nil calls.")
	if rpc_response.get("id", null) != 991:
		return _failure("Missing service bundle JSON-RPC error should preserve request id.")
	return {"success": true, "error": ""}


func _has_json_schema_2020_12(tool_entry, key: String) -> bool:
	if not (tool_entry is Dictionary):
		return false
	var schema = (tool_entry as Dictionary).get(key, {})
	return schema is Dictionary and str((schema as Dictionary).get("$schema", "")) == JSON_SCHEMA_2020_12_URI


func _has_tool(tools, tool_name: String) -> bool:
	if not (tools is Array):
		return false
	for tool_def in tools:
		if tool_def is Dictionary and str((tool_def as Dictionary).get("name", "")) == tool_name:
			return true
	return false


func _contains_tool_name_recursive(value, tool_name: String) -> bool:
	if value is String:
		return str(value) == tool_name
	if value is Array:
		for item in value:
			if _contains_tool_name_recursive(item, tool_name):
				return true
		return false
	if value is Dictionary:
		var dict := value as Dictionary
		for key in ["name", "fullName", "full_name"]:
			if str(dict.get(key, "")) == tool_name:
				return true
		for nested in dict.values():
			if _contains_tool_name_recursive(nested, tool_name):
				return true
	return false


func _tool_result_payload(result: Dictionary) -> Dictionary:
	var structured = result.get("structuredContent", null)
	if structured is Dictionary:
		return structured as Dictionary
	var content = result.get("content", [])
	if not (content is Array) or (content as Array).is_empty():
		return {}
	var first = (content as Array)[0]
	if not (first is Dictionary):
		return {}
	var parsed = JSON.parse_string(str((first as Dictionary).get("text", "")))
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _is_removed_scene_tool(structured, removed_tool: String, replacement_action: String) -> bool:
	if not (structured is Dictionary) or bool((structured as Dictionary).get("success", true)):
		return false
	var data = (structured as Dictionary).get("data", {})
	if not (data is Dictionary):
		return false
	var data_dict := data as Dictionary
	if str(data_dict.get("error_type", "")) != "removed_public_tool":
		return false
	if str(data_dict.get("removed_tool", "")) != removed_tool:
		return false
	if not ((data_dict.get("replacement_resources", []) as Array).has("godot-dotnet-mcp://scene/{path}")):
		return false
	var replacement_tools = data_dict.get("replacement_tools", [])
	if not (replacement_tools is Array) or (replacement_tools as Array).is_empty():
		return false
	var replacement = (replacement_tools as Array)[0]
	if not (replacement is Dictionary):
		return false
	var replacement_arguments = (replacement as Dictionary).get("arguments", {})
	return str((replacement as Dictionary).get("name", "")) == "system_scene_inspect" and replacement_arguments is Dictionary and str((replacement_arguments as Dictionary).get("action", "")) == replacement_action


func _is_removed_plugin_maintenance_tool(structured, removed_tool: String, replacement_action: String) -> bool:
	if not (structured is Dictionary) or bool((structured as Dictionary).get("success", true)):
		return false
	var data = (structured as Dictionary).get("data", {})
	if not (data is Dictionary):
		return false
	var data_dict := data as Dictionary
	if str(data_dict.get("error_type", "")) != "removed_public_tool":
		return false
	if str(data_dict.get("removed_tool", "")) != removed_tool:
		return false
	var replacement_tools = data_dict.get("replacement_tools", [])
	if not (replacement_tools is Array) or (replacement_tools as Array).is_empty():
		return false
	var replacement = (replacement_tools as Array)[0]
	if not (replacement is Dictionary):
		return false
	var replacement_arguments = (replacement as Dictionary).get("arguments", {})
	return str((replacement as Dictionary).get("name", "")) == "system_plugin_maintenance" and replacement_arguments is Dictionary and str((replacement_arguments as Dictionary).get("action", "")) == replacement_action


func _is_removed_resource_manage_tool(structured, expected_replacement_tool: String) -> bool:
	if not (structured is Dictionary) or bool((structured as Dictionary).get("success", true)):
		return false
	var data = (structured as Dictionary).get("data", {})
	if not (data is Dictionary):
		return false
	var data_dict := data as Dictionary
	if str(data_dict.get("error_type", "")) != "removed_public_tool":
		return false
	if str(data_dict.get("removed_tool", "")) != "resource_manage":
		return false
	if not ((data_dict.get("replacement_methods", []) as Array).has("tools/call")):
		return false
	if not ((data_dict.get("replacement_resources", []) as Array).has("godot-dotnet-mcp://tools/catalog/visible")):
		return false
	var replacement_tools = data_dict.get("replacement_tools", [])
	if not (replacement_tools is Array) or (replacement_tools as Array).is_empty():
		return false
	var replacement = (replacement_tools as Array)[0]
	return replacement is Dictionary and str((replacement as Dictionary).get("name", "")) == expected_replacement_tool


func _first_replacement_arguments(data) -> Dictionary:
	if not (data is Dictionary):
		return {}
	var replacement_tools = (data as Dictionary).get("replacement_tools", [])
	if not (replacement_tools is Array) or (replacement_tools as Array).is_empty():
		return {}
	var replacement = (replacement_tools as Array)[0]
	if not (replacement is Dictionary):
		return {}
	var replacement_arguments = (replacement as Dictionary).get("arguments", {})
	if replacement_arguments is Dictionary:
		return replacement_arguments
	return {}


func _verify_ready_initialize_phase_timing(tree: SceneTree) -> Dictionary:
	PluginSelfDiagnosticStore.clear()
	var ready_server = HttpServerScript.new()
	tree.root.add_child(ready_server)
	await tree.process_frame

	var operation = PluginSelfDiagnosticStore.begin_operation("server_start", "contract_ready_initialize")
	var operation_id := str(operation.get("operation_id", ""))
	ready_server.initialize(0, "127.0.0.1", false, operation_id)
	var finished = PluginSelfDiagnosticStore.end_operation(operation_id, true)

	ready_server.dispose()
	ready_server.queue_free()
	await tree.process_frame
	PluginSelfDiagnosticStore.clear()

	var phase_timings = finished.get("phase_timings", [])
	if not (phase_timings is Array):
		return _failure("Ready/initialize diagnostic operation did not expose phase timings.")
	if _has_phase(phase_timings as Array, "tool_loader.register_tools"):
		return _failure("Ready/initialize should not register tools before the first tool request.")
	if not _has_phase(phase_timings as Array, "http_server.create_tcp_server"):
		return _failure("Ready/initialize diagnostic operation should retain lightweight TCP server creation timing.")
	return {"success": true, "error": ""}


func _has_phase(phase_timings: Array, phase_name: String) -> bool:
	for timing in phase_timings:
		if timing is Dictionary and str((timing as Dictionary).get("phase", "")) == phase_name:
			return true
	return false


func _first_tool_has_group_path(tools) -> bool:
	if not (tools is Array) or (tools as Array).is_empty():
		return false
	var first_tool = (tools as Array)[0]
	return first_tool is Dictionary and (first_tool as Dictionary).has("groupPath")
