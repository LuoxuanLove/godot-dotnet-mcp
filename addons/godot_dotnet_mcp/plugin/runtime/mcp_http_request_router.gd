@tool
extends RefCounted
class_name MCPHttpRequestRouter

const ENV_ALLOWED_CORS_ORIGINS := "GODOT_DOTNET_MCP_ALLOWED_CORS_ORIGINS"

var _handle_mcp_request_async := Callable()
var _build_health_response := Callable()
var _build_tools_list_response := Callable()
var _handle_editor_lifecycle_request := Callable()
var _handle_editor_lifecycle_post_request := Callable()
var _build_cors_response := Callable()
var _allowed_cors_origins: Array[String] = []
var _allowed_hosts: Array[String] = []


func configure(context = null) -> void:
	if context == null:
		dispose()
		return
	_handle_mcp_request_async = context.handle_mcp_request_async
	_build_health_response = context.build_health_response
	_build_tools_list_response = context.build_tools_list_response
	_handle_editor_lifecycle_request = context.handle_editor_lifecycle_request
	_handle_editor_lifecycle_post_request = context.handle_editor_lifecycle_post_request
	_build_cors_response = context.build_cors_response
	_allowed_cors_origins = _read_allowed_cors_origins()


func dispose() -> void:
	_handle_mcp_request_async = Callable()
	_build_health_response = Callable()
	_build_tools_list_response = Callable()
	_handle_editor_lifecycle_request = Callable()
	_handle_editor_lifecycle_post_request = Callable()
	_build_cors_response = Callable()
	_allowed_cors_origins = []
	_allowed_hosts = []


func set_allowed_cors_origins(value) -> void:
	_allowed_cors_origins = _normalize_allowed_origins(value)


func set_allowed_hosts(value) -> void:
	_allowed_hosts = _normalize_allowed_hosts(value)


func route_request_async(method: String, path: String, request_body: String, headers: Dictionary = {}) -> Dictionary:
	var normalized_headers := _normalize_headers(headers)
	if not _is_host_allowed(str(normalized_headers.get("host", ""))):
		return _forbidden("HTTP Host is not allowed")

	var origin := str(normalized_headers.get("origin", "")).strip_edges()
	var has_origin := not origin.is_empty()
	if has_origin and not _is_origin_allowed(origin):
		return _forbidden("HTTP Origin is not allowed")

	if method == "OPTIONS":
		return _build_options_response(path, origin)

	if method == "POST" and _requires_json_content_type(path):
		var content_type := str(normalized_headers.get("content-type", "")).strip_edges().to_lower()
		if not content_type.is_empty() and not _is_json_content_type(content_type):
			return {
				"error": "Unsupported media type",
				"status": 415
			}

	var response: Dictionary
	if method == "POST" and path == "/mcp":
		response = await _call_async(_handle_mcp_request_async, [request_body], {"error": "MCP request handler is unavailable", "status": 500})
		return _attach_cors_headers(response, origin, path)

	if method == "GET" and path == "/mcp":
		response = {
			"status": 405,
			"_no_body": true,
			"_headers": {
				"Allow": "POST"
			}
		}
		return _attach_cors_headers(response, origin, path)

	if method == "GET" and path == "/health":
		response = _call_dict(_build_health_response, [], {"status": "degraded", "error": "Health response builder is unavailable", "status_code": 500})
		return _attach_cors_headers(response, origin, path)

	if method == "GET" and path == "/api/tools":
		response = _call_dict(_build_tools_list_response, [], {})
		return _attach_cors_headers(response, origin, path)

	if method == "GET" and path == "/api/editor/lifecycle":
		response = _call_dict(_handle_editor_lifecycle_request, ["status", {}], {"error": "editor_lifecycle_unavailable", "status": 500})
		return _attach_cors_headers(response, origin, path)

	if method == "POST" and path == "/api/editor/lifecycle":
		response = _call_dict(_handle_editor_lifecycle_post_request, [request_body], {"error": "editor_lifecycle_unavailable", "status": 500})
		return _attach_cors_headers(response, origin, path)

	return {"error": "Not found", "status": 404}


func _build_options_response(path: String, origin: String) -> Dictionary:
	var allowed_methods := _allowed_methods_for_path(path)
	if allowed_methods.is_empty():
		return {"error": "Not found", "status": 404}
	if origin.strip_edges().is_empty():
		return {
			"status": 405,
			"_no_body": true,
			"_headers": {
				"Allow": allowed_methods
			}
		}
	return _call_dict(
		_build_cors_response,
		[origin, allowed_methods, "Content-Type, Accept"],
		{
			"_status_code": 204,
			"_no_body": true,
			"_headers": _build_cors_headers(origin, allowed_methods)
		}
	)


func _attach_cors_headers(response: Dictionary, origin: String, path: String) -> Dictionary:
	if origin.strip_edges().is_empty():
		return response
	var enriched := response.duplicate(true)
	var response_headers := {}
	if enriched.has("_headers") and enriched["_headers"] is Dictionary:
		response_headers = (enriched["_headers"] as Dictionary).duplicate(true)
	var cors_headers := _build_cors_headers(origin, _allowed_methods_for_path(path))
	for header_name in cors_headers:
		response_headers[header_name] = cors_headers[header_name]
	enriched["_headers"] = response_headers
	return enriched


func _build_cors_headers(origin: String, allow_methods: String) -> Dictionary:
	return {
		"Access-Control-Allow-Origin": origin.strip_edges(),
		"Access-Control-Allow-Methods": allow_methods,
		"Access-Control-Allow-Headers": "Content-Type, Accept",
		"Access-Control-Max-Age": "86400",
		"Vary": "Origin"
	}


func _allowed_methods_for_path(path: String) -> String:
	match path:
		"/mcp":
			return "POST"
		"/health", "/api/tools":
			return "GET"
		"/api/editor/lifecycle":
			return "GET, POST"
		_:
			return ""


func _requires_json_content_type(path: String) -> bool:
	return path == "/mcp" or path == "/api/editor/lifecycle"


func _is_json_content_type(content_type: String) -> bool:
	return content_type == "application/json" or content_type.begins_with("application/json;")


func _is_origin_allowed(origin: String) -> bool:
	var normalized_origin := origin.strip_edges()
	if normalized_origin.is_empty() or normalized_origin == "null":
		return false
	for allowed_origin in _allowed_cors_origins:
		if normalized_origin == allowed_origin:
			return true
	return false


func _is_host_allowed(host_header: String) -> bool:
	var hostname := _normalize_host_name(host_header)
	if hostname.is_empty():
		return true
	if hostname == "127.0.0.1" or hostname == "localhost" or hostname == "::1":
		return true
	return _allowed_hosts.has(hostname)


func _normalize_host_name(host_value: String) -> String:
	var normalized_host := host_value.strip_edges().to_lower()
	if normalized_host.is_empty():
		return ""
	if normalized_host.begins_with("["):
		var closing_bracket := normalized_host.find("]")
		if closing_bracket == -1:
			return ""
		return normalized_host.substr(1, closing_bracket - 1)
	var colon_pos := normalized_host.rfind(":")
	if colon_pos > -1 and normalized_host.count(":") == 1:
		return normalized_host.substr(0, colon_pos)
	return normalized_host


func _normalize_headers(headers: Dictionary) -> Dictionary:
	var normalized := {}
	for key in headers:
		normalized[str(key).strip_edges().to_lower()] = headers[key]
	return normalized


func _normalize_allowed_origins(value) -> Array[String]:
	var origins: Array[String] = []
	if not (value is Array):
		return origins
	for origin_value in value:
		var origin := str(origin_value).strip_edges()
		if origin.is_empty():
			continue
		origins.append(origin)
	return origins


func _normalize_allowed_hosts(value) -> Array[String]:
	var hosts: Array[String] = []
	if not (value is Array):
		return hosts
	for host_value in value:
		var hostname := _normalize_host_name(str(host_value))
		if hostname.is_empty() or hostname == "0.0.0.0" or hostname == "::" or hostname == "*":
			continue
		if hosts.has(hostname):
			continue
		hosts.append(hostname)
	return hosts


func _read_allowed_cors_origins() -> Array[String]:
	if not OS.has_environment(ENV_ALLOWED_CORS_ORIGINS):
		return []
	var raw_origins := OS.get_environment(ENV_ALLOWED_CORS_ORIGINS).replace(";", ",").split(",", false)
	return _normalize_allowed_origins(raw_origins)


func _forbidden(message: String) -> Dictionary:
	return {
		"error": message,
		"status": 403
	}


func _call_dict(callable_obj: Callable, args: Array, fallback: Dictionary) -> Dictionary:
	if callable_obj.is_valid():
		var result = callable_obj.callv(args)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	return fallback.duplicate(true)


func _call_async(callable_obj: Callable, args: Array, fallback: Dictionary) -> Dictionary:
	if callable_obj.is_valid():
		var result = callable_obj.callv(args)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
		if result != null:
			result = await result
			if result is Dictionary:
				return (result as Dictionary).duplicate(true)
	return fallback.duplicate(true)
