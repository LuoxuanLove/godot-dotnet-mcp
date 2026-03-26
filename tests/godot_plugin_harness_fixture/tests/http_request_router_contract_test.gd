extends RefCounted

const HttpRequestRouterScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_request_router.gd")


class FakeCallbacks:
	extends RefCounted

	var last_mcp_body := ""
	var last_lifecycle_action := ""
	var last_lifecycle_args: Dictionary = {}

	func handle_mcp_request_async(body: String) -> Dictionary:
		last_mcp_body = body
		return {
			"status": 200,
			"echo": body
		}

	func build_health_response() -> Dictionary:
		return {
			"status": "ok",
			"tool_count": 2
		}

	func build_tools_list_response() -> Dictionary:
		return {
			"tools": [{"name": "system_project_state"}]
		}

	func handle_editor_lifecycle_request(action: String, args: Dictionary) -> Dictionary:
		last_lifecycle_action = action
		last_lifecycle_args = args.duplicate(true)
		return {
			"success": true,
			"action": action
		}

	func handle_editor_lifecycle_post_request(body: String) -> Dictionary:
		return {
			"success": true,
			"body": body
		}

	func build_cors_response() -> Dictionary:
		return {
			"status": 204,
			"cors": true
		}


func run_case(_tree: SceneTree) -> Dictionary:
	var router = HttpRequestRouterScript.new()
	var callbacks = FakeCallbacks.new()
	router.configure({
		"handle_mcp_request_async": Callable(callbacks, "handle_mcp_request_async"),
		"build_health_response": Callable(callbacks, "build_health_response"),
		"build_tools_list_response": Callable(callbacks, "build_tools_list_response"),
		"handle_editor_lifecycle_request": Callable(callbacks, "handle_editor_lifecycle_request"),
		"handle_editor_lifecycle_post_request": Callable(callbacks, "handle_editor_lifecycle_post_request"),
		"build_cors_response": Callable(callbacks, "build_cors_response")
	})

	var mcp_response: Dictionary = await router.route_request_async("POST", "/mcp", "{\"jsonrpc\":\"2.0\"}")
	if str(mcp_response.get("echo", "")) != "{\"jsonrpc\":\"2.0\"}":
		return _failure("HTTP request router did not forward POST /mcp to the MCP request handler.")

	var get_mcp_response: Dictionary = await router.route_request_async("GET", "/mcp", "")
	if int(get_mcp_response.get("status", 0)) != 405 or not bool(get_mcp_response.get("_no_body", false)):
		return _failure("HTTP request router did not preserve the GET /mcp 405 semantics.")

	var health_response: Dictionary = await router.route_request_async("GET", "/health", "")
	if str(health_response.get("status", "")) != "ok":
		return _failure("HTTP request router did not route GET /health.")

	var lifecycle_response: Dictionary = await router.route_request_async("GET", "/api/editor/lifecycle", "")
	if str(lifecycle_response.get("action", "")) != "status":
		return _failure("HTTP request router did not route lifecycle status requests.")

	var options_response: Dictionary = await router.route_request_async("OPTIONS", "/mcp", "")
	if int(options_response.get("status", 0)) != 204 or not bool(options_response.get("cors", false)):
		return _failure("HTTP request router did not route OPTIONS requests to the CORS responder.")

	var not_found_response: Dictionary = await router.route_request_async("GET", "/missing", "")
	if int(not_found_response.get("status", 0)) != 404:
		return _failure("HTTP request router did not return 404 for an unknown path.")

	return {
		"name": "http_request_router_contracts",
		"success": true,
		"error": "",
		"details": {
			"last_mcp_body_length": callbacks.last_mcp_body.length(),
			"lifecycle_action": callbacks.last_lifecycle_action,
			"not_found_status": int(not_found_response.get("status", 0))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "http_request_router_contracts",
		"success": false,
		"error": message
	}
