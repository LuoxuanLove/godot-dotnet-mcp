@tool
extends RefCounted
class_name ToolsTabContextMenuService

const ToolsTabContextMenuSupport = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_context_menu_support.gd")
const ToolsTabModelSupport = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_model_support.gd")


func build_entries(localization, metadata: Dictionary, has_children: bool, ids: Dictionary, user_tool_root: String) -> Array[Dictionary]:
	var context_ids := ids.duplicate(true)
	context_ids["user_tool_root"] = user_tool_root
	return ToolsTabContextMenuSupport.build_context_menu_entries(localization, metadata, has_children, context_ids)


func resolve_action(id: int, metadata: Dictionary, current_model: Dictionary, ids: Dictionary, user_tool_root: String) -> Dictionary:
	if id == int(ids.get("copy_localized_name", -1)):
		return {
			"type": "clipboard",
			"text": ToolsTabContextMenuSupport.get_context_menu_localized_name(metadata)
		}
	if id == int(ids.get("copy_english_id", -1)):
		return {
			"type": "clipboard",
			"text": ToolsTabContextMenuSupport.get_context_menu_english_id(metadata)
		}
	if id == int(ids.get("copy_schema", -1)):
		var full_name = str(metadata.get("key", ""))
		var tool_def = ToolsTabModelSupport.get_tool_def_by_full_name(current_model, full_name)
		var schema = tool_def.get("inputSchema", {})
		return {
			"type": "clipboard",
			"text": JSON.stringify(schema, "\t")
		}
	if id == int(ids.get("delete_tool", -1)):
		var script_path = ToolsTabContextMenuSupport.get_context_menu_user_tool_script_path(metadata, user_tool_root)
		if script_path.is_empty():
			return {"type": "none"}
		return {
			"type": "delete_user_tool",
			"script_path": script_path
		}
	if id == int(ids.get("expand_all", -1)):
		return {
			"type": "collapse_subtree",
			"collapsed": false
		}
	if id == int(ids.get("collapse_all", -1)):
		return {
			"type": "collapse_subtree",
			"collapsed": true
		}
	return {"type": "none"}
