@tool
extends RefCounted

var _connection_state = null
var _request_decoder = null
var _log_callback := Callable()
var _emit_client_connected := Callable()
var _emit_client_disconnected := Callable()
var _route_request_async := Callable()
var _write_http_response := Callable()
var _tick_loader := Callable()

const MAX_REQUESTS_PER_DRAIN := 16
const MAX_ACCEPTS_PER_FRAME := 8
const MAX_PENDING_REQUEST_BYTES := 1024 * 1024


func configure(connection_state, request_decoder, context = null) -> void:
	_connection_state = connection_state
	_request_decoder = request_decoder
	if context == null:
		_reset_callbacks()
		return
	_log_callback = context.log
	_emit_client_connected = context.emit_client_connected
	_emit_client_disconnected = context.emit_client_disconnected
	_route_request_async = context.route_request_async
	_write_http_response = context.write_http_response
	_tick_loader = context.tick_loader


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
		var available = client.get_available_bytes()
		if available > 0:
			var data = client.get_data(available)
			if data[0] != OK:
				_log("Error receiving data: %s" % data[0], "warning")
				return false
			var request_str = data[1].get_string_from_utf8()
			var pending_data = _connection_state.get_pending_data(client) + request_str
			var pending_byte_size: int = pending_data.to_utf8_buffer().size()
			if pending_byte_size > MAX_PENDING_REQUEST_BYTES:
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

		if _connection_state == null:
			return
		if _connection_state.has_client(client) and client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			var write_ok := bool(_write_http_response.call(client, response, no_body))
			if not write_ok:
				_log("Closing client after HTTP response write failure", "warning")
				client.disconnect_from_host()
				_connection_state.clear_processing(client)
				return
		_connection_state.clear_processing(client)

		drained_count += 1
		if drained_count >= MAX_REQUESTS_PER_DRAIN and not _connection_state.get_pending_data(client).is_empty():
			call_deferred("_process_http_request_async", client)
			return


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
	_tick_loader = Callable()
