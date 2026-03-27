extends RefCounted

const JsonRpcRouterScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_json_rpc_router.gd")
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
	router.configure({
		"handle_initialize": Callable(callbacks, "handle_initialize"),
		"handle_tools_list": Callable(callbacks, "handle_tools_list"),
		"handle_tools_call_async": Callable(callbacks, "handle_tools_call_async"),
		"handle_notification": Callable(callbacks, "handle_notification"),
		"build_json_rpc_response": Callable(callbacks, "build_json_rpc_response"),
		"build_json_rpc_error": Callable(callbacks, "build_json_rpc_error"),
		"log": Callable(callbacks, "log")
	})

	var initialize_response: Dictionary = await router.route_request_async("initialize", {}, 1, true)
	var initialize_result = initialize_response.get("result", {})
	if not (initialize_result is Dictionary) or str((initialize_result as Dictionary).get("protocolVersion", "")) != MCPProtocolFacts.get_protocol_version():
		return _failure("JSON-RPC router did not dispatch initialize requests.")
	if str((initialize_result as Dictionary).get("toolSchemaVersion", "")) != MCPProtocolFacts.get_tool_schema_version():
		return _failure("JSON-RPC router did not preserve the unified tool schema version.")
	var server_info = (initialize_result as Dictionary).get("serverInfo", {})
	if not (server_info is Dictionary) or str((server_info as Dictionary).get("name", "")) != MCPProtocolFacts.get_server_name():
		return _failure("JSON-RPC router did not preserve the unified server info payload.")

	var ping_response: Dictionary = await router.route_request_async("ping", {}, 2, true)
	if not ping_response.has("result"):
		return _failure("JSON-RPC router did not return an empty result for ping.")

	var notification_response: Dictionary = await router.route_request_async("notifications/initialized", {}, null, false)
	if int(notification_response.get("status", 0)) != 202 or not bool(notification_response.get("_no_body", false)):
		return _failure("JSON-RPC router did not suppress responses for notifications.")
	if callbacks.notifications.is_empty() or callbacks.notifications[0] != "notifications/initialized":
		return _failure("JSON-RPC router did not forward notifications to the notification handler.")

	var missing_response: Dictionary = await router.route_request_async("missing/method", {}, 3, true)
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
			"missing_method_code": int((missing_error as Dictionary).get("code", 0))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "json_rpc_router_contracts",
		"success": false,
		"error": message
	}
