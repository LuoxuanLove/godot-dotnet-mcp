@tool
extends Node
class_name MCPStdioServer

## MCP Stdio Transport Server
## Reads JSON-RPC 2.0 requests from stdin (Content-Length framed, same as LSP protocol)
## Writes responses to stdout
## Designed for Claude Desktop and headless Godot usage:
##   godot --headless --path /path/to/project --script res://addons/.../mcp_stdio_entry.gd

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const MCPProtocolFacts = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd")
const MCPResourcesServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_resources_service.gd")
const MCPResourcesServiceContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_resources_service_context.gd")
const MCPPromptsServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_prompts_service.gd")
const MCPPromptsServiceContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_prompts_service_context.gd")
const MCPToolActivityRegistry = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_activity_registry.gd")
const MCPToolRpcRouterScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_rpc_router.gd")
const MCPToolRpcRouterContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_rpc_router_context.gd")
const ToolPresentationService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_presentation_service.gd")

signal request_received(method: String, params: Dictionary)

var _enabled: bool = false
var _buffer: PackedByteArray = PackedByteArray()
var _tool_loader        # injected by server_runtime_controller, shared with HTTP server
var _debug_mode: bool = false
var _disabled_tools: Dictionary = {}
var _resources_service = MCPResourcesServiceScript.new()
var _prompts_service = MCPPromptsServiceScript.new()
var _tool_rpc_router = MCPToolRpcRouterScript.new()
var _tool_activity_registry = MCPToolActivityRegistry.new()
var _processing_stdin := false
var _transport_generation := 0
var _last_written_response: Dictionary = {}
const STDIN_READ_SIZE := 1 # Read incrementally to preserve partial JSON-RPC frames.
const MAX_STDIN_FRAMES_PER_TICK := 16
const MAX_STDIN_BYTES_PER_TICK := 8192
const MAX_STDIN_PENDING_BYTES := 1024 * 1024
const MAX_STDIN_CONTENT_LENGTH := 1024 * 1024


func _ready() -> void:
	set_process(true)


func initialize(tool_loader, debug_mode: bool = false) -> void:
	_tool_loader = tool_loader
	_debug_mode = debug_mode
	_configure_tool_activity_registry()
	_configure_tool_rpc_router()
	_configure_resources_prompts_services()


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
	if generation < 0:
		generation = _transport_generation
	_log("Parsing request (%d bytes)" % body.length(), "debug")
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
	if not (params is Dictionary):
		if not has_id:
			return
		_write_response(_create_json_rpc_error(-32602, "Invalid params: expected object", id))
		return
	var params_dict := params as Dictionary

	_log("Method: %s" % method, "debug")
	request_received.emit(method, params_dict)

	# Notifications (no id) get no response
	if not has_id:
		return

	var response: Dictionary
	match method:
		"initialize":
			_ensure_resources_prompts_services()
			response = _create_json_rpc_response({
				"protocolVersion": MCPProtocolFacts.get_protocol_version(),
				"toolSchemaVersion": MCPProtocolFacts.get_tool_schema_version(),
				"capabilities": _resources_service.build_server_capabilities(),
				"serverInfo": MCPProtocolFacts.build_server_info()
			}, id)
		"initialized", "notifications/initialized":
			response = _create_json_rpc_response({}, id)
		"tools/list":
			response = _handle_tools_list(id)
		"tools/call":
			response = await _handle_tools_call_async(params_dict, id)
		"resources/list":
			response = _handle_resources_list(params_dict, id)
		"resources/templates/list":
			response = _handle_resources_templates_list(params_dict, id)
		"resources/read":
			response = _handle_resources_read(params_dict, id)
		"prompts/list":
			response = _handle_prompts_list(params_dict, id)
		"prompts/get":
			response = _handle_prompts_get(params_dict, id)
		"ping":
			response = _create_json_rpc_response({}, id)
		_:
			response = _create_json_rpc_error(-32601, "Method not found: %s" % method, id)

	if not _enabled or generation != _transport_generation:
		_log("Dropping stdio response after transport stop or restart", "debug")
		return
	_write_response(response)


func _handle_tools_list(id) -> Dictionary:
	if _tool_loader == null:
		return _create_json_rpc_error(-32603, "Tool loader not initialized", id)
	var exposed_tools = _tool_loader.get_exposed_tool_definitions()
	return _create_json_rpc_response({
		"tools": ToolPresentationService.build_mcp_tool_list(exposed_tools)
	}, id)


func _handle_tools_call(params, id) -> Dictionary:
	return await _handle_tools_call_async(params, id)


func _handle_tools_call_async(params, id) -> Dictionary:
	if not (params is Dictionary):
		return _create_json_rpc_error(-32602, "Invalid params: expected object", id)
	var params_dict := params as Dictionary
	if params_dict.has("arguments") and not (params_dict.get("arguments") is Dictionary):
		return _create_json_rpc_response(await _tool_rpc_router.build_tool_call_result_async(params_dict), id)
	if _tool_loader == null:
		return _create_json_rpc_error(-32603, "Tool loader not initialized", id)
	return _create_json_rpc_response(await _tool_rpc_router.build_tool_call_result_async(params_dict), id)


func _is_tool_enabled(tool_name: String) -> bool:
	if _disabled_tools.has(tool_name):
		return false
	if _tool_loader != null and _tool_loader.has_method("is_tool_enabled"):
		return bool(_tool_loader.is_tool_enabled(tool_name))
	return true


func _is_tool_exposed(tool_name: String) -> bool:
	if _tool_loader != null and _tool_loader.has_method("is_tool_exposed"):
		return bool(_tool_loader.is_tool_exposed(tool_name))
	return false


func _handle_resources_list(params, id) -> Dictionary:
	if not (params is Dictionary):
		return _create_json_rpc_error(-32602, "Invalid params: expected object", id)
	_ensure_resources_prompts_services()
	return _create_json_rpc_response(_resources_service.build_resources_list_result(params), id)


func _handle_resources_templates_list(params, id) -> Dictionary:
	if not (params is Dictionary):
		return _create_json_rpc_error(-32602, "Invalid params: expected object", id)
	_ensure_resources_prompts_services()
	return _create_json_rpc_response(_resources_service.build_resource_templates_list_result(params), id)


func _handle_resources_read(params, id) -> Dictionary:
	if not (params is Dictionary):
		return _create_json_rpc_error(-32602, "Invalid params: expected object", id)
	_ensure_resources_prompts_services()
	var result: Dictionary = _resources_service.build_resources_read_result(params)
	if not bool(result.get("success", true)):
		return _create_json_rpc_error(-32602, str(result.get("error", "Resource not found")), id)
	return _create_json_rpc_response(result, id)

func _handle_prompts_list(params, id) -> Dictionary:
	if not (params is Dictionary):
		return _create_json_rpc_error(-32602, "Invalid params: expected object", id)
	_ensure_resources_prompts_services()
	return _create_json_rpc_response(_prompts_service.build_prompts_list_result(params), id)


func _handle_prompts_get(params, id) -> Dictionary:
	if not (params is Dictionary):
		return _create_json_rpc_error(-32602, "Invalid params: expected object", id)
	_ensure_resources_prompts_services()
	var result: Dictionary = _prompts_service.build_prompts_get_result(params)
	if not bool(result.get("success", true)):
		return _create_json_rpc_error(-32602, str(result.get("error", "Prompt not found")), id)
	return _create_json_rpc_response(result, id)


func _configure_resources_prompts_services() -> void:
	_configure_tool_activity_registry()
	var resources_context = MCPResourcesServiceContextScript.new()
	resources_context.get_tool_loader = func(): return _tool_loader
	resources_context.get_tool_loader_status = Callable(self, "_get_stdio_tool_loader_status")
	resources_context.get_tool_activity_registry = Callable(self, "_get_stdio_tool_activity_registry")
	resources_context.sanitize_for_json = Callable(self, "_sanitize_for_json")
	_resources_service.configure(resources_context)
	var prompts_context = MCPPromptsServiceContextScript.new()
	prompts_context.get_tool_loader_status = Callable(self, "_get_stdio_tool_loader_status")
	_prompts_service.configure(prompts_context)


func _configure_tool_rpc_router() -> void:
	var router_context = MCPToolRpcRouterContextScript.new()
	router_context.get_tool_loader = func(): return _tool_loader
	router_context.is_tool_enabled = Callable(self, "_is_tool_enabled")
	router_context.is_tool_exposed = Callable(self, "_is_tool_exposed")
	router_context.log = Callable(self, "_log")
	router_context.sanitize_for_json = Callable(self, "_sanitize_for_json")
	router_context.tool_activity_registry = _get_stdio_tool_activity_registry()
	_tool_rpc_router.configure(router_context)


func _configure_tool_activity_registry() -> void:
	if _tool_loader == null or not _tool_loader.has_method("set_tool_activity_registry"):
		return
	if _tool_loader.has_method("get_tool_activity_registry") and _tool_loader.get_tool_activity_registry() != null:
		return
	if _tool_loader.has_method("set_tool_activity_registry"):
		_tool_loader.set_tool_activity_registry(_tool_activity_registry)


func _get_stdio_tool_activity_registry():
	if _tool_loader != null and _tool_loader.has_method("get_tool_activity_registry"):
		var registry = _tool_loader.get_tool_activity_registry()
		if registry != null:
			return registry
	return _tool_activity_registry


func _ensure_resources_prompts_services() -> void:
	if _resources_service == null:
		_resources_service = MCPResourcesServiceScript.new()
	if _prompts_service == null:
		_prompts_service = MCPPromptsServiceScript.new()
	_configure_resources_prompts_services()


func _get_stdio_tool_loader_status() -> Dictionary:
	if _tool_loader == null:
		return {"initialized": false, "healthy": false, "status": "unavailable", "tool_count": 0, "exposed_tool_count": 0}
	var tool_count := 0
	if _tool_loader.has_method("get_tool_definitions"):
		tool_count = _tool_loader.get_tool_definitions().size()
	var exposed_tool_count := 0
	if _tool_loader.has_method("get_exposed_tool_definitions"):
		exposed_tool_count = _tool_loader.get_exposed_tool_definitions().size()
	return {"initialized": true, "healthy": true, "status": "ready", "tool_count": tool_count, "exposed_tool_count": exposed_tool_count}


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
		"structuredContent": sanitized,
		"isError": is_error
	}, id)


func _normalize_tool_result(result) -> Dictionary:
	if not (result is Dictionary):
		return {"success": true, "data": result, "message": ""}
	var normalized: Dictionary = result.duplicate(true)
	normalized["success"] = bool(normalized.get("success", true))
	var reserved := {"success": true, "data": true, "message": true, "error": true, "hints": true}
	if MCPToolActivityRegistry.is_protocol_activity_summary(normalized.get("activity", null)):
		reserved["activity"] = true
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
	_last_written_response = obj.duplicate(true)
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
