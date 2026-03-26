@tool
extends RefCounted

const SystemTreeCatalog = preload("res://addons/godot_dotnet_mcp/plugin/runtime/system_tree_catalog.gd")
const ToolsTabModelSupport = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_model_support.gd")

const SYSTEM_CATEGORY := "system"


static func build_preview_text(context: Dictionary) -> String:
	var localization = context.get("localization")
	var selected_tree_kind = str(context.get("selected_tree_kind", ""))
	var selected_tree_key = str(context.get("selected_tree_key", ""))
	if selected_tree_kind.is_empty() or selected_tree_key.is_empty():
		return str(_get_text(localization, "tool_preview_empty"))
	match selected_tree_kind:
		"domain":
			return _build_domain_preview(context)
		"root", "category":
			return _build_category_preview(context)
		"tool":
			return _build_tool_preview(context)
		"atomic":
			return _build_atomic_item_preview(context)
		"action":
			return _build_action_item_preview(context)
		_:
			return str(_get_text(localization, "tool_preview_empty"))


static func _build_domain_preview(context: Dictionary) -> String:
	var localization = context.get("localization")
	var current_model: Dictionary = context.get("current_model", {})
	var domain_key = str(context.get("selected_tree_key", ""))
	var domain_def = ToolsTabModelSupport.find_domain_definition(current_model, domain_key)
	if domain_def.is_empty():
		return str(_get_text(localization, "tool_preview_empty"))
	var label_key = str(domain_def.get("label", "domain_other"))
	var categories: Array = domain_def.get("categories", [])
	var lines: Array[String] = [
		"%s: %s" % [_get_text(localization, "tool_preview_domain"), _get_text(localization, label_key)],
		"",
		ToolsTabModelSupport.get_group_tooltip(localization, label_key),
		"",
		_get_text(localization, "tool_preview_category_count") % categories.size()
	]
	for category_variant in categories:
		var category = str(category_variant)
		if not current_model.get("tools_by_category", {}).has(category):
			continue
		lines.append("- %s" % ToolsTabModelSupport.get_category_label(localization, category))
	return "\n".join(ToolsTabModelSupport.filter_empty_preview_lines(lines))


static func _build_category_preview(context: Dictionary) -> String:
	var localization = context.get("localization")
	var current_model: Dictionary = context.get("current_model", {})
	var filtered_tools_by_category: Dictionary = context.get("filtered_tools_by_category", {})
	var category = str(context.get("selected_tree_key", ""))
	var tools: Array = ToolsTabModelSupport.get_filtered_tool_definitions(filtered_tools_by_category, category)
	var lines: Array[String] = [
		"%s: %s" % [_get_text(localization, "tool_preview_category"), ToolsTabModelSupport.get_category_label(localization, category)],
		"",
		ToolsTabModelSupport.get_group_tooltip(localization, ToolsTabModelSupport.get_category_label_key(category)),
		"",
		_get_text(localization, "tool_preview_tool_count") % ToolsTabModelSupport.count_previewable_tools(tools)
	]
	for tool_def in tools:
		var tool_name = str(tool_def.get("name", ""))
		var full_name = "%s_%s" % [category, tool_name]
		lines.append("- %s" % ToolsTabModelSupport.get_tool_display_name(localization, full_name, tool_name))
	if category == "user":
		var watch_lines = _build_user_watch_preview_lines(localization, current_model)
		if not watch_lines.is_empty():
			lines.append("")
			lines.append(_get_text(localization, "tool_preview_watch_section"))
			lines.append_array(watch_lines)
	if category == SYSTEM_CATEGORY:
		lines.append("")
		lines.append(_get_text(localization, "tool_preview_system_category_hint"))
	return "\n".join(ToolsTabModelSupport.filter_empty_preview_lines(lines))


static func _build_tool_preview(context: Dictionary) -> String:
	var localization = context.get("localization")
	var current_model: Dictionary = context.get("current_model", {})
	var category = str(context.get("selected_tool_category", ""))
	var tool_name = str(context.get("selected_tool_name", ""))
	var selected_tree_key = str(context.get("selected_tree_key", ""))
	if category.is_empty() or tool_name.is_empty():
		return str(_get_text(localization, "tool_preview_empty"))
	var tool_def = ToolsTabModelSupport.find_tool_definition(current_model, category, tool_name)
	if tool_def.is_empty():
		return str(_get_text(localization, "tool_preview_empty"))
	var display_name = ToolsTabModelSupport.get_tool_display_name(localization, selected_tree_key, tool_name)
	var description = ToolsTabModelSupport.get_tool_description(localization, selected_tree_key, tool_def)
	var lines: Array[String] = [
		"%s: %s" % [_get_text(localization, "tool_preview_tool"), display_name],
		"%s: %s" % [_get_text(localization, "tool_preview_tool_id"), selected_tree_key],
		"%s: %s" % [_get_text(localization, "tool_preview_category"), ToolsTabModelSupport.get_category_label(localization, category)],
		"",
		_get_text(localization, "tool_preview_description"),
		description if not description.is_empty() else _get_text(localization, "tool_preview_no_description")
	]
	var actions = ToolsTabModelSupport.extract_action_values(tool_def)
	if not actions.is_empty():
		lines.append("")
		lines.append(_get_text(localization, "tool_preview_actions"))
		for action_value in actions:
			lines.append("- %s" % ToolsTabModelSupport.get_action_display_name(localization, selected_tree_key, action_value))
	lines.append("")
	lines.append(_get_text(localization, "tool_preview_params"))
	var parameter_lines = ToolsTabModelSupport.build_parameter_preview_lines(localization, tool_def)
	if parameter_lines.is_empty():
		lines.append(_get_text(localization, "tool_preview_no_params"))
	else:
		lines.append_array(parameter_lines)
	if category == "user":
		var runtime_lines = _build_user_runtime_preview_lines(localization, tool_def)
		if not runtime_lines.is_empty():
			lines.append("")
			lines.append(_get_text(localization, "tool_preview_runtime_section"))
			lines.append_array(runtime_lines)
	if category == SYSTEM_CATEGORY:
		lines.append("")
		lines.append(_get_text(localization, "tool_preview_atomic_tools"))
		var atomic_lines = _build_atomic_tool_preview_lines(localization, current_model, selected_tree_key, 0, {})
		if atomic_lines.is_empty():
			lines.append(_get_text(localization, "tool_preview_no_atomic_tools"))
		else:
			lines.append_array(atomic_lines)
		lines.append("")
		lines.append(_get_text(localization, "tool_preview_system_tool_hint"))
	return "\n".join(ToolsTabModelSupport.filter_empty_preview_lines(lines))


static func _build_user_runtime_preview_lines(localization, tool_def: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var runtime_domain = str(tool_def.get("runtime_domain", ""))
	if not runtime_domain.is_empty():
		lines.append("%s: %s" % [_get_text(localization, "tool_preview_runtime_domain"), runtime_domain])
	var runtime_version = int(tool_def.get("runtime_version", 0))
	if runtime_version > 0:
		lines.append("%s: %d" % [_get_text(localization, "tool_preview_runtime_version"), runtime_version])
	var runtime_state = _get_user_runtime_state_label(localization, str(tool_def.get("state", "")))
	if not runtime_state.is_empty():
		lines.append("%s: %s" % [_get_text(localization, "tool_preview_runtime_state"), runtime_state])
	lines.append("%s: %s" % [
		_get_text(localization, "tool_preview_pending_reload"),
		_get_text(localization, "status_enabled") if bool(tool_def.get("pending_reload", false)) else _get_text(localization, "status_disabled")
	])
	var discovery_source = _get_user_watch_source_label(localization, str(tool_def.get("discovery_source", "")))
	if not discovery_source.is_empty():
		lines.append("%s: %s" % [_get_text(localization, "tool_preview_discovery_source"), discovery_source])
	var last_refresh_reason = _get_user_watch_reason_label(localization, str(tool_def.get("last_refresh_reason", "")))
	if not last_refresh_reason.is_empty():
		lines.append("%s: %s" % [_get_text(localization, "tool_preview_last_refresh_reason"), last_refresh_reason])
	var script_path = str(tool_def.get("script_path", ""))
	if not script_path.is_empty():
		lines.append("%s: %s" % [_get_text(localization, "tool_preview_script_path"), script_path])
	var last_error = str(tool_def.get("last_error", ""))
	if not last_error.is_empty():
		lines.append("%s: %s" % [_get_text(localization, "tool_preview_last_error"), last_error])
	var raw_state = str(tool_def.get("state", ""))
	if raw_state == "reload_failed":
		lines.append(_get_text(localization, "tool_preview_reload_failed_keeps_old_version"))
	elif raw_state == "waiting_quiesce":
		lines.append(_get_text(localization, "tool_preview_waiting_quiesce"))
	return lines


static func _build_user_watch_preview_lines(localization, current_model: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var watch_status: Dictionary = current_model.get("user_tool_watch", {})
	if not watch_status.is_empty():
		var watching = bool(watch_status.get("watching", false))
		lines.append("%s: %s" % [
			_get_text(localization, "tool_preview_watch_status"),
			_get_text(localization, "status_enabled") if watching else _get_text(localization, "status_disabled")
		])
		lines.append("%s: %d" % [
			_get_text(localization, "tool_preview_watch_known_scripts"),
			int(watch_status.get("known_script_count", 0))
		])
		var last_reason = _get_user_watch_reason_label(localization, str(watch_status.get("last_change_reason", "")))
		if not last_reason.is_empty():
			lines.append("%s: %s" % [_get_text(localization, "tool_preview_last_refresh_reason"), last_reason])
		var last_error = str(watch_status.get("last_error", ""))
		if not last_error.is_empty():
			lines.append("%s: %s" % [_get_text(localization, "tool_preview_watch_last_error"), last_error])
	var invalid_tools: Array[String] = []
	for tool_info in current_model.get("user_tools", []):
		if not (tool_info is Dictionary):
			continue
		var info := tool_info as Dictionary
		if bool(info.get("loadable", false)):
			continue
		var display_name = str(info.get("display_name", info.get("script_path", "")))
		var load_error = str(info.get("load_error", ""))
		invalid_tools.append("%s (%s)" % [display_name, load_error if not load_error.is_empty() else "invalid"])
	if not invalid_tools.is_empty():
		lines.append("%s: %d" % [_get_text(localization, "tool_preview_watch_invalid_scripts"), invalid_tools.size()])
		for invalid_entry in invalid_tools:
			lines.append("- %s" % invalid_entry)
	return lines


static func _get_user_runtime_state_label(localization, state: String) -> String:
	if state.is_empty():
		return ""
	var key = "tool_preview_runtime_state_%s" % state
	var translated = _get_text(localization, key)
	if translated != key:
		return translated
	return ToolsTabModelSupport.humanize_identifier(state)


static func _get_user_watch_source_label(localization, source: String) -> String:
	if source.is_empty():
		return ""
	var key = "tool_preview_discovery_source_%s" % source
	var translated = _get_text(localization, key)
	if translated != key:
		return translated
	return ToolsTabModelSupport.humanize_identifier(source)


static func _get_user_watch_reason_label(localization, reason: String) -> String:
	if reason.is_empty():
		return ""
	var key = "tool_preview_watch_reason_%s" % reason
	var translated = _get_text(localization, key)
	if translated != key:
		return translated
	return ToolsTabModelSupport.humanize_identifier(reason)


static func _build_atomic_item_preview(context: Dictionary) -> String:
	var localization = context.get("localization")
	var current_model: Dictionary = context.get("current_model", {})
	var atomic_full_name = str(context.get("selected_tree_key", ""))
	if atomic_full_name.is_empty():
		return str(_get_text(localization, "tool_preview_empty"))
	var tool_def = ToolsTabModelSupport.get_tool_def_by_full_name(current_model, atomic_full_name)
	if tool_def.is_empty():
		return str(_get_text(localization, "tool_preview_empty"))
	var category = ToolsTabModelSupport.extract_category_from_full_name(current_model, atomic_full_name)
	var tool_name = str(tool_def.get("name", ""))
	var display_name = ToolsTabModelSupport.get_tool_display_name(localization, atomic_full_name, tool_name)
	var description = ToolsTabModelSupport.get_tool_description(localization, atomic_full_name, tool_def)
	var actions = ToolsTabModelSupport.extract_action_values(tool_def)
	var lines: Array[String] = [
		"%s: %s" % [_get_text(localization, "tool_preview_tool"), display_name],
		"%s: %s" % [_get_text(localization, "tool_preview_tool_id"), atomic_full_name],
		"%s: %s" % [_get_text(localization, "tool_preview_category"), ToolsTabModelSupport.get_category_label(localization, category)],
		"",
		_get_text(localization, "tool_preview_description"),
		description if not description.is_empty() else _get_text(localization, "tool_preview_no_description")
	]
	if not actions.is_empty():
		lines.append("")
		lines.append(_get_text(localization, "tool_preview_actions"))
		for action_value in actions:
			lines.append("- %s" % ToolsTabModelSupport.get_action_display_name(localization, atomic_full_name, action_value))
	return "\n".join(ToolsTabModelSupport.filter_empty_preview_lines(lines))


static func _build_action_item_preview(context: Dictionary) -> String:
	var localization = context.get("localization")
	var current_model: Dictionary = context.get("current_model", {})
	var key = str(context.get("selected_tree_key", ""))
	if key.is_empty():
		return str(_get_text(localization, "tool_preview_empty"))
	var dot_idx = key.rfind(".")
	if dot_idx < 0:
		return str(_get_text(localization, "tool_preview_empty"))
	var parent_tool: String = key.left(dot_idx)
	var action_name: String = key.substr(dot_idx + 1)
	var tool_def = ToolsTabModelSupport.get_tool_def_by_full_name(current_model, parent_tool)
	var category = ToolsTabModelSupport.extract_category_from_full_name(current_model, parent_tool)
	var tool_name = str(tool_def.get("name", "")) if not tool_def.is_empty() else parent_tool
	var display_name = ToolsTabModelSupport.get_tool_display_name(localization, parent_tool, tool_name) if not tool_def.is_empty() else parent_tool
	var lines: Array[String] = [
		"%s: %s" % [_get_text(localization, "tool_action"), ToolsTabModelSupport.get_action_display_name(localization, parent_tool, action_name)],
		"%s: %s" % [_get_text(localization, "tool_preview_action_id"), action_name],
		"%s: %s" % [_get_text(localization, "tool_preview_parent_tool"), display_name],
		"%s: %s" % [_get_text(localization, "tool_preview_category"), ToolsTabModelSupport.get_category_label(localization, category)],
		"",
		_get_text(localization, "tool_preview_description"),
		ToolsTabModelSupport.get_action_description(localization, parent_tool, action_name, tool_def)
	]
	if not tool_def.is_empty():
		var param_lines = ToolsTabModelSupport.build_action_parameter_lines(localization, tool_def)
		if not param_lines.is_empty():
			lines.append("")
			lines.append(_get_text(localization, "tool_preview_params"))
			lines.append_array(param_lines)
	return "\n".join(ToolsTabModelSupport.filter_empty_preview_lines(lines))


static func _build_atomic_tool_preview_lines(localization, current_model: Dictionary, system_full_name: String, depth: int = 0, visited: Dictionary = {}) -> Array[String]:
	var lines: Array[String] = []
	for entry in SystemTreeCatalog.SYSTEM_TOOL_ATOMIC_CHILDREN.get(system_full_name, []):
		var atomic_full_name: String
		var actions: Array = []
		if entry is Dictionary:
			atomic_full_name = str(entry.get("tool", ""))
			actions = entry.get("actions", [])
		else:
			atomic_full_name = str(entry)
		if atomic_full_name.is_empty() or visited.has(atomic_full_name):
			continue
		var atomic_tool_def = ToolsTabModelSupport.get_tool_def_by_full_name(current_model, atomic_full_name)
		if atomic_tool_def.is_empty():
			continue
		var category = ToolsTabModelSupport.extract_category_from_full_name(current_model, atomic_full_name)
		var tool_name = str(atomic_tool_def.get("name", ""))
		if category.is_empty() or tool_name.is_empty():
			continue
		var display_name = ToolsTabModelSupport.get_tool_display_name(localization, atomic_full_name, tool_name)
		var indent = "  ".repeat(depth)
		lines.append("%s- %s" % [indent, display_name])
		for action_name in actions:
			lines.append("%s  - %s" % [indent, ToolsTabModelSupport.get_action_display_name(localization, atomic_full_name, str(action_name))])
		if category == SYSTEM_CATEGORY:
			var next_visited = visited.duplicate()
			next_visited[atomic_full_name] = true
			lines.append_array(_build_atomic_tool_preview_lines(localization, current_model, atomic_full_name, depth + 1, next_visited))
	return lines


static func _get_text(localization, key: String) -> String:
	if localization == null:
		return key
	return localization.get_text(key)
