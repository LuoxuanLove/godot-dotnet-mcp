@tool
extends RefCounted
class_name ToolsTabTreeStateService

const TreeCollapseState = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tree_collapse_state.gd")
const ToolsTabSelectionSupport = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_selection_support.gd")


func set_subtree_collapsed(item: TreeItem, collapsed: bool) -> void:
	item.collapsed = collapsed
	var child := item.get_first_child()
	while child != null:
		set_subtree_collapsed(child, collapsed)
		child = child.get_next()


func sync_subtree_collapsed_to_settings(item: TreeItem, text_column: int, settings: Dictionary, emit_collapse_changed: Callable) -> void:
	if item == null:
		return
	_sync_item_collapsed_to_settings(item, text_column, settings, emit_collapse_changed)
	var child := item.get_first_child()
	while child != null:
		sync_subtree_collapsed_to_settings(child, text_column, settings, emit_collapse_changed)
		child = child.get_next()


func find_item_by_selection(item: TreeItem, text_column: int, selection_state: Dictionary) -> TreeItem:
	if item == null:
		return null
	var metadata = item.get_metadata(text_column)
	if ToolsTabSelectionSupport.metadata_matches_state(metadata, selection_state):
		return item

	var child = item.get_first_child()
	while child != null:
		var found = find_item_by_selection(child, text_column, selection_state)
		if found != null:
			return found
		child = child.get_next()
	return null


func tree_has_hidden_content_below(tree: Tree, root: TreeItem, text_column: int) -> bool:
	var last_item = _find_last_visible_tree_item(root)
	if last_item == null:
		return false
	var rect = tree.get_item_area_rect(last_item, text_column, -1)
	return rect.position.y + rect.size.y > tree.size.y + 1.0


func _sync_item_collapsed_to_settings(item: TreeItem, text_column: int, settings: Dictionary, emit_collapse_changed: Callable) -> void:
	var metadata = item.get_metadata(text_column)
	if not (metadata is Dictionary):
		return
	var meta := metadata as Dictionary
	var kind := str(meta.get("kind", ""))
	var key := str(meta.get("key", ""))
	if key.is_empty() or not TreeCollapseState.EXPANDABLE_KINDS.has(kind):
		return
	var want_collapsed := item.collapsed
	var is_saved_collapsed: bool = TreeCollapseState.is_node_collapsed(settings, kind, key)
	if is_saved_collapsed != want_collapsed and emit_collapse_changed.is_valid():
		emit_collapse_changed.call(kind, key, want_collapsed)


func _find_last_visible_tree_item(item: TreeItem) -> TreeItem:
	if item == null:
		return null
	var child = item.get_first_child()
	if child == null:
		return item

	var last_visible: TreeItem = null
	while child != null:
		last_visible = child
		if not child.collapsed:
			var deepest = _find_last_visible_tree_item(child)
			if deepest != null:
				last_visible = deepest
		child = child.get_next()
	return last_visible
