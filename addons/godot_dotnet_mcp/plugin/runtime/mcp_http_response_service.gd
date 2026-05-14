@tool
extends RefCounted
class_name MCPHttpResponseService

var _get_tool_loader := Callable()
var _get_tool_loader_status := Callable()
var _get_server_stats := Callable()
var _get_editor_session_identity := Callable()
var _get_freshness_snapshot := Callable()
var _log := Callable()
var _server_name := ""
var _server_version := ""
var _protocol_version := ""
var _tool_schema_version := ""


func configure(context = null) -> void:
	if context == null:
		dispose()
		return
	_get_tool_loader = context.get_tool_loader
	_get_tool_loader_status = context.get_tool_loader_status
	_get_server_stats = context.get_server_stats
	_get_editor_session_identity = context.get_editor_session_identity
	_get_freshness_snapshot = context.get_freshness_snapshot
	_log = context.log
	_server_name = str(context.server_name)
	_server_version = str(context.server_version)
	_protocol_version = str(context.protocol_version)
	_tool_schema_version = str(context.tool_schema_version)


func dispose() -> void:
	_get_tool_loader = Callable()
	_get_tool_loader_status = Callable()
	_get_server_stats = Callable()
	_get_editor_session_identity = Callable()
	_get_freshness_snapshot = Callable()
	_log = Callable()
	_server_name = ""
	_server_version = ""
	_protocol_version = ""
	_tool_schema_version = ""


func build_json_rpc_response(result, id) -> Dictionary:
	return {
		"jsonrpc": "2.0",
		"result": result,
		"id": _normalize_json_rpc_id(id)
	}


func build_json_rpc_error(code: int, message: String, id) -> Dictionary:
	return {
		"jsonrpc": "2.0",
		"error": {
			"code": code,
			"message": message
		},
		"id": _normalize_json_rpc_id(id)
	}


func build_health_response() -> Dictionary:
	var loader = _get_loader()
	var exposed_tools: Array = []
	var tool_count := 0
	var domain_states: Array = []
	var reload_status := {}
	var performance := {}
	if loader != null:
		exposed_tools = loader.get_exposed_tool_definitions()
		tool_count = loader.get_tool_definitions().size()
		domain_states = loader.get_domain_states()
		reload_status = loader.get_reload_status()
		performance = loader.get_performance_summary()
	var loader_status := _get_loader_status_safe()
	var server_stats := _get_server_stats_safe()
	var status_text := "ok" if bool(loader_status.get("healthy", false)) else str(loader_status.get("status", "degraded"))
	return {
		"status": status_text,
		"server_name": _server_name,
		"server_version": _server_version,
		"protocol_version": _protocol_version,
		"tool_schema_version": _tool_schema_version,
		"running": bool(server_stats.get("running", false)),
		"listen_host": str(server_stats.get("listen_host", "")),
		"listen_port": int(server_stats.get("listen_port", 0)),
		"listen_url": str(server_stats.get("listen_url", "")),
		"editor_session_identity": _get_editor_session_identity_safe(),
		"connections": int(server_stats.get("connections", 0)),
		"total_connections": int(server_stats.get("total_connections", 0)),
		"total_requests": int(server_stats.get("total_requests", 0)),
		"last_request_method": str(server_stats.get("last_request_method", "")),
		"last_request_at_unix": int(server_stats.get("last_request_at_unix", 0)),
		"tool_count": tool_count,
		"exposed_tool_count": exposed_tools.size(),
		"tool_loader_status": loader_status,
		"domain_states": domain_states,
		"reload_status": reload_status,
		"freshness": _get_freshness_snapshot_safe(),
		"performance": performance
	}


func build_cors_response(origin: String = "", allow_methods: String = "GET, POST", allow_headers: String = "Content-Type, Accept") -> Dictionary:
	var response_headers := {}
	if not origin.strip_edges().is_empty():
		response_headers["Access-Control-Allow-Origin"] = origin.strip_edges()
		response_headers["Access-Control-Allow-Methods"] = allow_methods
		response_headers["Access-Control-Allow-Headers"] = allow_headers
		response_headers["Access-Control-Max-Age"] = "86400"
		response_headers["Vary"] = "Origin"
	return {
		"_status_code": 204,
		"_no_body": true,
		"_headers": response_headers
	}


func send_http_response(client: StreamPeerTCP, data: Dictionary, no_body: bool = false) -> void:
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

	var sanitized = sanitize_for_json(response_data)
	var body = "" if no_body else JSON.stringify(sanitized)
	var body_bytes = body.to_utf8_buffer()

	var headers = "HTTP/1.1 %d %s\r\n" % [status_code, _status_text_for(status_code)]
	if not no_body:
		headers += "Content-Type: application/json; charset=utf-8\r\n"
	headers += "Content-Length: %d\r\n" % body_bytes.size()
	headers += "Connection: keep-alive\r\n"
	for header_name in extra_headers:
		headers += "%s: %s\r\n" % [header_name, extra_headers[header_name]]
	headers += "\r\n"

	var header_bytes = headers.to_utf8_buffer()
	var header_error = client.put_data(header_bytes)
	var body_error = client.put_data(body_bytes)
	_log_message(
		"Response sent: status=%d, size=%d bytes, errors=(h:%s, b:%s)" % [
			status_code,
			body_bytes.size(),
			header_error,
			body_error
		],
		"debug"
	)


func sanitize_for_json(value):
	match typeof(value):
		TYPE_DICTIONARY:
			var result = {}
			for key in value:
				result[str(key)] = sanitize_for_json(value[key])
			return result
		TYPE_ARRAY:
			var result = []
			for item in value:
				result.append(sanitize_for_json(item))
			return result
		TYPE_FLOAT:
			if is_nan(value):
				return 0.0
			if is_inf(value):
				return 999999999.0 if value > 0 else -999999999.0
			return value
		TYPE_STRING:
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
		TYPE_COLOR:
			return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_NIL:
			return null
		_:
			return value


func _get_loader():
	if _get_tool_loader.is_valid():
		return _get_tool_loader.call()
	return null


func _get_loader_status_safe() -> Dictionary:
	if _get_tool_loader_status.is_valid():
		var status = _get_tool_loader_status.call()
		if status is Dictionary:
			return (status as Dictionary).duplicate(true)
	return {}


func _get_server_stats_safe() -> Dictionary:
	if _get_server_stats.is_valid():
		var stats = _get_server_stats.call()
		if stats is Dictionary:
			return (stats as Dictionary).duplicate(true)
	return {}


func _get_editor_session_identity_safe() -> Dictionary:
	if _get_editor_session_identity.is_valid():
		var identity = _get_editor_session_identity.call()
		if identity is Dictionary:
			return (identity as Dictionary).duplicate(true)
	return {}


func _get_freshness_snapshot_safe() -> Dictionary:
	if _get_freshness_snapshot.is_valid():
		var snapshot = _get_freshness_snapshot.call()
		if snapshot is Dictionary:
			return (snapshot as Dictionary).duplicate(true)
	return {}


func _status_text_for(status_code: int) -> String:
	var status_texts = {
		200: "OK",
		202: "Accepted",
		204: "No Content",
		403: "Forbidden",
		400: "Bad Request",
		404: "Not Found",
		405: "Method Not Allowed",
		415: "Unsupported Media Type",
		500: "Internal Server Error"
	}
	return str(status_texts.get(status_code, "OK"))


func _normalize_json_rpc_id(id):
	if typeof(id) == TYPE_FLOAT and not is_nan(id) and not is_inf(id) and floor(id) == id:
		return int(id)
	return id


func _log_message(message: String, level: String) -> void:
	if _log.is_valid():
		_log.call(message, level)
