@tool
extends RefCounted

var _connection_state = null
var _request_decoder = null
var _log_callback := Callable()
var _emit_client_connected := Callable()
var _emit_client_disconnected := Callable()
var _route_request_async := Callable()
var _write_http_response := Callable()
var _write_sse_stream_open := Callable()
var _write_sse_heartbeat := Callable()
var _write_sse_events := Callable()
var _get_sse_events_since_index := Callable()
var _tick_loader := Callable()
var _max_pending_request_bytes := DEFAULT_MAX_PENDING_REQUEST_BYTES

const MAX_REQUESTS_PER_DRAIN := 16
const MAX_ACCEPTS_PER_FRAME := 8
const MAX_REQUEST_HEADER_BYTES := 64 * 1024
const DEFAULT_MAX_PENDING_REQUEST_BYTES := (1024 * 1024) + MAX_REQUEST_HEADER_BYTES
const SSE_HEARTBEAT_INTERVAL_SECONDS := 15


func configure(connection_state, request_decoder, context = null) -> void:
	_connection_state = connection_state
	_request_decoder = request_decoder
	_max_pending_request_bytes = DEFAULT_MAX_PENDING_REQUEST_BYTES
	if context == null:
		_reset_callbacks()
		return
	_log_callback = context.log
	_emit_client_connected = context.emit_client_connected
	_emit_client_disconnected = context.emit_client_disconnected
	_route_request_async = context.route_request_async
	_write_http_response = context.write_http_response
	_write_sse_stream_open = context.write_sse_stream_open
	_write_sse_heartbeat = context.write_sse_heartbeat
	_write_sse_events = context.write_sse_events
	_get_sse_events_since_index = context.get_sse_events_since_index
	_tick_loader = context.tick_loader
	if int(context.max_pending_request_bytes) > 0:
		_max_pending_request_bytes = int(context.max_pending_request_bytes)


func dispose() -> void:
	_connection_state = null
	_request_decoder = null
	_reset_callbacks()


func process_frame(tcp_server: TCPServer, running: bool, delta: float) -> void:
	if not running or tcp_server == null or _connection_state == null:
		return

	_accept_new_connections(tcp_server)

	var clients_to_remove: Array[StreamPeerTCP] = []
	for client in _connection_state.get_clients_snapshot():
		var should_remove := _process_client(client)
		if should_remove:
			clients_to_remove.append(client)

	for client in clients_to_remove:
		_connection_state.remove_client(client)
		_log("Client disconnected", "info")
		if _emit_client_disconnected.is_valid():
			_emit_client_disconnected.call()

	if _tick_loader.is_valid():
		_tick_loader.call(delta)


func _accept_new_connections(tcp_server: TCPServer) -> void:
	var accepted_count := 0
	while accepted_count < MAX_ACCEPTS_PER_FRAME and tcp_server.is_connection_available():
		var client = tcp_server.take_connection()
		if client == null:
			return
		_connection_state.add_client(client)
		accepted_count += 1
		_log("Client connected (total: %d)" % _connection_state.get_connection_count(), "info")
		if _emit_client_connected.is_valid():
			_emit_client_connected.call()


func _process_client(client: StreamPeerTCP) -> bool:
	client.poll()
	var status = client.get_status()

	if status == StreamPeerTCP.STATUS_CONNECTED:
		if _connection_state.is_processing(client):
			return false
		if _connection_state.has_method("is_sse_streaming") and bool(_connection_state.is_sse_streaming(client)):
			return _process_sse_streaming_client(client)
		var available = client.get_available_bytes()
		if available > 0:
			var data = client.get_data(available)
			if data[0] != OK:
				_log("Error receiving data: %s" % data[0], "warning")
				return false
			var request_str = data[1].get_string_from_utf8()
			var pending_data = _connection_state.get_pending_data(client) + request_str
			var pending_byte_size: int = pending_data.to_utf8_buffer().size()
			if pending_byte_size > _max_pending_request_bytes:
				if _try_handle_pending_framing_error(client, pending_data):
					return true
				_log("Closing client with oversized pending HTTP request buffer: %d bytes" % pending_byte_size, "warning")
				if _connection_state.has_method("record_rejected_request"):
					_connection_state.record_rejected_request()
				client.disconnect_from_host()
				return true
			_connection_state.set_pending_data(client, pending_data)
			_log("Received %d bytes, total pending: %d" % [available, pending_data.length()], "debug")
		if not _connection_state.get_pending_data(client).is_empty():
			_process_http_request_async(client)
		return false

	if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
		_log("Client status changed: %s" % status, "debug")
		return true

	return false


func _try_handle_pending_framing_error(client: StreamPeerTCP, pending_data: String) -> bool:
	if _request_decoder == null:
		return false
	var decoded_request: Dictionary = _request_decoder.decode_pending_request(pending_data)
	if not bool(decoded_request.get("ready", false)):
		return false
	if not bool(decoded_request.get("framing_error", false)):
		return false
	_handle_framing_error(client, decoded_request)
	return true


func _process_http_request_async(client: StreamPeerTCP) -> void:
	if _connection_state.is_processing(client):
		return
	if _request_decoder == null:
		return

	var drained_count := 0
	while _connection_state != null and _connection_state.has_client(client):
		var data = _connection_state.get_pending_data(client)
		if data.is_empty():
			return
		var decoded_request: Dictionary = _request_decoder.decode_pending_request(data)
		if not bool(decoded_request.get("ready", false)):
			_log_pending_request_wait(decoded_request, data)
			return
		if bool(decoded_request.get("framing_error", false)):
			_handle_framing_error(client, decoded_request)
			return

		var headers: Dictionary = decoded_request.get("headers", {})
		_connection_state.set_pending_data(client, str(decoded_request.get("remaining_data", "")))
		if headers.is_empty():
			if _connection_state.get_pending_data(client).is_empty():
				return
			continue

		var request_body := str(decoded_request.get("request_body", ""))
		var content_length := int(decoded_request.get("content_length", 0))
		var body_byte_size := int(decoded_request.get("body_byte_size", 0))
		var is_chunked := bool(decoded_request.get("is_chunked", false))

		_log(
			"Request headers: method=%s, content_length=%d, body_bytes=%d, chunked=%s"
			% [headers.get("method", "?"), content_length, body_byte_size, is_chunked],
			"debug"
		)

		_connection_state.mark_processing(client)
		var method := str(headers.get("method", "GET"))
		var path := str(headers.get("path", "/"))
		_log("Processing: %s %s (body: %d bytes)" % [method, path, request_body.length()], "debug")
		var request_id := ""
		if _connection_state.has_method("record_request"):
			request_id = str(_connection_state.record_request(method, client, path, headers, request_body, body_byte_size))
		_log("Request audit identity: connection_request_id=%s" % request_id, "debug")

		if not _route_request_async.is_valid() or not _write_http_response.is_valid():
			_connection_state.clear_processing(client)
			return

		var response: Dictionary = await _route_request_async.call(method, path, request_body, headers)
		var no_body := bool(response.get("_no_body", false))
		if response.has("_no_body"):
			response.erase("_no_body")
		var stream_mode := str(response.get("_stream_mode", "")).strip_edges()
		if response.has("_stream_mode"):
			response.erase("_stream_mode")

		if _connection_state == null:
			return
		if _connection_state.has_client(client) and client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			var write_ok := false
			if stream_mode == "sse":
				write_ok = _open_sse_stream(client, response)
			else:
				write_ok = bool(_write_http_response.call(client, response, no_body))
			if not write_ok:
				_log("Closing client after HTTP response write failure", "warning")
				client.disconnect_from_host()
				_connection_state.clear_processing(client)
				return
			if stream_mode == "sse":
				_connection_state.clear_processing(client)
				return
		_connection_state.clear_processing(client)

		drained_count += 1
		if drained_count >= MAX_REQUESTS_PER_DRAIN and not _connection_state.get_pending_data(client).is_empty():
			call_deferred("_process_http_request_async", client)
			return


func _handle_framing_error(client: StreamPeerTCP, decoded_request: Dictionary) -> void:
	var error_type := str(decoded_request.get("error", "bad_request"))
	var message := str(decoded_request.get("message", "Invalid HTTP request framing."))
	_log("Rejecting malformed HTTP request: %s (%s)" % [message, error_type], "warning")
	if _connection_state != null:
		_connection_state.set_pending_data(client, "")
		if _connection_state.has_method("record_rejected_request"):
			_connection_state.record_rejected_request()
	if _write_http_response.is_valid():
		_write_http_response.call(client, {
			"_status_code": 400,
			"jsonrpc": "2.0",
			"error": {
				"code": -32700,
				"message": message,
				"data": {"type": error_type}
			},
			"id": null
		}, false)
	client.disconnect_from_host()


func _open_sse_stream(client: StreamPeerTCP, response: Dictionary) -> bool:
	if not _write_sse_stream_open.is_valid():
		return false
	var stream_response := response.duplicate(true)
	var session_id := str(stream_response.get("_sse_session_id", "")).strip_edges()
	var next_event_index := int(stream_response.get("_sse_next_event_index", 0))
	stream_response.erase("_sse_session_id")
	stream_response.erase("_sse_next_event_index")
	var write_ok := bool(_write_sse_stream_open.call(client, stream_response))
	if write_ok and _connection_state != null and _connection_state.has_method("mark_sse_streaming"):
		_connection_state.mark_sse_streaming(client, session_id, next_event_index)
		_connection_state.set_pending_data(client, "")
	return write_ok


func _process_sse_streaming_client(client: StreamPeerTCP) -> bool:
	if client.get_available_bytes() > 0:
		client.get_data(client.get_available_bytes())
	if _drain_sse_events(client):
		return true
	if not _write_sse_heartbeat.is_valid():
		return false
	var last_heartbeat := 0
	if _connection_state != null and _connection_state.has_method("get_sse_last_heartbeat_at_unix"):
		last_heartbeat = int(_connection_state.get_sse_last_heartbeat_at_unix(client))
	var now := int(Time.get_unix_time_from_system())
	if last_heartbeat > 0 and now - last_heartbeat < SSE_HEARTBEAT_INTERVAL_SECONDS:
		return false
	var heartbeat_ok := bool(_write_sse_heartbeat.call(client))
	if not heartbeat_ok:
		_log("Closing SSE stream after heartbeat write failure", "warning")
		client.disconnect_from_host()
		return true
	if _connection_state != null and _connection_state.has_method("mark_sse_heartbeat"):
		_connection_state.mark_sse_heartbeat(client)
	return false


func _drain_sse_events(client: StreamPeerTCP) -> bool:
	if not _write_sse_events.is_valid() or not _get_sse_events_since_index.is_valid():
		return false
	if _connection_state == null:
		return false
	if not _connection_state.has_method("get_sse_session_id") or not _connection_state.has_method("get_sse_next_event_index"):
		return false
	var session_id := str(_connection_state.get_sse_session_id(client)).strip_edges()
	if session_id.is_empty():
		return false
	var next_event_index := int(_connection_state.get_sse_next_event_index(client))
	var events = _get_sse_events_since_index.call(session_id, next_event_index)
	if not (events is Array) or (events as Array).is_empty():
		return false
	var body := _format_sse_events(events as Array)
	var write_ok := bool(_write_sse_events.call(client, body))
	if not write_ok:
		_log("Closing SSE stream after queued event write failure", "warning")
		client.disconnect_from_host()
		return true
	if _connection_state.has_method("mark_sse_events_sent"):
		_connection_state.mark_sse_events_sent(client, next_event_index + (events as Array).size())
	return false


func _format_sse_events(events: Array) -> String:
	var body := ""
	for event in events:
		if not (event is Dictionary):
			continue
		body += "id: %s\nretry: %d\nevent: %s\ndata: %s\n\n" % [
			str((event as Dictionary).get("id", "")),
			int((event as Dictionary).get("retry", 1000)),
			str((event as Dictionary).get("event", "message")),
			JSON.stringify((event as Dictionary).get("data", {}))
		]
	return body


func _log_pending_request_wait(decoded_request: Dictionary, data: String) -> void:
	var waiting_for := str(decoded_request.get("waiting_for", ""))
	if waiting_for == "headers" and data.length() > 0:
		_log("Waiting for headers... current data length: %d" % data.length(), "debug")
	elif waiting_for == "chunked_body":
		_log("Waiting for chunked body...", "debug")
	elif waiting_for == "body":
		_log(
			"Waiting for body... need %d bytes, have %d bytes"
			% [int(decoded_request.get("content_length", 0)), int(decoded_request.get("body_byte_size", 0))],
			"debug"
		)


func _log(message: String, level: String = "debug") -> void:
	if _log_callback.is_valid():
		_log_callback.call(message, level)


func _reset_callbacks() -> void:
	_log_callback = Callable()
	_emit_client_connected = Callable()
	_emit_client_disconnected = Callable()
	_route_request_async = Callable()
	_write_http_response = Callable()
	_write_sse_stream_open = Callable()
	_write_sse_heartbeat = Callable()
	_write_sse_events = Callable()
	_get_sse_events_since_index = Callable()
	_tick_loader = Callable()
