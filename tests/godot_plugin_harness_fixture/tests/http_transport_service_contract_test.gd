extends RefCounted

const HttpTransportServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_transport_service.gd")
const HttpTransportContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_transport_context.gd")
const HttpConnectionStateScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_connection_state.gd")
const HttpRequestDecoderScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_request_decoder.gd")


var _connected_count := 0
var _disconnected_count := 0
var _tick_count := 0
var _write_count := 0
var _last_method := ""
var _last_path := ""
var _last_body := ""
var _last_headers: Dictionary = {}
var _last_no_body := false
var _routed_bodies: Array[String] = []


func run_case(tree: SceneTree) -> Dictionary:
	_reset_state()

	var port := _pick_free_port(26340)
	if port < 0:
		return _failure("Could not reserve a TCP port for the HTTP transport contract server.")

	var tcp_server := TCPServer.new()
	if tcp_server.listen(port, "127.0.0.1") != OK:
		return _failure("Failed to start the HTTP transport contract server.")

	var client := StreamPeerTCP.new()
	client.connect_to_host("127.0.0.1", port)

	var connection_state = HttpConnectionStateScript.new()
	var decoder = HttpRequestDecoderScript.new()
	var transport = HttpTransportServiceScript.new()
	var context = HttpTransportContextScript.new()
	context.log = Callable(self, "_log")
	context.emit_client_connected = Callable(self, "_on_connected")
	context.emit_client_disconnected = Callable(self, "_on_disconnected")
	context.route_request_async = Callable(self, "_route_request_async")
	context.write_http_response = Callable(self, "_write_response")
	context.tick_loader = Callable(self, "_tick_loader")
	transport.configure(connection_state, decoder, context)

	var request_sent := false
	for _i in range(40):
		client.poll()
		if not request_sent and client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			var body := "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"ping\"}"
			var second_body := "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\"}"
			var frame := (
				"POST /mcp HTTP/1.1\r\n"
				+ "Host: localhost\r\n"
				+ "Origin: http://localhost:5173\r\n"
				+ "User-Agent: ContractClient/1.0\r\n"
				+ "Content-Type: application/json; charset=utf-8\r\n"
				+ "Content-Length: %d\r\n\r\n%s"
			) % [body.to_utf8_buffer().size(), body]
			var second_frame := (
				"POST /mcp HTTP/1.1\r\n"
				+ "Host: localhost\r\n"
				+ "Origin: http://localhost:5173\r\n"
				+ "User-Agent: ContractClient/1.0\r\n"
				+ "Content-Type: application/json; charset=utf-8\r\n"
				+ "Content-Length: %d\r\n\r\n%s"
			) % [second_body.to_utf8_buffer().size(), second_body]
			client.put_data((frame + second_frame).to_utf8_buffer())
			request_sent = true
		transport.process_frame(tcp_server, true, 0.016)
		if _write_count >= 2:
			break
		await tree.process_frame

	if _connected_count != 1:
		return _failure("HTTP transport should emit exactly one client_connected event.")
	if _write_count != 2:
		return _failure("HTTP transport should drain and write both pipelined responses from one socket read.")
	if _last_method != "POST" or _last_path != "/mcp":
		return _failure("HTTP transport did not preserve the routed request method or path.")
	if _routed_bodies != ["{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"ping\"}", "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\"}"]:
		return _failure("HTTP transport did not preserve both pipelined request bodies.")
	if str(_last_headers.get("origin", "")) != "http://localhost:5173":
		return _failure("HTTP transport did not preserve the Origin header for route security decisions.")
	if str(_last_headers.get("content-type", "")) != "application/json; charset=utf-8":
		return _failure("HTTP transport did not preserve the Content-Type header for route security decisions.")
	if _tick_count <= 0:
		return _failure("HTTP transport should tick the tool loader callback during processing.")
	var stats: Dictionary = connection_state.get_connection_stats()
	if int(stats.get("total_requests", 0)) != 2:
		return _failure("HTTP transport should record both processed pipelined requests.")
	if str(stats.get("last_request_id", "")) != "http-1-req-2":
		return _failure("HTTP transport should assign stable per-connection request identities.")
	if str(stats.get("last_request_path", "")) != "/mcp":
		return _failure("HTTP transport should record the last request path for audit diagnostics.")
	var client_sessions = stats.get("client_sessions", [])
	if not (client_sessions is Array) or (client_sessions as Array).size() != 1:
		return _failure("HTTP transport should expose one active client session summary.")
	var active_session: Dictionary = (client_sessions as Array)[0]
	if str(active_session.get("connection_id", "")) != "http-1":
		return _failure("HTTP transport client session should expose a stable connection id.")
	if int(active_session.get("request_count", 0)) != 2:
		return _failure("HTTP transport client session should count requests per connection.")
	if str(active_session.get("last_json_rpc_method", "")) != "tools/list":
		return _failure("HTTP transport client session should summarize the last JSON-RPC method without changing the response payload.")
	var client_summary: Dictionary = active_session.get("client_summary", {})
	if str(client_summary.get("origin", "")) != "http://localhost:5173":
		return _failure("HTTP transport client summary should retain the request Origin.")
	if str(client_summary.get("user_agent", "")) != "ContractClient/1.0":
		return _failure("HTTP transport client summary should retain the User-Agent.")
	var recent_requests = active_session.get("recent_requests", [])
	if not (recent_requests is Array) or (recent_requests as Array).size() != 2:
		return _failure("HTTP transport client session should retain recent request summaries.")
	if str(((recent_requests as Array)[0] as Dictionary).get("request_id", "")) != "http-1-req-1":
		return _failure("HTTP transport recent request audit should preserve the first request id.")

	client.disconnect_from_host()
	for _i in range(20):
		client.poll()
		transport.process_frame(tcp_server, true, 0.016)
		if _disconnected_count > 0:
			break
		await tree.process_frame

	tcp_server.stop()

	if _disconnected_count != 1:
		return _failure("HTTP transport should emit exactly one client_disconnected event after disconnect.")
	if connection_state.get_connection_count() != 0:
		return _failure("HTTP transport should clear disconnected clients from connection state.")
	var disconnected_stats: Dictionary = connection_state.get_connection_stats()
	var recent_client_sessions = disconnected_stats.get("recent_client_sessions", [])
	if not (recent_client_sessions is Array) or (recent_client_sessions as Array).is_empty():
		return _failure("HTTP transport should retain a recent disconnected client session for diagnostics.")
	var disconnected_session: Dictionary = (recent_client_sessions as Array)[0]
	if bool(disconnected_session.get("active", true)):
		return _failure("HTTP transport recent client session should be marked inactive after disconnect.")
	if str(disconnected_session.get("connection_id", "")) != "http-1":
		return _failure("HTTP transport recent client session should preserve the stable connection id.")

	return {
		"name": "http_transport_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"connected_count": _connected_count,
			"disconnected_count": _disconnected_count,
			"tick_count": _tick_count,
			"last_method": _last_method
		}
	}


func _route_request_async(method: String, path: String, body: String, headers: Dictionary) -> Dictionary:
	_last_method = method
	_last_path = path
	_last_body = body
	_last_headers = headers.duplicate(true)
	_routed_bodies.append(body)
	await (Engine.get_main_loop() as SceneTree).process_frame
	return {
		"status": 200,
		"body": "ok"
	}


func _write_response(_client: StreamPeerTCP, _data: Dictionary, no_body: bool = false) -> bool:
	_write_count += 1
	_last_no_body = no_body
	return true


func _tick_loader(_delta: float) -> void:
	_tick_count += 1


func _on_connected() -> void:
	_connected_count += 1


func _on_disconnected() -> void:
	_disconnected_count += 1


func _log(_message: String, _level: String = "debug") -> void:
	pass


func _pick_free_port(start_port: int) -> int:
	for port in range(start_port, start_port + 20):
		var probe := TCPServer.new()
		if probe.listen(port, "127.0.0.1") == OK:
			probe.stop()
			return port
	return -1


func _reset_state() -> void:
	_connected_count = 0
	_disconnected_count = 0
	_tick_count = 0
	_write_count = 0
	_last_method = ""
	_last_path = ""
	_last_body = ""
	_last_headers = {}
	_last_no_body = false
	_routed_bodies = []


func _failure(message: String) -> Dictionary:
	return {
		"name": "http_transport_service_contracts",
		"success": false,
		"error": message
	}
