extends RefCounted

const HttpRequestRouterScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_request_router.gd")
const HttpRequestRouterContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_request_router_context.gd")


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

	func build_cors_response(origin: String = "", allow_methods: String = "GET, POST", allow_headers: String = "Content-Type, Accept, MCP-Protocol-Version, Mcp-Session-Id") -> Dictionary:
		return {
			"_status_code": 204,
			"_no_body": true,
			"_headers": {
				"Access-Control-Allow-Origin": origin,
				"Access-Control-Allow-Methods": allow_methods,
				"Access-Control-Allow-Headers": allow_headers,
				"Vary": "Origin"
			}
		}


func run_case(_tree: SceneTree) -> Dictionary:
	var router = HttpRequestRouterScript.new()
	var callbacks = FakeCallbacks.new()
	var context = HttpRequestRouterContextScript.new()
	context.handle_mcp_request_async = Callable(callbacks, "handle_mcp_request_async")
	context.build_health_response = Callable(callbacks, "build_health_response")
	context.build_tools_list_response = Callable(callbacks, "build_tools_list_response")
	context.handle_editor_lifecycle_request = Callable(callbacks, "handle_editor_lifecycle_request")
	context.handle_editor_lifecycle_post_request = Callable(callbacks, "handle_editor_lifecycle_post_request")
	context.build_cors_response = Callable(callbacks, "build_cors_response")
	router.configure(context)
	router.set_allowed_cors_origins(["http://localhost:5173"])
	router.set_allowed_hosts(["10.0.0.8"])

	var mcp_response: Dictionary = await router.route_request_async(
		"POST",
		"/mcp",
		"{\"jsonrpc\":\"2.0\"}",
		{"host": "localhost:3000", "accept": "application/json, text/event-stream", "mcp-protocol-version": "2025-11-25"}
	)
	if str(mcp_response.get("echo", "")) != "{\"jsonrpc\":\"2.0\"}":
		return _failure("HTTP request router did not forward POST /mcp to the MCP request handler.")
	var mcp_headers: Dictionary = mcp_response.get("_headers", {})
	if str(mcp_headers.get("MCP-Protocol-Version", "")) != "2025-11-25":
		return _failure("HTTP request router did not attach the MCP protocol version response header.")
	if str(mcp_headers.get("Mcp-Session-Id", "")).is_empty():
		return _failure("HTTP request router did not attach a streamable HTTP session id.")
	var generated_session_id := str(mcp_headers.get("Mcp-Session-Id", ""))

	var repeated_generated_session_response: Dictionary = await router.route_request_async(
		"POST",
		"/mcp",
		"{}",
		{"host": "localhost:3000", "accept": "application/json"}
	)
	var repeated_generated_session_headers: Dictionary = repeated_generated_session_response.get("_headers", {})
	if str(repeated_generated_session_headers.get("Mcp-Session-Id", "")) != generated_session_id:
		return _failure("HTTP request router should keep generated MCP session ids stable per router instance.")

	var second_router = HttpRequestRouterScript.new()
	second_router.configure(context)
	var second_router_response: Dictionary = await second_router.route_request_async(
		"POST",
		"/mcp",
		"{}",
		{"host": "localhost:3000", "accept": "application/json"}
	)
	var second_router_headers: Dictionary = second_router_response.get("_headers", {})
	if str(second_router_headers.get("Mcp-Session-Id", "")) == generated_session_id:
		return _failure("HTTP request router should not reuse one fixed generated MCP session id across router instances.")

	var existing_session_response: Dictionary = await router.route_request_async(
		"POST",
		"/mcp",
		"{}",
		{"host": "localhost:3000", "accept": "application/json", "mcp-session-id": "client-session-7"}
	)
	var existing_session_headers: Dictionary = existing_session_response.get("_headers", {})
	if str(existing_session_headers.get("Mcp-Session-Id", "")) != "client-session-7":
		return _failure("HTTP request router should echo an existing MCP session id.")

	var accept_denied_response: Dictionary = await router.route_request_async(
		"POST",
		"/mcp",
		"{}",
		{"host": "localhost:3000", "accept": "text/event-stream"}
	)
	if int(accept_denied_response.get("status", 0)) != 406:
		return _failure("HTTP request router should reject POST /mcp when Accept omits application/json.")
	var accept_denied_headers: Dictionary = accept_denied_response.get("_headers", {})
	if str(accept_denied_headers.get("MCP-Protocol-Version", "")) != "2025-11-25":
		return _failure("HTTP request router should attach protocol headers to MCP transport guard failures.")

	var version_denied_response: Dictionary = await router.route_request_async(
		"POST",
		"/mcp",
		"{}",
		{"host": "localhost:3000", "accept": "application/json", "mcp-protocol-version": "2025-06-18"}
	)
	if int(version_denied_response.get("status", 0)) != 400:
		return _failure("HTTP request router should reject mismatched MCP-Protocol-Version headers.")
	if str(version_denied_response.get("supported_protocol_version", "")) != "2025-11-25":
		return _failure("HTTP request router should report the supported MCP protocol version.")

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
	var options_headers: Dictionary = options_response.get("_headers", {})
	if int(options_response.get("status", 0)) != 405 or str(options_headers.get("Allow", "")) != "POST":
		return _failure("HTTP request router did not reject non-CORS OPTIONS requests with the allowed methods.")

	var denied_origin_response: Dictionary = await router.route_request_async("OPTIONS", "/mcp", "", {"origin": "https://example.com", "host": "localhost:3000"})
	if int(denied_origin_response.get("status", 0)) != 403:
		return _failure("HTTP request router did not reject disallowed CORS origins.")

	var allowed_origin_response: Dictionary = await router.route_request_async("OPTIONS", "/mcp", "", {"origin": "http://localhost:5173", "host": "localhost:3000"})
	var allowed_origin_headers: Dictionary = allowed_origin_response.get("_headers", {})
	if int(allowed_origin_response.get("_status_code", 0)) != 204:
		return _failure("HTTP request router did not allow configured CORS preflight origins.")
	if str(allowed_origin_headers.get("Access-Control-Allow-Origin", "")) != "http://localhost:5173":
		return _failure("HTTP request router did not echo the configured CORS origin.")
	if str(allowed_origin_headers.get("Access-Control-Allow-Headers", "")).find("MCP-Protocol-Version") == -1:
		return _failure("HTTP request router CORS preflight should allow MCP protocol headers.")
	if str(allowed_origin_headers.get("Access-Control-Allow-Headers", "")).find("Mcp-Session-Id") == -1:
		return _failure("HTTP request router CORS preflight should allow MCP session headers.")
	if str(allowed_origin_headers.get("Access-Control-Allow-Origin", "")) == "*":
		return _failure("HTTP request router must not use wildcard CORS origins.")

	var host_denied_response: Dictionary = await router.route_request_async("GET", "/health", "", {"host": "example.com:3000"})
	if int(host_denied_response.get("status", 0)) != 403:
		return _failure("HTTP request router did not reject non-loopback Host headers.")

	var configured_host_response: Dictionary = await router.route_request_async("GET", "/health", "", {"host": "10.0.0.8:3000"})
	if int(configured_host_response.get("status", 0)) == 403:
		return _failure("HTTP request router rejected the configured server Host header.")

	var content_type_denied_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "content-type": "text/plain"})
	if int(content_type_denied_response.get("status", 0)) != 415:
		return _failure("HTTP request router did not reject non-JSON POST content types.")

	var allowed_origin_health: Dictionary = await router.route_request_async("GET", "/health", "", {"origin": "http://localhost:5173", "host": "localhost:3000"})
	var allowed_origin_health_headers: Dictionary = allowed_origin_health.get("_headers", {})
	if str(allowed_origin_health_headers.get("Access-Control-Allow-Origin", "")) != "http://localhost:5173":
		return _failure("HTTP request router did not add CORS headers to allowed actual requests.")

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
