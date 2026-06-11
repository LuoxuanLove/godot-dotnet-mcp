extends RefCounted

const JsonRpcRouterScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_json_rpc_router.gd")
const JsonRpcRouterContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_json_rpc_router_context.gd")
const MCPProtocolFacts = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd")


class FakeCallbacks:
	extends RefCounted

	var notifications: Array[String] = []

	func handle_initialize(_params: Dictionary, id) -> Dictionary:
		return {
			"jsonrpc": "2.0",
			"result": {
				"idEcho": id,
				"protocolVersion": MCPProtocolFacts.get_protocol_version(),
				"toolSchemaVersion": MCPProtocolFacts.get_tool_schema_version(),
				"serverInfo": MCPProtocolFacts.build_server_info()
			},
			"id": id
		}

	func handle_tools_list(_params: Dictionary, id) -> Dictionary:
		return {
			"jsonrpc": "2.0",
			"result": {
				"tools": [{"name": "system_project_state"}]
			},
			"id": id
		}

	func handle_tools_call_async(params: Dictionary, id) -> Dictionary:
		return {
			"jsonrpc": "2.0",
			"result": {
				"content": [{
					"type": "text",
					"text": str(params.get("name", ""))
				}],
				"isError": false
			},
			"id": id
		}

	func handle_resources_list(_params: Dictionary, id) -> Dictionary:
		return {
			"jsonrpc": "2.0",
			"result": {
				"resources": [{"uri": "godot-dotnet-mcp://server/capabilities", "name": "Server capabilities"}]
			},
			"id": id
		}

	func handle_resources_templates_list(_params: Dictionary, id) -> Dictionary:
		return {
			"jsonrpc": "2.0",
			"result": {
				"resourceTemplates": [{"uriTemplate": "godot-dotnet-mcp://scene/{path}", "name": "Scene read"}]
			},
			"id": id
		}

	func handle_resources_read(params: Dictionary, id) -> Dictionary:
		return {
			"jsonrpc": "2.0",
			"result": {
				"contents": [{"uri": str(params.get("uri", "")), "mimeType": "text/plain", "text": "resource"}]
			},
			"id": id
		}

	func handle_prompts_list(_params: Dictionary, id) -> Dictionary:
		return {
			"jsonrpc": "2.0",
			"result": {
				"prompts": [{"name": "godot.content_authoring", "description": "Plan content work from grounded project, scene, or script evidence before editing."}]
			},
			"id": id
		}

	func handle_prompts_get(params: Dictionary, id) -> Dictionary:
		return {
			"jsonrpc": "2.0",
			"result": {
				"description": str(params.get("name", "")),
				"messages": [{"role": "user", "content": {"type": "text", "text": "prompt"}}]
			},
			"id": id
		}

	func handle_notification(method: String, _params: Dictionary) -> void:
		notifications.append(method)

	func build_json_rpc_response(result, id) -> Dictionary:
		return {
			"jsonrpc": "2.0",
			"result": result,
			"id": id
		}

	func build_json_rpc_error(code: int, message: String, id) -> Dictionary:
		return {
			"jsonrpc": "2.0",
			"error": {
				"code": code,
				"message": message
			},
			"id": id
		}

	func log(_message: String, _level: String) -> void:
		pass


func run_case(_tree: SceneTree) -> Dictionary:
	var router = JsonRpcRouterScript.new()
	var callbacks = FakeCallbacks.new()
	var context = JsonRpcRouterContextScript.new()
	context.handle_initialize = Callable(callbacks, "handle_initialize")
	context.handle_tools_list = Callable(callbacks, "handle_tools_list")
	context.handle_tools_call_async = Callable(callbacks, "handle_tools_call_async")
	context.handle_resources_list = Callable(callbacks, "handle_resources_list")
	context.handle_resources_templates_list = Callable(callbacks, "handle_resources_templates_list")
	context.handle_resources_read = Callable(callbacks, "handle_resources_read")
	context.handle_prompts_list = Callable(callbacks, "handle_prompts_list")
	context.handle_prompts_get = Callable(callbacks, "handle_prompts_get")
	context.handle_notification = Callable(callbacks, "handle_notification")
	context.build_json_rpc_response = Callable(callbacks, "build_json_rpc_response")
	context.build_json_rpc_error = Callable(callbacks, "build_json_rpc_error")
	context.log = Callable(callbacks, "log")
	router.configure(context)

	var initialize_response: Dictionary = await router.route_request_async("initialize", {}, 1, true)
	var initialize_result = initialize_response.get("result", {})
	if not (initialize_result is Dictionary) or str((initialize_result as Dictionary).get("protocolVersion", "")) != MCPProtocolFacts.get_protocol_version():
		return _failure("JSON-RPC router did not dispatch initialize requests.")
	if str((initialize_result as Dictionary).get("protocolVersion", "")) != "2025-11-25":
		return _failure("JSON-RPC router initialize should advertise MCP 2025-11-25.")
	if str((initialize_result as Dictionary).get("toolSchemaVersion", "")) != MCPProtocolFacts.get_tool_schema_version():
		return _failure("JSON-RPC router did not preserve the unified tool schema version.")
	var server_info = (initialize_result as Dictionary).get("serverInfo", {})
	if not (server_info is Dictionary) or str((server_info as Dictionary).get("name", "")) != MCPProtocolFacts.get_server_name():
		return _failure("JSON-RPC router did not preserve the unified server info payload.")
	if str((server_info as Dictionary).get("description", "")) != MCPProtocolFacts.get_server_description():
		return _failure("JSON-RPC router initialize should expose serverInfo.description.")

	var ping_response: Dictionary = await router.route_request_async("ping", {}, 2, true)
	if not ping_response.has("result"):
		return _failure("JSON-RPC router did not return an empty result for ping.")

	var notification_response: Dictionary = await router.route_request_async("notifications/initialized", {}, null, false)
	if int(notification_response.get("status", 0)) != 202 or not bool(notification_response.get("_no_body", false)):
		return _failure("JSON-RPC router did not suppress responses for notifications.")
	if callbacks.notifications.is_empty() or callbacks.notifications[0] != "notifications/initialized":
		return _failure("JSON-RPC router did not forward notifications to the notification handler.")

	var resources_list_response: Dictionary = await router.route_request_async("resources/list", {}, 3, true)
	var resources_list_result = resources_list_response.get("result", {})
	if not (resources_list_result is Dictionary) or not ((resources_list_result as Dictionary).get("resources", []) is Array):
		return _failure("JSON-RPC router did not dispatch resources/list requests.")

	var resources_templates_response: Dictionary = await router.route_request_async("resources/templates/list", {}, 4, true)
	var resources_templates_result = resources_templates_response.get("result", {})
	if not (resources_templates_result is Dictionary) or not ((resources_templates_result as Dictionary).get("resourceTemplates", []) is Array):
		return _failure("JSON-RPC router did not dispatch resources/templates/list requests.")

	var resources_read_response: Dictionary = await router.route_request_async("resources/read", {"uri": "godot-dotnet-mcp://server/capabilities"}, 4, true)
	var resources_read_result = resources_read_response.get("result", {})
	if not (resources_read_result is Dictionary) or not ((resources_read_result as Dictionary).get("contents", []) is Array):
		return _failure("JSON-RPC router did not dispatch resources/read requests.")

	var prompts_list_response: Dictionary = await router.route_request_async("prompts/list", {}, 5, true)
	var prompts_list_result = prompts_list_response.get("result", {})
	if not (prompts_list_result is Dictionary) or not ((prompts_list_result as Dictionary).get("prompts", []) is Array):
		return _failure("JSON-RPC router did not dispatch prompts/list requests.")

	var prompts_get_response: Dictionary = await router.route_request_async("prompts/get", {"name": "godot.content_authoring"}, 6, true)
	var prompts_get_result = prompts_get_response.get("result", {})
	if not (prompts_get_result is Dictionary) or not ((prompts_get_result as Dictionary).get("messages", []) is Array):
		return _failure("JSON-RPC router did not dispatch prompts/get requests.")

	var missing_response: Dictionary = await router.route_request_async("missing/method", {}, 7, true)
	var missing_error = missing_response.get("error", {})
	if not (missing_error is Dictionary) or int((missing_error as Dictionary).get("code", 0)) != -32601:
		return _failure("JSON-RPC router did not preserve the method-not-found error contract.")

	return {
		"name": "json_rpc_router_contracts",
		"success": true,
		"error": "",
		"details": {
			"notification_count": callbacks.notifications.size(),
			"initialize_id": int(initialize_response.get("id", -1)),
			"resource_count": ((resources_list_result as Dictionary).get("resources", []) as Array).size(),
			"prompt_count": ((prompts_list_result as Dictionary).get("prompts", []) as Array).size(),
			"missing_method_code": int((missing_error as Dictionary).get("code", 0))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "json_rpc_router_contracts",
		"success": false,
		"error": message
	}
