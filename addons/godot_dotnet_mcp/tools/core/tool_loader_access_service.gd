@tool
extends RefCounted
class_name ToolLoaderAccessService


func get_tool_access_provider(server_context):
	if server_context == null:
		return null
	if server_context.has_method("get_tool_access_provider"):
		return server_context.get_tool_access_provider()
	if server_context.has_method("get_parent"):
		return server_context.get_parent()
	return null


func is_category_visible(category: String, server_context) -> bool:
	var provider = get_tool_access_provider(server_context)
	if provider != null and provider.has_method("is_tool_category_visible"):
		return as_bool(provider.is_tool_category_visible(category))
	return true


func is_category_executable(category: String, server_context) -> bool:
	var provider = get_tool_access_provider(server_context)
	if provider != null and provider.has_method("is_tool_category_executable"):
		return as_bool(provider.is_tool_category_executable(category))
	return true


func get_tool_access_error(category: String, server_context) -> String:
	var provider = get_tool_access_provider(server_context)
	if provider != null and provider.has_method("get_tool_access_denied_message"):
		return str(provider.get_tool_access_denied_message(category))
	return "Tool category is disabled."


func as_bool(value) -> bool:
	if value is bool:
		return value
	if value is int:
		return value != 0
	if value is float:
		return !is_zero_approx(value)
	if value is String:
		var normalized = value.strip_edges().to_lower()
		return normalized == "true" or normalized == "1" or normalized == "yes" or normalized == "on"
	return value != null
