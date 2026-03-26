@tool
extends RefCounted
class_name MCPDefaultToolPermissionProvider

const ToolPermissionPolicy = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_permission_policy.gd")

var _permission_level := ToolPermissionPolicy.PERMISSION_EVOLUTION
var _show_user_tools := true


func configure(options: Dictionary = {}) -> void:
	_permission_level = ToolPermissionPolicy.normalize_permission_level(
		str(options.get("permission_level", ToolPermissionPolicy.PERMISSION_EVOLUTION))
	)
	_show_user_tools = bool(options.get("show_user_tools", true))


func get_permission_level() -> String:
	return _permission_level


func is_tool_category_visible_for_permission(category: String) -> bool:
	if category == "user":
		return _show_user_tools
	if category == "plugin":
		return _permission_level == ToolPermissionPolicy.PERMISSION_DEVELOPER
	return is_tool_category_executable_for_permission(category)


func is_tool_category_executable_for_permission(category: String) -> bool:
	return ToolPermissionPolicy.permission_allows_category(_permission_level, category)


func get_permission_denied_message_for_category(category: String) -> String:
	return "Current permission level '%s' does not allow category '%s'." % [_permission_level, category]
