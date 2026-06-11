extends RefCounted

const HttpRequestRouterScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_request_router.gd")
const HttpRequestRouterContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_request_router_context.gd")
const JsonRpcRequestServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_json_rpc_request_service.gd")
const JsonRpcRequestContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_json_rpc_request_context.gd")
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

	func build_cors_response(origin: String = "", allow_methods: String = "GET, POST", allow_headers: String = "Content-Type, Accept, MCP-Protocol-Version, Mcp-Session-Id, Last-Event-ID") -> Dictionary:
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


class ResponsePostService:
	extends RefCounted

	var _service = JsonRpcRequestServiceScript.new()
	var routed_requests := 0

	func _init() -> void:
		var context = JsonRpcRequestContextScript.new()
		context.route_json_rpc_async = Callable(self, "route_json_rpc_async")
		context.build_json_rpc_error = Callable(self, "build_json_rpc_error")
		context.emit_request_received = Callable(self, "emit_request_received")
		context.log = Callable(self, "log")
		_service.configure(context)

	func handle_mcp_request_async(body: String) -> Dictionary:
		return await _service.handle_request_async(body)

	func route_json_rpc_async(_method: String, _params: Dictionary, id, _has_id: bool) -> Dictionary:
		routed_requests += 1
		return {
			"jsonrpc": "2.0",
			"result": {"routed": true},
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

	func emit_request_received(_method: String, _params: Dictionary) -> void:
		routed_requests += 1

	func log(_message: String, _level: String) -> void:
		pass


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
	if int(mcp_response.get("status", 0)) != 406:
		return _failure("HTTP request router should require explicit Streamable HTTP Accept headers for POST /mcp.")

	var get_mcp_without_sse: Dictionary = await router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "application/json"})
	if int(get_mcp_without_sse.get("status", 0)) != 406:
		return _failure("HTTP request router should reject GET /mcp requests that cannot accept SSE responses.")
	var get_mcp_response: Dictionary = await router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream", "mcp-session-id": "client-sse-1", "last-event-id": "cursor-7"})
	if int(get_mcp_response.get("status", 0)) != 200:
		return _failure("HTTP request router should allow GET /mcp as a Streamable HTTP SSE probe.")
	if str(get_mcp_response.get("_content_type", "")) != "text/event-stream; charset=utf-8":
		return _failure("HTTP request router should mark GET /mcp responses as SSE.")
	var get_mcp_headers: Dictionary = get_mcp_response.get("_headers", {})
	if str(get_mcp_headers.get("Mcp-Session-Id", "")) != "client-sse-1":
		return _failure("HTTP request router should echo the GET /mcp SSE session id.")
	if str(get_mcp_headers.get("MCP-Protocol-Version", "")) != ProtocolFactsScript.get_protocol_version():
		return _failure("HTTP request router should attach protocol headers to GET /mcp SSE responses.")
	if str(get_mcp_headers.get("Cache-Control", "")) != "no-cache, no-transform":
		return _failure("HTTP request router should disable caching for GET /mcp SSE responses.")
	var get_mcp_body := str(get_mcp_response.get("_raw_body", ""))
	if get_mcp_body.find("event: message") == -1 or get_mcp_body.find("\"jsonrpc\":\"2.0\"") == -1 or get_mcp_body.find("\"method\":\"notifications/message\"") == -1 or get_mcp_body.find("\"transport\":\"streamable_http\"") == -1:
		return _failure("HTTP request router should return an observable Streamable HTTP SSE message for GET /mcp.")
	if get_mcp_body.find("id: streamable-http-get-client-sse-1-") == -1:
		return _failure("HTTP request router should attach a stream-specific SSE event id.")
	if get_mcp_body.find("retry: 1000") == -1:
		return _failure("HTTP request router should advertise an SSE retry interval before closing probe responses.")
	if get_mcp_body.find("\"resume_from_event_id\":\"cursor-7\"") == -1:
		return _failure("HTTP request router should surface Last-Event-ID as a GET /mcp resume cursor hint.")
	var get_protocol_denied_response: Dictionary = await router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream", "mcp-protocol-version": "1900-01-01"})
	if int(get_protocol_denied_response.get("status", 0)) != 400:
		return _failure("HTTP request router should reject unsupported MCP-Protocol-Version headers on GET /mcp.")
	var get_invalid_session_response: Dictionary = await router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream", "mcp-session-id": "client\r\nInjected: yes"})
	if int(get_invalid_session_response.get("status", 0)) != 400 or str(get_invalid_session_response.get("error", "")) != "Invalid MCP session id":
		return _failure("HTTP request router should reject invalid GET /mcp session ids before echoing response headers.")
	var get_invalid_session_bad_version_response: Dictionary = await router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream", "mcp-protocol-version": "1900-01-01", "mcp-session-id": "client\r\nInjected: yes"})
	var get_invalid_session_bad_version_headers: Dictionary = get_invalid_session_bad_version_response.get("_headers", {})
	if int(get_invalid_session_bad_version_response.get("status", 0)) != 400 or str(get_invalid_session_bad_version_response.get("error", "")) != "Invalid MCP session id":
		return _failure("HTTP request router should prioritize unsafe GET session ids over protocol-version guard responses.")
	if str(get_invalid_session_bad_version_headers.get("Mcp-Session-Id", "")).find("Injected") != -1:
		return _failure("HTTP request router must not echo unsafe GET session ids on earlier transport guard failures.")

	var health_response: Dictionary = await router.route_request_async("GET", "/health", "")
	if str(health_response.get("status", "")) != "ok":
		return _failure("HTTP request router did not route GET /health.")

	var lifecycle_response: Dictionary = await router.route_request_async("GET", "/api/editor/lifecycle", "")
	if str(lifecycle_response.get("action", "")) != "status":
		return _failure("HTTP request router did not route lifecycle status requests.")

	var options_response: Dictionary = await router.route_request_async("OPTIONS", "/mcp", "")
	var options_headers: Dictionary = options_response.get("_headers", {})
	if int(options_response.get("status", 0)) != 405 or str(options_headers.get("Allow", "")) != "GET, POST":
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
	if str(allowed_origin_headers.get("Access-Control-Allow-Headers", "")).find("Last-Event-ID") == -1:
		return _failure("HTTP request router CORS preflight should allow SSE resume cursor headers.")
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

	var json_only_accept_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "accept": "application/json"})
	if int(json_only_accept_response.get("status", 0)) != 406:
		return _failure("HTTP request router should reject POST /mcp requests that omit text/event-stream from Accept.")

	var sse_only_accept_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "accept": "text/event-stream"})
	if int(sse_only_accept_response.get("status", 0)) != 406:
		return _failure("HTTP request router should reject POST /mcp requests that omit application/json from Accept.")

	var streamable_accept_response: Dictionary = await router.route_request_async("POST", "/mcp", "{\"jsonrpc\":\"2.0\",\"id\":2}", {"host": "localhost:3000", "content-type": "application/json", "accept": "application/json, text/event-stream"})
	if str(streamable_accept_response.get("echo", "")) != "{\"jsonrpc\":\"2.0\",\"id\":2}":
		return _failure("HTTP request router did not allow Streamable HTTP Accept headers for POST /mcp.")
	var streamable_accept_headers: Dictionary = streamable_accept_response.get("_headers", {})
	if str(streamable_accept_headers.get("MCP-Protocol-Version", "")) != ProtocolFactsScript.get_protocol_version():
		return _failure("HTTP request router did not attach the MCP protocol version response header.")
	var generated_session_id := str(streamable_accept_headers.get("Mcp-Session-Id", ""))
	if generated_session_id.is_empty():
		return _failure("HTTP request router did not attach a streamable HTTP session id.")

	var second_streamable_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "accept": "application/json, text/event-stream"})
	var second_streamable_headers: Dictionary = second_streamable_response.get("_headers", {})
	if str(second_streamable_headers.get("Mcp-Session-Id", "")) == generated_session_id:
		return _failure("HTTP request router should not reuse one generated MCP session id for independent requests.")

	var second_router = HttpRequestRouterScript.new()
	second_router.configure(context)
	var second_router_response: Dictionary = await second_router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "accept": "application/json, text/event-stream"})
	var second_router_headers: Dictionary = second_router_response.get("_headers", {})
	if str(second_router_headers.get("Mcp-Session-Id", "")) == generated_session_id:
		return _failure("HTTP request router should not reuse one generated MCP session id across router instances.")

	var existing_session_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "accept": "application/json, text/event-stream", "mcp-session-id": "client-session-7"})
	var existing_session_headers: Dictionary = existing_session_response.get("_headers", {})
	if str(existing_session_headers.get("Mcp-Session-Id", "")) != "client-session-7":
		return _failure("HTTP request router should echo an existing MCP session id.")
	var invalid_session_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "accept": "application/json, text/event-stream", "mcp-session-id": "client\nInjected: yes"})
	if int(invalid_session_response.get("status", 0)) != 400 or str(invalid_session_response.get("error", "")) != "Invalid MCP session id":
		return _failure("HTTP request router should reject invalid POST /mcp session ids before echoing response headers.")
	var invalid_session_bad_accept_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "accept": "text/html", "mcp-session-id": "client\nInjected: yes"})
	var invalid_session_bad_accept_headers: Dictionary = invalid_session_bad_accept_response.get("_headers", {})
	if int(invalid_session_bad_accept_response.get("status", 0)) != 400 or str(invalid_session_bad_accept_response.get("error", "")) != "Invalid MCP session id":
		return _failure("HTTP request router should prioritize unsafe POST session ids over accept guard responses.")
	if str(invalid_session_bad_accept_headers.get("Mcp-Session-Id", "")).find("Injected") != -1:
		return _failure("HTTP request router must not echo unsafe POST session ids on earlier transport guard failures.")

	var accept_denied_headers: Dictionary = sse_only_accept_response.get("_headers", {})
	if str(accept_denied_headers.get("MCP-Protocol-Version", "")) != ProtocolFactsScript.get_protocol_version():
		return _failure("HTTP request router should attach protocol headers to MCP transport guard failures.")

	var protocol_denied_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "accept": "application/json, text/event-stream", "mcp-protocol-version": "1900-01-01"})
	if int(protocol_denied_response.get("status", 0)) != 400:
		return _failure("HTTP request router did not reject unsupported MCP-Protocol-Version headers.")
	if str(protocol_denied_response.get("supported_protocol_version", "")) != ProtocolFactsScript.get_protocol_version():
		return _failure("HTTP request router should report the supported MCP protocol version.")

	var protocol_allowed_response: Dictionary = await router.route_request_async("POST", "/mcp", "{\"jsonrpc\":\"2.0\",\"id\":3}", {"host": "localhost:3000", "accept": "application/json, text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version()})
	if str(protocol_allowed_response.get("echo", "")) != "{\"jsonrpc\":\"2.0\",\"id\":3}":
		return _failure("HTTP request router rejected the configured MCP-Protocol-Version header.")

	var response_post_router = HttpRequestRouterScript.new()
	var response_post_service = ResponsePostService.new()
	var response_post_context = HttpRequestRouterContextScript.new()
	response_post_context.handle_mcp_request_async = Callable(response_post_service, "handle_mcp_request_async")
	response_post_context.build_health_response = Callable(callbacks, "build_health_response")
	response_post_context.build_tools_list_response = Callable(callbacks, "build_tools_list_response")
	response_post_context.handle_editor_lifecycle_request = Callable(callbacks, "handle_editor_lifecycle_request")
	response_post_context.handle_editor_lifecycle_post_request = Callable(callbacks, "handle_editor_lifecycle_post_request")
	response_post_context.build_cors_response = Callable(callbacks, "build_cors_response")
	response_post_router.configure(response_post_context)
	var json_rpc_response_post: Dictionary = await response_post_router.route_request_async(
		"POST",
		"/mcp",
		JSON.stringify({"jsonrpc": "2.0", "id": 44, "result": {"ok": true}}),
		{"host": "localhost:3000", "content-type": "application/json", "accept": "application/json, text/event-stream"}
	)
	var json_rpc_response_headers: Dictionary = json_rpc_response_post.get("_headers", {})
	if int(json_rpc_response_post.get("status", 0)) != 202 or not bool(json_rpc_response_post.get("_no_body", false)):
		return _failure("HTTP request router should accept JSON-RPC response POST envelopes with 202 and no body.")
	if str(json_rpc_response_headers.get("MCP-Protocol-Version", "")) != ProtocolFactsScript.get_protocol_version():
		return _failure("HTTP request router should attach protocol headers to accepted response POST envelopes.")
	if str(json_rpc_response_headers.get("Mcp-Session-Id", "")).is_empty():
		return _failure("HTTP request router should attach a session header to accepted response POST envelopes.")
	if response_post_service.routed_requests != 0:
		return _failure("HTTP request router should not route accepted JSON-RPC response POST envelopes as requests.")

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
