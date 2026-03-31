@tool
extends RefCounted
class_name ToolsTabViewStateService

const TreeCollapseState = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tree_collapse_state.gd")
const ToolsTabModelSupport = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_model_support.gd")
const ToolsTabPreviewBuilder = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_preview_builder.gd")
const ToolsTabSelectionSupport = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_selection_support.gd")


func build_header_state(localization, model: Dictionary, filtered_tools_by_category: Dictionary) -> Dictionary:
	var categories: Array = model.get("tools_by_category", {}).keys()
	categories.sort()
	return {
		"tool_count_text": localization.get_text("tools_enabled") % ToolsTabModelSupport.count_enabled_tools(model, filtered_tools_by_category, categories),
		"search_placeholder_text": localization.get_text("tool_search_placeholder")
	}


func build_preview_state(
	localization,
	current_model: Dictionary,
	filtered_tools_by_category: Dictionary,
	selection_state: Dictionary,
	previous_preview_key: String
) -> Dictionary:
	var current_preview_key := ToolsTabSelectionSupport.build_preview_key(selection_state)
	return {
		"title": localization.get_text("tool_preview_title"),
		"text": ToolsTabPreviewBuilder.build_preview_text({
			"localization": localization,
			"current_model": current_model,
			"filtered_tools_by_category": filtered_tools_by_category,
			"selected_tree_kind": str(selection_state.get("kind", "")),
			"selected_tree_key": str(selection_state.get("key", "")),
			"selected_tool_category": str(selection_state.get("category", "")),
			"selected_tool_name": str(selection_state.get("tool_name", ""))
		}),
		"preview_key": current_preview_key,
		"selection_changed": current_preview_key != previous_preview_key
	}


func build_tree_signature(model: Dictionary, search_query: String) -> String:
	var tools_by_category = model.get("tools_by_category", {})
	var parts: Array[String] = [
		search_query,
		JSON.stringify(model.get("settings", {}).get("disabled_tools", [])),
		JSON.stringify(TreeCollapseState.get_collapsed_nodes(model.get("settings", {}))),
		JSON.stringify(model.get("domain_defs", [])),
		JSON.stringify(model.get("tool_load_errors", []))
	]
	var categories: Array = tools_by_category.keys()
	categories.sort()
	for category in categories:
		parts.append(str(category))
		var tools: Array = tools_by_category.get(category, [])
		for tool_def in tools:
			if not (tool_def is Dictionary):
				continue
			var tool_dict := tool_def as Dictionary
			parts.append("%s|%s|%s|%s" % [
				str(tool_dict.get("name", "")),
				str(tool_dict.get("source", "")),
				str(tool_dict.get("script_path", "")),
				str(tool_dict.get("load_state", ""))
			])
	return "\n".join(parts)
