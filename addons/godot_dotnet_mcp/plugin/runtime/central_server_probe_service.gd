@tool
extends RefCounted
class_name CentralServerProbeService

var _settings: Dictionary = {}
var _shutdown_path := "/api/server/shutdown"


func configure(settings: Dictionary, shutdown_path: String = "/api/server/shutdown") -> void:
	_settings = settings
	_shutdown_path = shutdown_path


func is_local_target() -> bool:
	var host := _get_host().to_lower()
	return host == "127.0.0.1" or host == "localhost" or host == "::1"


func is_auto_launch_enabled() -> bool:
	return bool(_settings.get("central_server_auto_launch", true))


func build_endpoint() -> String:
	return "http://%s:%d/" % [_get_host(), _get_port()]


func probe_endpoint(pid: int, status: String) -> Dictionary:
	if not is_local_target():
		return {
			"reachable": false,
			"status": status
		}

	var reachable = _probe_connection(_get_host(), _get_port(), 250)
	var next_status = status
	if reachable and (pid <= 0 or not OS.is_process_running(pid)) and status != "starting":
		next_status = "running"
	elif not reachable and pid <= 0 and status == "running":
		next_status = "idle"

	return {
		"reachable": reachable,
		"status": next_status
	}


func request_endpoint_shutdown(wait_timeout_msec: int = 3000) -> Dictionary:
	var host = _get_host()
	var port = _get_port()
	var peer := StreamPeerTCP.new()
	var connect_error := peer.connect_to_host(host, port)
	if connect_error != OK:
		return {
			"success": false,
			"message": "Failed to connect to the local central server control endpoint."
		}

	var connect_deadline := Time.get_ticks_msec() + 500
	while peer.get_status() == StreamPeerTCP.STATUS_CONNECTING and Time.get_ticks_msec() < connect_deadline:
		OS.delay_msec(10)
		_poll_peer(peer)

	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		if peer.get_status() != StreamPeerTCP.STATUS_NONE:
			peer.disconnect_from_host()
		return {
			"success": false,
			"message": "Failed to connect to the local central server control endpoint."
		}

	var request = "POST %s HTTP/1.1\r\nHost: %s:%d\r\nContent-Type: application/json\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}" % [_shutdown_path, host, port]
	var write_error := peer.put_data(request.to_utf8_buffer())
	if write_error != OK:
		peer.disconnect_from_host()
		return {
			"success": false,
			"message": "Failed to send shutdown request to the local central server."
		}

	var response_deadline := Time.get_ticks_msec() + 1000
	while peer.get_status() == StreamPeerTCP.STATUS_CONNECTED and Time.get_ticks_msec() < response_deadline:
		_poll_peer(peer)
		var available = peer.get_available_bytes()
		if available > 0:
			peer.get_data(available)
			break
		OS.delay_msec(10)

	if peer.get_status() != StreamPeerTCP.STATUS_NONE:
		peer.disconnect_from_host()

	var shutdown_deadline := Time.get_ticks_msec() + wait_timeout_msec
	while Time.get_ticks_msec() < shutdown_deadline:
		if not _probe_connection(host, port, 250):
			return {
				"success": true,
				"message": "Local central server stopped through the control endpoint."
			}
		OS.delay_msec(25)

	return {
		"success": false,
		"message": "Timed out while waiting for the local central server to stop."
	}


func validate_http_transport(http_host: String, http_port: int) -> Dictionary:
	var peer := StreamPeerTCP.new()
	var connect_error := peer.connect_to_host(http_host, http_port)
	if connect_error != OK:
		return {
			"success": false,
			"message": "Failed to connect to the embedded HTTP MCP endpoint."
		}

	var connect_deadline := Time.get_ticks_msec() + 500
	while peer.get_status() == StreamPeerTCP.STATUS_CONNECTING and Time.get_ticks_msec() < connect_deadline:
		OS.delay_msec(10)
		_poll_peer(peer)

	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		if peer.get_status() != StreamPeerTCP.STATUS_NONE:
			peer.disconnect_from_host()
		return {
			"success": false,
			"message": "Failed to connect to the embedded HTTP MCP endpoint."
		}

	var request = "GET /health HTTP/1.1\r\nHost: %s:%d\r\nConnection: close\r\n\r\n" % [http_host, http_port]
	var write_error := peer.put_data(request.to_utf8_buffer())
	if write_error != OK:
		peer.disconnect_from_host()
		return {
			"success": false,
			"message": "Failed to query the embedded HTTP MCP endpoint."
		}

	var response_buffer := PackedByteArray()
	var response_deadline := Time.get_ticks_msec() + 1500
	while peer.get_status() == StreamPeerTCP.STATUS_CONNECTED and Time.get_ticks_msec() < response_deadline:
		_poll_peer(peer)
		var available = peer.get_available_bytes()
		if available > 0:
			var chunk = peer.get_data(available)
			if int(chunk[0]) == OK:
				response_buffer.append_array(chunk[1])
		else:
			OS.delay_msec(10)
	if peer.get_status() != StreamPeerTCP.STATUS_NONE:
		peer.disconnect_from_host()

	var response_text = response_buffer.get_string_from_utf8()
	if response_text.contains("200 OK"):
		return {
			"success": true,
			"mode": "http",
			"message": "Embedded HTTP MCP endpoint validated successfully.",
			"endpoint": "http://%s:%d/mcp" % [http_host, http_port]
		}

	return {
		"success": false,
		"message": "Embedded HTTP MCP endpoint validation returned an unexpected response.",
		"response": response_text
	}


func _probe_connection(host: String, port: int, timeout_msec: int) -> bool:
	var peer := StreamPeerTCP.new()
	var error := peer.connect_to_host(host, port)
	if error != OK:
		return false

	var deadline := Time.get_ticks_msec() + timeout_msec
	while peer.get_status() == StreamPeerTCP.STATUS_CONNECTING and Time.get_ticks_msec() < deadline:
		OS.delay_msec(10)
		_poll_peer(peer)

	var reachable = peer.get_status() == StreamPeerTCP.STATUS_CONNECTED
	if peer.get_status() != StreamPeerTCP.STATUS_NONE:
		peer.disconnect_from_host()
	return reachable


func _poll_peer(peer: StreamPeerTCP) -> void:
	if peer == null:
		return
	if peer.has_method("poll"):
		peer.poll()


func _get_host() -> String:
	return str(_settings.get("central_server_host", "127.0.0.1")).strip_edges()


func _get_port() -> int:
	return int(_settings.get("central_server_port", 3020))
