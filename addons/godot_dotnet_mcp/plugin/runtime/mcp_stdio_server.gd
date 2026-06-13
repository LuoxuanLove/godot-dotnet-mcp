@tool
extends Node
class_name MCPStdioServer

## MCP Stdio Transport Server
## Reads JSON-RPC 2.0 requests from stdin (newline-delimited by default)
## Writes responses to stdout
## Designed for Claude Desktop and headless Godot usage:
##   godot --headless --path /path/to/project --script res://addons/.../mcp_stdio_entry.gd

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const MCPStdioServiceBundleScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_stdio_service_bundle.gd")

signal request_received(method: String, params: Dictionary)

var _enabled: bool = false
var _buffer: PackedByteArray = PackedByteArray()
var _tool_loader        # injected by server_runtime_controller, shared with HTTP server
var _debug_mode: bool = false
var _disabled_tools: Dictionary = {}
var _service_bundle = MCPStdioServiceBundleScript.new()
var _processing_stdin := false
var _transport_generation := 0
var _last_written_response: Dictionary = {}
var _last_written_frame := ""
var _stdio_framing_mode := "newline"
const STDIO_FRAMING_NEWLINE := "newline"
const STDIO_FRAMING_LEGACY_CONTENT_LENGTH := "legacy_content_length"
const STDIN_READ_SIZE := 1 # Read incrementally to preserve partial JSON-RPC frames.
const MAX_STDIN_FRAMES_PER_TICK := 16
const MAX_STDIN_BYTES_PER_TICK := 8192
const MAX_STDIN_CONTENT_LENGTH := 1024 * 1024
const MAX_STDIN_HEADER_BYTES := 64 * 1024
const MAX_STDIN_PENDING_BYTES := MAX_STDIN_CONTENT_LENGTH + MAX_STDIN_HEADER_BYTES


func _ready() -> void:
	set_process(true)


func _exit_tree() -> void:
	dispose()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		dispose()


func dispose() -> void:
	if _service_bundle != null and _service_bundle.has_method("dispose"):
		_service_bundle.dispose()
	_service_bundle = null
	_enabled = false
	_buffer = PackedByteArray()
	_tool_loader = null
	_disabled_tools.clear()
	_last_written_response = {}
	_last_written_frame = ""


func initialize(tool_loader, debug_mode: bool = false) -> void:
	_tool_loader = tool_loader
	_debug_mode = debug_mode
	_configure_service_bundle()


func start() -> void:
	_enabled = true
	_transport_generation += 1
	_buffer = PackedByteArray()
	_log("stdio transport started", "info")


func stop() -> void:
	_enabled = false
	_transport_generation += 1
	_buffer = PackedByteArray()
	_log("stdio transport stopped", "info")


func is_running() -> bool:
	return _enabled


func set_framing_mode(mode: String) -> void:
	if mode == STDIO_FRAMING_NEWLINE or mode == STDIO_FRAMING_LEGACY_CONTENT_LENGTH:
		_stdio_framing_mode = mode


func get_framing_mode() -> String:
	return _stdio_framing_mode


func set_disabled_tools(disabled: Array) -> void:
	_disabled_tools.clear()
	for t in disabled:
		_disabled_tools[str(t)] = true


func get_gdscript_lsp_diagnostics_service():
	if _tool_loader != null and _tool_loader.has_method("get_gdscript_lsp_diagnostics_service"):
		var service = _tool_loader.get_gdscript_lsp_diagnostics_service()
		if service != null:
			return service
	return null


func _process(_delta: float) -> void:
	if _enabled and not _processing_stdin:
		_processing_stdin = true
		var generation := _transport_generation
		var frames_processed := 0
		var bytes_read := 0
		while _enabled and generation == _transport_generation and frames_processed < MAX_STDIN_FRAMES_PER_TICK:
			if await _try_parse_frame(generation):
				frames_processed += 1
				continue
			if bytes_read >= MAX_STDIN_BYTES_PER_TICK:
				break
			var read_any := false
			while bytes_read < MAX_STDIN_BYTES_PER_TICK:
				var read_size = mini(STDIN_READ_SIZE, MAX_STDIN_BYTES_PER_TICK - bytes_read)
				var chunk: PackedByteArray = OS.read_buffer_from_stdin(read_size)
				if chunk.is_empty():
					break
				read_any = true
				bytes_read += chunk.size()
				_buffer.append_array(chunk)
				if _buffer.size() > MAX_STDIN_PENDING_BYTES:
					_reject_stdio_frame(
						"Stdio pending buffer exceeded maximum supported size of %d bytes." % MAX_STDIN_PENDING_BYTES,
						"stdio_pending_buffer_exceeded"
					)
					break
			if not read_any:
				break
		_processing_stdin = false

	if _tool_loader != null and _tool_loader.has_method("tick"):
		_tool_loader.tick(_delta)


func _try_parse_frame(generation: int) -> bool:
	if _stdio_framing_mode == STDIO_FRAMING_LEGACY_CONTENT_LENGTH:
		return await _try_parse_legacy_content_length_frame(generation)
	return await _try_parse_newline_frame(generation)


func _try_parse_newline_frame(generation: int) -> bool:
	while true:
		if not _enabled or generation != _transport_generation:
			return false
		if _buffer.size() > MAX_STDIN_PENDING_BYTES:
			_reject_stdio_frame(
				"Stdio pending buffer exceeded maximum supported size of %d bytes." % MAX_STDIN_PENDING_BYTES,
				"stdio_pending_buffer_exceeded"
			)
			return false
		if _buffer.size() > 0 and _buffer.get_string_from_utf8().begins_with("Content-Length:"):
			_reject_stdio_frame(
				"Legacy Content-Length stdio framing requires explicit compatibility mode.",
				"stdio_legacy_content_length_requires_compat"
			)
			return false
		var newline_index := _find_byte(_buffer, 10)
		if newline_index == -1:
			if _buffer.size() > MAX_STDIN_CONTENT_LENGTH:
				_reject_stdio_frame(
					"Stdio newline-delimited frame exceeded maximum supported size of %d bytes." % MAX_STDIN_CONTENT_LENGTH,
					"stdio_line_too_large"
				)
			return false
		var line_bytes: PackedByteArray = _buffer.slice(0, newline_index)
		_buffer = _buffer.slice(newline_index + 1)
		if line_bytes.size() > 0 and line_bytes[line_bytes.size() - 1] == 13:
			line_bytes = line_bytes.slice(0, line_bytes.size() - 1)
		if line_bytes.is_empty():
			continue
		if line_bytes.size() > MAX_STDIN_CONTENT_LENGTH:
			_reject_stdio_frame(
				"Stdio newline-delimited frame exceeded maximum supported size of %d bytes." % MAX_STDIN_CONTENT_LENGTH,
				"stdio_line_too_large"
			)
			return false
		var body: String = line_bytes.get_string_from_utf8()
		await _handle_request(body, generation)
		return true

	return false


func _try_parse_legacy_content_length_frame(generation: int) -> bool:
	while true:
		if not _enabled or generation != _transport_generation:
			return false
		if _buffer.size() > MAX_STDIN_PENDING_BYTES:
			_reject_stdio_frame(
				"Stdio pending buffer exceeded maximum supported size of %d bytes." % MAX_STDIN_PENDING_BYTES,
				"stdio_pending_buffer_exceeded"
			)
			return false
		var buffer_text: String = _buffer.get_string_from_ascii()
		var header_end: int = buffer_text.find("\r\n\r\n")
		if header_end == -1:
			return false
		var header_bytes: PackedByteArray = _buffer.slice(0, header_end)
		var header: String = header_bytes.get_string_from_ascii()
		var content_length_result := _parse_stdio_content_length(header)
		if not bool(content_length_result.get("success", false)):
			_reject_stdio_frame(
				str(content_length_result.get("error", "Invalid stdio Content-Length header.")),
				str(content_length_result.get("type", "stdio_bad_content_length"))
			)
			return false
		var content_length := int(content_length_result.get("content_length", 0))
		var body_start: int = header_end + 4
		# Byte-level check (UTF-8 multi-byte safe)
		if _buffer.size() - body_start < content_length:
			return false  # Wait for more data
		var body_bytes: PackedByteArray = _buffer.slice(body_start, body_start + content_length)
		var body: String = body_bytes.get_string_from_utf8()
		_buffer = _buffer.slice(body_start + content_length)
		await _handle_request(body, generation)
		return true

	return false


func _find_byte(bytes: PackedByteArray, byte_value: int) -> int:
	for index in range(bytes.size()):
		if bytes[index] == byte_value:
			return index
	return -1


func _parse_stdio_content_length(header: String) -> Dictionary:
	var values: Array[String] = []
	for line in header.split("\r\n"):
		if line.to_lower().begins_with("content-length:"):
			values.append(line.substr(15).strip_edges())
	if values.is_empty():
		return {"success": false, "type": "stdio_missing_content_length", "error": "Missing Content-Length header."}
	if values.size() > 1:
		return {"success": false, "type": "stdio_duplicate_content_length", "error": "Duplicate Content-Length headers are not supported."}
	var text := values[0]
	if not text.is_valid_int():
		return {"success": false, "type": "stdio_bad_content_length", "error": "Content-Length must be a positive integer."}
	var parsed := int(text)
	if parsed <= 0:
		return {"success": false, "type": "stdio_bad_content_length", "error": "Content-Length must be greater than zero."}
	if parsed > MAX_STDIN_CONTENT_LENGTH:
		return {
			"success": false,
			"type": "stdio_frame_too_large",
			"error": "Content-Length exceeds maximum supported size of %d bytes." % MAX_STDIN_CONTENT_LENGTH
		}
	return {"success": true, "content_length": parsed}


func _reject_stdio_frame(message: String, error_type: String = "stdio_bad_framing") -> void:
	_buffer = PackedByteArray()
	_log("Rejecting malformed stdio frame: %s (%s)" % [message, error_type], "warning")
	_write_response(_create_json_rpc_error(-32700, "%s [%s]" % [message, error_type], null))


func _handle_request(body: String, generation: int = -1) -> void:
	var should_guard_generation := generation >= 0
	if generation < 0:
		generation = _transport_generation
	_configure_service_bundle()
	var result: Dictionary = await _service_bundle.handle_request_async(body)
	if not bool(result.get("respond", false)):
		_last_written_response = {}
		_last_written_frame = ""
		return
	var response: Dictionary = result.get("response", {})

	if should_guard_generation and (not _enabled or generation != _transport_generation):
		_log("Dropping stdio response after transport stop or restart", "debug")
		return
	_write_response(response)


func _handle_tools_list(id) -> Dictionary:
	_configure_service_bundle()
	return _service_bundle.handle_tools_list(id)


func _handle_tools_call(params, id) -> Dictionary:
	return await _handle_tools_call_async(params, id)


func _handle_tools_call_async(params, id) -> Dictionary:
	_configure_service_bundle()
	return await _service_bundle.handle_tools_call_async(params, id)


func _is_stdio_tool_disabled(tool_name: String) -> bool:
	if _disabled_tools.has(tool_name):
		return true
	return false


func _handle_resources_list(params, id) -> Dictionary:
	_configure_service_bundle()
	return _service_bundle.handle_resources_list(params, id)


func _handle_resources_templates_list(params, id) -> Dictionary:
	_configure_service_bundle()
	return _service_bundle.handle_resources_templates_list(params, id)


func _handle_resources_read(params, id) -> Dictionary:
	_configure_service_bundle()
	return _service_bundle.handle_resources_read(params, id)

func _handle_prompts_list(params, id) -> Dictionary:
	_configure_service_bundle()
	return _service_bundle.handle_prompts_list(params, id)


func _handle_prompts_get(params, id) -> Dictionary:
	_configure_service_bundle()
	return _service_bundle.handle_prompts_get(params, id)


func _get_stdio_tool_activity_registry():
	_configure_service_bundle()
	return _service_bundle.get_stdio_tool_activity_registry()


func _configure_service_bundle() -> void:
	if _service_bundle == null:
		_service_bundle = MCPStdioServiceBundleScript.new()
	_service_bundle.configure(self)


func _get_stdio_tool_loader_status() -> Dictionary:
	_configure_service_bundle()
	return _service_bundle.get_stdio_tool_loader_status()


func _normalize_tool_result(result) -> Dictionary:
	_configure_service_bundle()
	return _service_bundle.normalize_tool_result(result)


func _create_json_rpc_response(result, id) -> Dictionary:
	return {"jsonrpc": "2.0", "result": result, "id": id}


func _create_json_rpc_error(code: int, message: String, id) -> Dictionary:
	return {"jsonrpc": "2.0", "error": {"code": code, "message": message}, "id": id}


func _write_response(obj: Dictionary) -> void:
	_last_written_response = obj.duplicate(true)
	var body := JSON.stringify(_sanitize_for_json(obj))
	var body_bytes := body.to_utf8_buffer()
	if _stdio_framing_mode == STDIO_FRAMING_LEGACY_CONTENT_LENGTH:
		_last_written_frame = "Content-Length: %d\r\n\r\n%s" % [body_bytes.size(), body]
	else:
		_last_written_frame = body
	if OS.has_method("write_string_to_stdout"):
		OS.call("write_string_to_stdout", _last_written_frame)
	else:
		print(_last_written_frame)


func _sanitize_for_json(value):
	match typeof(value):
		TYPE_DICTIONARY:
			var result = {}
			for key in value:
				result[str(key)] = _sanitize_for_json(value[key])
			return result
		TYPE_ARRAY:
			var result = []
			for item in value:
				result.append(_sanitize_for_json(item))
			return result
		TYPE_FLOAT:
			if is_nan(value):
				return 0.0
			if is_inf(value):
				return 999999999.0 if value > 0 else -999999999.0
			return value
		TYPE_STRING_NAME:
			return str(value)
		TYPE_NODE_PATH:
			return str(value)
		TYPE_OBJECT:
			if value == null:
				return null
			return str(value)
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4:
			return str(value)
		_:
			return value


func _log(message: String, level: String = "debug") -> void:
	MCPDebugBuffer.record(level, "stdio_server", message)
