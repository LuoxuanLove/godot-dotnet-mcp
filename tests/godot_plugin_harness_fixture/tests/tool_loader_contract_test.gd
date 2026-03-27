extends RefCounted

const DefaultPermissionProviderScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/default_tool_permission_provider.gd")
const ToolLoaderScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader.gd")


class FakeServerContext extends RefCounted:
	var _permission_provider

	func _init(permission_provider) -> void:
		_permission_provider = permission_provider

	func get_plugin_permission_provider():
		return _permission_provider


var _loader = null


func run_case(_tree: SceneTree) -> Dictionary:
	var permission_provider = DefaultPermissionProviderScript.new()
	permission_provider.configure({
		"permission_level": "evolution",
		"show_user_tools": true
	})

	_loader = ToolLoaderScript.new()
	_loader.configure(FakeServerContext.new(permission_provider))
	var summary: Dictionary = _loader.initialize([])

	if int(summary.get("category_count", 0)) <= 0:
		return _failure("Tool loader initialize() did not report any categories.")
	if int(summary.get("tool_count", 0)) <= 0:
		return _failure("Tool loader initialize() did not report any visible tools.")
	if int(summary.get("exposed_tool_count", 0)) <= 0:
		return _failure("Tool loader initialize() did not report any exposed tools.")

	var status: Dictionary = _loader.get_tool_loader_status()
	if not bool(status.get("healthy", false)):
		return _failure("Tool loader status should be healthy after initialization.")

	var exposed_tools: Array[Dictionary] = _loader.get_exposed_tool_definitions()
	if exposed_tools.is_empty():
		return _failure("Tool loader did not return any exposed tool definitions.")

	var all_tools: Array[Dictionary] = _loader.get_tool_definitions()
	for tool_def in all_tools:
		if bool(tool_def.get("compatibility_alias", false)):
			return _failure("Tool loader should no longer surface compatibility_alias definitions.")

	for removed_wrapper_path in [
		"res://addons/godot_dotnet_mcp/tools/script_tools.gd",
		"res://addons/godot_dotnet_mcp/tools/node_tools.gd",
		"res://addons/godot_dotnet_mcp/tools/animation_tools.gd",
		"res://addons/godot_dotnet_mcp/tools/physics_tools.gd",
		"res://addons/godot_dotnet_mcp/tools/filesystem_tools.gd",
	]:
		if ResourceLoader.exists(removed_wrapper_path):
			return _failure("Removed legacy root wrapper should not exist: %s" % removed_wrapper_path)

	var tools_by_category: Dictionary = _loader.get_tools_by_category()
	if tools_by_category.has("plugin"):
		return _failure("Tool loader should no longer expose the legacy plugin category.")

	var exposed_names: Array[String] = []
	for tool_def in exposed_tools:
		exposed_names.append(str(tool_def.get("name", "")))
	if not exposed_names.has("system_project_state"):
		return _failure("Tool loader did not expose system_project_state under the default permission provider.")
	for deprecated_name in ["debug_log", "filesystem_file", "resource_manage"]:
		if exposed_names.has(deprecated_name):
			return _failure("Tool loader still exposed deprecated compatibility tool '%s'." % deprecated_name)

	_loader.set_disabled_tools(["system_project_state"])
	if _loader.is_tool_exposed("system_project_state"):
		return _failure("Disabled tool system_project_state should no longer be exposed.")

	var disabled_status: Dictionary = _loader.get_tool_loader_status()
	if int(disabled_status.get("exposed_tool_count", 0)) >= int(status.get("exposed_tool_count", 0)):
		return _failure("Disabling system_project_state did not reduce the exposed tool count.")

	return {
		"name": "tool_loader_contracts",
		"success": true,
		"error": "",
		"details": {
			"initial_tool_count": int(summary.get("tool_count", 0)),
			"initial_exposed_tool_count": int(summary.get("exposed_tool_count", 0)),
			"disabled_exposed_tool_count": int(disabled_status.get("exposed_tool_count", 0)),
			"healthy_status": str(status.get("status", ""))
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	if _loader != null and _loader.has_method("shutdown"):
		_loader.shutdown()
	_loader = null


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_loader_contracts",
		"success": false,
		"error": message
	}
