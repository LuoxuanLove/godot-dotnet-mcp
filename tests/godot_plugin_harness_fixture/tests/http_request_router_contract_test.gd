extends RefCounted

const HttpRequestRouterScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_request_router.gd")
const HttpRequestRouterContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_request_router_context.gd")
const ProtocolFactsScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd")


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

	func build_cors_response(origin: String = "", allow_methods: String = "GET, POST", allow_headers: String = "Content-Type, Accept") -> Dictionary:
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
	if str(allowed_origin_headers.get("Access-Control-Allow-Origin", "")) == "*":
		return _failure("HTTP request router must not use wildcard CORS origins.")
	if str(allowed_origin_headers.get("Access-Control-Allow-Headers", "")).find("MCP-Protocol-Version") == -1:
		return _failure("HTTP request router CORS preflight should allow MCP-Protocol-Version headers.")

	var host_denied_response: Dictionary = await router.route_request_async("GET", "/health", "", {"host": "example.com:3000"})
	if int(host_denied_response.get("status", 0)) != 403:
		return _failure("HTTP request router did not reject non-loopback Host headers.")

	var configured_host_response: Dictionary = await router.route_request_async("GET", "/health", "", {"host": "10.0.0.8:3000"})
	if int(configured_host_response.get("status", 0)) == 403:
		return _failure("HTTP request router rejected the configured server Host header.")

	var content_type_denied_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "content-type": "text/plain"})
	if int(content_type_denied_response.get("status", 0)) != 415:
		return _failure("HTTP request router did not reject non-JSON POST content types.")

	var accept_denied_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "accept": "text/html"})
	if int(accept_denied_response.get("status", 0)) != 406:
		return _failure("HTTP request router did not reject POST /mcp requests that cannot accept JSON or SSE responses.")

	var streamable_accept_response: Dictionary = await router.route_request_async("POST", "/mcp", "{\"jsonrpc\":\"2.0\",\"id\":2}", {"host": "localhost:3000", "content-type": "application/json", "accept": "application/json, text/event-stream"})
	if str(streamable_accept_response.get("echo", "")) != "{\"jsonrpc\":\"2.0\",\"id\":2}":
		return _failure("HTTP request router did not allow Streamable HTTP Accept headers for POST /mcp.")

	var protocol_denied_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "accept": "application/json", "mcp-protocol-version": "1900-01-01"})
	if int(protocol_denied_response.get("status", 0)) != 400:
		return _failure("HTTP request router did not reject unsupported MCP-Protocol-Version headers.")
	if str(protocol_denied_response.get("expected_protocol_version", "")) != ProtocolFactsScript.get_protocol_version():
		return _failure("HTTP request router should report the expected MCP protocol version.")

	var protocol_allowed_response: Dictionary = await router.route_request_async("POST", "/mcp", "{\"jsonrpc\":\"2.0\",\"id\":3}", {"host": "localhost:3000", "accept": "application/json", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version()})
	if str(protocol_allowed_response.get("echo", "")) != "{\"jsonrpc\":\"2.0\",\"id\":3}":
		return _failure("HTTP request router rejected the configured MCP-Protocol-Version header.")

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
