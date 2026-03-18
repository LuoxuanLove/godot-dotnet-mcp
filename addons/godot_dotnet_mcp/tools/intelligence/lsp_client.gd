@tool
extends RefCounted

## GDScript LSP client — connects to Godot's built-in LSP server (127.0.0.1:6005).
## Provides GDScript static diagnostics (parse errors, warnings) via textDocument/publishDiagnostics.
## Uses StreamPeerTCP with a synchronous polling loop (same pattern as debug_dotnet restore/build).

const HOST := "127.0.0.1"
const PORT := 6005
const CONNECT_TIMEOUT_MS := 2000
const DEFAULT_RESPONSE_TIMEOUT_MS := 5000

var _read_buffer := PackedByteArray()
var _request_id := 0


## Get GDScript static diagnostics for a .gd file.
## Returns: {available: bool, parse_errors: Array, error_count: int, warning_count: int}
## On failure: {available: false, error: String}
func get_diagnostics(res_path: String, timeout_ms: int = DEFAULT_RESPONSE_TIMEOUT_MS) -> Dictionary:
	if not res_path.ends_with(".gd"):
		return {"available": false, "error": "LSP diagnostics only supported for .gd files"}
	if not FileAccess.file_exists(res_path):
		return {"available": false, "error": "File not found: %s" % res_path}

	var source_code := FileAccess.get_file_as_string(res_path)
	var global_path := ProjectSettings.globalize_path(res_path)
	var uri := _path_to_uri(global_path)
	var root_uri := _path_to_uri(ProjectSettings.globalize_path("res://"))

	_read_buffer = PackedByteArray()
	_request_id = 1

	var tcp := StreamPeerTCP.new()
	if tcp.connect_to_host(HOST, PORT) != OK:
		return {"available": false, "error": "Cannot connect to Godot LSP at %s:%d" % [HOST, PORT]}

	var deadline := Time.get_ticks_msec() + CONNECT_TIMEOUT_MS
	while tcp.get_status() == StreamPeerTCP.STATUS_CONNECTING:
		tcp.poll()
		if Time.get_ticks_msec() > deadline:
			tcp.disconnect_from_host()
			return {"available": false, "error": "LSP connection timeout after %dms" % CONNECT_TIMEOUT_MS}
		OS.delay_msec(10)

	if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return {"available": false, "error": "LSP connection failed (status: %d)" % tcp.get_status()}

	# initialize request
	_send_request(tcp, "initialize", {
		"processId": OS.get_process_id(),
		"rootUri": root_uri,
		"capabilities": {
			"textDocument": {"publishDiagnostics": {"relatedInformation": false}}
		}
	}, _request_id)

	var init_resp := _wait_for_response(tcp, _request_id, timeout_ms)
	if init_resp.is_empty():
		tcp.disconnect_from_host()
		return {"available": false, "error": "No response from LSP initialize — is Godot's LSP enabled?"}

	# initialized notification
	_send_notification(tcp, "initialized", {})

	# textDocument/didOpen
	_send_notification(tcp, "textDocument/didOpen", {
		"textDocument": {
			"uri": uri,
			"languageId": "gdscript",
			"version": 1,
			"text": source_code
		}
	})

	# Wait for publishDiagnostics for this URI
	var diag_msg := _wait_for_diagnostic(tcp, uri, timeout_ms)
	tcp.disconnect_from_host()

	if diag_msg.is_empty():
		return {
			"available": true,
			"parse_errors": [],
			"error_count": 0,
			"warning_count": 0,
			"note": "No diagnostics received within timeout — script may be clean or LSP response is slow."
		}
	return _parse_diagnostics(diag_msg)


func _wait_for_response(tcp: StreamPeerTCP, expected_id: int, timeout_ms: int) -> Dictionary:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		tcp.poll()
		if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			break
		var msg := _try_read_message(tcp)
		if not msg.is_empty() and int(msg.get("id", -999)) == expected_id:
			return msg
		OS.delay_msec(10)
	return {}


func _wait_for_diagnostic(tcp: StreamPeerTCP, target_uri: String, timeout_ms: int) -> Dictionary:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		tcp.poll()
		if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			break
		var msg := _try_read_message(tcp)
		if not msg.is_empty():
			if str(msg.get("method", "")) == "textDocument/publishDiagnostics":
				var params = msg.get("params", {})
				if params is Dictionary and str((params as Dictionary).get("uri", "")) == target_uri:
					return msg
		OS.delay_msec(20)
	return {}


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

	# Find \r\n\r\n header terminator
	var header_end := -1
	for i in range(_read_buffer.size() - 3):
		if _read_buffer[i] == 13 and _read_buffer[i + 1] == 10 \
				and _read_buffer[i + 2] == 13 and _read_buffer[i + 3] == 10:
			header_end = i + 4
			break
	if header_end == -1:
		return {}

	# Parse Content-Length
	var header_str := _read_buffer.slice(0, header_end).get_string_from_utf8()
	var content_length := -1
	for line in header_str.split("\r\n"):
		if line.to_lower().begins_with("content-length:"):
			content_length = int(line.substr(line.find(":") + 1).strip_edges())
			break
	if content_length < 0:
		_read_buffer = _read_buffer.slice(header_end)
		return {}

	# Wait until full body is buffered
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
		return {"available": true, "parse_errors": [], "error_count": 0, "warning_count": 0}
	var raw_diags = (params as Dictionary).get("diagnostics", [])
	if not (raw_diags is Array):
		return {"available": true, "parse_errors": [], "error_count": 0, "warning_count": 0}

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
		# LSP severity: 1=Error 2=Warning 3=Information 4=Hint
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

	return {
		"available": true,
		"parse_errors": parse_errors,
		"error_count": error_count,
		"warning_count": warning_count
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
	if not normalized.begins_with("/"):
		normalized = "/" + normalized
	normalized = normalized.replace(" ", "%20")
	return "file://" + normalized
