@tool
extends RefCounted
class_name MCPHttpRequestRouter

var _handle_mcp_request_async := Callable()
var _build_health_response := Callable()
var _build_tools_list_response := Callable()
var _handle_editor_lifecycle_request := Callable()
var _handle_editor_lifecycle_post_request := Callable()
var _build_cors_response := Callable()


func configure(callbacks: Dictionary = {}) -> void:
	_handle_mcp_request_async = callbacks.get("handle_mcp_request_async", Callable())
	_build_health_response = callbacks.get("build_health_response", Callable())
	_build_tools_list_response = callbacks.get("build_tools_list_response", Callable())
	_handle_editor_lifecycle_request = callbacks.get("handle_editor_lifecycle_request", Callable())
	_handle_editor_lifecycle_post_request = callbacks.get("handle_editor_lifecycle_post_request", Callable())
	_build_cors_response = callbacks.get("build_cors_response", Callable())


func dispose() -> void:
	_handle_mcp_request_async = Callable()
	_build_health_response = Callable()
	_build_tools_list_response = Callable()
	_handle_editor_lifecycle_request = Callable()
	_handle_editor_lifecycle_post_request = Callable()
	_build_cors_response = Callable()


func route_request_async(method: String, path: String, request_body: String) -> Dictionary:
	if method == "POST" and path == "/mcp":
		return await _call_async(_handle_mcp_request_async, [request_body], {"error": "MCP request handler is unavailable", "status": 500})

	if method == "GET" and path == "/mcp":
		return {
			"status": 405,
			"_no_body": true,
			"_headers": {
				"Allow": "POST, OPTIONS"
			}
		}

	if method == "GET" and path == "/health":
		return _call_dict(_build_health_response, [], {"status": "degraded", "error": "Health response builder is unavailable", "status_code": 500})

	if method == "GET" and path == "/api/tools":
		return _call_dict(_build_tools_list_response, [], {})

	if method == "GET" and path == "/api/editor/lifecycle":
		return _call_dict(_handle_editor_lifecycle_request, ["status", {}], {"error": "editor_lifecycle_unavailable", "status": 500})

	if method == "POST" and path == "/api/editor/lifecycle":
		return _call_dict(_handle_editor_lifecycle_post_request, [request_body], {"error": "editor_lifecycle_unavailable", "status": 500})

	if method == "OPTIONS":
		return _call_dict(_build_cors_response, [], {"status": 204, "cors": true})

	return {"error": "Not found", "status": 404}


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
