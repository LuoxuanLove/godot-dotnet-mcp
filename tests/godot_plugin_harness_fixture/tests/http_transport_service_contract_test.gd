extends RefCounted

const HttpTransportServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_transport_service.gd")
const HttpTransportContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_transport_context.gd")
const HttpConnectionStateScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_connection_state.gd")
const HttpRequestDecoderScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_request_decoder.gd")
const HttpSseEventQueueScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_sse_event_queue.gd")

const MAX_HTTP_BODY_BYTES := 1024 * 1024
const TEST_PENDING_REQUEST_BYTES := 512
const OVERSIZED_DECLARED_HTTP_BODY_BYTES := MAX_HTTP_BODY_BYTES + 1
const OVERSIZED_PENDING_BODY_BYTES := TEST_PENDING_REQUEST_BYTES + 256

var _connected_count := 0
var _disconnected_count := 0
var _tick_count := 0
var _write_count := 0
var _sse_open_count := 0
var _sse_heartbeat_count := 0
var _sse_event_write_count := 0
var _last_method := ""
var _last_path := ""
var _last_body := ""
var _last_headers: Dictionary = {}
var _last_no_body := false
var _last_response: Dictionary = {}
var _sse_event_bodies: Array[String] = []
var _queued_sse_events: Array[Dictionary] = []
var _queued_sse_next_index := 0
var _routed_bodies: Array[String] = []
var _record_routed_body_content := true


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
				+ "MCP-Protocol-Version: 2025-11-25\r\n"
				+ "Mcp-Session-Id: transport-session-1\r\n"
				+ "Content-Length: %d\r\n\r\n%s"
			) % [body.to_utf8_buffer().size(), body]
			var second_frame := (
				"POST /mcp HTTP/1.1\r\n"
				+ "Host: localhost\r\n"
				+ "Origin: http://localhost:5173\r\n"
				+ "User-Agent: ContractClient/1.0\r\n"
				+ "Content-Type: application/json; charset=utf-8\r\n"
				+ "MCP-Protocol-Version: 2025-11-25\r\n"
				+ "Mcp-Session-Id: transport-session-1\r\n"
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
	if str(client_summary.get("mcp_protocol_version", "")) != "2025-11-25":
		return _failure("HTTP transport client summary should retain the MCP protocol version.")
	if not bool(client_summary.get("mcp_session_present", false)):
		return _failure("HTTP transport client summary should retain MCP session presence without exposing the session id.")
	if client_summary.has("mcp_session_id"):
		return _failure("HTTP transport client summary must not expose raw MCP session ids.")
	var recent_requests = active_session.get("recent_requests", [])
	if not (recent_requests is Array) or (recent_requests as Array).size() != 2:
		return _failure("HTTP transport client session should retain recent request summaries.")
	if str(((recent_requests as Array)[0] as Dictionary).get("request_id", "")) != "http-1-req-1":
		return _failure("HTTP transport recent request audit should preserve the first request id.")
	if str(((recent_requests as Array)[0] as Dictionary).get("mcp_protocol_version", "")) != "2025-11-25":
		return _failure("HTTP transport recent request audit should preserve the MCP protocol version.")
	if not bool(((recent_requests as Array)[0] as Dictionary).get("mcp_session_present", false)):
		return _failure("HTTP transport recent request audit should preserve MCP session presence without exposing the session id.")
	if ((recent_requests as Array)[0] as Dictionary).has("mcp_session_id"):
		return _failure("HTTP transport recent request audit must not expose raw MCP session ids.")

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

	var sse_stream_check: Dictionary = await _run_sse_stream_lifecycle_contract(tree)
	if not bool(sse_stream_check.get("success", false)):
		return sse_stream_check

	var sse_bounded_cursor_check: Dictionary = _run_sse_event_queue_bounded_cursor_contract()
	if not bool(sse_bounded_cursor_check.get("success", false)):
		return sse_bounded_cursor_check

	var invalid_length_check: Dictionary = await _run_bad_content_length_contract(
		tree,
		"POST /mcp HTTP/1.1\r\nContent-Length: nope\r\n\r\n{}",
		"Invalid",
		26370
	)
	if not bool(invalid_length_check.get("success", false)):
		return invalid_length_check

	var oversized_length_check: Dictionary = await _run_bad_content_length_contract(
		tree,
		"POST /mcp HTTP/1.1\r\nContent-Length: %d\r\n\r\n{}" % (MAX_HTTP_BODY_BYTES + 1),
		"Oversized",
		26390
	)
	if not bool(oversized_length_check.get("success", false)):
		return oversized_length_check

	var complete_oversized_length_check: Dictionary = await _run_pending_limit_oversized_content_length_contract(tree)
	if not bool(complete_oversized_length_check.get("success", false)):
		return complete_oversized_length_check

	var max_length_check: Dictionary = await _run_max_content_length_contract(tree)
	if not bool(max_length_check.get("success", false)):
		return max_length_check

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


func _run_bad_content_length_contract(tree: SceneTree, frame: String, label: String, start_port: int) -> Dictionary:
	_reset_state()
	var port := _pick_free_port(start_port)
	if port < 0:
		return _failure("Could not reserve a TCP port for the %s HTTP transport contract server." % label.to_lower())

	var tcp_server := TCPServer.new()
	if tcp_server.listen(port, "127.0.0.1") != OK:
		return _failure("Failed to start the %s HTTP transport contract server." % label.to_lower())

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
	context.write_sse_stream_open = Callable(self, "_write_sse_stream_open")
	context.write_sse_heartbeat = Callable(self, "_write_sse_heartbeat")
	context.write_sse_events = Callable(self, "_write_sse_events")
	context.get_sse_events_since_index = Callable(self, "_get_sse_events_since_index")
	context.tick_loader = Callable(self, "_tick_loader")
	transport.configure(connection_state, decoder, context)

	var request_sent := false
	for _i in range(40):
		client.poll()
		if not request_sent and client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			client.put_data(frame.to_utf8_buffer())
			request_sent = true
		transport.process_frame(tcp_server, true, 0.016)
		if _write_count >= 1 and _disconnected_count >= 1:
			break
		await tree.process_frame

	tcp_server.stop()

	if _connected_count != 1:
		return _failure("%s HTTP framing should still emit one client_connected event." % label)
	if not _routed_bodies.is_empty():
		return _failure("%s HTTP Content-Length should not route a request body." % label)
	if _write_count != 1:
		return _failure("%s HTTP Content-Length should write exactly one 400 response." % label)
	if int(_last_response.get("_status_code", 0)) != 400:
		return _failure("%s HTTP Content-Length should return HTTP 400." % label)
	var error_payload: Dictionary = _last_response.get("error", {})
	if int(error_payload.get("code", 0)) != -32700:
		return _failure("%s HTTP Content-Length should return a JSON-RPC parse/framing error." % label)
	var error_data: Dictionary = error_payload.get("data", {})
	if str(error_data.get("type", "")) != "bad_content_length":
		return _failure("%s HTTP Content-Length should report bad_content_length." % label)
	var stats: Dictionary = connection_state.get_connection_stats()
	if int(stats.get("rejected_requests", 0)) != 1:
		return _failure("%s HTTP Content-Length should increment rejected request diagnostics." % label)
	if int(stats.get("total_requests", 0)) != 0:
		return _failure("%s HTTP Content-Length should not be recorded as a routed request." % label)
	if _disconnected_count != 1:
		return _failure("%s HTTP Content-Length should close and remove the client." % label)
	return {"success": true, "error": ""}


func _run_pending_limit_oversized_content_length_contract(tree: SceneTree) -> Dictionary:
	_reset_state()
	var port := _pick_free_port(26410)
	if port < 0:
		return _failure("Could not reserve a TCP port for the pending-limit oversized HTTP transport contract server.")

	var tcp_server := TCPServer.new()
	if tcp_server.listen(port, "127.0.0.1") != OK:
		return _failure("Failed to start the pending-limit oversized HTTP transport contract server.")

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
	context.max_pending_request_bytes = TEST_PENDING_REQUEST_BYTES
	transport.configure(connection_state, decoder, context)

	var body := "B".repeat(OVERSIZED_PENDING_BODY_BYTES)
	var header := (
		"POST /mcp HTTP/1.1\r\n"
		+ "Host: localhost\r\n"
		+ "Content-Type: application/json\r\n"
		+ "Content-Length: %d\r\n\r\n" % OVERSIZED_DECLARED_HTTP_BODY_BYTES
	)
	var frame := header + body
	var frame_size := frame.to_utf8_buffer().size()
	if frame_size <= TEST_PENDING_REQUEST_BYTES:
		return _failure("Pending-limit oversized HTTP Content-Length fixture must exceed the test pending buffer allowance.")
	if frame_size >= MAX_HTTP_BODY_BYTES:
		return _failure("Pending-limit oversized HTTP Content-Length fixture should stay small enough for the contract harness.")

	var frame_bytes := frame.to_utf8_buffer()
	var request_sent := false
	for _i in range(160):
		client.poll()
		if not request_sent and client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			var offset := 0
			while offset < frame_bytes.size():
				var end = mini(offset + 65536, frame_bytes.size())
				client.put_data(frame_bytes.slice(offset, end))
				offset = end
			request_sent = true
		transport.process_frame(tcp_server, true, 0.016)
		if _write_count >= 1 and _disconnected_count >= 1:
			break
		await tree.process_frame

	tcp_server.stop()

	if _connected_count != 1:
		return _failure("Pending-limit oversized HTTP Content-Length should emit one client_connected event.")
	if not _routed_bodies.is_empty():
		return _failure("Pending-limit oversized HTTP Content-Length should not route a request body.")
	if _write_count != 1:
		return _failure("Pending-limit oversized HTTP Content-Length should write exactly one 400 response.")
	if int(_last_response.get("_status_code", 0)) != 400:
		return _failure("Pending-limit oversized HTTP Content-Length should return HTTP 400.")
	var error_payload: Dictionary = _last_response.get("error", {})
	var error_data: Dictionary = error_payload.get("data", {})
	if str(error_data.get("type", "")) != "bad_content_length":
		return _failure("Pending-limit oversized HTTP Content-Length should report bad_content_length.")
	var stats: Dictionary = connection_state.get_connection_stats()
	if int(stats.get("rejected_requests", 0)) != 1:
		return _failure("Pending-limit oversized HTTP Content-Length should increment rejected request diagnostics.")
	if int(stats.get("total_requests", 0)) != 0:
		return _failure("Pending-limit oversized HTTP Content-Length should not be recorded as a routed request.")
	if _disconnected_count != 1:
		return _failure("Pending-limit oversized HTTP Content-Length should close and remove the client.")
	if connection_state.get_connection_count() != 0:
		return _failure("Pending-limit oversized HTTP Content-Length should remove the disconnected client from connection state.")
	return {"success": true, "error": ""}


func _run_sse_stream_lifecycle_contract(tree: SceneTree) -> Dictionary:
	_reset_state()
	var port := _pick_free_port(26450)
	if port < 0:
		return _failure("Could not reserve a TCP port for the SSE lifecycle HTTP transport contract server.")

	var tcp_server := TCPServer.new()
	if tcp_server.listen(port, "127.0.0.1") != OK:
		return _failure("Failed to start the SSE lifecycle HTTP transport contract server.")

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
	context.write_sse_stream_open = Callable(self, "_write_sse_stream_open")
	context.write_sse_heartbeat = Callable(self, "_write_sse_heartbeat")
	context.write_sse_events = Callable(self, "_write_sse_events")
	context.get_sse_events_since_index = Callable(self, "_get_sse_events_since_index")
	context.tick_loader = Callable(self, "_tick_loader")
	transport.configure(connection_state, decoder, context)

	var request_sent := false
	for _i in range(80):
		client.poll()
		if not request_sent and client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			var frame := (
				"GET /mcp HTTP/1.1\r\n"
				+ "Host: localhost\r\n"
				+ "Accept: text/event-stream\r\n"
				+ "MCP-Protocol-Version: 2025-11-25\r\n"
				+ "Mcp-Session-Id: transport-sse-1\r\n\r\n"
			)
			client.put_data(frame.to_utf8_buffer())
			request_sent = true
		transport.process_frame(tcp_server, true, 0.016)
		if _sse_open_count >= 1 and _sse_heartbeat_count >= 1:
			break
		await tree.process_frame

	_queued_sse_events = [
		{
			"id": "server-notification-1",
			"retry": 1000,
			"event": "message",
			"data": {
				"jsonrpc": "2.0",
				"method": "notifications/message",
				"params": {
					"level": "info",
					"logger": "godot-dotnet-mcp.transport",
					"data": {"delivered": true}
				}
			}
		}
	]
	_queued_sse_next_index = 2
	for _i in range(40):
		client.poll()
		transport.process_frame(tcp_server, true, 0.016)
		if _sse_event_write_count >= 1:
			break
		await tree.process_frame

	if _connected_count != 1:
		tcp_server.stop()
		return _failure("SSE lifecycle transport should emit one client_connected event.")
	if _write_count != 0:
		tcp_server.stop()
		return _failure("SSE lifecycle transport should not use ordinary JSON response writing for streaming GET /mcp.")
	if _sse_open_count != 1:
		tcp_server.stop()
		return _failure("SSE lifecycle transport should open exactly one long-lived SSE stream.")
	if _sse_heartbeat_count < 1:
		tcp_server.stop()
		return _failure("SSE lifecycle transport should tick heartbeat delivery for open streams.")
	var stats: Dictionary = connection_state.get_connection_stats()
	var client_sessions = stats.get("client_sessions", [])
	if not (client_sessions is Array) or (client_sessions as Array).size() != 1:
		tcp_server.stop()
		return _failure("SSE lifecycle transport should expose one active streaming client session.")
	var active_session: Dictionary = (client_sessions as Array)[0]
	if str(active_session.get("transport_mode", "")) != "sse":
		tcp_server.stop()
		return _failure("SSE lifecycle transport should mark active client sessions with transport_mode=sse.")
	if int(active_session.get("sse_last_heartbeat_at_unix", 0)) <= 0:
		tcp_server.stop()
		return _failure("SSE lifecycle transport should record heartbeat time for diagnostics.")
	if str(_last_response.get("_raw_body", "")).find("transport-sse-open") == -1:
		tcp_server.stop()
		return _failure("SSE lifecycle transport should pass initial stream events to the SSE writer.")
	if _sse_event_write_count != 1:
		tcp_server.stop()
		return _failure("SSE lifecycle transport should drain queued server-to-client events for open streams.")
	if _sse_event_bodies.is_empty() or _sse_event_bodies[0].find("server-notification-1") == -1 or _sse_event_bodies[0].find("\"method\":\"notifications/message\"") == -1:
		tcp_server.stop()
		return _failure("SSE lifecycle transport should write queued server-to-client events as SSE messages.")
	stats = connection_state.get_connection_stats()
	client_sessions = stats.get("client_sessions", [])
	active_session = (client_sessions as Array)[0]
	if int(active_session.get("sse_next_event_index", 0)) < 2:
		tcp_server.stop()
		return _failure("SSE lifecycle transport should advance the queued event cursor after delivery.")

	client.disconnect_from_host()
	for _i in range(40):
		client.poll()
		transport.process_frame(tcp_server, true, 0.016)
		if _disconnected_count > 0:
			break
		await tree.process_frame

	tcp_server.stop()

	if _disconnected_count != 1:
		return _failure("SSE lifecycle transport should emit client_disconnected after stream disconnect.")
	if connection_state.get_connection_count() != 0:
		return _failure("SSE lifecycle transport should clear disconnected streaming clients.")
	var disconnected_stats: Dictionary = connection_state.get_connection_stats()
	var recent_client_sessions = disconnected_stats.get("recent_client_sessions", [])
	if not (recent_client_sessions is Array) or (recent_client_sessions as Array).is_empty():
		return _failure("SSE lifecycle transport should retain recent disconnected streaming sessions.")
	var disconnected_session: Dictionary = (recent_client_sessions as Array)[0]
	if str(disconnected_session.get("transport_mode", "")) != "sse":
		return _failure("SSE lifecycle transport should preserve transport_mode=sse in recent diagnostics.")
	return {"success": true, "error": ""}


func _run_sse_event_queue_bounded_cursor_contract() -> Dictionary:
	var queue = HttpSseEventQueueScript.new()
	for index in range(32):
		queue.append_event("bounded-active-stream", "message", {"index": index + 1}, "bounded")
	var next_event_index := int(queue.event_count("bounded-active-stream"))
	if next_event_index != 32:
		queue.dispose()
		return _failure("SSE event queue should expose the next absolute event index before truncation.")
	queue.append_event("bounded-active-stream", "message", {"index": 33}, "bounded")
	var new_events: Array = queue.events_since_index("bounded-active-stream", next_event_index)
	if new_events.size() != 1:
		queue.dispose()
		return _failure("SSE event queue should deliver events appended after a full bounded log to active stream cursors.")
	var new_event: Dictionary = new_events[0]
	if str(new_event.get("id", "")) != "bounded-bounded-active-stream-33":
		queue.dispose()
		return _failure("SSE event queue should preserve monotonic event ids after bounded log truncation.")
	var retained_events: Array = queue.events_since_index("bounded-active-stream", 0)
	if retained_events.size() != 32:
		queue.dispose()
		return _failure("SSE event queue should keep only the bounded retained window for stale absolute cursors.")
	var first_retained: Dictionary = retained_events[0]
	if str(first_retained.get("id", "")) != "bounded-bounded-active-stream-2":
		queue.dispose()
		return _failure("SSE event queue should advance the retained-window base index after truncation.")
	var stale_batch: Dictionary = queue.events_since_index_with_cursor("bounded-active-stream", 0)
	if int(stale_batch.get("next_index", 0)) != 33:
		queue.dispose()
		return _failure("SSE event queue should expose the true next absolute cursor for stale retained-window reads.")
	var stale_resume_status: Dictionary = queue.resume_status("bounded-active-stream", "bounded-bounded-active-stream-1")
	if bool(stale_resume_status.get("found", true)):
		queue.dispose()
		return _failure("SSE event queue should report stale retained-window cursor ids as not found.")
	if str(stale_resume_status.get("status", "")) != "stale_cursor":
		queue.dispose()
		return _failure("SSE event queue should distinguish stale retained-window cursors from unknown sessions.")
	if int(stale_resume_status.get("base_index", 0)) != 1 or int(stale_resume_status.get("next_index", 0)) != 33:
		queue.dispose()
		return _failure("SSE event queue should expose retained-window bounds for stale cursor diagnostics.")
	var unknown_cursor_status: Dictionary = queue.resume_status("bounded-active-stream", "bounded-bounded-active-stream-999")
	if str(unknown_cursor_status.get("status", "")) != "unknown_cursor":
		queue.dispose()
		return _failure("SSE event queue should distinguish existing-session unknown cursors from stale retained-window cursors.")
	var foreign_cursor_status: Dictionary = queue.resume_status("bounded-active-stream", "bounded-other-stream-1")
	if str(foreign_cursor_status.get("status", "")) != "unknown_cursor":
		queue.dispose()
		return _failure("SSE event queue should not report foreign session cursors as stale retained-window cursors.")
	var unknown_resume_status: Dictionary = queue.resume_status("missing-bounded-stream", "bounded-missing-1")
	if str(unknown_resume_status.get("status", "")) != "unknown_session":
		queue.dispose()
		return _failure("SSE event queue should distinguish unknown sessions from stale cursors.")
	var repeated_batch: Dictionary = queue.events_since_index_with_cursor("bounded-active-stream", int(stale_batch.get("next_index", 0)))
	if not (repeated_batch.get("events", []) as Array).is_empty():
		queue.dispose()
		return _failure("SSE event queue should not repeat retained-window events after the true next cursor is acknowledged.")
	queue.dispose()
	return {"success": true, "error": ""}


func _run_max_content_length_contract(tree: SceneTree) -> Dictionary:
	_reset_state()
	_record_routed_body_content = false
	var port := _pick_free_port(26430)
	if port < 0:
		return _failure("Could not reserve a TCP port for the maximum HTTP body contract server.")

	var tcp_server := TCPServer.new()
	if tcp_server.listen(port, "127.0.0.1") != OK:
		return _failure("Failed to start the maximum HTTP body contract server.")

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
	for _i in range(220):
		client.poll()
		if not request_sent and client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			var body := "{\"padding\":\"" + "A".repeat(MAX_HTTP_BODY_BYTES - 14) + "\"}"
			var header := (
				"POST /mcp HTTP/1.1\r\n"
				+ "Host: localhost\r\n"
				+ "Origin: http://localhost:5173\r\n"
				+ "User-Agent: ContractClient/1.0\r\n"
				+ "Content-Type: application/json\r\n"
				+ "Content-Length: %d\r\n\r\n"
			) % body.to_utf8_buffer().size()
			client.put_data(header.to_utf8_buffer())
			client.put_data(body.to_utf8_buffer())
			request_sent = true
		transport.process_frame(tcp_server, true, 0.016)
		if _write_count >= 1:
			break
		await tree.process_frame

	tcp_server.stop()
	_record_routed_body_content = true

	if _connected_count != 1:
		return _failure("Maximum HTTP Content-Length should emit one client_connected event.")
	if _write_count != 1:
		return _failure("Maximum HTTP Content-Length should route and write one response.")
	if _routed_bodies != ["bytes:%d" % MAX_HTTP_BODY_BYTES]:
		return _failure("Maximum HTTP Content-Length should route the full body without storing test fixture body copies.")
	if int(_last_response.get("status", 0)) != 200:
		return _failure("Maximum HTTP Content-Length should receive the routed HTTP 200 response.")
	var stats: Dictionary = connection_state.get_connection_stats()
	if int(stats.get("rejected_requests", 0)) != 0:
		return _failure("Maximum HTTP Content-Length should not increment rejected request diagnostics.")
	if int(stats.get("total_requests", 0)) != 1:
		return _failure("Maximum HTTP Content-Length should be recorded as one routed request.")
	client.disconnect_from_host()
	return {"success": true, "error": ""}


func _route_request_async(method: String, path: String, body: String, headers: Dictionary) -> Dictionary:
	_last_method = method
	_last_path = path
	if _record_routed_body_content:
		_last_body = body
		_routed_bodies.append(body)
	else:
		_last_body = "bytes:%d" % body.to_utf8_buffer().size()
		_routed_bodies.append(_last_body)
	_last_headers = headers.duplicate(true)
	await (Engine.get_main_loop() as SceneTree).process_frame
	if method == "GET" and path == "/mcp":
		return {
			"status": 200,
			"_stream_mode": "sse",
			"_raw_body": "id: transport-sse-open\nretry: 1000\nevent: message\ndata: {}\n\n",
			"_sse_session_id": "transport-sse-1",
			"_sse_next_event_index": 1,
			"_headers": {
				"MCP-Protocol-Version": "2025-11-25",
				"Mcp-Session-Id": "transport-sse-1"
			}
		}
	return {
		"status": 200,
		"body": "ok"
	}


func _write_response(_client: StreamPeerTCP, _data: Dictionary, no_body: bool = false) -> bool:
	_write_count += 1
	_last_no_body = no_body
	_last_response = _data.duplicate(true)
	return true


func _write_sse_stream_open(_client: StreamPeerTCP, _data: Dictionary) -> bool:
	_sse_open_count += 1
	_last_response = _data.duplicate(true)
	return true


func _write_sse_heartbeat(_client: StreamPeerTCP) -> bool:
	_sse_heartbeat_count += 1
	return true


func _write_sse_events(_client: StreamPeerTCP, body: String) -> bool:
	_sse_event_write_count += 1
	_sse_event_bodies.append(body)
	return true


func _get_sse_events_since_index(session_id: String, start_index: int):
	if session_id != "transport-sse-1":
		return {"events": [], "next_index": start_index}
	if start_index > 1:
		return {"events": [], "next_index": start_index}
	return {
		"events": _queued_sse_events.duplicate(true),
		"next_index": _queued_sse_next_index
	}


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
	_sse_open_count = 0
	_sse_heartbeat_count = 0
	_sse_event_write_count = 0
	_last_method = ""
	_last_path = ""
	_last_body = ""
	_last_headers = {}
	_last_no_body = false
	_last_response = {}
	_sse_event_bodies = []
	_queued_sse_events = []
	_queued_sse_next_index = 0
	_routed_bodies = []
	_record_routed_body_content = true


func _failure(message: String) -> Dictionary:
	return {
		"name": "http_transport_service_contracts",
		"success": false,
		"error": message
	}
