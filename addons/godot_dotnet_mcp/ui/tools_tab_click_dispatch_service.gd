@tool
extends RefCounted
class_name ToolsTabClickDispatchService


func resolve_keyboard_action(event: InputEventKey, selected_item: TreeItem) -> Dictionary:
	if event == null or not event.pressed or event.echo:
		return {"type": "none"}
	if event.keycode != KEY_SPACE:
		return {"type": "none"}
	if selected_item == null or selected_item.get_child_count() <= 0:
		return {"type": "none"}
	return {
		"type": "toggle_item_collapsed",
		"item": selected_item
	}


func resolve_mouse_action(event: InputEventMouseButton, tree: Tree) -> Dictionary:
	if event == null or not event.pressed:
		return {"type": "none"}
	if event.button_index == MOUSE_BUTTON_RIGHT:
		var context_item = tree.get_item_at_position(event.position)
		if context_item == null:
			return {"type": "none"}
		return {
			"type": "show_context_menu",
			"item": context_item,
			"global_position": tree.get_global_transform().origin + event.position
		}
	if event.button_index != MOUSE_BUTTON_LEFT:
		return {"type": "none"}
	if event.shift_pressed:
		var collapse_item: TreeItem = tree.get_item_at_position(event.position)
		if collapse_item == null or collapse_item.get_child_count() <= 0:
			return {"type": "none"}
		return {
			"type": "collapse_subtree",
			"item": collapse_item,
			"collapsed": not collapse_item.collapsed
		}
	return {
		"type": "deferred_click",
		"position": event.position
	}


func resolve_deferred_click(tree: Tree, mouse_position: Vector2, text_column: int, check_column: int) -> Dictionary:
	var column = tree.get_column_at_position(mouse_position)
	if column < 0:
		return {"type": "none"}
	var item = tree.get_item_at_position(mouse_position)
	if item == null:
		return {"type": "none"}
	return resolve_item_column_action(item, column, text_column, check_column)


func resolve_item_column_action(item: TreeItem, column: int, text_column: int, check_column: int) -> Dictionary:
	if item == null or column < 0:
		return {"type": "none"}
	if column == text_column:
		return {
			"type": "select_metadata",
			"metadata": item.get_metadata(text_column)
		}
	if column == check_column:
		return _resolve_toggle_action(item, text_column, check_column)
	return {"type": "none"}


func _resolve_toggle_action(item: TreeItem, text_column: int, check_column: int) -> Dictionary:
	var metadata = item.get_metadata(text_column)
	if not (metadata is Dictionary):
		return {"type": "none"}
	var metadata_dict := metadata as Dictionary
	return {
		"type": "toggle_entry",
		"kind": str(metadata_dict.get("kind", "")),
		"key": str(metadata_dict.get("key", "")),
		"enabled": item.is_checked(check_column)
	}
