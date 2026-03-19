@tool
extends RefCounted

## GDScript LSP client.
## Connects to Godot's built-in LSP server (127.0.0.1:6005) and advances one
## request at a time without blocking the caller.

const HOST := "127.0.0.1"
const PORT := 6005
const CONNECT_TIMEOUT_MS := 2000
const DEFAULT_RESPONSE_TIMEOUT_MS := 15000

const STATE_IDLE := "idle"
const STATE_CONNECTING := "connecting"
const STATE_WAITING_INITIALIZE := "waiting_initialize"
const STATE_WAITING_DIAGNOSTICS := "waiting_diagnostics"
const STATE_READY := "ready"
const STATE_FAILED := "failed"

var _read_buffer := PackedByteArray()
var _request_id := 0
var _tcp: StreamPeerTCP
var _active_path := ""
var _active_source_code := ""
var _active_uri := ""
var _active_root_uri := ""
var _source_hash := ""
var _deadline_msec := 0
var _init_request_id := 0
var _state := STATE_IDLE
var _request_started_msec := 0
var _request_finished_msec := 0
var _status: Dictionary = {
	"available": false,
	"pending": false,
	"finished": true,
	"state": STATE_IDLE,
	"phase": STATE_IDLE,
	"parse_errors": [],
	"error_count": 0,
	"warning_count": 0
}


## Compatibility wrapper for older call sites.
## Starts a request and immediately returns the current status snapshot.
func get_diagnostics(res_path: String, timeout_ms: int = DEFAULT_RESPONSE_TIMEOUT_MS) -> Dictionary:
	var source_code := ""
	if FileAccess.file_exists(res_path):
		source_code = FileAccess.get_file_as_string(res_path)
	return start_diagnostics(res_path, source_code, timeout_ms)


func start_diagnostics(res_path: String, source_code: String, timeout_ms: int = DEFAULT_RESPONSE_TIMEOUT_MS) -> Dictionary:
	if not res_path.ends_with(".gd"):
		_active_path = res_path
		_state = STATE_FAILED
		_status = _build_failure_status("LSP diagnostics only supported for .gd files")
		return _status.duplicate(true)
	if not FileAccess.file_exists(res_path):
		_active_path = res_path
		_state = STATE_FAILED
		_status = _build_failure_status("File not found: %s" % res_path)
		return _status.duplicate(true)

	_reset_session()

	_active_path = res_path
	_active_source_code = source_code
	_active_uri = _path_to_uri(ProjectSettings.globalize_path(res_path))
	_active_root_uri = _path_to_uri(ProjectSettings.globalize_path("res://"))
	_source_hash = str(source_code.hash())
	_request_id = 1
	_init_request_id = 1
	_deadline_msec = Time.get_ticks_msec() + maxi(timeout_ms, 1)
	_state = STATE_CONNECTING
	_request_started_msec = Time.get_ticks_msec()
	_request_finished_msec = 0

	_tcp = StreamPeerTCP.new()
	if _tcp.connect_to_host(HOST, PORT) != OK:
		return _finish_failure("Cannot connect to Godot LSP at %s:%d" % [HOST, PORT])

	_status = {
		"available": false,
		"pending": true,
		"finished": false,
		"state": STATE_CONNECTING,
		"phase": STATE_CONNECTING,
		"parse_errors": [],
		"error_count": 0,
		"warning_count": 0,
		"script": _active_path,
		"source_hash": _source_hash,
		"note": "LSP request queued"
	}
	return get_status()


func tick(_delta: float) -> void:
	if not has_active_request():
		return
	if _tcp == null:
		_finish_failure("LSP session missing TCP socket")
		return

	_tcp.poll()
	match _state:
		STATE_CONNECTING:
			_tick_connecting()
		STATE_WAITING_INITIALIZE:
			_tick_waiting_initialize()
		STATE_WAITING_DIAGNOSTICS:
			_tick_waiting_diagnostics()
		_:
			pass


func has_active_request() -> bool:
	return _state in [STATE_CONNECTING, STATE_WAITING_INITIALIZE, STATE_WAITING_DIAGNOSTICS]


func get_status() -> Dictionary:
	return _status.duplicate(true)


func get_debug_snapshot() -> Dictionary:
	var tcp_status := StreamPeerTCP.STATUS_NONE
	if _tcp != null:
		tcp_status = _tcp.get_status()
	return {
		"state": _state,
		"status": get_status(),
		"has_active_request": has_active_request(),
		"active_path": _active_path,
		"active_uri": _active_uri,
		"active_root_uri": _active_root_uri,
		"source_hash": _source_hash,
		"request_started_msec": _request_started_msec,
		"request_finished_msec": _request_finished_msec,
		"deadline_msec": _deadline_msec,
		"deadline_remaining_msec": maxi(_deadline_msec - Time.get_ticks_msec(), 0) if _deadline_msec > 0 else 0,
		"tcp_status": tcp_status,
		"buffered_bytes": _read_buffer.size()
	}


func cancel() -> void:
	if _tcp != null:
		_tcp.disconnect_from_host()
	_reset_session()


func _tick_connecting() -> void:
	if _tcp == null:
		_finish_failure("LSP session missing TCP socket")
		return

	var tcp_status := _tcp.get_status()
	if tcp_status == StreamPeerTCP.STATUS_CONNECTING:
		if Time.get_ticks_msec() > _deadline_msec:
			_finish_failure("LSP connection timeout after %dms" % CONNECT_TIMEOUT_MS)
		return

	if tcp_status != StreamPeerTCP.STATUS_CONNECTED:
		_finish_failure("LSP connection failed (status: %d)" % tcp_status)
		return

	_send_request(_tcp, "initialize", {
		"processId": OS.get_process_id(),
		"rootUri": _active_root_uri,
		"capabilities": {
			"textDocument": {"publishDiagnostics": {"relatedInformation": false}}
		}
	}, _init_request_id)

	_state = STATE_WAITING_INITIALIZE
	_status["state"] = STATE_WAITING_INITIALIZE
	_status["phase"] = STATE_WAITING_INITIALIZE
	_status["note"] = "Waiting for initialize response"
	_tick_waiting_initialize()


func _tick_waiting_initialize() -> void:
	if _tcp == null:
		_finish_failure("LSP session missing TCP socket")
		return

	var processed := 0
	while processed < 8:
		var msg := _try_read_message(_tcp)
		if msg.is_empty():
			break
		processed += 1
		if int(msg.get("id", -999)) == _init_request_id:
			_send_notification(_tcp, "initialized", {})
			_send_document_open()
			_state = STATE_WAITING_DIAGNOSTICS
			_status["state"] = STATE_WAITING_DIAGNOSTICS
			_status["phase"] = STATE_WAITING_DIAGNOSTICS
			_status["note"] = "Waiting for publishDiagnostics after didOpen"
			_tick_waiting_diagnostics()
			return

	if Time.get_ticks_msec() > _deadline_msec:
		_finish_failure("No response from LSP initialize - is Godot's LSP enabled?")


func _tick_waiting_diagnostics() -> void:
	if _tcp == null:
		_finish_failure("LSP session missing TCP socket")
		return

	var processed := 0
	while processed < 8:
		var msg := _try_read_message(_tcp)
		if msg.is_empty():
			break
		processed += 1
		if str(msg.get("method", "")) != "textDocument/publishDiagnostics":
			continue
		var params = msg.get("params", {})
		if params is Dictionary and _uris_match(str((params as Dictionary).get("uri", "")), _active_uri):
			var diag_result := _parse_diagnostics(msg)
			_finish_success(diag_result)
			return

	if Time.get_ticks_msec() > _deadline_msec:
		_finish_timeout()


func _try_read_message(tcp: StreamPeerTCP) -> Dictionary:
	var available := tcp.get_available_bytes()
	if available > 0:
		var chunk := tcp.get_data(available)
		if int(chunk[0]) == OK and chunk[1] is PackedByteArray:
			_read_buffer.append_array(chunk[1] as PackedByteArray)
	return _try_parse_frame()


func _try_parse_frame() -> Dictionary:
	if _read_buffer.size() < 4:
		return {}

	# Find \r\n\r\n header terminator.
	var header_end := -1
	for i in range(_read_buffer.size() - 3):
		if _read_buffer[i] == 13 and _read_buffer[i + 1] == 10 \
				and _read_buffer[i + 2] == 13 and _read_buffer[i + 3] == 10:
			header_end = i + 4
			break
	if header_end == -1:
		return {}

	var header_str := _read_buffer.slice(0, header_end).get_string_from_utf8()
	var content_length := -1
	for line in header_str.split("\r\n"):
		if line.to_lower().begins_with("content-length:"):
			content_length = int(line.substr(line.find(":") + 1).strip_edges())
			break
	if content_length < 0:
		_read_buffer = _read_buffer.slice(header_end)
		return {}

	if _read_buffer.size() < header_end + content_length:
		return {}

	var body_bytes := _read_buffer.slice(header_end, header_end + content_length)
	_read_buffer = _read_buffer.slice(header_end + content_length)

	var body_str := body_bytes.get_string_from_utf8()
	var json := JSON.new()
	if json.parse(body_str) != OK:
		return {}
	var result = json.get_data()
	if result is Dictionary:
		return result as Dictionary
	return {}


func _parse_diagnostics(msg: Dictionary) -> Dictionary:
	var params = msg.get("params", {})
	if not (params is Dictionary):
		return _build_success_status([])
	var raw_diags = (params as Dictionary).get("diagnostics", [])
	if not (raw_diags is Array):
		return _build_success_status([])

	var parse_errors: Array = []
	var error_count := 0
	var warning_count := 0

	for d in raw_diags:
		if not (d is Dictionary):
			continue
		var range_d = (d as Dictionary).get("range", {})
		var start_d: Dictionary = range_d.get("start", {}) if range_d is Dictionary else {}
		var end_d: Dictionary = range_d.get("end", {}) if range_d is Dictionary else {}
		var severity := int((d as Dictionary).get("severity", 1))
		var severity_str: String
		match severity:
			1:
				severity_str = "error"
				error_count += 1
			2:
				severity_str = "warning"
				warning_count += 1
			3:
				severity_str = "information"
			_:
				severity_str = "hint"

		var line_0 := int(start_d.get("line", 0))
		var col_0 := int(start_d.get("character", 0))
		var col_end := int(end_d.get("character", col_0))
		parse_errors.append({
			"severity": severity_str,
			"message": str((d as Dictionary).get("message", "")),
			"line": line_0 + 1,  # LSP is 0-based; return 1-based
			"column": col_0,
			"length": max(0, col_end - col_0)
		})

	return _build_success_status(parse_errors, error_count, warning_count)


func _build_success_status(parse_errors: Array, error_count: int = -1, warning_count: int = -1) -> Dictionary:
	if error_count < 0 or warning_count < 0:
		error_count = 0
		warning_count = 0
		for item in parse_errors:
			if not (item is Dictionary):
				continue
			match str((item as Dictionary).get("severity", "")):
				"error":
					error_count += 1
				"warning":
					warning_count += 1

	return {
		"available": true,
		"pending": false,
		"finished": true,
		"state": STATE_READY,
		"phase": STATE_READY,
		"script": _active_path,
		"source_hash": _source_hash,
		"parse_errors": parse_errors,
		"error_count": error_count,
		"warning_count": warning_count
	}


func _build_failure_status(message: String) -> Dictionary:
	return {
		"available": false,
		"pending": false,
		"finished": true,
		"state": STATE_FAILED,
		"phase": str(_status.get("phase", _state)),
		"script": _active_path,
		"source_hash": _source_hash,
		"parse_errors": [],
		"error_count": 0,
		"warning_count": 0,
		"error": message
	}


func _finish_success(result: Dictionary) -> void:
	_status = result.duplicate(true)
	_status["available"] = true
	_status["pending"] = false
	_status["finished"] = true
	_status["state"] = STATE_READY
	_status["phase"] = STATE_READY
	_status["script"] = _active_path
	_status["source_hash"] = _source_hash
	_status.erase("note")
	_disconnect_tcp()
	_state = STATE_READY
	_request_finished_msec = Time.get_ticks_msec()


func _finish_timeout() -> void:
	_finish_failure("No diagnostics received within timeout - script may be clean or LSP response is slow.")


func _finish_failure(message: String) -> Dictionary:
	_status = _build_failure_status(message)
	_disconnect_tcp()
	_state = STATE_FAILED
	_request_finished_msec = Time.get_ticks_msec()
	return _status.duplicate(true)


func _disconnect_tcp() -> void:
	if _tcp != null:
		_tcp.disconnect_from_host()
	_tcp = null


func _reset_session() -> void:
	_disconnect_tcp()
	_read_buffer = PackedByteArray()
	_request_id = 0
	_init_request_id = 0
	_active_path = ""
	_active_source_code = ""
	_active_uri = ""
	_active_root_uri = ""
	_source_hash = ""
	_deadline_msec = 0
	_state = STATE_IDLE
	_request_started_msec = 0
	_request_finished_msec = 0
	_status = {
		"available": false,
		"pending": false,
		"finished": true,
		"state": STATE_IDLE,
		"phase": STATE_IDLE,
		"parse_errors": [],
		"error_count": 0,
		"warning_count": 0
	}


func _send_request(tcp: StreamPeerTCP, method: String, params: Dictionary, id: int) -> void:
	_send_raw(tcp, JSON.stringify({
		"jsonrpc": "2.0",
		"id": id,
		"method": method,
		"params": params
	}))


func _send_notification(tcp: StreamPeerTCP, method: String, params: Dictionary) -> void:
	_send_raw(tcp, JSON.stringify({
		"jsonrpc": "2.0",
		"method": method,
		"params": params
	}))


func _send_raw(tcp: StreamPeerTCP, body: String) -> void:
	var body_bytes := body.to_utf8_buffer()
	var header := ("Content-Length: %d\r\n\r\n" % body_bytes.size()).to_utf8_buffer()
	var full_msg := PackedByteArray()
	full_msg.append_array(header)
	full_msg.append_array(body_bytes)
	tcp.put_data(full_msg)


func _path_to_uri(path: String) -> String:
	var normalized := path.replace("\\", "/")
	if normalized.length() > 1 and normalized[1] == ":":
		normalized = "%s%%3A%s" % [normalized[0], normalized.substr(2)]
	if not normalized.begins_with("/"):
		normalized = "/" + normalized
	normalized = normalized.replace(" ", "%20")
	return "file://" + normalized


func _send_document_open() -> void:
	_send_notification(_tcp, "textDocument/didOpen", {
		"textDocument": {
			"uri": _active_uri,
			"languageId": "gdscript",
			"version": 1,
			"text": _active_source_code
		}
	})


func _uris_match(uri_a: String, uri_b: String) -> bool:
	return _normalize_file_uri(uri_a) == _normalize_file_uri(uri_b)


func _normalize_file_uri(uri: String) -> String:
	var normalized := uri.uri_decode().replace("\\", "/")
	if normalized.begins_with("file://"):
		normalized = normalized.trim_prefix("file://")
	if OS.get_name() == "Windows":
		if normalized.length() > 2 and normalized[0] == "/" and normalized[2] == ":":
			normalized = normalized.substr(1)
		normalized = normalized.to_lower()
	return normalized
