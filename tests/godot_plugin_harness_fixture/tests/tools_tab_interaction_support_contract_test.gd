extends RefCounted

const ToolsTabContextMenuSupport = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_context_menu_support.gd")
const ToolsTabClickDispatchService = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_click_dispatch_service.gd")
const ToolsTabContextMenuService = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_context_menu_service.gd")
const ToolsTabSelectionSupport = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_selection_support.gd")
const ToolsTabTreeStateService = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_tree_state_service.gd")

var _tree_control: Tree = null


class CollapseRecorder extends RefCounted:
	var entries: Array[Dictionary] = []

	func record(kind: String, key: String, collapsed: bool) -> void:
		entries.append({
			"kind": kind,
			"key": key,
			"collapsed": collapsed
		})


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


func run_case(tree: SceneTree) -> Dictionary:
	var tree_state_service = ToolsTabTreeStateService.new()
	var click_dispatch_service = ToolsTabClickDispatchService.new()
	var context_menu_service = ToolsTabContextMenuService.new()
	var metadata = ToolsTabContextMenuSupport.build_tree_node_metadata("tool", "user_sample_tool", "Sample Tool", "user_sample_tool", {
		"category": "user",
		"source": "user_tool",
		"script_path": "res://addons/godot_dotnet_mcp/custom_tools/sample_tool.gd",
		"tool_name": "sample_tool",
		"inputSchema": {
			"properties": {
				"scope": {
					"type": "string"
				}
			}
		}
	})
	var ids := {
		"copy_localized_name": 0,
		"copy_english_id": 1,
		"copy_schema": 2,
		"delete_tool": 3,
		"expand_all": 10,
		"collapse_all": 11
	}
	var menu_entries = context_menu_service.build_entries(
		FakeLocalization.new(),
		metadata,
		true,
		ids,
		"res://addons/godot_dotnet_mcp/custom_tools"
	)
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

	var context_model := {
		"tools_by_category": {
			"user": [
				{
					"name": "sample_tool",
					"inputSchema": {
						"properties": {
							"scope": {
								"type": "string"
							}
						}
					}
				}
			]
		}
	}
	var schema_action = context_menu_service.resolve_action(2, metadata, context_model, ids, "res://addons/godot_dotnet_mcp/custom_tools")
	if str(schema_action.get("type", "")) != "clipboard" or str(schema_action.get("text", "")).find("\"scope\"") == -1:
		return _failure("Context menu service should resolve schema copy into clipboard text.")
	var delete_action = context_menu_service.resolve_action(3, metadata, context_model, ids, "res://addons/godot_dotnet_mcp/custom_tools")
	if str(delete_action.get("type", "")) != "delete_user_tool":
		return _failure("Context menu service should resolve delete action for a user tool.")
	var collapse_action = context_menu_service.resolve_action(11, metadata, context_model, ids, "res://addons/godot_dotnet_mcp/custom_tools")
	if str(collapse_action.get("type", "")) != "collapse_subtree" or not bool(collapse_action.get("collapsed", false)):
		return _failure("Context menu service should resolve collapse-all into a collapsed subtree action.")

	var selection_state = ToolsTabSelectionSupport.build_state_from_metadata(metadata)
	if not ToolsTabSelectionSupport.has_selection(selection_state):
		return _failure("Selection helper should report a selection after reading metadata.")
	if ToolsTabSelectionSupport.build_preview_key(selection_state) != "tool|user_sample_tool|sample_tool":
		return _failure("Selection helper built an unexpected preview key.")
	if not ToolsTabSelectionSupport.metadata_matches_state(metadata, selection_state):
		return _failure("Selection helper should match the originating metadata.")

	_tree_control = Tree.new()
	_tree_control.columns = 2
	_tree_control.size = Vector2(240, 96)
	_tree_control.set_column_expand(0, true)
	_tree_control.set_column_expand(1, false)
	tree.root.add_child(_tree_control)
	await tree.process_frame
	_tree_control.create_item()
	var root = _tree_control.get_root()
	var domain_item = _tree_control.create_item(root)
	domain_item.set_metadata(0, {"kind": "domain", "key": "user"})
	var category_item = _tree_control.create_item(domain_item)
	category_item.set_metadata(0, {"kind": "category", "key": "user"})
	var tool_item = _tree_control.create_item(category_item)
	tool_item.set_metadata(0, metadata)

	tree_state_service.set_subtree_collapsed(domain_item, true)
	if not category_item.collapsed or not tool_item.collapsed:
		return _failure("Tree state service should collapse the whole subtree recursively.")

	var recorder = CollapseRecorder.new()
	tree_state_service.sync_subtree_collapsed_to_settings(
		domain_item,
		0,
		{},
		Callable(recorder, "record")
	)
	if recorder.entries.size() != 3:
		return _failure("Tree state service should emit collapse changes for every expandable node in the subtree.")

	var found_item = tree_state_service.find_item_by_selection(root, 0, selection_state)
	if found_item != tool_item:
		return _failure("Tree state service should restore the tree item that matches the saved selection state.")

	tool_item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
	tool_item.set_checked(1, true)
	var toggle_action = click_dispatch_service.resolve_item_column_action(tool_item, 1, 0, 1)
	if str(toggle_action.get("type", "")) != "toggle_entry":
		return _failure("Click dispatch service should resolve checkbox clicks into toggle actions.")
	if str(toggle_action.get("kind", "")) != "tool" or not bool(toggle_action.get("enabled", false)):
		return _failure("Click dispatch service should preserve toggle target kind and enabled state.")

	var keyboard_event := InputEventKey.new()
	keyboard_event.pressed = true
	keyboard_event.keycode = KEY_SPACE
	var keyboard_action = click_dispatch_service.resolve_keyboard_action(keyboard_event, domain_item)
	if str(keyboard_action.get("type", "")) != "toggle_item_collapsed":
		return _failure("Click dispatch service should resolve space key on expandable items into collapse toggle actions.")

	return {
		"name": "tools_tab_interaction_support_contracts",
		"success": true,
		"error": "",
		"details": {
			"menu_entry_count": menu_entries.size(),
			"preview_key": ToolsTabSelectionSupport.build_preview_key(selection_state),
			"collapse_entry_count": recorder.entries.size(),
			"schema_action_type": str(schema_action.get("type", "")),
			"toggle_action_type": str(toggle_action.get("type", ""))
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	if _tree_control != null and is_instance_valid(_tree_control):
		_tree_control.queue_free()
	_tree_control = null
	await tree.process_frame
	await tree.process_frame


func _failure(message: String) -> Dictionary:
	return {
		"name": "tools_tab_interaction_support_contracts",
		"success": false,
		"error": message
	}
