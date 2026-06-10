extends RefCounted

# {"name": "public_tool_surface_removal_guard"}

const ToolLoaderScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader.gd")
const ToolRpcRouterScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_rpc_router.gd")
const ToolRpcRouterContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_rpc_router_context.gd")
const ToolActivityRegistryScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_activity_registry.gd")


class FakeServerContext extends RefCounted:
	var _tool_access_provider

	func _init(tool_access_provider) -> void:
		_tool_access_provider = tool_access_provider

	func get_tool_access_provider():
		return _tool_access_provider


class FakeToolAccessProvider extends RefCounted:
	func is_tool_category_visible(_category: String) -> bool:
		return true

	func is_tool_category_executable(_category: String) -> bool:
		return true

	func get_tool_access_denied_message(_category: String) -> String:
		return "Tool category disabled"


class DisabledCallbacks extends RefCounted:
	var loader = null

	func get_tool_loader():
		return loader

	func is_tool_enabled(_tool_name: String) -> bool:
		return false

	func is_tool_exposed(_tool_name: String) -> bool:
		return false

	func log(_message: String, _level: String) -> void:
		pass

	func sanitize_for_json(value):
		return value


var _loader = null
var _router = null


func run_case(_tree: SceneTree) -> Dictionary:
	_loader = ToolLoaderScript.new()
	_loader.configure(FakeServerContext.new(FakeToolAccessProvider.new()))
	_loader.set_tool_activity_registry(ToolActivityRegistryScript.new())
	_loader.initialize([])

	for removed_tool_name in ["filesystem_file"]:
		if not _loader.is_public_removed_tool(removed_tool_name):
			return _failure("Tool loader should classify %s as a removed public tool." % removed_tool_name)
		if _loader.is_tool_exposed(removed_tool_name):
			return _failure("Tool loader should remove %s from normal public exposure." % removed_tool_name)
		if _contains_tool_name_recursive(_loader.get_exposed_tool_definitions(), removed_tool_name):
			return _failure("Tool loader exposed definitions should not include removed public tool %s." % removed_tool_name)

	var direct_removed_result: Dictionary = _loader.build_removed_public_tool_result("filesystem_file", {
		"action": "read",
		"path": "res://project.godot"
	})
	if not _is_removed_filesystem_file_tool(direct_removed_result, "read_file"):
		return _failure("Tool loader should provide filesystem_file removed_public_tool guidance for system_project_files(read_file).")

	var callbacks = DisabledCallbacks.new()
	callbacks.loader = _loader
	var context = ToolRpcRouterContextScript.new()
	context.get_tool_loader = Callable(callbacks, "get_tool_loader")
	context.is_tool_enabled = Callable(callbacks, "is_tool_enabled")
	context.is_tool_exposed = Callable(callbacks, "is_tool_exposed")
	context.log = Callable(callbacks, "log")
	context.sanitize_for_json = Callable(callbacks, "sanitize_for_json")
	context.tool_activity_registry = _loader.get_tool_activity_registry()

	_router = ToolRpcRouterScript.new()
	_router.configure(context)
	var router_result: Dictionary = await _router.build_tool_call_result_async({
		"name": "filesystem_file",
		"arguments": {
			"action": "read",
			"path": "res://project.godot"
		}
	})
	if not bool(router_result.get("isError", false)):
		return _failure("Tool RPC router should reject removed filesystem_file calls.")
	if not _is_removed_filesystem_file_tool(router_result.get("structuredContent", {}), "read_file"):
		return _failure("Tool RPC router should return removed_public_tool guidance before enabled/exposed checks.")

	return {
		"name": "public_tool_surface_removal_guard",
		"success": true,
		"error": "",
		"details": {
			"removed_tool": "filesystem_file",
			"replacement_tool": "system_project_files"
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	if _router != null and _router.has_method("dispose"):
		_router.dispose()
	_router = null
	if _loader != null and _loader.has_method("shutdown"):
		_loader.shutdown()
	_loader = null


func _is_removed_filesystem_file_tool(result, replacement_action: String) -> bool:
	var structured = result
	if not (structured is Dictionary) or bool((structured as Dictionary).get("success", true)):
		return false
	var data = (structured as Dictionary).get("data", {})
	if not (data is Dictionary):
		return false
	var data_dict := data as Dictionary
	if str(data_dict.get("error_type", "")) != "removed_public_tool":
		return false
	if str(data_dict.get("removed_tool", "")) != "filesystem_file":
		return false
	var replacement_methods = data_dict.get("replacement_methods", [])
	if not (replacement_methods is Array) or not (replacement_methods as Array).has("resources/templates/list"):
		return false
	if not ((data_dict.get("replacement_resources", []) as Array).has("godot-dotnet-mcp://script/{path}")):
		return false
	var replacement_tools = data_dict.get("replacement_tools", [])
	if not (replacement_tools is Array) or (replacement_tools as Array).is_empty():
		return false
	var replacement = (replacement_tools as Array)[0]
	if not (replacement is Dictionary):
		return false
	var replacement_arguments = (replacement as Dictionary).get("arguments", {})
	return str((replacement as Dictionary).get("name", "")) == "system_project_files" and replacement_arguments is Dictionary and str((replacement_arguments as Dictionary).get("action", "")) == replacement_action


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


func _failure(message: String) -> Dictionary:
	return {
		"name": "public_tool_surface_removal_guard",
		"success": false,
		"error": message
	}
