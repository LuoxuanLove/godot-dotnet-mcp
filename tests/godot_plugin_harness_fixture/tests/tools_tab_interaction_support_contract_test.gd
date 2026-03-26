extends RefCounted

const ToolsTabContextMenuSupport = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_context_menu_support.gd")
const ToolsTabSelectionSupport = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_selection_support.gd")


class FakeLocalization extends RefCounted:
	var _texts := {
		"tool_ctx_copy_localized_name": "Copy localized name",
		"tool_ctx_copy_english_id": "Copy english id",
		"tool_ctx_copy_schema_json": "Copy schema",
		"btn_delete_user_tool": "Delete user tool",
		"btn_expand_all": "Expand all",
		"btn_collapse_all": "Collapse all"
	}

	func get_text(key: String) -> String:
		return str(_texts.get(key, key))


func run_case(_tree: SceneTree) -> Dictionary:
	var metadata = ToolsTabContextMenuSupport.build_tree_node_metadata("tool", "user_sample_tool", "Sample Tool", "user_sample_tool", {
		"category": "user",
		"source": "user_tool",
		"script_path": "res://addons/godot_dotnet_mcp/custom_tools/sample_tool.gd",
		"tool_name": "sample_tool"
	})
	var menu_entries = ToolsTabContextMenuSupport.build_context_menu_entries(FakeLocalization.new(), metadata, true, {
		"copy_localized_name": 0,
		"copy_english_id": 1,
		"copy_schema": 2,
		"delete_tool": 3,
		"expand_all": 10,
		"collapse_all": 11,
		"user_tool_root": "res://addons/godot_dotnet_mcp/custom_tools"
	})
	if menu_entries.size() < 7:
		return _failure("Context menu helper did not create the expected number of entries for a user tool.")
	var has_delete := false
	for entry in menu_entries:
		if str(entry.get("label", "")) == "Delete user tool":
			has_delete = true
			break
	if not has_delete:
		return _failure("Context menu helper did not include the delete action for a user tool entry.")
	if ToolsTabContextMenuSupport.get_context_menu_localized_name(metadata) != "Sample Tool":
		return _failure("Context menu helper did not preserve the localized display name.")
	if ToolsTabContextMenuSupport.get_context_menu_user_tool_script_path(metadata, "res://addons/godot_dotnet_mcp/custom_tools") != "res://addons/godot_dotnet_mcp/custom_tools/sample_tool.gd":
		return _failure("Context menu helper did not preserve the user tool script path.")

	var selection_state = ToolsTabSelectionSupport.build_state_from_metadata(metadata)
	if not ToolsTabSelectionSupport.has_selection(selection_state):
		return _failure("Selection helper should report a selection after reading metadata.")
	if ToolsTabSelectionSupport.build_preview_key(selection_state) != "tool|user_sample_tool|sample_tool":
		return _failure("Selection helper built an unexpected preview key.")
	if not ToolsTabSelectionSupport.metadata_matches_state(metadata, selection_state):
		return _failure("Selection helper should match the originating metadata.")

	return {
		"name": "tools_tab_interaction_support_contracts",
		"success": true,
		"error": "",
		"details": {
			"menu_entry_count": menu_entries.size(),
			"preview_key": ToolsTabSelectionSupport.build_preview_key(selection_state)
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tools_tab_interaction_support_contracts",
		"success": false,
		"error": message
	}
