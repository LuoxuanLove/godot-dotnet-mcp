@tool
extends RefCounted

const SystemTreeCatalog = preload("res://addons/godot_dotnet_mcp/plugin/runtime/system_tree_catalog.gd")
const ToolsTabModelSupport = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_model_support.gd")

const SYSTEM_CATEGORY := "system"


static func build_filtered_tools_by_category(model: Dictionary, query: String) -> Dictionary:
	var filtered_tools_by_category: Dictionary = {}
	var normalized_query = query.strip_edges().to_lower()
	var localization = model.get("localization")
	for category_variant in model.get("tools_by_category", {}).keys():
		var category := str(category_variant)
		var filtered: Array = []
		var category_matches = normalized_query.is_empty() or ToolsTabModelSupport.get_category_label(localization, category).to_lower().contains(normalized_query)
		for tool_def in model.get("tools_by_category", {}).get(category, []):
			if not (tool_def is Dictionary):
				continue
			var tool_dict := tool_def as Dictionary
			if matches_tool_search(model, category, tool_dict, normalized_query, category_matches):
				filtered.append(tool_dict)
		filtered_tools_by_category[category] = filtered
	return filtered_tools_by_category


static func category_matches_search(model: Dictionary, category: String, filtered_tools_by_category: Dictionary, query: String) -> bool:
	var normalized_query = query.strip_edges().to_lower()
	if normalized_query.is_empty():
		return true
	if ToolsTabModelSupport.get_category_label(model.get("localization"), category).to_lower().contains(normalized_query):
		return true
	return not ToolsTabModelSupport.get_filtered_tool_definitions(filtered_tools_by_category, category).is_empty()


static func matches_tool_search(model: Dictionary, category: String, tool_def: Dictionary, query: String, category_matches: bool = false) -> bool:
	if query.is_empty() or category_matches:
		return true
	var localization = model.get("localization")
	var tool_name = str(tool_def.get("name", ""))
	var full_name = "%s_%s" % [category, tool_name]
	if ToolsTabModelSupport.get_tool_display_name(localization, full_name, tool_name).to_lower().contains(query):
		return true
	if category != SYSTEM_CATEGORY:
		return false
	return matches_atomic_tool_search_recursive(model, full_name, query, {})


static func matches_atomic_tool_search(model: Dictionary, atomic_full_name: String, atomic_tool_def: Dictionary, query: String) -> bool:
	if query.is_empty():
		return true
	var localization = model.get("localization")
	var tool_name = str(atomic_tool_def.get("name", ""))
	if ToolsTabModelSupport.get_tool_display_name(localization, atomic_full_name, tool_name).to_lower().contains(query):
		return true
	var description = ToolsTabModelSupport.get_tool_description(localization, atomic_full_name, atomic_tool_def)
	return description.to_lower().contains(query)


static func matches_action_search(localization, parent_tool: String, action_name: String, tool_def: Dictionary, query: String) -> bool:
	if query.is_empty():
		return true
	if ToolsTabModelSupport.get_action_display_name(localization, parent_tool, action_name).to_lower().contains(query):
		return true
	if action_name.to_lower().contains(query):
		return true
	var description = ToolsTabModelSupport.get_action_description(localization, parent_tool, action_name, tool_def)
	return description.to_lower().contains(query)


static func matches_atomic_tool_search_recursive(model: Dictionary, system_full_name: String, query: String, visited: Dictionary) -> bool:
	var localization = model.get("localization")
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
		var atomic_tool_def = ToolsTabModelSupport.get_tool_def_by_full_name(model, atomic_full_name)
		if atomic_tool_def.is_empty():
			continue
		if matches_atomic_tool_search(model, atomic_full_name, atomic_tool_def, query):
			return true
		for action_name in actions:
			if matches_action_search(localization, atomic_full_name, str(action_name), atomic_tool_def, query):
				return true
		var next_visited = visited.duplicate()
		next_visited[atomic_full_name] = true
		if matches_atomic_tool_search_recursive(model, atomic_full_name, query, next_visited):
			return true
	return false
