extends RefCounted

const HttpResponseServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_response_service.gd")


class FakeToolLoader:
	extends RefCounted

	func get_exposed_tool_definitions() -> Array:
		return [{"name": "system_project_state"}, {"name": "system_scene_inspect"}]

	func get_tool_definitions() -> Array:
		return get_exposed_tool_definitions()

	func get_domain_states() -> Array:
		return [{"category": "system", "status": "ready"}]

	func get_reload_status() -> Dictionary:
		return {"status": "idle"}

	func get_performance_summary() -> Dictionary:
		return {"slow_operations": 0}


class FakeCallbacks:
	extends RefCounted

	var loader
	var loader_status: Dictionary
	var server_stats: Dictionary
	var last_log: Dictionary = {}

	func _init(current_loader, current_loader_status: Dictionary, current_server_stats: Dictionary) -> void:
		loader = current_loader
		loader_status = current_loader_status.duplicate(true)
		server_stats = current_server_stats.duplicate(true)

	func get_tool_loader():
		return loader

	func get_tool_loader_status() -> Dictionary:
		return loader_status.duplicate(true)

	func get_server_stats() -> Dictionary:
		return server_stats.duplicate(true)

	func log(message: String, level: String) -> void:
		last_log = {
			"message": message,
			"level": level
		}


func run_case(_tree: SceneTree) -> Dictionary:
	var service = HttpResponseServiceScript.new()
	var callbacks = FakeCallbacks.new(
		FakeToolLoader.new(),
		{
			"healthy": true,
			"status": "ready"
		},
		{
			"running": true,
			"connections": 3,
			"total_connections": 5,
			"total_requests": 12,
			"last_request_method": "POST",
			"last_request_at_unix": 123456
		}
	)
	service.configure({
		"get_tool_loader": Callable(callbacks, "get_tool_loader"),
		"get_tool_loader_status": Callable(callbacks, "get_tool_loader_status"),
		"get_server_stats": Callable(callbacks, "get_server_stats"),
		"log": Callable(callbacks, "log")
	}, {
		"server_name": "godot-mcp-server",
		"server_version": "0.5.0"
	})

	var rpc_response: Dictionary = service.build_json_rpc_response({"ok": true}, 7.0)
	if int(rpc_response.get("id", -1)) != 7:
		return _failure("JSON-RPC response did not normalize an integral float id.")

	var rpc_error: Dictionary = service.build_json_rpc_error(-32601, "Method not found", 3.0)
	var rpc_error_payload = rpc_error.get("error", {})
	if not (rpc_error_payload is Dictionary) or int((rpc_error_payload as Dictionary).get("code", 0)) != -32601:
		return _failure("JSON-RPC error payload did not preserve the error code.")

	var health: Dictionary = service.build_health_response()
	if str(health.get("status", "")) != "ok":
		return _failure("Health response did not reflect a healthy loader state.")
	if int(health.get("connections", -1)) != 3:
		return _failure("Health response did not project server stats.")
	if int(health.get("exposed_tool_count", 0)) != 2:
		return _failure("Health response did not count exposed tools from the loader.")

	var sanitized = service.sanitize_for_json({
		"nan": NAN,
		"node_path": NodePath("root/player"),
		"color": Color(0.1, 0.2, 0.3, 1.0)
	})
	if not (sanitized is Dictionary):
		return _failure("sanitize_for_json did not return a dictionary payload.")
	var sanitized_dict: Dictionary = sanitized
	if float(sanitized_dict.get("nan", 1.0)) != 0.0:
		return _failure("sanitize_for_json did not normalize NaN.")
	if str(sanitized_dict.get("node_path", "")) != "root/player":
		return _failure("sanitize_for_json did not normalize NodePath values.")
	var sanitized_color = sanitized_dict.get("color", {})
	if not (sanitized_color is Dictionary) or not (sanitized_color as Dictionary).has("r"):
		return _failure("sanitize_for_json did not normalize Color values.")

	return {
		"name": "http_response_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"health_status": str(health.get("status", "")),
			"exposed_tool_count": int(health.get("exposed_tool_count", 0)),
			"normalized_response_id": int(rpc_response.get("id", -1))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "http_response_service_contracts",
		"success": false,
		"error": message
	}
