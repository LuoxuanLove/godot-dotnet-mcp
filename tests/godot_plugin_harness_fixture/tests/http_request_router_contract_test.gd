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

	var mcp_response: Dictionary = await router.route_request_async("POST", "/mcp", "{\"jsonrpc\":\"2.0\"}", {"host": "localhost:3000", "content-type": "application/json", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version()})
	if int(mcp_response.get("status", 0)) != 406:
		return _failure("HTTP request router should require explicit Streamable HTTP Accept headers for POST /mcp after required content/protocol headers pass.")

	var get_mcp_without_sse: Dictionary = await router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "application/json", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version()})
	if int(get_mcp_without_sse.get("status", 0)) != 406:
		return _failure("HTTP request router should reject GET /mcp requests that cannot accept SSE responses.")
	var get_mcp_sse_q_zero: Dictionary = await router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream;q=0", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version()})
	if int(get_mcp_sse_q_zero.get("status", 0)) != 406:
		return _failure("HTTP request router should reject GET /mcp requests that declare text/event-stream with q=0.")
	var get_missing_protocol_response: Dictionary = await router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream"})
	if int(get_missing_protocol_response.get("status", 0)) != 400 or str(get_missing_protocol_response.get("error", "")) != "Missing MCP protocol version":
		return _failure("HTTP request router should require MCP-Protocol-Version on GET /mcp.")
	var get_mcp_response: Dictionary = await router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "client-sse-1", "last-event-id": "cursor-7"})
	if int(get_mcp_response.get("status", 0)) != 200:
		return _failure("HTTP request router should allow GET /mcp as a Streamable HTTP SSE probe.")
	if str(get_mcp_response.get("_content_type", "")) != "text/event-stream; charset=utf-8":
		return _failure("HTTP request router should mark GET /mcp responses as SSE.")
	if str(get_mcp_response.get("_stream_mode", "")) != "sse":
		return _failure("HTTP request router should mark GET /mcp responses as streaming SSE connections.")
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
		return _failure("HTTP request router should advertise an SSE retry interval for stream resumption.")
	if get_mcp_body.find("\"resume_from_event_id\":\"cursor-7\"") == -1:
		return _failure("HTTP request router should surface Last-Event-ID as a GET /mcp resume cursor hint.")
	if get_mcp_body.find("\"resume_cursor_found\":false") == -1:
		return _failure("HTTP request router should report missing SSE resume cursors without replaying unrelated events.")
	if get_mcp_body.find("\"resume_status\":\"unknown_session\"") == -1:
		return _failure("HTTP request router should distinguish unknown SSE resume sessions from matched or stale cursors.")
	if get_mcp_body.find("\"resume_start_index\":0") == -1 or get_mcp_body.find("\"resume_base_index\":0") == -1 or get_mcp_body.find("\"resume_next_index\":0") == -1:
		return _failure("HTTP request router should expose stable SSE resume window indexes for unknown cursors.")
	var first_sse_event_id := _extract_first_sse_event_id(get_mcp_body)
	if first_sse_event_id.is_empty():
		return _failure("HTTP request router should expose an SSE event id that clients can resume from.")
	var resumed_mcp_response: Dictionary = await router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "client-sse-1", "last-event-id": first_sse_event_id})
	if int(resumed_mcp_response.get("status", 0)) != 200:
		return _failure("HTTP request router should accept Last-Event-ID cursors for SSE replay probes.")
	var resumed_body := str(resumed_mcp_response.get("_raw_body", ""))
	if _count_sse_event_id(resumed_body, first_sse_event_id) != 0:
		return _failure("HTTP request router should replay events after the Last-Event-ID cursor, not repeat the cursor event.")
	if _count_sse_events(resumed_body) != 1:
		return _failure("HTTP request router should return exactly the new event when resuming from the latest known cursor.")
	if resumed_body.find("\"resume_cursor_found\":true") == -1:
		return _failure("HTTP request router should report matched SSE resume cursors in event data.")
	if resumed_body.find("\"resume_status\":\"matched\"") == -1:
		return _failure("HTTP request router should report matched SSE resume status in event data.")
	if resumed_body.find("\"replay_event_count\":0") == -1:
		return _failure("HTTP request router should report zero stored events after a latest-cursor resume before adding the new probe event.")
	if resumed_body.find("\"resume_start_index\":1") == -1 or resumed_body.find("\"resume_next_index\":1") == -1:
		return _failure("HTTP request router should expose the absolute resume window after a matched cursor.")
	var second_sse_event_id := _extract_first_sse_event_id(resumed_body)
	if second_sse_event_id.is_empty() or second_sse_event_id == first_sse_event_id:
		return _failure("HTTP request router should assign a new SSE event id for each resumable probe event.")
	var replay_mcp_response: Dictionary = await router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "client-sse-1", "last-event-id": first_sse_event_id})
	var replay_body := str(replay_mcp_response.get("_raw_body", ""))
	if replay_body.find(second_sse_event_id) == -1:
		return _failure("HTTP request router should replay stored events after a matched Last-Event-ID cursor.")
	if _count_sse_events(replay_body) != 2:
		return _failure("HTTP request router should include stored replay events plus the current probe event for matched older cursors.")
	if replay_body.find("\"replay_event_count\":1") == -1:
		return _failure("HTTP request router should report the number of stored replay events after a matched older cursor.")
	var unknown_active_cursor_response: Dictionary = await router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "client-sse-1", "last-event-id": "streamable-http-get-client-sse-1-999"})
	var unknown_active_cursor_body := str(unknown_active_cursor_response.get("_raw_body", ""))
	if unknown_active_cursor_body.find("\"resume_status\":\"unknown_cursor\"") == -1:
		return _failure("HTTP request router should distinguish active-session unknown SSE cursors from stale retained-window cursors.")
	var underscore_session_response: Dictionary = await router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "client_key"})
	var underscore_first_event_id := _extract_first_sse_event_id(str(underscore_session_response.get("_raw_body", "")))
	if not underscore_first_event_id.ends_with("-1"):
		return _failure("HTTP request router should start SSE counters at one for a new session.")
	await router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "client key"})
	var underscore_second_response: Dictionary = await router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "client_key"})
	var underscore_second_event_id := _extract_first_sse_event_id(str(underscore_second_response.get("_raw_body", "")))
	if not underscore_second_event_id.ends_with("-2"):
		return _failure("HTTP request router should keep independent counters for sessions whose sanitized SSE tokens collide.")
	for index in range(31):
		await router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "collision-fill-%02d" % index})
	var underscore_third_response: Dictionary = await router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "client_key"})
	var underscore_third_event_id := _extract_first_sse_event_id(str(underscore_third_response.get("_raw_body", "")))
	if not underscore_third_event_id.ends_with("-3"):
		return _failure("HTTP request router should not reset an active session counter when evicting another session with the same sanitized SSE token.")
	for index in range(40):
		await router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "bounded-session-%02d" % index})
	var evicted_mcp_response: Dictionary = await router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "client-sse-1", "last-event-id": first_sse_event_id})
	var evicted_body := str(evicted_mcp_response.get("_raw_body", ""))
	if evicted_body.find(second_sse_event_id) != -1:
		return _failure("HTTP request router should evict old SSE sessions instead of replaying them after the global session bound is exceeded.")
	if _count_sse_events(evicted_body) != 1:
		return _failure("HTTP request router should keep only the current event for an evicted SSE resume cursor.")
	if evicted_body.find("\"resume_cursor_found\":false") == -1:
		return _failure("HTTP request router should report evicted SSE resume cursors as missing.")
	if evicted_body.find("\"resume_status\":\"unknown_session\"") == -1:
		return _failure("HTTP request router should report evicted SSE sessions as unknown sessions.")

	var bounded_router = HttpRequestRouterScript.new()
	bounded_router.configure(context)
	var bounded_first_response: Dictionary = await bounded_router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "bounded-resume"})
	var bounded_first_event_id := _extract_first_sse_event_id(str(bounded_first_response.get("_raw_body", "")))
	for index in range(33):
		await bounded_router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "bounded-resume"})
	var stale_cursor_response: Dictionary = await bounded_router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "bounded-resume", "last-event-id": bounded_first_event_id})
	var stale_cursor_body := str(stale_cursor_response.get("_raw_body", ""))
	if stale_cursor_body.find("\"resume_cursor_found\":false") == -1:
		return _failure("HTTP request router should report stale retained-window cursors as not found.")
	if stale_cursor_body.find("\"resume_status\":\"stale_cursor\"") == -1:
		return _failure("HTTP request router should distinguish stale retained-window cursors from unknown sessions.")
	if stale_cursor_body.find("\"resume_base_index\":2") == -1 or stale_cursor_body.find("\"resume_next_index\":34") == -1:
		return _failure("HTTP request router should expose retained-window indexes for stale cursors.")
	var get_protocol_denied_response: Dictionary = await router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream", "mcp-protocol-version": "1900-01-01"})
	if int(get_protocol_denied_response.get("status", 0)) != 400:
		return _failure("HTTP request router should reject unsupported MCP-Protocol-Version headers on GET /mcp.")
	var get_invalid_session_response: Dictionary = await router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "client\r\nInjected: yes"})
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
	if int(options_response.get("status", 0)) != 405 or str(options_headers.get("Allow", "")) != "GET, POST, DELETE":
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
	if str(allowed_origin_headers.get("Access-Control-Allow-Methods", "")) != "GET, POST, DELETE":
		return _failure("HTTP request router CORS preflight should advertise DELETE /mcp support.")
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

	var missing_content_type_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "accept": "application/json, text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version()})
	if int(missing_content_type_response.get("status", 0)) != 415:
		return _failure("HTTP request router should require Content-Type on POST /mcp.")

	var accept_denied_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "content-type": "application/json", "accept": "text/html", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version()})
	if int(accept_denied_response.get("status", 0)) != 406:
		return _failure("HTTP request router did not reject POST /mcp requests that cannot accept JSON or SSE responses.")

	var json_only_accept_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "content-type": "application/json", "accept": "application/json", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version()})
	if int(json_only_accept_response.get("status", 0)) != 406:
		return _failure("HTTP request router should reject POST /mcp requests that omit text/event-stream from Accept.")

	var sse_only_accept_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "content-type": "application/json", "accept": "text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version()})
	if int(sse_only_accept_response.get("status", 0)) != 406:
		return _failure("HTTP request router should reject POST /mcp requests that omit application/json from Accept.")
	var json_q_zero_accept_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "content-type": "application/json", "accept": "application/json;q=0, text/event-stream;q=1", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version()})
	if int(json_q_zero_accept_response.get("status", 0)) != 406:
		return _failure("HTTP request router should reject POST /mcp requests that declare application/json with q=0.")
	var sse_q_zero_accept_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "content-type": "application/json", "accept": "application/json;q=1, text/event-stream;q=0", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version()})
	if int(sse_q_zero_accept_response.get("status", 0)) != 406:
		return _failure("HTTP request router should reject POST /mcp requests that declare text/event-stream with q=0.")

	var missing_protocol_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "content-type": "application/json", "accept": "application/json, text/event-stream"})
	if int(missing_protocol_response.get("status", 0)) != 400 or str(missing_protocol_response.get("error", "")) != "Missing MCP protocol version":
		return _failure("HTTP request router should require MCP-Protocol-Version on POST /mcp.")

	var streamable_accept_response: Dictionary = await router.route_request_async("POST", "/mcp", "{\"jsonrpc\":\"2.0\",\"id\":2}", {"host": "localhost:3000", "content-type": "application/json", "accept": "application/json, text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version()})
	if str(streamable_accept_response.get("echo", "")) != "{\"jsonrpc\":\"2.0\",\"id\":2}":
		return _failure("HTTP request router did not allow Streamable HTTP Accept headers for POST /mcp.")
	var streamable_accept_headers: Dictionary = streamable_accept_response.get("_headers", {})
	if str(streamable_accept_headers.get("MCP-Protocol-Version", "")) != ProtocolFactsScript.get_protocol_version():
		return _failure("HTTP request router did not attach the MCP protocol version response header.")
	var generated_session_id := str(streamable_accept_headers.get("Mcp-Session-Id", ""))
	if generated_session_id.is_empty():
		return _failure("HTTP request router did not attach a streamable HTTP session id.")

	var second_streamable_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "content-type": "application/json", "accept": "application/json, text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version()})
	var second_streamable_headers: Dictionary = second_streamable_response.get("_headers", {})
	if str(second_streamable_headers.get("Mcp-Session-Id", "")) == generated_session_id:
		return _failure("HTTP request router should not reuse one generated MCP session id for independent requests.")

	var second_router = HttpRequestRouterScript.new()
	second_router.configure(context)
	var second_router_response: Dictionary = await second_router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "content-type": "application/json", "accept": "application/json, text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version()})
	var second_router_headers: Dictionary = second_router_response.get("_headers", {})
	if str(second_router_headers.get("Mcp-Session-Id", "")) == generated_session_id:
		return _failure("HTTP request router should not reuse one generated MCP session id across router instances.")

	var existing_session_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "content-type": "application/json", "accept": "application/json, text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "client-session-7"})
	var existing_session_headers: Dictionary = existing_session_response.get("_headers", {})
	if str(existing_session_headers.get("Mcp-Session-Id", "")) != "client-session-7":
		return _failure("HTTP request router should echo an existing MCP session id.")
	var delete_post_only_session: Dictionary = await router.route_request_async("DELETE", "/mcp", "", {"host": "localhost:3000", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "client-session-7"})
	if int(delete_post_only_session.get("status", 0)) != 204 or not bool(delete_post_only_session.get("_no_body", false)):
		return _failure("HTTP request router should allow DELETE /mcp for a session issued by ordinary POST responses.")
	var invalid_session_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "content-type": "application/json", "accept": "application/json, text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "client\nInjected: yes"})
	if int(invalid_session_response.get("status", 0)) != 400 or str(invalid_session_response.get("error", "")) != "Invalid MCP session id":
		return _failure("HTTP request router should reject invalid POST /mcp session ids before echoing response headers.")
	var invalid_session_bad_accept_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "content-type": "application/json", "accept": "text/html", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "client\nInjected: yes"})
	var invalid_session_bad_accept_headers: Dictionary = invalid_session_bad_accept_response.get("_headers", {})
	if int(invalid_session_bad_accept_response.get("status", 0)) != 400 or str(invalid_session_bad_accept_response.get("error", "")) != "Invalid MCP session id":
		return _failure("HTTP request router should prioritize unsafe POST session ids over accept guard responses.")
	if str(invalid_session_bad_accept_headers.get("Mcp-Session-Id", "")).find("Injected") != -1:
		return _failure("HTTP request router must not echo unsafe POST session ids on earlier transport guard failures.")

	var accept_denied_headers: Dictionary = sse_only_accept_response.get("_headers", {})
	if str(accept_denied_headers.get("MCP-Protocol-Version", "")) != ProtocolFactsScript.get_protocol_version():
		return _failure("HTTP request router should attach protocol headers to MCP transport guard failures.")

	var protocol_denied_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "content-type": "application/json", "accept": "application/json, text/event-stream", "mcp-protocol-version": "1900-01-01"})
	if int(protocol_denied_response.get("status", 0)) != 400:
		return _failure("HTTP request router did not reject unsupported MCP-Protocol-Version headers.")
	if str(protocol_denied_response.get("supported_protocol_version", "")) != ProtocolFactsScript.get_protocol_version():
		return _failure("HTTP request router should report the supported MCP protocol version.")

	var protocol_allowed_response: Dictionary = await router.route_request_async("POST", "/mcp", "{\"jsonrpc\":\"2.0\",\"id\":3}", {"host": "localhost:3000", "content-type": "application/json", "accept": "application/json, text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version()})
	if str(protocol_allowed_response.get("echo", "")) != "{\"jsonrpc\":\"2.0\",\"id\":3}":
		return _failure("HTTP request router rejected the configured MCP-Protocol-Version header.")

	var delete_missing_session_response: Dictionary = await router.route_request_async("DELETE", "/mcp", "", {"host": "localhost:3000", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version()})
	if int(delete_missing_session_response.get("status", 0)) != 400 or str(delete_missing_session_response.get("error", "")) != "Missing MCP session id":
		return _failure("HTTP request router should require Mcp-Session-Id for DELETE /mcp session termination.")
	var delete_invalid_session_response: Dictionary = await router.route_request_async("DELETE", "/mcp", "", {"host": "localhost:3000", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "client\nInjected: yes"})
	if int(delete_invalid_session_response.get("status", 0)) != 400 or str(delete_invalid_session_response.get("error", "")) != "Invalid MCP session id":
		return _failure("HTTP request router should reject unsafe DELETE /mcp session ids.")
	var delete_missing_protocol_response: Dictionary = await router.route_request_async("DELETE", "/mcp", "", {"host": "localhost:3000", "mcp-session-id": "delete-session"})
	if int(delete_missing_protocol_response.get("status", 0)) != 400 or str(delete_missing_protocol_response.get("error", "")) != "Missing MCP protocol version":
		return _failure("HTTP request router should require MCP-Protocol-Version for DELETE /mcp.")
	var delete_unknown_session_response: Dictionary = await router.route_request_async("DELETE", "/mcp", "", {"host": "localhost:3000", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "delete-never-issued"})
	if int(delete_unknown_session_response.get("status", 0)) != 404 or str(delete_unknown_session_response.get("error", "")) != "MCP session not found":
		return _failure("HTTP request router should reject DELETE /mcp for a never-issued MCP session.")
	var delete_session_seed: Dictionary = await router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "delete-session"})
	if int(delete_session_seed.get("status", 0)) != 200:
		return _failure("HTTP request router should allow a session to exist before DELETE /mcp termination.")
	var delete_session_response: Dictionary = await router.route_request_async("DELETE", "/mcp", "", {"host": "localhost:3000", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "delete-session"})
	if int(delete_session_response.get("status", 0)) != 204 or not bool(delete_session_response.get("_no_body", false)):
		return _failure("HTTP request router should return 204 no body for successful DELETE /mcp session termination.")
	if str(delete_session_response.get("_terminate_mcp_session_id", "")) != "delete-session":
		return _failure("HTTP request router should emit an internal termination directive for active SSE streams.")
	var delete_session_headers: Dictionary = delete_session_response.get("_headers", {})
	if str(delete_session_headers.get("X-MCP-Session-Terminated", "")) != "true":
		return _failure("HTTP request router should expose session termination metadata on DELETE /mcp.")
	var get_after_delete_response: Dictionary = await router.route_request_async("GET", "/mcp", "", {"host": "localhost:3000", "accept": "text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "delete-session"})
	if int(get_after_delete_response.get("status", 0)) != 404:
		return _failure("HTTP request router should reject GET /mcp for a terminated session.")
	var post_after_delete_response: Dictionary = await router.route_request_async("POST", "/mcp", "{}", {"host": "localhost:3000", "content-type": "application/json", "accept": "application/json, text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "delete-session"})
	if int(post_after_delete_response.get("status", 0)) != 404:
		return _failure("HTTP request router should reject POST /mcp for a terminated session.")
	var delete_after_delete_response: Dictionary = await router.route_request_async("DELETE", "/mcp", "", {"host": "localhost:3000", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "delete-session"})
	if int(delete_after_delete_response.get("status", 0)) != 404:
		return _failure("HTTP request router should report terminated MCP sessions as not found on repeated DELETE /mcp.")

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
	var json_preferred_request_post: Dictionary = await response_post_router.route_request_async(
		"POST",
		"/mcp",
		JSON.stringify({"jsonrpc": "2.0", "id": 45, "method": "tools/list"}),
		{"host": "localhost:3000", "content-type": "application/json", "accept": "application/json, text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "post-json-preferred"}
	)
	if str(json_preferred_request_post.get("jsonrpc", "")) != "2.0" or not json_preferred_request_post.has("result"):
		return _failure("HTTP request router should keep JSON response mode when application/json is the preferred POST response type.")
	if json_preferred_request_post.has("_stream_mode"):
		return _failure("HTTP request router should not switch JSON-preferred POST requests to SSE response mode.")
	var sse_preferred_request_post: Dictionary = await response_post_router.route_request_async(
		"POST",
		"/mcp",
		JSON.stringify({"jsonrpc": "2.0", "id": 46, "method": "tools/list"}),
		{"host": "localhost:3000", "content-type": "application/json", "accept": "application/json;q=0.1, text/event-stream;q=1.0", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "post-sse-preferred"}
	)
	if sse_preferred_request_post.has("_stream_mode"):
		return _failure("HTTP request router should keep POST SSE responses as finite raw HTTP responses, not long-lived streams.")
	if str(sse_preferred_request_post.get("_content_type", "")) != "text/event-stream; charset=utf-8":
		return _failure("HTTP request router should mark POST SSE responses with text/event-stream content type.")
	var sse_preferred_headers: Dictionary = sse_preferred_request_post.get("_headers", {})
	if str(sse_preferred_headers.get("Cache-Control", "")) != "no-cache, no-transform":
		return _failure("HTTP request router should disable buffering/cache for POST SSE responses.")
	var sse_preferred_body := str(sse_preferred_request_post.get("_raw_body", ""))
	if sse_preferred_body.find("event: message") == -1 or sse_preferred_body.find("\"jsonrpc\":\"2.0\"") == -1 or sse_preferred_body.find("\"id\":46") == -1:
		return _failure("HTTP request router should wrap the POST JSON-RPC response as an SSE message event.")
	if sse_preferred_body.find("id: streamable-http-post-post-sse-preferred-") == -1:
		return _failure("HTTP request router should attach a session-scoped event id to POST SSE responses.")
	var get_after_post_sse_response: Dictionary = await response_post_router.route_request_async(
		"GET",
		"/mcp",
		"",
		{"host": "localhost:3000", "accept": "text/event-stream", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version(), "mcp-session-id": "post-sse-preferred"}
	)
	var get_after_post_sse_body := str(get_after_post_sse_response.get("_raw_body", ""))
	if get_after_post_sse_body.find("\"id\":46") != -1:
		return _failure("HTTP request router should not replay finite POST SSE responses through unrelated GET SSE probes.")
	var routed_requests_before_response_envelope: int = response_post_service.routed_requests
	var json_rpc_response_post: Dictionary = await response_post_router.route_request_async(
		"POST",
		"/mcp",
		JSON.stringify({"jsonrpc": "2.0", "id": 44, "result": {"ok": true}}),
		{"host": "localhost:3000", "content-type": "application/json", "accept": "text/event-stream, application/json", "mcp-protocol-version": ProtocolFactsScript.get_protocol_version()}
	)
	var json_rpc_response_headers: Dictionary = json_rpc_response_post.get("_headers", {})
	if int(json_rpc_response_post.get("status", 0)) != 202 or not bool(json_rpc_response_post.get("_no_body", false)):
		return _failure("HTTP request router should accept JSON-RPC response POST envelopes with 202 and no body.")
	if str(json_rpc_response_headers.get("MCP-Protocol-Version", "")) != ProtocolFactsScript.get_protocol_version():
		return _failure("HTTP request router should attach protocol headers to accepted response POST envelopes.")
	if str(json_rpc_response_headers.get("Mcp-Session-Id", "")).is_empty():
		return _failure("HTTP request router should attach a session header to accepted response POST envelopes.")
	if response_post_service.routed_requests != routed_requests_before_response_envelope:
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


func _extract_first_sse_event_id(body: String) -> String:
	for line in body.split("\n", false):
		var normalized := str(line).strip_edges()
		if normalized.begins_with("id: "):
			return normalized.substr(4).strip_edges()
	return ""


func _count_sse_events(body: String) -> int:
	var count := 0
	for line in body.split("\n", false):
		if str(line).strip_edges().begins_with("event: "):
			count += 1
	return count


func _count_sse_event_id(body: String, event_id: String) -> int:
	var count := 0
	for line in body.split("\n", false):
		var normalized := str(line).strip_edges()
		if normalized == "id: %s" % event_id:
			count += 1
	return count
