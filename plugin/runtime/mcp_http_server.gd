@tool
extends Node
class_name MCPHttpServer

## MCP Server for Godot Engine
## Implements HTTP server with JSON-RPC 2.0 protocol for MCP communication

const MCPToolLoader = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader.gd")
const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")

signal server_started
signal server_stopped
signal client_connected
signal client_disconnected
signal request_received(method: String, params: Dictionary)

var _tcp_server: TCPServer
var _port: int = 3000
var _host: String = "127.0.0.1"
var _running: bool = false
var _debug_mode: bool = false
var _clients: Array[StreamPeerTCP] = []
var _pending_data: Dictionary = {}  # client -> accumulated data
var _total_connections: int = 0
var _total_requests: int = 0
var _last_request_method: String = ""
var _last_request_at_unix: int = 0

var _disabled_tools: Dictionary = {}
var _tool_loader := MCPToolLoader.new()
var _tool_loader_initialized := false

# MCP Protocol info
const MCP_VERSION = "2025-06-18"
const SERVER_NAME = "godot-mcp-server"
const SERVER_VERSION = "0.2.0"


func _ready() -> void:
	_ensure_initialized()


func _log(message: String) -> void:
	if _debug_mode:
		MCPDebugBuffer.record("info", "mcp_server", message)
		print("[MCP] " + message)


func _process(_delta: float) -> void:
	if not _running:
		return

	# Accept new connections
	if _tcp_server.is_connection_available():
		var client = _tcp_server.take_connection()
		if client:
			_clients.append(client)
			_pending_data[client] = ""
			_total_connections += 1
			_log("Client connected (total: %d)" % _clients.size())
			client_connected.emit()

	# Process existing clients
	var clients_to_remove: Array[StreamPeerTCP] = []
	for client in _clients:
		client.poll()
		var status = client.get_status()

		if status == StreamPeerTCP.STATUS_CONNECTED:
			var available = client.get_available_bytes()
			if available > 0:
				var data = client.get_data(available)
				if data[0] == OK:
					var request_str = data[1].get_string_from_utf8()
					_pending_data[client] += request_str
					_log("Received %d bytes, total pending: %d" % [available, _pending_data[client].length()])
					_process_http_request(client)
				else:
					_log("Error receiving data: %s" % data[0])
		elif status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
			clients_to_remove.append(client)
			_log("Client status changed: %s" % status)

	# Remove disconnected clients
	for client in clients_to_remove:
		_clients.erase(client)
		_pending_data.erase(client)
		_log("Client disconnected")
		client_disconnected.emit()


func initialize(port: int, host: String, debug: bool) -> void:
	_ensure_initialized()
	_port = port
	_host = host
	_debug_mode = debug


func reinitialize(port: int, host: String, debug: bool, disabled_tools: Array = [], reason: String = "manual") -> Dictionary:
	_ensure_initialized()
	if _running:
		stop()

	_port = port
	_host = host
	_debug_mode = debug
	set_disabled_tools(disabled_tools)
	_register_tools()

	_log("Reinitialized via %s on http://%s:%d/mcp" % [reason, _host, _port])
	if not _tool_loader.get_tool_load_errors().is_empty():
		_log("Tool load warnings after reinit: %d" % _tool_loader.get_tool_load_errors().size())

	return {
		"tool_count": _tool_loader.get_tool_definitions().size(),
		"tool_category_count": _tool_loader.get_domain_states().size(),
		"tool_load_error_count": _tool_loader.get_tool_load_errors().size()
	}


func start() -> bool:
	_ensure_initialized()
	if _running:
		return true

	var error = _tcp_server.listen(_port, _host)
	if error != OK:
		push_error("[MCP] Failed to start server on port %d: %s" % [_port, error_string(error)])
		PluginSelfDiagnosticStore.record_incident(
			"error",
			"server_error",
			"server_listen_failed",
			"Embedded MCP server failed to listen on the configured endpoint",
			"mcp_http_server",
			"start",
			"",
			"",
			"",
			true,
			"Check whether the configured host/port is already in use.",
			{
				"host": _host,
				"port": _port,
				"error_code": error,
				"error_text": error_string(error)
			}
		)
		return false

	_running = true
	_log("Server started on http://%s:%d/mcp" % [_host, _port])
	server_started.emit()
	return true


func stop() -> void:
	if not _running:
		return

	# Disconnect all clients
	for client in _clients:
		client.disconnect_from_host()
	_clients.clear()
	_pending_data.clear()

	_tcp_server.stop()
	_running = false
	_log("Server stopped")
	server_stopped.emit()


func is_running() -> bool:
	return _running


func set_port(port: int) -> void:
	_port = port


func set_debug_mode(debug: bool) -> void:
	_debug_mode = debug


func get_connection_count() -> int:
	return _clients.size()


func get_connection_stats() -> Dictionary:
	return {
		"active_connections": _clients.size(),
		"total_connections": _total_connections,
		"total_requests": _total_requests,
		"last_request_method": _last_request_method,
		"last_request_at_unix": _last_request_at_unix
	}


func set_disabled_tools(disabled: Array) -> void:
	_disabled_tools.clear()
	for name in disabled:
		_disabled_tools[str(name)] = true
	_tool_loader.set_disabled_tools(disabled)


func get_disabled_tools() -> Array:
	return _disabled_tools.keys()


func is_tool_enabled(tool_name: String) -> bool:
	return not _disabled_tools.has(tool_name)


func get_tools_by_category() -> Dictionary:
	"""Returns tools organized by category for UI display"""
	return _tool_loader.get_tools_by_category()


func get_all_tools_by_category() -> Dictionary:
	return _tool_loader.get_all_tools_by_category()


func get_enabled_tools() -> Array[Dictionary]:
	"""Returns only enabled tool definitions"""
	var enabled: Array[Dictionary] = []

	for tool_def in _tool_loader.get_tool_definitions():
		if is_tool_enabled(tool_def["name"]):
			enabled.append(tool_def)

	return enabled


func get_tool_load_errors() -> Array[Dictionary]:
	return _tool_loader.get_tool_load_errors()


func get_domain_states() -> Array[Dictionary]:
	return _tool_loader.get_domain_states()


func get_all_domain_states() -> Array[Dictionary]:
	return _tool_loader.get_all_domain_states()


func get_reload_status() -> Dictionary:
	return _tool_loader.get_reload_status()


func get_performance_summary() -> Dictionary:
	return _tool_loader.get_performance_summary()


func reload_tool_domain(domain: String) -> Dictionary:
	return _tool_loader.reload_domain(domain)


func reload_all_tool_domains() -> Dictionary:
	return _tool_loader.reload_all_domains()


func _ensure_initialized() -> void:
	if _tcp_server == null:
		_tcp_server = TCPServer.new()
	if not _tool_loader_initialized:
		_tool_loader.configure(self)
		_register_tools()


func _register_tools() -> void:
	var summary = _tool_loader.initialize(get_disabled_tools())
	_tool_loader_initialized = true
	_log("Registered %d tools across %d categories" % [int(summary.get("tool_count", 0)), int(summary.get("category_count", 0))])
	if int(summary.get("tool_load_error_count", 0)) > 0:
		_log("Skipped %d tool categories due to load errors" % int(summary.get("tool_load_error_count", 0)))
		PluginSelfDiagnosticStore.record_incident(
			"warning",
			"tool_load_error",
			"tool_domain_load_failed",
			"One or more tool domains were skipped during server registration",
			"mcp_http_server",
			"register_tools",
			"",
			"",
			"",
			true,
			"Inspect the tool loader load-error list and editor output for the failing categories.",
			{"tool_load_error_count": int(summary.get("tool_load_error_count", 0))}
		)


func _process_http_request(client: StreamPeerTCP) -> void:
	var data = _pending_data.get(client, "")
	if data.is_empty():
		return

	# Check for complete HTTP request (headers end with \r\n\r\n)
	var header_end = data.find("\r\n\r\n")
	if header_end == -1:
		if data.length() > 0:
			_log("Waiting for headers... current data length: %d" % data.length())
		return

	# Parse HTTP headers
	var header_section = data.substr(0, header_end)
	var headers = _parse_http_headers(header_section)

	if headers.is_empty():
		_pending_data[client] = ""
		return

	# Get content length - support chunked encoding
	var content_length = 0
	var is_chunked = false

	if headers.has("content-length"):
		content_length = int(headers["content-length"])
	elif headers.has("transfer-encoding") and headers["transfer-encoding"].to_lower().contains("chunked"):
		is_chunked = true

	# Check if we have complete body
	var body_start = header_end + 4
	var body = data.substr(body_start)

	# IMPORTANT: Content-Length is in bytes, not characters!
	# For UTF-8 strings with multi-byte chars (emojis, Chinese, etc.), we must compare byte sizes
	var body_bytes = body.to_utf8_buffer()
	var body_byte_size = body_bytes.size()
	var request_body := ""

	_log("Request headers: method=%s, content_length=%d, body_bytes=%d, chunked=%s" % [headers.get("method", "?"), content_length, body_byte_size, is_chunked])

	# Handle chunked encoding
	if is_chunked:
		var decoded_chunked = _decode_chunked_body_bytes(body_bytes)
		if not bool(decoded_chunked.get("complete", false)):
			_log("Waiting for chunked body...")
			return  # Wait for more data
		var request_bytes: PackedByteArray = decoded_chunked.get("body", PackedByteArray())
		request_body = request_bytes.get_string_from_utf8()
		var remaining_bytes: PackedByteArray = decoded_chunked.get("remaining", PackedByteArray())
		_pending_data[client] = remaining_bytes.get_string_from_utf8()
	elif body_byte_size < content_length:
		_log("Waiting for body... need %d bytes, have %d bytes" % [content_length, body_byte_size])
		return  # Wait for more data

	# Extract the complete request body (by bytes, then convert back to string)
	if not is_chunked:
		# Extract exactly content_length bytes and convert to string
		var request_bytes = body_bytes.slice(0, content_length)
		request_body = request_bytes.get_string_from_utf8()
		# Remove processed data (also by bytes)
		if body_byte_size > content_length:
			var remaining_bytes = body_bytes.slice(content_length)
			_pending_data[client] = remaining_bytes.get_string_from_utf8()
		else:
			_pending_data[client] = ""

	# Route request
	var method = headers.get("method", "GET")
	var path = headers.get("path", "/")

	_log("Processing: %s %s (body length: %d)" % [method, path, request_body.length()])
	_total_requests += 1
	_last_request_method = method
	_last_request_at_unix = int(Time.get_unix_time_from_system())

	var response: Dictionary
	var no_body := false

	if method == "POST" and path == "/mcp":
		_log("Handling MCP request...")
		response = _handle_mcp_request(request_body)
		no_body = response.get("_no_body", false)
		if response.has("_no_body"):
			response.erase("_no_body")
		_log("MCP response ready")
	elif method == "GET" and path == "/mcp":
		response = {
			"status": 405,
			"_no_body": true,
			"_headers": {
				"Allow": "POST, OPTIONS"
			}
		}
		no_body = true
	elif method == "GET" and path == "/health":
		response = _create_health_response()
	elif method == "GET" and path == "/api/tools":
		response = _create_tools_list_response()
	elif method == "OPTIONS":
		response = _create_cors_response()
	else:
		response = {"error": "Not found", "status": 404}

	_log("Sending response...")
	_send_http_response(client, response, no_body)
	_log("Response sent")


func _decode_chunked_body_bytes(data: PackedByteArray) -> Dictionary:
	# Decode chunked transfer encoding with byte offsets.
	# Returns completion state, decoded body, and any remaining bytes.
	var result := PackedByteArray()
	var pos = 0

	while pos < data.size():
		# Find chunk size line end
		var line_end = _find_crlf_bytes(data, pos)
		if line_end == -1:
			return {"complete": false}  # Need more data

		# Parse chunk size (hex)
		var size_str = data.slice(pos, line_end).get_string_from_utf8().strip_edges()
		# Remove any chunk extensions
		var semicolon = size_str.find(";")
		if semicolon != -1:
			size_str = size_str.substr(0, semicolon)

		var chunk_size = size_str.hex_to_int()
		var chunk_start = line_end + 2

		if chunk_size == 0:
			if chunk_start + 1 < data.size() and data[chunk_start] == 13 and data[chunk_start + 1] == 10:
				return {
					"complete": true,
					"body": result,
					"remaining": data.slice(chunk_start + 2, data.size())
				}
			var trailer_end = _find_double_crlf_bytes(data, chunk_start)
			if trailer_end == -1:
				return {"complete": false}  # Need more data
			return {
				"complete": true,
				"body": result,
				"remaining": data.slice(trailer_end, data.size())
			}

		# Check if we have the full chunk
		var chunk_end = chunk_start + chunk_size

		if chunk_end + 2 > data.size():
			return {"complete": false}  # Need more data
		if data[chunk_end] != 13 or data[chunk_end + 1] != 10:
			return {"complete": false}

		# Extract chunk data
		result.append_array(data.slice(chunk_start, chunk_end))
		pos = chunk_end + 2  # Skip chunk data and trailing CRLF

	return {"complete": false}  # Need more data


func _find_crlf_bytes(data: PackedByteArray, start: int) -> int:
	for index in range(start, data.size() - 1):
		if data[index] == 13 and data[index + 1] == 10:
			return index
	return -1


func _find_double_crlf_bytes(data: PackedByteArray, start: int) -> int:
	for index in range(start, data.size() - 3):
		if data[index] == 13 and data[index + 1] == 10 and data[index + 2] == 13 and data[index + 3] == 10:
			return index + 4
	return -1


func _close_client(client: StreamPeerTCP) -> void:
	if client in _clients:
		client.disconnect_from_host()
		_clients.erase(client)
		_pending_data.erase(client)
		_log("Client connection closed")


func _parse_http_headers(header_section: String) -> Dictionary:
	var result: Dictionary = {}
	var lines = header_section.split("\r\n")

	if lines.size() == 0:
		return result

	# Parse request line
	var request_line = lines[0].split(" ")
	if request_line.size() >= 2:
		result["method"] = request_line[0]
		result["path"] = request_line[1]

	# Parse headers
	for i in range(1, lines.size()):
		var line = lines[i]
		var colon_pos = line.find(":")
		if colon_pos > 0:
			var key = line.substr(0, colon_pos).strip_edges().to_lower()
			var value = line.substr(colon_pos + 1).strip_edges()
			result[key] = value

	return result


func _handle_mcp_request(body: String) -> Dictionary:
	_log("Parsing request body (%d bytes)..." % body.length())
	var json = JSON.new()
	var error = json.parse(body)

	if error != OK:
		push_error("[MCP] JSON parse error: %s" % json.get_error_message())
		PluginSelfDiagnosticStore.record_incident(
			"warning",
			"server_error",
			"json_parse_error",
			"MCP request JSON parsing failed",
			"mcp_http_server",
			"handle_mcp_request",
			"",
			"",
			"",
			true,
			"Inspect the malformed request body sent to /mcp.",
			{
				"error_message": json.get_error_message(),
				"body_length": body.length()
			}
		)
		return _create_json_rpc_error(-32700, "Parse error: %s" % json.get_error_message(), null)

	var request = json.get_data()
	if not request is Dictionary:
		return _create_json_rpc_error(-32600, "Invalid Request", null)

	var method = request.get("method", "")
	var params = request.get("params", {})
	var has_id = request.has("id")
	var id = _normalize_json_rpc_id(request.get("id"))

	_log("Method: %s, ID: %s" % [method, id])

	request_received.emit(method, params)

	if not has_id:
		_handle_notification(method, params)
		return {"status": 202, "_no_body": true}

	var response: Dictionary

	match method:
		"initialize":
			response = _handle_initialize(params, id)
		"initialized", "notifications/initialized":
			response = _create_json_rpc_response({}, id)
		"tools/list":
			response = _handle_tools_list(params, id)
		"tools/call":
			response = _handle_tools_call(params, id)
		"ping":
			response = _create_json_rpc_response({}, id)
		_:
			response = _create_json_rpc_error(-32601, "Method not found: %s" % method, id)

	_log("Response ready for method: %s" % method)

	return response


func _handle_notification(method: String, _params: Dictionary) -> void:
	match method:
		"initialized", "notifications/initialized":
			_log("Client initialized")
		"notifications/cancelled":
			_log("Request cancelled by client")
		_:
			_log("Notification received: %s" % method)


func _handle_initialize(params: Dictionary, id) -> Dictionary:
	var result = {
		"protocolVersion": MCP_VERSION,
		"capabilities": {
			"tools": {
				"listChanged": false
			}
		},
		"serverInfo": {
			"name": SERVER_NAME,
			"version": SERVER_VERSION
		}
	}
	return _create_json_rpc_response(result, id)


func get_plugin_permission_provider():
	return get_parent()


func _handle_tools_list(_params: Dictionary, id) -> Dictionary:
	var tools_list: Array[Dictionary] = []

	for tool_def in _tool_loader.get_tool_definitions():
		# Only include enabled tools
		if is_tool_enabled(tool_def["name"]):
			tools_list.append({
				"name": tool_def["name"],
				"description": tool_def.get("description", ""),
				"loadState": tool_def.get("load_state", "definitions_only"),
				"source": tool_def.get("source", "builtin"),
				"inputSchema": tool_def.get("inputSchema", {
					"type": "object",
					"properties": {}
				})
			})

	return _create_json_rpc_response({"tools": tools_list}, id)


func _handle_tools_call(params: Dictionary, id) -> Dictionary:
	var tool_name = params.get("name", "")
	var arguments = params.get("arguments", {})

	_log("Tool call: %s" % tool_name)

	if tool_name.is_empty():
		return _create_tool_response({"success": false, "error": "Missing tool name"}, id)

	# Check if tool is enabled
	if not is_tool_enabled(tool_name):
		return _create_tool_response({"success": false, "error": "Tool '%s' is disabled" % tool_name}, id)

	var resolved = _resolve_tool_call_name(tool_name)
	if not bool(resolved.get("success", false)):
		return _create_tool_response({"success": false, "error": "Invalid tool name format: %s" % tool_name}, id)

	var category = str(resolved.get("category", ""))
	var actual_tool_name = str(resolved.get("tool", ""))

	_log("Category: %s, Tool: %s" % [category, actual_tool_name])

	_log("Executing tool...")
	var result: Dictionary = _tool_loader.execute_tool(category, actual_tool_name, arguments)
	result = _normalize_tool_result(result)
	if not result.get("success", false):
		MCPDebugBuffer.record(
			"error",
			"tool_call",
			str(result.get("error", "Tool execution failed")),
			tool_name,
			{"arguments": _sanitize_for_json(arguments)}
		)
	elif tool_name.begins_with("scene_run_"):
		MCPDebugBuffer.record(
			"info",
			"scene_run",
			str(result.get("message", "Scene run action completed")),
			tool_name
		)

	_log("Tool result: success=%s" % result.get("success", false))

	return _create_tool_response(result, id)


func _resolve_tool_call_name(tool_name: String) -> Dictionary:
	for tool_def in _tool_loader.get_tool_definitions():
		if str(tool_def.get("name", "")) != tool_name:
			continue
		var exact_category = str(tool_def.get("category", ""))
		if exact_category.is_empty():
			break
		var resolved_tool = tool_name
		var exact_prefix = "%s_" % exact_category
		if tool_name.begins_with(exact_prefix):
			resolved_tool = tool_name.substr(exact_prefix.length())
		return {
			"success": true,
			"category": exact_category,
			"tool": resolved_tool
		}

	var matched_category := ""
	for state in _tool_loader.get_domain_states():
		var category = str(state.get("category", ""))
		if category.is_empty():
			continue
		var prefix = "%s_" % category
		if tool_name.begins_with(prefix) and prefix.length() > matched_category.length():
			matched_category = category

	if matched_category.is_empty():
		var parts = tool_name.split("_", true, 1)
		if parts.size() < 2:
			return {"success": false}
		return {
			"success": true,
			"category": parts[0],
			"tool": parts[1]
		}

	return {
		"success": true,
		"category": matched_category,
		"tool": tool_name.substr(matched_category.length() + 1)
	}


func _create_tool_response(result: Dictionary, id) -> Dictionary:
	var normalized_result = _normalize_tool_result(result)
	var sanitized_result = _sanitize_for_json(normalized_result)
	var result_text = JSON.stringify(sanitized_result)
	var is_error = not normalized_result.get("success", false)

	_log("Tool response text length: %d, is_error=%s" % [result_text.length(), is_error])

	return _create_json_rpc_response({
		"content": [{
			"type": "text",
			"text": result_text
		}],
		"isError": is_error
	}, id)


func _normalize_tool_result(result) -> Dictionary:
	if not (result is Dictionary):
		return {
			"success": true,
			"data": result,
			"message": ""
		}

	var normalized: Dictionary = result.duplicate(true)
	var is_success = bool(normalized.get("success", true))
	normalized["success"] = is_success

	var reserved_keys = {
		"success": true,
		"data": true,
		"message": true,
		"error": true,
		"hints": true
	}
	var extra_data := {}
	for key in normalized.keys():
		if reserved_keys.has(str(key)):
			continue
		extra_data[str(key)] = normalized[key]

	if is_success:
		if not normalized.has("data"):
			normalized["data"] = extra_data if not extra_data.is_empty() else null
		if not normalized.has("message"):
			normalized["message"] = ""
		normalized.erase("error")
		if normalized.has("hints") and normalized.get("hints", []).is_empty():
			normalized.erase("hints")
	else:
		if not normalized.has("error"):
			normalized["error"] = str(normalized.get("message", "Tool execution failed"))
		normalized.erase("message")
		if not normalized.has("data") and not extra_data.is_empty():
			normalized["data"] = extra_data

	for key in extra_data.keys():
		normalized.erase(key)

	return normalized


func _create_json_rpc_response(result, id) -> Dictionary:
	return {
		"jsonrpc": "2.0",
		"result": result,
		"id": _normalize_json_rpc_id(id)
	}


func _create_json_rpc_error(code: int, message: String, id) -> Dictionary:
	return {
		"jsonrpc": "2.0",
		"error": {
			"code": code,
			"message": message
		},
		"id": _normalize_json_rpc_id(id)
	}


func _create_health_response() -> Dictionary:
	return {
		"status": "ok",
		"server": SERVER_NAME,
		"version": SERVER_VERSION,
		"running": _running,
		"connections": _clients.size(),
		"total_connections": _total_connections,
		"total_requests": _total_requests,
		"last_request_method": _last_request_method,
		"last_request_at_unix": _last_request_at_unix,
		"domain_states": _tool_loader.get_domain_states(),
		"reload_status": _tool_loader.get_reload_status(),
		"performance": _tool_loader.get_performance_summary()
	}


func _create_tools_list_response() -> Dictionary:
	return {
		"tools": _tool_loader.get_tool_definitions(),
		"domain_states": _tool_loader.get_domain_states(),
		"performance": _tool_loader.get_performance_summary()
	}


func _create_cors_response() -> Dictionary:
	return {
		"status": 204,
		"cors": true
	}


func _send_http_response(client: StreamPeerTCP, data: Dictionary, no_body: bool = false) -> void:
	# Sanitize data before JSON serialization
	var response_data = data.duplicate(true)
	var extra_headers = response_data.get("_headers", {})
	if response_data.has("_headers"):
		response_data.erase("_headers")

	var status_code = 200
	if response_data.has("_status_code"):
		if typeof(response_data["_status_code"]) == TYPE_INT:
			status_code = int(response_data["_status_code"])
		response_data.erase("_status_code")
	elif response_data.has("status") and typeof(response_data["status"]) == TYPE_INT:
		status_code = int(response_data["status"])

	var sanitized = _sanitize_for_json(response_data)
	var body = "" if no_body else JSON.stringify(sanitized)
	var body_bytes = body.to_utf8_buffer()
	var status_text = "OK" if status_code == 200 else "Error"

	var status_texts = {200: "OK", 202: "Accepted", 204: "No Content", 404: "Not Found", 405: "Method Not Allowed", 500: "Internal Server Error"}
	status_text = status_texts.get(status_code, "OK")

	var headers = "HTTP/1.1 %d %s\r\n" % [status_code, status_text]
	if not no_body:
		headers += "Content-Type: application/json; charset=utf-8\r\n"
	headers += "Content-Length: %d\r\n" % body_bytes.size()
	headers += "Access-Control-Allow-Origin: *\r\n"
	headers += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
	headers += "Access-Control-Allow-Headers: Content-Type, Accept, X-Requested-With, Authorization\r\n"
	headers += "Access-Control-Max-Age: 86400\r\n"
	headers += "Connection: keep-alive\r\n"
	for header_name in extra_headers:
		headers += "%s: %s\r\n" % [header_name, extra_headers[header_name]]
	headers += "\r\n"

	# Send headers and body
	var header_bytes = headers.to_utf8_buffer()
	var err1 = client.put_data(header_bytes)
	var err2 = client.put_data(body_bytes)

	_log("Response sent: status=%d, size=%d bytes, errors=(h:%s, b:%s)" % [status_code, body_bytes.size(), err1, err2])


func _normalize_json_rpc_id(id):
	if typeof(id) == TYPE_FLOAT and not is_nan(id) and not is_inf(id) and floor(id) == id:
		return int(id)
	return id


func _sanitize_for_json(value):
	"""Recursively sanitize values to ensure valid JSON serialization"""
	match typeof(value):
		TYPE_DICTIONARY:
			var result = {}
			for key in value:
				# Ensure key is a string
				var str_key = str(key)
				result[str_key] = _sanitize_for_json(value[key])
			return result
		TYPE_ARRAY:
			var result = []
			for item in value:
				result.append(_sanitize_for_json(item))
			return result
		TYPE_FLOAT:
			# Handle NaN and Infinity which are not valid JSON
			if is_nan(value):
				return 0.0
			if is_inf(value):
				return 999999999.0 if value > 0 else -999999999.0
			return value
		TYPE_STRING:
			# Ensure string is valid
			return value
		TYPE_STRING_NAME:
			return str(value)
		TYPE_NODE_PATH:
			return str(value)
		TYPE_OBJECT:
			# Convert objects to string representation
			if value == null:
				return null
			return str(value)
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4:
			return str(value)
		TYPE_COLOR:
			return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_NIL:
			return null
		_:
			return value
