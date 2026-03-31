extends RefCounted

const ToolsApiServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tools_api_service.gd")
const ToolsApiServiceContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tools_api_service_context.gd")


class FakeToolLoader:
	extends RefCounted

	func get_exposed_tool_definitions() -> Array:
		return [{"name": "system_project_state"}, {"name": "system_scene_inspect"}]

	func get_tool_definitions() -> Array:
		return get_exposed_tool_definitions()

	func get_domain_states() -> Array:
		return [{"category": "system", "status": "ready"}]

	func get_performance_summary() -> Dictionary:
		return {"slow_operations": 0}


class FakeCallbacks:
	extends RefCounted

	var loader = FakeToolLoader.new()
	var loader_status := {
		"initialized": true,
		"healthy": true,
		"status": "ready"
	}

	func get_tool_loader():
		return loader

	func get_tool_loader_status() -> Dictionary:
		return loader_status.duplicate(true)


func run_case(_tree: SceneTree) -> Dictionary:
	var service = ToolsApiServiceScript.new()
	var callbacks = FakeCallbacks.new()
	var context = ToolsApiServiceContextScript.new()
	context.get_tool_loader = Callable(callbacks, "get_tool_loader")
	context.get_tool_loader_status = Callable(callbacks, "get_tool_loader_status")
	service.configure(context)

	var response: Dictionary = service.build_tools_list_response()
	var tools = response.get("tools", [])
	if not (tools is Array) or (tools as Array).size() != 2:
		return _failure("Tools API service did not preserve the exposed tool definitions.")
	if int(response.get("tool_count", 0)) != 2:
		return _failure("Tools API service did not preserve the tool count.")
	var tool_loader_status = response.get("tool_loader_status", {})
	if not (tool_loader_status is Dictionary) or str((tool_loader_status as Dictionary).get("status", "")) != "ready":
		return _failure("Tools API service did not preserve the loader status snapshot.")

	return {
		"name": "tools_api_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": int(response.get("tool_count", 0)),
			"domain_state_count": (response.get("domain_states", []) as Array).size(),
			"loader_status": str((tool_loader_status as Dictionary).get("status", ""))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tools_api_service_contracts",
		"success": false,
		"error": message
	}
