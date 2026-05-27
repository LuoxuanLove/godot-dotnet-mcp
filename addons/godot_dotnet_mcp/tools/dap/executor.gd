@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

const DEFAULT_HOST := "127.0.0.1"
const DEFAULT_PORT := 6006
const DEFAULT_TIMEOUT_MS := 1000

static var _sequence := 1
static var _breakpoints_by_source := {}


func get_tools() -> Array[Dictionary]:
	return [{
		"name": "debugger",
		"description": "GODOT DAP DEBUGGER: Send Debug Adapter Protocol breakpoint, stepping, stack-trace, and output-event requests to Godot's built-in DAP endpoint. The built-in endpoint is intended for GDScript debugging; managed C# breakpoints require a .NET debugger.",
		"inputSchema": {
			"type": "object",
			"properties": {
				"action": {"type": "string", "enum": ["status", "set_breakpoint", "remove_breakpoint", "list_breakpoints", "pause", "continue", "step_over", "stack_trace", "output"], "description": "DAP debugger action"},
				"host": {"type": "string", "description": "DAP host (default 127.0.0.1)"},
				"port": {"type": "integer", "description": "DAP port (default 6006)"},
				"timeout_ms": {"type": "integer", "description": "Timeout in milliseconds"},
				"source_path": {"type": "string", "description": "Source path for breakpoint actions"},
				"line": {"type": "integer", "description": "Breakpoint line"},
				"thread_id": {"type": "integer", "description": "DAP thread id"}
			},
			"required": ["action"]
		}
	}]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name != "debugger":
		return _error("Unknown tool: %s" % tool_name)
	match str(args.get("action", "")):
		"status":
			return _success(_status_data())
		"list_breakpoints":
			return _success(_breakpoint_list_data())
		_:
			return _error("DAP action requires asynchronous execution", {"error_type": "dap_async_required"})


func execute_async(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name != "debugger":
		return _error("Unknown tool: %s" % tool_name)
	match str(args.get("action", "")):
		"status", "list_breakpoints":
			return execute(tool_name, args)
		"set_breakpoint":
			return await _set_breakpoint(args)
		"remove_breakpoint":
			return await _remove_breakpoint(args)
		"pause":
			return await _send_thread_request("pause", args)
		"continue":
			return await _send_thread_request("continue", args)
		"step_over":
			return await _send_thread_request("next", args)
		"stack_trace":
			return await _send_thread_request("stackTrace", args)
		"output":
			return await _collect_output(args)
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _set_breakpoint(args: Dictionary) -> Dictionary:
	var source_path := _source_path(args)
	if source_path.is_empty():
		return _error("DAP set_breakpoint requires source_path")
	var line := int(args.get("line", 0))
	if line <= 0:
		return _error("DAP set_breakpoint requires line")
	var lines: Array = (_breakpoints_by_source.get(source_path, []) as Array).duplicate()
	if not lines.has(line):
		lines.append(line)
	lines.sort()
	var result := await _send_breakpoints(source_path, lines, args)
	if bool(result.get("success", false)):
		_store_breakpoints(source_path, lines)
		result = _with_breakpoint_list(result)
	return result


func _remove_breakpoint(args: Dictionary) -> Dictionary:
	var source_path := _source_path(args)
	if source_path.is_empty():
		return _error("DAP remove_breakpoint requires source_path")
	var line := int(args.get("line", 0))
	var lines: Array = (_breakpoints_by_source.get(source_path, []) as Array).duplicate()
	lines.erase(line)
	var result := await _send_breakpoints(source_path, lines, args)
	if bool(result.get("success", false)):
		_store_breakpoints(source_path, lines)
		result = _with_breakpoint_list(result)
	return result


func _send_breakpoints(source_path: String, lines: Array, args: Dictionary) -> Dictionary:
	var breakpoints: Array[Dictionary] = []
	for line in lines:
		breakpoints.append({"line": int(line)})
	var dap_args := {"source": {"path": _dap_path(source_path)}, "breakpoints": breakpoints}
	return await _send_request("setBreakpoints", dap_args, args)


func _send_thread_request(command: String, args: Dictionary) -> Dictionary:
	return await _send_request(command, {"threadId": int(args.get("thread_id", 1))}, args)


func _collect_output(args: Dictionary) -> Dictionary:
	var connection := await _connect(args)
	if not bool(connection.get("success", false)):
		return connection
	var peer: StreamPeerTCP = connection.get("peer")
	var buffer := PackedByteArray()
	var messages: Array[Dictionary] = []
	await _read_messages(peer, buffer, messages, _timeout_ms(args))
	peer.disconnect_from_host()
	var outputs: Array[Dictionary] = []
	for message in messages:
		if str(message.get("type", "")) == "event" and str(message.get("event", "")) == "output":
			outputs.append((message.get("body", {}) as Dictionary).duplicate(true))
	return _success({"outputs": outputs, "messages": messages})


func _send_request(command: String, arguments: Dictionary, args: Dictionary) -> Dictionary:
	var connection := await _connect(args)
	if not bool(connection.get("success", false)):
		return connection
	var peer: StreamPeerTCP = connection.get("peer")
	var request_seq := _sequence
	_sequence += 1
	var request := {"seq": request_seq, "type": "request", "command": command, "arguments": arguments}
	var body := JSON.stringify(request)
	var body_bytes := body.to_utf8_buffer()
	var frame := PackedByteArray()
	frame.append_array(("Content-Length: %d\r\n\r\n" % body_bytes.size()).to_utf8_buffer())
	frame.append_array(body_bytes)
	var write_error := peer.put_data(frame)
	if write_error != OK:
		peer.disconnect_from_host()
		return _error("Failed to write DAP request", {"error_type": "dap_write_failed", "command": command, "code": write_error})
	var buffer := PackedByteArray()
	var messages: Array[Dictionary] = []
	await _read_messages(peer, buffer, messages, _timeout_ms(args), request_seq)
	peer.disconnect_from_host()
	var response := _find_response(messages, request_seq)
	if response.is_empty():
		return _error("DAP request timed out", {"error_type": "dap_timeout", "command": command, "request": request, "messages": messages})
	if not bool(response.get("success", true)):
		return _error("DAP request failed", {"error_type": "dap_response_failed", "command": command, "request": request, "response": response, "messages": messages})
	return _success({"request": request, "response": response, "messages": messages})


func _connect(args: Dictionary) -> Dictionary:
	var host := str(args.get("host", DEFAULT_HOST)).strip_edges()
	var port := int(args.get("port", DEFAULT_PORT))
	var peer := StreamPeerTCP.new()
	if host.is_empty() or port <= 0 or port > 65535:
		return _error("Invalid DAP endpoint", _dap_unavailable_data(args, "invalid_endpoint"))
	var err := peer.connect_to_host(host, port)
	if err != OK:
		var connect_data := _dap_unavailable_data(args, "connect_failed")
		connect_data["code"] = err
		return _error("DAP endpoint unavailable", connect_data)
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started <= _timeout_ms(args):
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			return {"success": true, "peer": peer}
		if peer.get_status() == StreamPeerTCP.STATUS_ERROR or peer.get_status() == StreamPeerTCP.STATUS_NONE:
			return _error("DAP endpoint unavailable", _dap_unavailable_data(args, _peer_status_name(peer.get_status())))
		await _wait_frame()
	peer.disconnect_from_host()
	return _error("DAP endpoint unavailable", _dap_unavailable_data(args, "timeout"))


func _read_messages(peer: StreamPeerTCP, buffer: PackedByteArray, messages: Array[Dictionary], timeout_ms: int, request_seq: int = -1) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started <= timeout_ms:
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			return
		var available := peer.get_available_bytes()
		if available > 0:
			var packet := peer.get_data(available)
			if int(packet[0]) == OK and packet[1] is PackedByteArray:
				buffer.append_array(packet[1] as PackedByteArray)
				buffer = _drain_frames(buffer, messages)
				if request_seq >= 0 and not _find_response(messages, request_seq).is_empty():
					return
		await _wait_frame()


func _store_breakpoints(source_path: String, lines: Array) -> void:
	if lines.is_empty():
		_breakpoints_by_source.erase(source_path)
	else:
		_breakpoints_by_source[source_path] = lines.duplicate()


func _with_breakpoint_list(result: Dictionary) -> Dictionary:
	var data: Dictionary = result.get("data", {})
	data["breakpoints"] = _breakpoint_list_data().get("breakpoints", [])
	result["data"] = data
	return result


func _drain_frames(buffer: PackedByteArray, messages: Array[Dictionary]) -> PackedByteArray:
	while true:
		var header_end := _find_header_end(buffer)
		if header_end < 0:
			return buffer
		var content_length := _content_length(buffer.slice(0, header_end).get_string_from_utf8())
		if content_length < 0:
			buffer.clear()
			return buffer
		var body_start := header_end + 4
		if buffer.size() < body_start + content_length:
			return buffer
		var parsed = JSON.parse_string(buffer.slice(body_start, body_start + content_length).get_string_from_utf8())
		if parsed is Dictionary:
			messages.append(parsed as Dictionary)
		buffer = buffer.slice(body_start + content_length)
	return buffer


func _find_header_end(buffer: PackedByteArray) -> int:
	for index in range(buffer.size() - 3):
		if buffer[index] == 13 and buffer[index + 1] == 10 and buffer[index + 2] == 13 and buffer[index + 3] == 10:
			return index
	return -1


func _content_length(header: String) -> int:
	for line in header.split("\r\n"):
		if line.to_lower().begins_with("content-length:"):
			return int(line.substr(line.find(":") + 1).strip_edges())
	return -1


func _find_response(messages: Array[Dictionary], request_seq: int) -> Dictionary:
	for message in messages:
		if str(message.get("type", "")) == "response" and int(message.get("request_seq", -1)) == request_seq:
			return message
	return {}


func _breakpoint_list_data() -> Dictionary:
	var items: Array[Dictionary] = []
	for source_path in _breakpoints_by_source.keys():
		for line in _breakpoints_by_source[source_path]:
			items.append({"source_path": str(source_path), "line": int(line)})
	return {"count": items.size(), "breakpoints": items}


func _status_data() -> Dictionary:
	return {
		"protocol": "Debug Adapter Protocol",
		"godot_builtin_dap_scope": "GDScript",
		"csharp_debugger_note": "C# breakpoints require a .NET debugger such as coreclr.",
		"sequence": _sequence,
		"default_host": DEFAULT_HOST,
		"default_port": DEFAULT_PORT,
		"breakpoint_count": int(_breakpoint_list_data().get("count", 0))
	}


func _dap_unavailable_data(args: Dictionary, transport_status: String) -> Dictionary:
	var host := str(args.get("host", DEFAULT_HOST)).strip_edges()
	var port := int(args.get("port", DEFAULT_PORT))
	return {
		"error_type": "dap_unavailable",
		"endpoint": "%s:%d" % [host, port],
		"host": host,
		"port": port,
		"timeout_ms": _timeout_ms(args),
		"transport_status": transport_status,
		"protocol": "Debug Adapter Protocol"
	}


func _peer_status_name(status: int) -> String:
	match status:
		StreamPeerTCP.STATUS_NONE:
			return "none"
		StreamPeerTCP.STATUS_CONNECTING:
			return "connecting"
		StreamPeerTCP.STATUS_CONNECTED:
			return "connected"
		StreamPeerTCP.STATUS_ERROR:
			return "error"
		_:
			return "unknown"


func _source_path(args: Dictionary) -> String:
	return str(args.get("source_path", args.get("path", ""))).strip_edges()


func _dap_path(path: String) -> String:
	var normalized := _normalize_res_path(path)
	if normalized.begins_with("res://"):
		return ProjectSettings.globalize_path(normalized)
	return path


func _timeout_ms(args: Dictionary) -> int:
	var value := int(args.get("timeout_ms", DEFAULT_TIMEOUT_MS))
	return value if value > 0 else DEFAULT_TIMEOUT_MS


func _wait_frame() -> void:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		await (loop as SceneTree).process_frame
	else:
		OS.delay_msec(10)
