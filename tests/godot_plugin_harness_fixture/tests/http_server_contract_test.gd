extends RefCounted

const HttpServerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_server.gd")
const ProtocolFactsScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const RESTART_CONTRACT_PORT := 39993

var _server


func run_case(_tree: SceneTree) -> Dictionary:
	var ready_timing_result := await _verify_ready_initialize_phase_timing(_tree)
	if not bool(ready_timing_result.get("success", false)):
		return ready_timing_result

	_server = HttpServerScript.new()
	_server.initialize(0, "127.0.0.1", false)

	var loader_status: Dictionary = _server.get_tool_loader_status()
	var loader_required_keys := ["initialized", "healthy", "status", "tool_count", "exposed_tool_count", "category_count", "tool_load_error_count", "last_summary"]
	for key in loader_required_keys:
		if not loader_status.has(key):
			return _failure("Tool loader status is missing key '%s'." % key)
	if str(loader_status.get("status", "")).is_empty():
		return _failure("Tool loader status did not expose a status label.")
	if not bool(loader_status.get("initialized", false)):
		return _failure("Tool loader did not initialize during http server setup.")
	if int(loader_status.get("tool_count", 0)) <= 0:
		return _failure("Tool loader did not report any visible tools.")
	if int(loader_status.get("exposed_tool_count", 0)) <= 0:
		return _failure("Tool loader did not report any exposed tools.")
	if not bool(loader_status.get("healthy", false)):
		return _failure("Tool loader should be healthy when the default tool access provider is active.")
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

	var tools_list: Dictionary = _server.build_tools_api_snapshot()
	var expected_schema_version := ProtocolFactsScript.get_tool_schema_version()
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
	for removed_tool_name in ["system_help", "system_plugin_reload", "system_plugin_update", "system_editor_log", "system_tool_catalog", "system_tool_activity", "system_scene_validate", "system_scene_analyze"]:
		if _contains_tool_name_recursive(tools_list, removed_tool_name):
			return _failure("Tools list response should not expose removed public tool %s." % removed_tool_name)

	var rpc_initialize: Dictionary = await _server.handle_jsonrpc_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 10,
		"method": "initialize",
		"params": {}
	}))
	var rpc_initialize_result = rpc_initialize.get("result", {})
	if not (rpc_initialize_result is Dictionary):
		return _failure("JSON-RPC initialize did not return a result object.")
	if str((rpc_initialize_result as Dictionary).get("toolSchemaVersion", "")) != expected_schema_version:
		return _failure("JSON-RPC initialize did not expose the current tool schema version.")

	var full_reload_summary: Dictionary = _server.reinitialize(0, "127.0.0.1", false, [], "tool_full_reload")
	if int(full_reload_summary.get("tool_count", 0)) <= 0:
		return _failure("HTTP server full reload reinitialize did not report visible tools.")
	var full_reload_tools_list: Dictionary = _server.build_tools_api_snapshot()
	for removed_tool_name in ["system_help", "system_plugin_reload", "system_plugin_update", "system_editor_log", "system_tool_catalog", "system_tool_activity", "system_scene_validate", "system_scene_analyze"]:
		if _contains_tool_name_recursive(full_reload_tools_list, removed_tool_name):
			return _failure("HTTP server full reload should not expose removed public tool %s." % removed_tool_name)

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
	for removed_tool_name in ["system_help", "system_plugin_reload", "system_plugin_update", "system_editor_log", "system_tool_catalog", "system_tool_activity", "system_scene_validate", "system_scene_analyze"]:
		if _contains_tool_name_recursive(rpc_tools_list_result, removed_tool_name):
			return _failure("JSON-RPC tools/list should not expose removed public tool %s." % removed_tool_name)
	for tool_entry in rpc_tools:
		if not (tool_entry is Dictionary):
			continue
		if (tool_entry as Dictionary).has("groupPath") or (tool_entry as Dictionary).has("treeChildren"):
			return _failure("JSON-RPC tools/list should not expose presentation metadata on flat tool entries.")

	var rpc_missing_tool: Dictionary = await _server.handle_jsonrpc_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 2,
		"method": "tools/call",
		"params": {}
	}))
	var rpc_missing_tool_result = rpc_missing_tool.get("result", {})
	if not (rpc_missing_tool_result is Dictionary):
		return _failure("JSON-RPC tools/call did not return a result object for invalid input.")
	if not bool((rpc_missing_tool_result as Dictionary).get("isError", false)):
		return _failure("JSON-RPC tools/call should return isError=true when the tool name is missing.")
	var rpc_missing_tool_structured = (rpc_missing_tool_result as Dictionary).get("structuredContent", {})
	if not (rpc_missing_tool_structured is Dictionary) or bool((rpc_missing_tool_structured as Dictionary).get("success", true)):
		return _failure("JSON-RPC tools/call missing-name response should expose failing structuredContent.")
	var rpc_content = (rpc_missing_tool_result as Dictionary).get("content", [])
	if not (rpc_content is Array) or (rpc_content as Array).is_empty():
		return _failure("JSON-RPC tools/call error result did not include text content.")
	var rpc_error_text := str(((rpc_content as Array)[0] as Dictionary).get("text", ""))
	if rpc_error_text.find("Missing tool name") == -1:
		return _failure("JSON-RPC tools/call missing-name response did not preserve the router error text.")
	var rpc_missing_tool_payload = JSON.parse_string(rpc_error_text)
	if not (rpc_missing_tool_payload is Dictionary):
		return _failure("JSON-RPC tools/call missing-name text content should remain parseable JSON.")
	if str((rpc_missing_tool_structured as Dictionary).get("error", "")) != str((rpc_missing_tool_payload as Dictionary).get("error", "")):
		return _failure("JSON-RPC tools/call missing-name structuredContent should match the compatibility text JSON error.")

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
	var rpc_removed_help_structured = (rpc_removed_help_result as Dictionary).get("structuredContent", {})
	if not (rpc_removed_help_structured is Dictionary) or str((rpc_removed_help_structured as Dictionary).get("error", "")).find("system_help") == -1:
		return _failure("JSON-RPC system_help removal response should include the removed tool name.")
	var rpc_removed_help_data = (rpc_removed_help_structured as Dictionary).get("data", {})
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
	var rpc_invalid_arguments_result = rpc_invalid_arguments.get("result", {})
	if not (rpc_invalid_arguments_result is Dictionary) or not bool((rpc_invalid_arguments_result as Dictionary).get("isError", false)):
		return _failure("JSON-RPC tools/call should return isError=true for non-object arguments.")
	var rpc_invalid_arguments_structured = (rpc_invalid_arguments_result as Dictionary).get("structuredContent", {})
	if not (rpc_invalid_arguments_structured is Dictionary) or bool((rpc_invalid_arguments_structured as Dictionary).get("success", true)):
		return _failure("JSON-RPC tools/call non-object arguments should expose failing structuredContent.")
	var rpc_invalid_arguments_content = (rpc_invalid_arguments_result as Dictionary).get("content", [])
	if not (rpc_invalid_arguments_content is Array) or (rpc_invalid_arguments_content as Array).is_empty():
		return _failure("JSON-RPC tools/call non-object arguments should include text content.")
	var rpc_invalid_arguments_text := str(((rpc_invalid_arguments_content as Array)[0] as Dictionary).get("text", ""))
	if rpc_invalid_arguments_text.find("Tool arguments must be an object") == -1:
		return _failure("JSON-RPC tools/call non-object arguments should preserve the router error text.")

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
	var rpc_removed_catalog_structured = (rpc_removed_catalog_result as Dictionary).get("structuredContent", {})
	if not (rpc_removed_catalog_structured is Dictionary) or bool((rpc_removed_catalog_structured as Dictionary).get("success", true)):
		return _failure("Removed system_tool_catalog should return failing structuredContent.")
	var rpc_removed_catalog_data = (rpc_removed_catalog_structured as Dictionary).get("data", {})
	if not (rpc_removed_catalog_data is Dictionary) or str((rpc_removed_catalog_data as Dictionary).get("error_type", "")) != "removed_public_tool":
		return _failure("Removed system_tool_catalog structuredContent should expose error_type=removed_public_tool.")
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
	var rpc_removed_activity_structured = (rpc_removed_activity_result as Dictionary).get("structuredContent", {})
	if not (rpc_removed_activity_structured is Dictionary) or bool((rpc_removed_activity_structured as Dictionary).get("success", true)):
		return _failure("JSON-RPC removed system_tool_activity should expose failing structuredContent.")
	var rpc_removed_activity_data = (rpc_removed_activity_structured as Dictionary).get("data", {})
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
		var rpc_removed_plugin_structured = (rpc_removed_plugin_result as Dictionary).get("structuredContent", {})
		if not _is_removed_plugin_maintenance_tool(rpc_removed_plugin_structured, str(removed_plugin_case.get("tool", "")), str(removed_plugin_case.get("replacement_action", ""))):
			return _failure("JSON-RPC removed %s should point to system_plugin_maintenance." % str(removed_plugin_case.get("tool", "")))
		if str(removed_plugin_case.get("replacement_action", "")) == "refresh_update_refs":
			var rpc_removed_plugin_data = (rpc_removed_plugin_structured as Dictionary).get("data", {})
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
		var rpc_removed_scene_structured = (rpc_removed_scene_result as Dictionary).get("structuredContent", {})
		if not _is_removed_scene_tool(rpc_removed_scene_structured, str(removed_scene_case.get("tool", "")), str(removed_scene_case.get("action", ""))):
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
	if not _has_phase(phase_timings as Array, "tool_loader.register_tools"):
		return _failure("Ready/initialize diagnostic operation should retain first tool loader registration timing.")
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
