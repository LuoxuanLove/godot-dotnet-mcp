extends RefCounted

# {"name": "tools_api_service_contracts"}

const ToolsApiServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tools_api_service.gd")
const ToolsApiServiceContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tools_api_service_context.gd")


class FakeToolLoader:
	extends RefCounted

	func get_exposed_tool_definitions() -> Array:
		return [{
			"name": "system_project_state",
			"category": "system",
			"domain_key": "core",
			"enabled": true,
			"inputSchema": {"type": "object", "properties": {}}
		}, {
			"name": "system_scene_inspect",
			"category": "system",
			"domain_key": "core",
			"enabled": true,
			"inputSchema": {"type": "object", "properties": {}}
		}, {
			"name": "system_tool_activity",
			"category": "system",
			"domain_key": "core",
			"enabled": true,
			"inputSchema": {"type": "object", "properties": {}}
		}]

	func get_tool_definitions() -> Array:
		return get_exposed_tool_definitions()

	func get_domain_states() -> Array:
		return [{"category": "system", "status": "ready"}]

	func get_all_tools_by_category() -> Dictionary:
		return {
			"system": [{
				"name": "project_state",
				"full_name": "system_project_state",
				"category": "system",
				"enabled": true,
				"inputSchema": {"type": "object", "properties": {}}
			}, {
				"name": "tool_activity",
				"full_name": "system_tool_activity",
				"category": "system",
				"enabled": true,
				"inputSchema": {"type": "object", "properties": {}}
			}],
			"project": [{
				"name": "info",
				"full_name": "project_info",
				"category": "project",
				"enabled": true,
				"inputSchema": {"type": "object", "properties": {}}
			}],
			"filesystem": [{
				"name": "directory",
				"full_name": "filesystem_directory",
				"category": "filesystem",
				"enabled": true,
				"inputSchema": {"type": "object", "properties": {}}
			}]
		}

	func get_performance_summary() -> Dictionary:
		return {"slow_operations": 0}

	func is_public_removed_tool(tool_name: String) -> bool:
		return tool_name == "system_tool_activity"


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
		return _failure("Tools API service did not preserve the filtered exposed tool definitions.")
	if int(response.get("tool_count", 0)) != 2:
		return _failure("Tools API service did not preserve the filtered visible tool count.")
	if _contains_tool_name_recursive(response, "system_tool_activity"):
		return _failure("Tools API service should consume the snapshot-filtered tool catalog.")
	if not (response.get("toolTree", []) is Array) or (response.get("toolTree", []) as Array).is_empty():
		return _failure("Tools API service did not expose the unified tool tree.")
	if not (response.get("toolGroups", []) is Array) or (response.get("toolGroups", []) as Array).is_empty():
		return _failure("Tools API service did not expose tool groups.")
	if not ((tools as Array)[0] as Dictionary).has("groupPath"):
		return _failure("Tools API service should enrich flat tools with non-breaking groupPath metadata.")
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


func _contains_tool_name_recursive(value, tool_name: String) -> bool:
	if value is String:
		return str(value) == tool_name
	if value is Array:
		for item in value:
			if _contains_tool_name_recursive(item, tool_name):
				return true
		return false
	if value is Dictionary:
		var dict := value as Dictionary
		for key in ["name", "fullName", "full_name"]:
			if str(dict.get(key, "")) == tool_name:
				return true
		for nested in dict.values():
			if _contains_tool_name_recursive(nested, tool_name):
				return true
	return false
