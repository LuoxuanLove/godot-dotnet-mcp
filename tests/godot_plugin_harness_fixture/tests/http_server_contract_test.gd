extends RefCounted

const HttpServerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_server.gd")

var _server


func run_case(_tree: SceneTree) -> Dictionary:
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
		return _failure("Tool loader should be healthy when the default permission provider is active.")

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
	var required_keys := ["tools", "domain_states", "tool_count", "exposed_tool_count", "tool_loader_status", "performance"]
	for key in required_keys:
		if not tools_list.has(key):
			return _failure("Tools list response is missing key '%s'." % key)
	if not (tools_list.get("tools", []) is Array):
		return _failure("Tools list response did not return tools as an array.")
	if not (tools_list.get("tool_loader_status", {}) is Dictionary):
		return _failure("Tools list response did not return a tool_loader_status dictionary.")
	if (tools_list.get("tools", []) as Array).is_empty():
		return _failure("Tools list response did not return any exposed tools.")

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
	var rpc_content = (rpc_missing_tool_result as Dictionary).get("content", [])
	if not (rpc_content is Array) or (rpc_content as Array).is_empty():
		return _failure("JSON-RPC tools/call error result did not include text content.")
	var rpc_error_text := str(((rpc_content as Array)[0] as Dictionary).get("text", ""))
	if rpc_error_text.find("Missing tool name") == -1:
		return _failure("JSON-RPC tools/call missing-name response did not preserve the router error text.")

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
