@tool
extends Node
class_name MCPStdioServer

## MCP Stdio Transport Server
## Reads JSON-RPC 2.0 requests from stdin (Content-Length framed, same as LSP protocol)
## Writes responses to stdout
## Designed for Claude Desktop and headless Godot usage:
##   godot --headless --path /path/to/project --script res://addons/.../mcp_stdio_entry.gd

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const GDScriptLspDiagnosticsService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/gdscript_lsp_diagnostics_service.gd")
const GDScriptLspDiagnosticsServicePath = "res://addons/godot_dotnet_mcp/plugin/runtime/gdscript_lsp_diagnostics_service.gd"

signal request_received(method: String, params: Dictionary)

var _enabled: bool = false
var _buffer: PackedByteArray = PackedByteArray()
var _tool_loader        # injected by server_runtime_controller, shared with HTTP server
var _debug_mode: bool = false
var _disabled_tools: Dictionary = {}
const MCP_VERSION = "2025-06-18"
const SERVER_NAME = "godot-mcp-server"
const SERVER_VERSION = "0.5.0"
const STDIN_READ_SIZE := 1 # Read incrementally to preserve partial JSON-RPC frames.


func _ready() -> void:
	set_process(true)


func initialize(tool_loader, debug_mode: bool = false) -> void:
	_tool_loader = tool_loader
	_debug_mode = debug_mode


func start() -> void:
	_enabled = true
	_log("stdio transport started", "info")


func stop() -> void:
	_enabled = false
	_log("stdio transport stopped", "info")


func is_running() -> bool:
	return _enabled


func set_disabled_tools(disabled: Array) -> void:
	_disabled_tools.clear()
	for t in disabled:
		_disabled_tools[str(t)] = true


func get_gdscript_lsp_diagnostics_service():
	if _tool_loader != null and _tool_loader.has_method("get_gdscript_lsp_diagnostics_service"):
		return _tool_loader.get_gdscript_lsp_diagnostics_service()
	return GDScriptLspDiagnosticsService.get_singleton()


func _process(_delta: float) -> void:
	if _enabled:
		while true:
			var chunk: PackedByteArray = OS.read_buffer_from_stdin(STDIN_READ_SIZE)
			if chunk.is_empty():
				break
			_buffer.append_array(chunk)
			if _try_parse_frame():
				break

	if _tool_loader != null and _tool_loader.has_method("tick"):
		_tool_loader.tick(_delta)


func _try_parse_frame() -> bool:
	while true:
		var buffer_text: String = _buffer.get_string_from_ascii()
		var header_end: int = buffer_text.find("\r\n\r\n")
		if header_end == -1:
			return false
		var header_bytes: PackedByteArray = _buffer.slice(0, header_end)
		var header: String = header_bytes.get_string_from_ascii()
		var content_length: int = -1
		for line in header.split("\r\n"):
			if line.to_lower().begins_with("content-length:"):
				content_length = int(line.substr(15).strip_edges())
		if content_length < 0:
			# Malformed header — discard buffer up to next potential header
			_buffer = PackedByteArray()
			return false
		var body_start: int = header_end + 4
		# Byte-level check (UTF-8 multi-byte safe)
		if _buffer.size() - body_start < content_length:
			return false  # Wait for more data
		var body_bytes: PackedByteArray = _buffer.slice(body_start, body_start + content_length)
		var body: String = body_bytes.get_string_from_utf8()
		_buffer = _buffer.slice(body_start + content_length)
		_handle_request(body)
		return true

	return false


func _handle_request(body: String) -> void:
	_log("Parsing request (%d bytes)" % body.length(), "trace")
	var json := JSON.new()
	if json.parse(body) != OK:
		_write_response(_create_json_rpc_error(-32700, "Parse error: %s" % json.get_error_message(), null))
		return

	var request: Variant = json.get_data()
	if not request is Dictionary:
		_write_response(_create_json_rpc_error(-32600, "Invalid Request", null))
		return

	var request_dict: Dictionary = request
	var method: String = str(request_dict.get("method", ""))
	var params: Variant = request_dict.get("params", {})
	var has_id: bool = request_dict.has("id")
	var id: Variant = request_dict.get("id")

	_log("Method: %s" % method, "debug")
	request_received.emit(method, params)

	# Notifications (no id) get no response
	if not has_id:
		return

	var response: Dictionary
	match method:
		"initialize":
			response = _create_json_rpc_response({
				"protocolVersion": MCP_VERSION,
				"capabilities": {"tools": {"listChanged": false}},
				"serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION}
			}, id)
		"initialized", "notifications/initialized":
			response = _create_json_rpc_response({}, id)
		"tools/list":
			response = _handle_tools_list(id)
		"tools/call":
			response = _handle_tools_call(params, id)
		"ping":
			response = _create_json_rpc_response({}, id)
		_:
			response = _create_json_rpc_error(-32601, "Method not found: %s" % method, id)

	_write_response(response)


func _handle_tools_list(id) -> Dictionary:
	if _tool_loader == null:
		return _create_json_rpc_error(-32603, "Tool loader not initialized", id)
	var tools_list: Array[Dictionary] = []
	for tool_def in _tool_loader.get_exposed_tool_definitions():
		tools_list.append({
			"name": tool_def["name"],
			"description": tool_def.get("description", ""),
			"category": tool_def.get("category", ""),
			"domainKey": tool_def.get("domain_key", "other"),
			"loadState": tool_def.get("load_state", "definitions_only"),
			"source": tool_def.get("source", "builtin"),
			"enabled": bool(tool_def.get("enabled", true)),
			"inputSchema": tool_def.get("inputSchema", {"type": "object", "properties": {}})
		})
	return _create_json_rpc_response({"tools": tools_list}, id)


func _handle_tools_call(params: Dictionary, id) -> Dictionary:
	if _tool_loader == null:
		return _create_json_rpc_error(-32603, "Tool loader not initialized", id)
	var tool_name := str(params.get("name", ""))
	var arguments = params.get("arguments", {})

	if tool_name.is_empty():
		return _create_tool_response({"success": false, "error": "Missing tool name"}, id)
	if _disabled_tools.has(tool_name):
		return _create_tool_response({"success": false, "error": "Tool '%s' is disabled" % tool_name}, id)
	if _tool_loader.has_method("is_tool_exposed") and not bool(_tool_loader.is_tool_exposed(tool_name)):
		return _create_tool_response({"success": false, "error": "Tool '%s' is not exposed" % tool_name}, id)

	var resolved := _resolve_tool_call_name(tool_name)
	if not bool(resolved.get("success", false)):
		return _create_tool_response({"success": false, "error": "Invalid tool name: %s" % tool_name}, id)

	var result: Dictionary = _tool_loader.execute_tool(str(resolved["category"]), str(resolved["tool"]), arguments)
	return _create_tool_response(result, id)


func _resolve_tool_call_name(tool_name: String) -> Dictionary:
	# Exact match via tool definitions
	for tool_def in _tool_loader.get_tool_definitions():
		if str(tool_def.get("name", "")) != tool_name:
			continue
		var cat := str(tool_def.get("category", ""))
		if cat.is_empty():
			break
		var resolved := tool_name
		if tool_name.begins_with("%s_" % cat):
			resolved = tool_name.substr(cat.length() + 1)
		return {"success": true, "category": cat, "tool": resolved}
	# Fallback: longest matching prefix
	var best_cat := ""
	for state in _tool_loader.get_domain_states():
		var cat := str(state.get("category", ""))
		if not cat.is_empty() and tool_name.begins_with("%s_" % cat) and cat.length() > best_cat.length():
			best_cat = cat
	if not best_cat.is_empty():
		return {"success": true, "category": best_cat, "tool": tool_name.substr(best_cat.length() + 1)}
	# Last resort: split on first _
	var parts := tool_name.split("_", true, 1)
	if parts.size() < 2:
		return {"success": false}
	return {"success": true, "category": parts[0], "tool": parts[1]}


func _create_tool_response(result: Dictionary, id) -> Dictionary:
	var normalized := _normalize_tool_result(result)
	var sanitized: Variant = _sanitize_for_json(normalized)
	var result_text := JSON.stringify(sanitized)
	var is_error := not bool(normalized.get("success", false))
	return _create_json_rpc_response({
		"content": [{"type": "text", "text": result_text}],
		"isError": is_error
	}, id)


func _normalize_tool_result(result) -> Dictionary:
	if not (result is Dictionary):
		return {"success": true, "data": result, "message": ""}
	var normalized: Dictionary = result.duplicate(true)
	normalized["success"] = bool(normalized.get("success", true))
	var reserved := {"success": true, "data": true, "message": true, "error": true, "hints": true}
	var extra := {}
	for key in normalized.keys():
		if not reserved.has(key):
			extra[key] = normalized[key]
	if normalized["success"]:
		if not normalized.has("data"):
			normalized["data"] = extra if not extra.is_empty() else null
		if not normalized.has("message"):
			normalized["message"] = ""
		normalized.erase("error")
	else:
		if not normalized.has("error"):
			normalized["error"] = str(normalized.get("message", "Tool execution failed"))
		normalized.erase("message")
		if not normalized.has("data") and not extra.is_empty():
			normalized["data"] = extra
	for key in extra.keys():
		normalized.erase(key)
	return normalized


func _create_json_rpc_response(result, id) -> Dictionary:
	return {"jsonrpc": "2.0", "result": result, "id": id}


func _create_json_rpc_error(code: int, message: String, id) -> Dictionary:
	return {"jsonrpc": "2.0", "error": {"code": code, "message": message}, "id": id}


func _write_response(obj: Dictionary) -> void:
	var body := JSON.stringify(_sanitize_for_json(obj))
	var body_bytes := body.to_utf8_buffer()
	# Content-Length frame; print() appends \n which is fine as inter-frame whitespace
	print("Content-Length: %d\r\n\r\n%s" % [body_bytes.size(), body])


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
