extends RefCounted

const HttpResponseServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_response_service.gd")
const HttpResponseContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_response_context.gd")
const MCPProtocolFacts = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd")


class FakeToolLoader:
	extends RefCounted

	func get_exposed_tool_definitions() -> Array:
		return [{"name": "system_project_state"}, {"name": "system_scene_inspect"}]

	func get_tool_definitions() -> Array:
		return get_exposed_tool_definitions()

	func get_domain_states() -> Array:
		return [{"category": "system", "status": "ready"}]

	func get_reload_status() -> Dictionary:
		return {"status": "idle"}

	func get_performance_summary() -> Dictionary:
		return {"slow_operations": 0}


class FakeCallbacks:
	extends RefCounted

	var loader
	var loader_status: Dictionary
	var server_stats: Dictionary
	var freshness_snapshot: Dictionary = {"status": "fresh", "needs_lifecycle_reload": false}
	var last_log: Dictionary = {}

	func _init(current_loader, current_loader_status: Dictionary, current_server_stats: Dictionary) -> void:
		loader = current_loader
		loader_status = current_loader_status.duplicate(true)
		server_stats = current_server_stats.duplicate(true)

	func get_tool_loader():
		return loader

	func get_tool_loader_status() -> Dictionary:
		return loader_status.duplicate(true)

	func get_server_stats() -> Dictionary:
		return server_stats.duplicate(true)

	func get_editor_session_identity() -> Dictionary:
		return {
			"session_id": "health-contract-session",
			"identity_scope": "current_editor_process",
			"process_owner": "godot_dotnet_mcp_editor",
			"external_validation_process": false,
			"safe_to_terminate": false,
			"pid": 6363,
			"listen_host": "127.0.0.1",
			"listen_port": 3000,
			"listen_url": "http://127.0.0.1:3000/mcp"
		}

	func get_freshness_snapshot() -> Dictionary:
		return freshness_snapshot.duplicate(true)

	func log(message: String, level: String) -> void:
		last_log = {
			"message": message,
			"level": level
		}


func run_case(_tree: SceneTree) -> Dictionary:
	var service = HttpResponseServiceScript.new()
	var callbacks = FakeCallbacks.new(
		FakeToolLoader.new(),
		{
			"healthy": true,
			"status": "ready"
		},
		{
			"running": true,
			"listen_host": "127.0.0.1",
			"listen_port": 3000,
			"listen_url": "http://127.0.0.1:3000/mcp",
			"connections": 3,
			"total_connections": 5,
			"total_requests": 12,
			"rejected_requests": 1,
			"client_session_count": 1,
			"client_sessions": [
				{
					"connection_id": "http-5",
					"active": true,
					"connected_at_unix": 123400,
					"last_seen_at_unix": 123456,
					"request_count": 2,
					"last_request_id": "http-5-req-2",
					"last_request_method": "POST",
					"last_request_path": "/mcp",
					"last_request_at_unix": 123456,
					"last_json_rpc_method": "tools/list",
					"client_summary": {
						"host": "localhost",
						"origin": "http://localhost:5173",
						"user_agent": "ContractClient/1.0",
						"authorization_present": true
					},
					"recent_requests": [
						{
							"request_id": "http-5-req-1",
							"method": "POST",
							"path": "/mcp",
							"json_rpc_method": "initialize"
						},
						{
							"request_id": "http-5-req-2",
							"method": "POST",
							"path": "/mcp",
							"json_rpc_method": "tools/list"
						}
					]
				}
			],
			"recent_client_sessions": [
				{
					"connection_id": "http-4",
					"active": false,
					"request_count": 1,
					"last_request_id": "http-4-req-1",
					"client_summary": {"user_agent": "PreviousClient/1.0"},
					"recent_requests": []
				}
			],
			"last_request_id": "http-5-req-2",
			"last_request_method": "POST",
			"last_request_path": "/mcp",
			"last_request_at_unix": 123456
		}
	)
	var context = HttpResponseContextScript.new()
	var server_facts = MCPProtocolFacts.build_server_facts()
	context.get_tool_loader = Callable(callbacks, "get_tool_loader")
	context.get_tool_loader_status = Callable(callbacks, "get_tool_loader_status")
	context.get_server_stats = Callable(callbacks, "get_server_stats")
	context.get_editor_session_identity = Callable(callbacks, "get_editor_session_identity")
	context.get_freshness_snapshot = Callable(callbacks, "get_freshness_snapshot")
	context.log = Callable(callbacks, "log")
	context.server_name = str(server_facts.get("server_name", ""))
	context.server_version = str(server_facts.get("server_version", ""))
	context.protocol_version = str(server_facts.get("protocol_version", ""))
	context.tool_schema_version = str(server_facts.get("tool_schema_version", ""))
	service.configure(context)

	var rpc_response: Dictionary = service.build_json_rpc_response({"ok": true}, 7.0)
	if int(rpc_response.get("id", -1)) != 7:
		return _failure("JSON-RPC response did not normalize an integral float id.")

	var rpc_error: Dictionary = service.build_json_rpc_error(-32601, "Method not found", 3.0)
	var rpc_error_payload = rpc_error.get("error", {})
	if not (rpc_error_payload is Dictionary) or int((rpc_error_payload as Dictionary).get("code", 0)) != -32601:
		return _failure("JSON-RPC error payload did not preserve the error code.")

	var health: Dictionary = service.build_health_response()
	if str(health.get("status", "")) != "ok":
		return _failure("Health response did not reflect a healthy loader state.")
	if int(health.get("connections", -1)) != 3:
		return _failure("Health response did not project server stats.")
	if int(health.get("rejected_requests", -1)) != 1:
		return _failure("Health response did not project rejected request stats.")
	if str(health.get("last_request_id", "")) != "http-5-req-2":
		return _failure("Health response did not project the latest request identity.")
	if str(health.get("last_request_path", "")) != "/mcp":
		return _failure("Health response did not project the latest request path.")
	var client_sessions = health.get("client_sessions", [])
	if not (client_sessions is Array) or (client_sessions as Array).size() != 1:
		return _failure("Health response should expose active client sessions.")
	var client_session: Dictionary = (client_sessions as Array)[0]
	if str(client_session.get("connection_id", "")) != "http-5":
		return _failure("Health response client session should expose connection_id.")
	if str(client_session.get("last_request_id", "")) != "http-5-req-2":
		return _failure("Health response client session should expose the last request id.")
	if str(client_session.get("last_json_rpc_method", "")) != "tools/list":
		return _failure("Health response client session should summarize the latest JSON-RPC method.")
	var client_summary: Dictionary = client_session.get("client_summary", {})
	if str(client_summary.get("user_agent", "")) != "ContractClient/1.0":
		return _failure("Health response client session should retain the client summary.")
	if not bool(client_summary.get("authorization_present", false)) or client_summary.has("authorization"):
		return _failure("Health response client summary should only report authorization presence, not token contents.")
	var recent_client_sessions = health.get("recent_client_sessions", [])
	if not (recent_client_sessions is Array) or (recent_client_sessions as Array).is_empty():
		return _failure("Health response should expose recent disconnected client sessions.")
	if str(((recent_client_sessions as Array)[0] as Dictionary).get("connection_id", "")) != "http-4":
		return _failure("Health response recent client session should preserve the disconnected connection id.")
	if str(health.get("listen_host", "")) != "127.0.0.1" or int(health.get("listen_port", 0)) != 3000:
		return _failure("Health response should expose the MCP listen endpoint.")
	var health_identity: Dictionary = health.get("editor_session_identity", {})
	if str(health_identity.get("session_id", "")) != "health-contract-session":
		return _failure("Health response should expose the current editor session identity.")
	if bool(health_identity.get("safe_to_terminate", true)) or bool(health_identity.get("external_validation_process", true)):
		return _failure("Health response session identity must distinguish the current MCP editor from external validation processes.")
	if int(health.get("exposed_tool_count", 0)) != 2:
		return _failure("Health response did not count exposed tools from the loader.")
	if str(health.get("server_name", "")) != MCPProtocolFacts.get_server_name():
		return _failure("Health response did not expose the unified server name.")
	if str(health.get("server_version", "")) != MCPProtocolFacts.get_server_version():
		return _failure("Health response did not expose the unified server version.")
	if str(health.get("protocol_version", "")) != MCPProtocolFacts.get_protocol_version():
		return _failure("Health response did not expose the unified protocol version.")
	if str(health.get("tool_schema_version", "")) != MCPProtocolFacts.get_tool_schema_version():
		return _failure("Health response did not expose the unified tool schema version.")
	var server_info := MCPProtocolFacts.build_server_info()
	if str(server_info.get("description", "")).is_empty():
		return _failure("Unified server info should expose an MCP 2025-11-25 implementation description.")
	var freshness: Dictionary = health.get("freshness", {})
	if str(freshness.get("status", "")) != "fresh" or bool(freshness.get("needs_lifecycle_reload", true)):
		return _failure("Health response should expose plugin instance freshness.")
	var maintenance: Dictionary = health.get("maintenance", {})
	if bool(maintenance.get("active", true)) or str(maintenance.get("transport_state", "")) != "ready":
		return _failure("Health response should expose an idle maintenance window when the plugin is fresh.")
	if not health.has("maintenance_window") or not (health.get("maintenance_window") is Dictionary):
		return _failure("Health response should include a maintenance_window alias for clients.")
	var maintenance_window: Dictionary = health.get("maintenance_window", {})
	if str(maintenance_window.get("transport_state", "")) != str(maintenance.get("transport_state", "")):
		return _failure("Health response maintenance_window should mirror the maintenance contract.")
	callbacks.freshness_snapshot = {
		"status": "stale",
		"needs_lifecycle_reload": true,
		"lifecycle_reload": {
			"state": "scheduled",
			"pending": true,
			"last_request_id": "reload-1",
			"last_source": "tool"
		}
	}
	var maintenance_health: Dictionary = service.build_health_response()
	var active_maintenance: Dictionary = maintenance_health.get("maintenance_window", {})
	if not bool(active_maintenance.get("active", false)) or not bool(active_maintenance.get("disconnect_expected", false)):
		return _failure("Health response should expose an active maintenance window during lifecycle reload.")
	if not bool(active_maintenance.get("refetch_tools_required", false)) or int(active_maintenance.get("retry_after_ms", 0)) <= 0:
		return _failure("Health maintenance window should tell clients to retry and refetch tools after reconnect.")

	var cors_response: Dictionary = service.build_cors_response("http://localhost:5173", "POST")
	var cors_headers: Dictionary = cors_response.get("_headers", {})
	if int(cors_response.get("_status_code", 0)) != 204 or not bool(cors_response.get("_no_body", false)):
		return _failure("CORS response did not preserve preflight no-body semantics.")
	if str(cors_headers.get("Access-Control-Allow-Origin", "")) != "http://localhost:5173":
		return _failure("CORS response did not echo the configured origin.")
	if str(cors_headers.get("Access-Control-Allow-Origin", "")) == "*":
		return _failure("CORS response must not emit wildcard origins.")
	if str(cors_headers.get("Vary", "")) != "Origin":
		return _failure("CORS response did not include Vary: Origin.")
	if str(cors_headers.get("Access-Control-Allow-Headers", "")).find("MCP-Protocol-Version") == -1:
		return _failure("CORS response should allow the MCP-Protocol-Version header.")
	if str(cors_headers.get("Access-Control-Allow-Headers", "")).find("Mcp-Session-Id") == -1:
		return _failure("CORS response should allow the Mcp-Session-Id header.")
	if str(cors_headers.get("Access-Control-Allow-Headers", "")).find("Last-Event-ID") == -1:
		return _failure("CORS response should allow the Last-Event-ID resume cursor header.")

	var raw_sse_text := _send_raw_response_over_loopback(service, {
		"status": 406,
		"_content_type": "text/event-stream; charset=utf-8",
		"_raw_body": "event: endpoint\ndata: {}\n\n",
		"_headers": {
			"Cache-Control": "no-cache"
		}
	})
	if raw_sse_text.is_empty():
		return _failure("HTTP response service should send raw SSE responses.")
	if raw_sse_text.find("HTTP/1.1 406 Not Acceptable") == -1:
		return _failure("HTTP response service should use the correct 406 status text.")
	if raw_sse_text.find("Content-Type: text/event-stream; charset=utf-8") == -1:
		return _failure("HTTP response service should preserve raw SSE content type.")
	if raw_sse_text.find("Connection: keep-alive") == -1:
		return _failure("HTTP response service should keep raw SSE HTTP connections alive.")
	if raw_sse_text.find("event: endpoint\ndata: {}\n\n") == -1:
		return _failure("HTTP response service should write raw SSE bodies without JSON encoding.")

	var sanitized = service.sanitize_for_json({
		"nan": NAN,
		"node_path": NodePath("root/player"),
		"color": Color(0.1, 0.2, 0.3, 1.0)
	})
	if not (sanitized is Dictionary):
		return _failure("sanitize_for_json did not return a dictionary payload.")
	var sanitized_dict: Dictionary = sanitized
	if float(sanitized_dict.get("nan", 1.0)) != 0.0:
		return _failure("sanitize_for_json did not normalize NaN.")
	if str(sanitized_dict.get("node_path", "")) != "root/player":
		return _failure("sanitize_for_json did not normalize NodePath values.")
	var sanitized_color = sanitized_dict.get("color", {})
	if not (sanitized_color is Dictionary) or not (sanitized_color as Dictionary).has("r"):
		return _failure("sanitize_for_json did not normalize Color values.")

	return {
		"name": "http_response_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"health_status": str(health.get("status", "")),
			"exposed_tool_count": int(health.get("exposed_tool_count", 0)),
			"normalized_response_id": int(rpc_response.get("id", -1)),
			"server_version": str(health.get("server_version", ""))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "http_response_service_contracts",
		"success": false,
		"error": message
	}


func _send_raw_response_over_loopback(service, response_data: Dictionary) -> String:
	var port := _pick_free_port(34150)
	if port <= 0:
		return ""
	var server := TCPServer.new()
	if server.listen(port, "127.0.0.1") != OK:
		return ""
	var client := StreamPeerTCP.new()
	client.connect_to_host("127.0.0.1", port)
	var accepted: StreamPeerTCP = null
	for _i in range(120):
		if server.is_connection_available():
			accepted = server.take_connection()
			break
		Engine.get_main_loop().process_frame
	if accepted == null:
		server.stop()
		return ""
	if not service.send_http_response(accepted, response_data):
		server.stop()
		return ""
	var text := ""
	for _i in range(120):
		client.poll()
		var available := client.get_available_bytes()
		if available > 0:
			var packet := client.get_data(available)
			if int(packet[0]) == OK:
				text += (packet[1] as PackedByteArray).get_string_from_utf8()
		if text.find("\r\n\r\n") != -1 and text.find("event: endpoint") != -1:
			break
		Engine.get_main_loop().process_frame
	server.stop()
	return text


func _pick_free_port(start_port: int) -> int:
	for port in range(start_port, start_port + 20):
		var probe := TCPServer.new()
		if probe.listen(port, "127.0.0.1") == OK:
			probe.stop()
			return port
	return -1
