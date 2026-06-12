@tool
extends RefCounted
class_name ToolLoaderQueryService


func build_tools_by_category(
		projection_service,
		context: Dictionary,
		visible_only: bool,
		entries_by_category: Dictionary,
		warn_empty_visible: Callable = Callable()) -> Dictionary:
	var tools: Dictionary = projection_service.build_tools_by_category(context, visible_only)
	if visible_only:
		_warn_if_empty_visible(tools, entries_by_category, warn_empty_visible, "Visible tools by category resolved to empty; returning fail-closed visible set")
	return tools


func build_tool_definitions(
		projection_service,
		context: Dictionary,
		visible_only: bool,
		entries_by_category: Dictionary,
		warn_empty_visible: Callable = Callable()) -> Array[Dictionary]:
	var definitions: Array[Dictionary] = projection_service.build_tool_definitions(context, visible_only)
	if visible_only:
		_warn_if_empty_visible(definitions, entries_by_category, warn_empty_visible, "Visible tool definitions resolved to empty; returning fail-closed visible set")
	return definitions


func build_exposed_tool_definitions(projection_service, context: Dictionary, visible_tool_definitions: Array) -> Array[Dictionary]:
	return projection_service.build_exposed_tool_definitions(context, visible_tool_definitions)


func build_domain_states(
		projection_service,
		context: Dictionary,
		visible_only: bool,
		entries_by_category: Dictionary,
		warn_empty_visible: Callable = Callable()) -> Array[Dictionary]:
	var states: Array[Dictionary] = projection_service.build_domain_states(context, visible_only)
	if visible_only:
		_warn_if_empty_visible(states, entries_by_category, warn_empty_visible, "Visible domain states resolved to empty; returning fail-closed visible set")
	return states


func is_tool_exposed(
		tool_name: String,
		exposed_tool_definitions: Array,
		public_surface_policy,
		visible_tool_definitions: Array,
		is_tool_enabled: Callable = Callable()) -> bool:
	for tool_def in exposed_tool_definitions:
		if not (tool_def is Dictionary):
			continue
		if str((tool_def as Dictionary).get("name", "")) == tool_name:
			return true
	if public_surface_policy.is_callable_removed_public_tool(tool_name, visible_tool_definitions, is_tool_enabled):
		return true
	return public_surface_policy.is_callable_compatibility_alias(tool_name, visible_tool_definitions, is_tool_enabled)


func build_tool_loader_status(
		status_service,
		visible_tool_definitions: Array,
		exposed_tool_definitions: Array,
		ordered_categories: Array,
		tool_load_error_count: int) -> Dictionary:
	return status_service.build_tool_loader_status(
		visible_tool_definitions.size(),
		exposed_tool_definitions.size(),
		ordered_categories.size(),
		tool_load_error_count
	)


func _warn_if_empty_visible(value, entries_by_category: Dictionary, warn_empty_visible: Callable, message: String) -> void:
	if not _is_empty(value) or entries_by_category.is_empty() or not warn_empty_visible.is_valid():
		return
	warn_empty_visible.call(message)


func _is_empty(value) -> bool:
	if value is Dictionary:
		return (value as Dictionary).is_empty()
	if value is Array:
		return (value as Array).is_empty()
	return true
