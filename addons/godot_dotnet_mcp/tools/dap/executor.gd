@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

const DEFAULT_HOST := "127.0.0.1"
const DEFAULT_PORT := 6006
const DEFAULT_TIMEOUT_MS := 1000
const MAX_TIMEOUT_MS := 30000
const DEFAULT_SESSION_ID := "default"
const MAX_SESSIONS := 8
const MAX_MESSAGES_PER_SESSION := 200
const MAX_BUFFER_BYTES := 1048576
const MAX_FRAME_BYTES := 1048576
const MAX_BREAKPOINT_SOURCES := 512
const MAX_BREAKPOINTS_PER_SOURCE := 256

const SENSITIVE_KEYS := ["authorization", "password", "secret", "token", "key", "apikey", "api_key", "access_token", "refresh_token"]
const SENSITIVE_VALUE_MARKERS := ["authorization:", "bearer ", "password=", "password:", "secret=", "secret:", "token=", "token:", "api_key=", "api_key:", "apikey=", "apikey:", "access_token=", "access_token:", "refresh_token=", "refresh_token:"]

const ACTIONS := [
	"status",
	"get_settings",
	"set_settings",
	"initialize",
	"launch",
	"attach",
	"configuration_done",
	"disconnect",
	"terminate",
	"threads",
	"set_breakpoint",
	"remove_breakpoint",
	"list_breakpoints",
	"pause",
	"continue",
	"step_over",
	"stack_trace",
	"output"
]

static var _sequence := 1
static var _breakpoints_by_session := {}
static var _sessions_by_id := {}
static var _settings := {
	"host": DEFAULT_HOST,
	"port": DEFAULT_PORT,
	"timeout_ms": DEFAULT_TIMEOUT_MS,
	"default_session_id": DEFAULT_SESSION_ID,
	"default_launch_args": {},
	"default_attach_args": {},
	"allow_remote_hosts": false
}


func get_tools() -> Array[Dictionary]:
	return [{
		"name": "debugger",
		"description": "GODOT DAP DEBUGGER: Drive Godot's Debug Adapter Protocol endpoint through one high-level session tool. Supports endpoint status, runtime settings, initialize, launch/attach, configuration_done, breakpoints, pause/continue/step_over, threads, stack_trace, output, terminate, and disconnect. The built-in endpoint is intended for GDScript debugging; managed C# breakpoints require a .NET debugger.",
		"inputSchema": {
			"type": "object",
			"properties": {
				"action": {"type": "string", "enum": ACTIONS, "description": "DAP debugger action"},
				"session_id": {"type": "string", "description": "DAP session id (default from settings, initially 'default')"},
				"host": {"type": "string", "description": "DAP host (default 127.0.0.1)"},
				"port": {"type": "integer", "description": "DAP port (default 6006)"},
				"timeout_ms": {"type": "integer", "description": "Timeout in milliseconds, capped at 30000"},
				"settings": {"type": "object", "description": "Runtime DAP settings for set_settings"},
				"include_raw": {"type": "boolean", "description": "Include sanitized raw DAP request/messages in responses"},
				"adapter_args": {"type": "object", "description": "Launch/attach arguments sent to the adapter"},
				"program": {"type": "string", "description": "Optional launch program/project path argument"},
				"cwd": {"type": "string", "description": "Optional launch working directory argument"},
				"restart": {"type": "boolean", "description": "DAP restart flag for launch/attach/disconnect"},
				"terminate_debuggee": {"type": "boolean", "description": "DAP terminateDebuggee flag for disconnect"},
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
		"get_settings":
			return _success(_settings_data())
		"set_settings":
			return _set_settings(args)
		"list_breakpoints":
			return _success(_breakpoint_list_data(_session_id(args)))
		_:
			return _error("DAP action requires asynchronous execution", {"error_type": "dap_async_required"})


func execute_async(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name != "debugger":
		return _error("Unknown tool: %s" % tool_name)
	var timeout_error := _timeout_limit_error(args)
	if not timeout_error.is_empty():
		return timeout_error
	match str(args.get("action", "")):
		"status", "get_settings", "set_settings", "list_breakpoints":
			return execute(tool_name, args)
		"initialize":
			return await _initialize(args)
		"launch":
			return await _launch_or_attach("launch", args)
		"attach":
			return await _launch_or_attach("attach", args)
		"configuration_done":
			return await _configuration_done(args)
		"disconnect":
			return await _disconnect(args)
		"terminate":
			return await _terminate(args)
		"threads":
			return await _session_request("threads", {}, args, {"require_initialized": true})
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


func _initialize(args: Dictionary) -> Dictionary:
	var initialize_args := {
		"clientID": str(args.get("client_id", "godot-dotnet-mcp")),
		"clientName": str(args.get("client_name", "Godot .NET MCP")),
		"adapterID": str(args.get("adapter_id", "godot")),
		"pathFormat": "path",
		"linesStartAt1": true,
		"columnsStartAt1": true,
		"supportsVariableType": true,
		"supportsVariablePaging": true,
		"supportsRunInTerminalRequest": false
	}
	var result := await _session_request("initialize", initialize_args, args, {})
	if bool(result.get("success", false)):
		var session := _get_session(_session_id(args))
		if not session.is_empty():
			session["initialized"] = true
			session["capabilities"] = (result.get("data", {}).get("response", {}).get("body", {}) as Dictionary).duplicate(true)
	return result


func _launch_or_attach(command: String, args: Dictionary) -> Dictionary:
	var session_id := _session_id(args)
	var session := _get_session(session_id)
	if session.is_empty() or not bool(session.get("initialized", false)):
		return _session_state_error(session_id, "initialize", "%s requires an initialized DAP session" % command)
	var request_args := _adapter_args(command, args)
	var result := await _session_request(command, request_args, args, {"require_initialized": true})
	if bool(result.get("success", false)):
		session = _get_session(session_id)
		session["started"] = true
		session["launch_mode"] = command
	return result


func _configuration_done(args: Dictionary) -> Dictionary:
	var session_id := _session_id(args)
	var session := _get_session(session_id)
	if session.is_empty() or not bool(session.get("initialized", false)):
		return _session_state_error(session_id, "initialize", "configuration_done requires an initialized DAP session")
	if not bool(session.get("started", false)):
		return _session_state_error(session_id, "launch_or_attach", "configuration_done requires launch or attach first")
	var result := await _session_request("configurationDone", {}, args, {"require_initialized": true})
	if bool(result.get("success", false)):
		session = _get_session(session_id)
		session["configured"] = true
	return result


func _disconnect(args: Dictionary) -> Dictionary:
	var request_args := {
		"restart": bool(args.get("restart", false)),
		"terminateDebuggee": bool(args.get("terminate_debuggee", args.get("terminateDebuggee", false)))
	}
	var result := await _session_request("disconnect", request_args, args, {"require_existing": true})
	if bool(result.get("success", false)):
		_close_session(_session_id(args))
	return result


func _terminate(args: Dictionary) -> Dictionary:
	var result := await _session_request("terminate", {}, args, {"require_existing": true})
	if bool(args.get("disconnect", false)):
		_close_session(_session_id(args))
	return result


func _set_breakpoint(args: Dictionary) -> Dictionary:
	var source_path := _source_path(args)
	if source_path.is_empty():
		return _error("DAP set_breakpoint requires source_path")
	var line := int(args.get("line", 0))
	if line <= 0:
		return _error("DAP set_breakpoint requires line")
	var session_id := _session_id(args)
	var breakpoint_store := _breakpoint_store(session_id)
	if not breakpoint_store.has(source_path) and breakpoint_store.size() >= MAX_BREAKPOINT_SOURCES:
		return _error("Too many DAP breakpoint sources for session", {"error_type": "dap_limit_exceeded", "limit": MAX_BREAKPOINT_SOURCES, "session_id": session_id})
	var lines: Array = (breakpoint_store.get(source_path, []) as Array).duplicate()
	if not lines.has(line):
		lines.append(line)
	lines.sort()
	if lines.size() > MAX_BREAKPOINTS_PER_SOURCE:
		return _error("Too many DAP breakpoints for source", {"error_type": "dap_limit_exceeded", "limit": MAX_BREAKPOINTS_PER_SOURCE})
	var result := await _send_breakpoints(source_path, lines, args)
	if bool(result.get("success", false)):
		_store_breakpoints(session_id, source_path, lines)
		result = _with_breakpoint_list(result)
	return result


func _remove_breakpoint(args: Dictionary) -> Dictionary:
	var source_path := _source_path(args)
	if source_path.is_empty():
		return _error("DAP remove_breakpoint requires source_path")
	var line := int(args.get("line", 0))
	var session_id := _session_id(args)
	var breakpoint_store := _breakpoint_store(session_id)
	var lines: Array = (breakpoint_store.get(source_path, []) as Array).duplicate()
	lines.erase(line)
	var result := await _send_breakpoints(source_path, lines, args)
	if bool(result.get("success", false)):
		_store_breakpoints(session_id, source_path, lines)
		result = _with_breakpoint_list(result)
	return result


func _send_breakpoints(source_path: String, lines: Array, args: Dictionary) -> Dictionary:
	var breakpoints: Array[Dictionary] = []
	for line in lines:
		breakpoints.append({"line": int(line)})
	var dap_args := {"source": {"path": _dap_path(source_path)}, "breakpoints": breakpoints}
	return await _session_request("setBreakpoints", dap_args, args, {})


func _send_thread_request(command: String, args: Dictionary) -> Dictionary:
	return await _session_request(command, {"threadId": int(args.get("thread_id", 1))}, args, {})


func _collect_output(args: Dictionary) -> Dictionary:
	var session_result := await _ensure_session(args)
	if not bool(session_result.get("success", false)):
		return session_result
	var session: Dictionary = session_result.get("session", {})
	var message_start := (session.get("messages", []) as Array).size()
	var read_result := await _read_messages(session, _timeout_ms(args))
	if not bool(read_result.get("success", true)):
		return read_result
	var messages: Array = (session.get("messages", []) as Array).duplicate(true)
	var new_messages := messages.slice(message_start)
	var outputs: Array[Dictionary] = []
	for message in new_messages:
		if str(message.get("type", "")) == "event" and str(message.get("event", "")) == "output":
			outputs.append((message.get("body", {}) as Dictionary).duplicate(true))
	var data := {"outputs": _sanitize_value(outputs), "session_id": str(session.get("id", ""))}
	if bool(args.get("include_raw", false)):
		data["messages"] = _sanitize_value(new_messages)
	return _success(data)


func _session_request(command: String, arguments: Dictionary, args: Dictionary, options: Dictionary) -> Dictionary:
	var session_id := _session_id(args)
	var existing := _get_session(session_id)
	if bool(options.get("require_existing", false)) and existing.is_empty():
		return _session_state_error(session_id, "initialize", "DAP session is not connected")
	if bool(options.get("require_initialized", false)):
		if existing.is_empty() or not bool(existing.get("initialized", false)):
			return _session_state_error(session_id, "initialize", "DAP session must be initialized first")
	if not existing.is_empty() and bool(options.get("require_initialized", false) or options.get("require_existing", false)) and not _session_endpoint_matches(existing, args):
		return _session_state_error(session_id, "same_endpoint", "DAP session endpoint changed; initialize a new session before this action")
	var session_result := await _ensure_session(args)
	if not bool(session_result.get("success", false)):
		return session_result
	var session: Dictionary = session_result.get("session", {})
	if bool(options.get("require_existing", false)) and session.is_empty():
		return _session_state_error(session_id, "initialize", "DAP session is not connected")
	if bool(options.get("require_initialized", false)) and not bool(session.get("initialized", false)):
		return _session_state_error(session_id, "initialize", "DAP session must be initialized first")
	var request_seq := _sequence
	_sequence += 1
	var request := {"seq": request_seq, "type": "request", "command": command, "arguments": arguments}
	var write_result := _write_request(session, request)
	if not bool(write_result.get("success", false)):
		return write_result
	var read_result := await _read_messages(session, _timeout_ms(args), request_seq)
	if not bool(read_result.get("success", true)):
		return read_result
	var messages: Array = (session.get("messages", []) as Array).duplicate(true)
	var response := _find_response(messages, request_seq)
	if response.is_empty():
		return _dap_request_error("DAP request timed out", "dap_timeout", session_id, command, request, {}, messages, args)
	if not bool(response.get("success", true)):
		return _dap_request_error("DAP request failed", "dap_response_failed", session_id, command, request, response, messages, args)
	var data := {"session_id": session_id, "response": _sanitize_value(response)}
	if bool(args.get("include_raw", false)):
		data["request"] = _sanitize_value(request)
		data["messages"] = _sanitize_value(messages)
	return _success(data)


func _ensure_session(args: Dictionary) -> Dictionary:
	var session_id := _session_id(args)
	var host := _host(args)
	var port := _port(args)
	var endpoint_error := _validate_endpoint(host, port)
	if not endpoint_error.is_empty():
		return endpoint_error
	var session := _get_session(session_id)
	if not session.is_empty():
		var peer: StreamPeerTCP = session.get("peer")
		if str(session.get("host", "")) == host and int(session.get("port", 0)) == port:
			peer.poll()
			if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
				return {"success": true, "session": session}
		_close_session(session_id)
	var connection := await _connect(args)
	if not bool(connection.get("success", false)):
		return connection
	session = {
		"id": session_id,
		"peer": connection.get("peer"),
		"buffer": PackedByteArray(),
		"messages": [],
		"host": host,
		"port": port,
		"initialized": false,
		"started": false,
		"configured": false,
		"launch_mode": "",
		"capabilities": {}
	}
	_remember_session(session_id, session)
	return {"success": true, "session": session}


func _connect(args: Dictionary) -> Dictionary:
	var host := _host(args)
	var port := _port(args)
	var peer := StreamPeerTCP.new()
	var endpoint_error := _validate_endpoint(host, port)
	if not endpoint_error.is_empty():
		return endpoint_error
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


func _write_request(session: Dictionary, request: Dictionary) -> Dictionary:
	var peer: StreamPeerTCP = session.get("peer")
	var body := JSON.stringify(request)
	var body_bytes := body.to_utf8_buffer()
	var frame := PackedByteArray()
	frame.append_array(("Content-Length: %d\r\n\r\n" % body_bytes.size()).to_utf8_buffer())
	frame.append_array(body_bytes)
	var write_error := peer.put_data(frame)
	if write_error != OK:
		_close_session(str(session.get("id", "")))
		return _error("Failed to write DAP request", {"error_type": "dap_write_failed", "command": str(request.get("command", "")), "code": write_error})
	return _success({})


func _read_messages(session: Dictionary, timeout_ms: int, request_seq: int = -1) -> Dictionary:
	var peer: StreamPeerTCP = session.get("peer")
	var buffer: PackedByteArray = session.get("buffer", PackedByteArray())
	var messages: Array = session.get("messages", [])
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started <= timeout_ms:
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			session["buffer"] = buffer
			session["messages"] = messages
			return _success({})
		var available := peer.get_available_bytes()
		if available > 0:
			var packet := peer.get_data(available)
			if int(packet[0]) == OK and packet[1] is PackedByteArray:
				buffer.append_array(packet[1] as PackedByteArray)
				if buffer.size() > MAX_BUFFER_BYTES:
					var buffer_error := _dap_limit_error("DAP buffer exceeded maximum size", str(session.get("id", "")), "buffer_bytes", buffer.size(), MAX_BUFFER_BYTES)
					_close_session(str(session.get("id", "")))
					return buffer_error
				var drain_result := _drain_frames(buffer, messages, str(session.get("id", "")))
				if not bool(drain_result.get("success", false)):
					_close_session(str(session.get("id", "")))
					return drain_result
				buffer = drain_result.get("buffer", PackedByteArray())
				if request_seq >= 0 and not _find_response(messages, request_seq).is_empty():
					session["buffer"] = buffer
					session["messages"] = messages
					return _success({})
		await _wait_frame()
	session["buffer"] = buffer
	session["messages"] = messages
	return _success({})


func _store_breakpoints(session_id: String, source_path: String, lines: Array) -> void:
	var breakpoint_store := _breakpoint_store(session_id)
	if lines.is_empty():
		breakpoint_store.erase(source_path)
	else:
		breakpoint_store[source_path] = lines.duplicate()
	if breakpoint_store.is_empty():
		_breakpoints_by_session.erase(session_id)
	else:
		_breakpoints_by_session[session_id] = breakpoint_store


func _with_breakpoint_list(result: Dictionary) -> Dictionary:
	var data: Dictionary = result.get("data", {})
	data["breakpoints"] = _breakpoint_list_data(str(data.get("session_id", DEFAULT_SESSION_ID))).get("breakpoints", [])
	result["data"] = data
	return result


func _drain_frames(buffer: PackedByteArray, messages: Array, session_id: String) -> Dictionary:
	while true:
		var header_end := _find_header_end(buffer)
		if header_end < 0:
			return {"success": true, "buffer": buffer}
		var content_length := _content_length(buffer.slice(0, header_end).get_string_from_utf8())
		if content_length < 0:
			buffer.clear()
			return {"success": true, "buffer": buffer}
		if content_length > MAX_FRAME_BYTES:
			return _dap_limit_error("DAP frame exceeded maximum size", session_id, "frame_bytes", content_length, MAX_FRAME_BYTES)
		var body_start := header_end + 4
		if buffer.size() < body_start + content_length:
			return {"success": true, "buffer": buffer}
		var parsed = JSON.parse_string(buffer.slice(body_start, body_start + content_length).get_string_from_utf8())
		if parsed is Dictionary:
			messages.append(parsed as Dictionary)
			_trim_messages(messages)
		buffer = buffer.slice(body_start + content_length)
	return {"success": true, "buffer": buffer}


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


func _find_response(messages: Array, request_seq: int) -> Dictionary:
	for message in messages:
		if message is Dictionary and str((message as Dictionary).get("type", "")) == "response" and int((message as Dictionary).get("request_seq", -1)) == request_seq:
			return message as Dictionary
	return {}


func _breakpoint_store(session_id: String) -> Dictionary:
	if _breakpoints_by_session.has(session_id) and _breakpoints_by_session[session_id] is Dictionary:
		return (_breakpoints_by_session[session_id] as Dictionary).duplicate(true)
	return {}


func _breakpoint_list_data(session_id: String = DEFAULT_SESSION_ID) -> Dictionary:
	var items: Array[Dictionary] = []
	var breakpoint_store := _breakpoint_store(session_id)
	for source_path in breakpoint_store.keys():
		for line in breakpoint_store[source_path]:
			items.append({"session_id": session_id, "source_path": str(source_path), "line": int(line)})
	return {"session_id": session_id, "count": items.size(), "breakpoints": items}


func _total_breakpoint_count() -> int:
	var total := 0
	for session_id in _breakpoints_by_session.keys():
		total += int(_breakpoint_list_data(str(session_id)).get("count", 0))
	return total


func _status_data() -> Dictionary:
	var sessions: Array[Dictionary] = []
	for session_id in _sessions_by_id.keys():
		var session: Dictionary = _sessions_by_id[session_id]
		sessions.append({
			"session_id": str(session_id),
			"endpoint": "%s:%d" % [str(session.get("host", "")), int(session.get("port", 0))],
			"initialized": bool(session.get("initialized", false)),
			"started": bool(session.get("started", false)),
			"configured": bool(session.get("configured", false)),
			"launch_mode": str(session.get("launch_mode", "")),
			"message_count": (session.get("messages", []) as Array).size(),
			"capabilities": (session.get("capabilities", {}) as Dictionary).duplicate(true)
		})
	return {
		"protocol": "Debug Adapter Protocol",
		"godot_builtin_dap_scope": "GDScript",
		"csharp_debugger_note": "C# breakpoints require a .NET debugger such as coreclr.",
		"sequence": _sequence,
		"default_host": str(_settings.get("host", DEFAULT_HOST)),
		"default_port": int(_settings.get("port", DEFAULT_PORT)),
		"default_session_id": str(_settings.get("default_session_id", DEFAULT_SESSION_ID)),
		"breakpoint_count": _total_breakpoint_count(),
		"session_count": sessions.size(),
		"sessions": sessions,
		"settings": _settings_data(false)
	}


func _settings_data(include_adapter_args: bool = false) -> Dictionary:
	var data := _settings.duplicate(true)
	if include_adapter_args:
		return _sanitize_value(data) as Dictionary
	data["default_launch_args"] = {}
	data["default_attach_args"] = {}
	return data


func _set_settings(args: Dictionary) -> Dictionary:
	var incoming = args.get("settings", {})
	if not (incoming is Dictionary):
		return _error("DAP settings must be a dictionary", {"error_type": "dap_invalid_settings"})
	var incoming_settings := incoming as Dictionary
	var next_settings := _settings.duplicate(true)
	if incoming_settings.has("allow_remote_hosts"):
		next_settings["allow_remote_hosts"] = bool(incoming_settings["allow_remote_hosts"])
	for key in incoming_settings.keys():
		match str(key):
			"host":
				var host := str(incoming_settings[key]).strip_edges()
				if host.is_empty():
					return _error("DAP host setting cannot be empty", {"error_type": "dap_invalid_settings"})
				if not _is_loopback_host(host) and not bool(next_settings.get("allow_remote_hosts", false)):
					return _error("DAP host must be loopback unless allow_remote_hosts is enabled", {"error_type": "dap_invalid_settings"})
				next_settings["host"] = host
			"port":
				var port := int(incoming_settings[key])
				if port <= 0 or port > 65535:
					return _error("DAP port setting is invalid", {"error_type": "dap_invalid_settings"})
				else:
					next_settings["port"] = port
			"timeout_ms":
				var timeout_ms := int(incoming_settings[key])
				if timeout_ms <= 0:
					return _error("DAP timeout_ms setting is invalid", {"error_type": "dap_invalid_settings"})
				if timeout_ms > MAX_TIMEOUT_MS:
					return _error("DAP timeout_ms setting exceeds the maximum", {"error_type": "dap_limit_exceeded", "limit": MAX_TIMEOUT_MS, "timeout_ms": timeout_ms})
				else:
					next_settings["timeout_ms"] = timeout_ms
			"default_session_id":
				var default_session_id := str(incoming_settings[key]).strip_edges()
				if default_session_id.is_empty():
					return _error("DAP default_session_id setting cannot be empty", {"error_type": "dap_invalid_settings"})
				else:
					next_settings["default_session_id"] = default_session_id
			"default_launch_args", "default_attach_args":
				var value = incoming_settings[key]
				if not (value is Dictionary):
					return _error("DAP %s setting must be a dictionary" % str(key), {"error_type": "dap_invalid_settings"})
				next_settings[str(key)] = (value as Dictionary).duplicate(true)
			"allow_remote_hosts":
				pass
			_:
				return _error("Unknown DAP setting: %s" % str(key), {"error_type": "dap_invalid_settings"})
	if not bool(next_settings.get("allow_remote_hosts", false)) and not _is_loopback_host(str(next_settings.get("host", DEFAULT_HOST))):
		return _error("DAP host must be loopback unless allow_remote_hosts is enabled", {"error_type": "dap_invalid_settings"})
	_settings = next_settings
	return _success(_settings_data(false), "DAP settings updated")


func _adapter_args(command: String, args: Dictionary) -> Dictionary:
	var defaults_key := "default_launch_args" if command == "launch" else "default_attach_args"
	var out: Dictionary = (_settings.get(defaults_key, {}) as Dictionary).duplicate(true)
	var raw_args = args.get("adapter_args", {})
	if raw_args is Dictionary:
		for key in (raw_args as Dictionary).keys():
			out[key] = (raw_args as Dictionary)[key]
	if args.has("program"):
		out["program"] = str(args.get("program", ""))
	if args.has("cwd"):
		out["cwd"] = str(args.get("cwd", ""))
	if args.has("restart"):
		out["restart"] = bool(args.get("restart", false))
	return out


func _session_id(args: Dictionary) -> String:
	var value := str(args.get("session_id", _settings.get("default_session_id", DEFAULT_SESSION_ID))).strip_edges()
	return value if not value.is_empty() else DEFAULT_SESSION_ID


func _get_session(session_id: String) -> Dictionary:
	if _sessions_by_id.has(session_id) and _sessions_by_id[session_id] is Dictionary:
		return _sessions_by_id[session_id]
	return {}


func _session_endpoint_matches(session: Dictionary, args: Dictionary) -> bool:
	return str(session.get("host", "")) == _host(args) and int(session.get("port", 0)) == _port(args)


func _close_session(session_id: String) -> void:
	var session := _get_session(session_id)
	if session.is_empty():
		return
	var peer: StreamPeerTCP = session.get("peer")
	if peer != null:
		peer.disconnect_from_host()
	_sessions_by_id.erase(session_id)
	_breakpoints_by_session.erase(session_id)


func _remember_session(session_id: String, session: Dictionary) -> void:
	if not _sessions_by_id.has(session_id) and _sessions_by_id.size() >= MAX_SESSIONS:
		_close_session(str(_sessions_by_id.keys()[0]))
	_sessions_by_id[session_id] = session


func _trim_messages(messages: Array) -> void:
	while messages.size() > MAX_MESSAGES_PER_SESSION:
		messages.remove_at(0)


func _validate_endpoint(host: String, port: int) -> Dictionary:
	if host.is_empty() or port <= 0 or port > 65535:
		return _error("Invalid DAP endpoint", _dap_unavailable_data({"host": host, "port": port}, "invalid_endpoint"))
	if not _is_loopback_host(host) and not bool(_settings.get("allow_remote_hosts", false)):
		return _error("DAP remote endpoints are disabled", _dap_unavailable_data({"host": host, "port": port}, "remote_endpoint_disabled"))
	return {}


func _is_loopback_host(host: String) -> bool:
	var normalized := host.strip_edges().to_lower()
	return normalized == "localhost" or normalized == "127.0.0.1" or normalized == "::1" or normalized == "[::1]"


func _session_state_error(session_id: String, expected: String, message: String) -> Dictionary:
	return _error(message, {"error_type": "dap_invalid_session_state", "session_id": session_id, "expected": expected})


func _dap_request_error(message: String, error_type: String, session_id: String, command: String, request: Dictionary, response: Dictionary, messages: Array, args: Dictionary) -> Dictionary:
	var data := {"error_type": error_type, "session_id": session_id, "command": command}
	if bool(args.get("include_raw", false)):
		data["request"] = _sanitize_value(request)
		if not response.is_empty():
			data["response"] = _sanitize_value(response)
		data["messages"] = _sanitize_value(messages)
	return _error(message, data)


func _dap_limit_error(message: String, session_id: String, size_key: String, size_value: int, limit: int) -> Dictionary:
	return _error(message, {"error_type": "dap_limit_exceeded", "session_id": session_id, size_key: size_value, "limit": limit})


func _sanitize_value(value):
	if value is Dictionary:
		var out := {}
		for key in (value as Dictionary).keys():
			var key_text := str(key)
			if _is_sensitive_key(key_text):
				out[key] = "[redacted]"
			else:
				out[key] = _sanitize_value((value as Dictionary)[key])
		return out
	if value is Array:
		var out_array := []
		for item in value:
			out_array.append(_sanitize_value(item))
		return out_array
	if value is String:
		return _sanitize_string(value)
	return value


func _sanitize_string(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	for marker in SENSITIVE_VALUE_MARKERS:
		if normalized.find(str(marker)) >= 0:
			return "[redacted]"
	return value


func _is_sensitive_key(key: String) -> bool:
	var normalized := key.to_lower().replace("-", "_")
	for sensitive_key in SENSITIVE_KEYS:
		if normalized.find(str(sensitive_key)) >= 0:
			return true
	return false


func _dap_unavailable_data(args: Dictionary, transport_status: String) -> Dictionary:
	var host := _host(args)
	var port := _port(args)
	return {
		"error_type": "dap_unavailable",
		"endpoint": "%s:%d" % [host, port],
		"host": host,
		"port": port,
		"timeout_ms": _timeout_ms(args),
		"transport_status": transport_status,
		"protocol": "Debug Adapter Protocol"
	}


func _timeout_limit_error(args: Dictionary) -> Dictionary:
	if not args.has("timeout_ms"):
		return {}
	var timeout_ms := int(args.get("timeout_ms", DEFAULT_TIMEOUT_MS))
	if timeout_ms <= 0:
		return {}
	if timeout_ms > MAX_TIMEOUT_MS:
		return _error("DAP timeout_ms exceeds the maximum", {"error_type": "dap_limit_exceeded", "limit": MAX_TIMEOUT_MS, "timeout_ms": timeout_ms})
	return {}


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


func _host(args: Dictionary) -> String:
	return str(args.get("host", _settings.get("host", DEFAULT_HOST))).strip_edges()


func _port(args: Dictionary) -> int:
	return int(args.get("port", _settings.get("port", DEFAULT_PORT)))


func _timeout_ms(args: Dictionary) -> int:
	var value := int(args.get("timeout_ms", _settings.get("timeout_ms", DEFAULT_TIMEOUT_MS)))
	if value <= 0:
		return DEFAULT_TIMEOUT_MS
	return mini(value, MAX_TIMEOUT_MS)


func _wait_frame() -> void:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		await (loop as SceneTree).process_frame
	else:
		OS.delay_msec(10)
