@tool
extends RefCounted
class_name MCPDefaultToolAccessProvider

var _show_user_tools := true


func configure(options: Dictionary = {}) -> void:
	_show_user_tools = bool(options.get("show_user_tools", true))


func is_tool_category_visible(category: String) -> bool:
	if category == "user":
		return _show_user_tools
	return true


func is_tool_category_executable(category: String) -> bool:
	if category == "user":
		return _show_user_tools
	return true


func get_tool_access_denied_message(category: String) -> String:
	return "Tool category '%s' is disabled." % category
