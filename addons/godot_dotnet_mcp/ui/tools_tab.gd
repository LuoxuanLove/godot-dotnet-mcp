@tool
extends VBoxContainer

signal tool_toggled(tool_name: String, enabled: bool)
signal delete_user_tool_requested(script_path: String)
signal category_toggled(category: String, enabled: bool)
signal domain_toggled(domain_key: String, enabled: bool)
signal tree_collapse_changed(kind: String, key: String, collapsed: bool)

const ToolsTabContextMenuService = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_context_menu_service.gd")
const ToolsTabClickDispatchService = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_click_dispatch_service.gd")
const ToolsTabSearchService = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_search_service.gd")
const ToolsTabSelectionSupport = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_selection_support.gd")
const ToolsTabViewBindingService = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_view_binding_service.gd")
const ToolsTabTreeRenderer = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_tree_renderer.gd")
const ToolsTabTreeStateService = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_tree_state_service.gd")
const ToolsTabViewStateService = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_view_state_service.gd")

const TREE_TEXT_COLUMN := 0
const TREE_CHECK_COLUMN := 1
const USER_TOOL_CUSTOM_ROOT := "res://addons/godot_dotnet_mcp/custom_tools"

@onready var _tool_count_label: Label = %ToolCountLabel
@onready var _search_edit: LineEdit = %ToolSearchEdit
@onready var _content_split: VSplitContainer = %ContentSplit
@onready var _tool_tree: Tree = %ToolTree
@onready var _top_shadow: ColorRect = %TopShadow
@onready var _bottom_shadow: ColorRect = %BottomShadow
@onready var _tool_preview_panel: PanelContainer = %ToolPreviewPanel
@onready var _tool_preview_title: Label = %ToolPreviewTitle
@onready var _tool_preview_text: TextEdit = %ToolPreviewText

const _CTX_COPY_LOCALIZED_NAME := 0
const _CTX_COPY_ENGLISH_ID := 1
const _CTX_COPY_SCHEMA := 2
const _CTX_DELETE_TOOL := 3
const _CTX_EXPAND_ALL := 10
const _CTX_COLLAPSE_ALL := 11
const _CONTEXT_MENU_ACTION_IDS := {
	"copy_localized_name": _CTX_COPY_LOCALIZED_NAME,
	"copy_english_id": _CTX_COPY_ENGLISH_ID,
	"copy_schema": _CTX_COPY_SCHEMA,
	"delete_tool": _CTX_DELETE_TOOL,
	"expand_all": _CTX_EXPAND_ALL,
	"collapse_all": _CTX_COLLAPSE_ALL
}

var _tree_syncing := false
var _current_scale := -1.0
var _localization = null
var _context_menu: PopupMenu = null
var _context_menu_metadata: Dictionary = {}
var _context_menu_target: TreeItem = null
var _current_model: Dictionary = {}
var _filtered_tools_by_category: Dictionary = {}
var _selection_state: Dictionary = ToolsTabSelectionSupport.empty_state()
var _selection_sync_queued := false
var _last_tree_signature := ""
var _last_preview_key := ""
var _click_dispatch_service = ToolsTabClickDispatchService.new()
var _context_menu_service = ToolsTabContextMenuService.new()
var _tree_renderer = ToolsTabTreeRenderer.new()
var _tree_state_service = ToolsTabTreeStateService.new()
var _view_binding_service = ToolsTabViewBindingService.new()
var _view_state_service = ToolsTabViewStateService.new()


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_search_edit.text_changed.connect(_on_search_text_changed)
	_tool_tree.item_collapsed.connect(_on_tree_item_collapsed)
	_tool_tree.gui_input.connect(_on_tree_gui_input)
	_tool_tree.set_allow_reselect(true)
	_view_binding_service.configure_preview_text(_tool_preview_text)
	var top_pane = _content_split.get_node("TopPane") as Control
	var bottom_pane = _content_split.get_node("BottomPane") as Control
	var tool_list_panel = _content_split.get_node("TopPane/ToolListOuterMargin/ToolListPanel") as Control
	top_pane.clip_contents = true
	bottom_pane.clip_contents = true
	tool_list_panel.clip_contents = true
	_tool_preview_panel.clip_contents = true
	_view_binding_service.configure_tree_shadow(_top_shadow, false)
	_view_binding_service.configure_tree_shadow(_bottom_shadow, true)
	set_process(true)
	_context_menu = PopupMenu.new()
	add_child(_context_menu)
	_context_menu.id_pressed.connect(_on_context_menu_id_pressed)


func apply_model(model: Dictionary) -> void:
	var localization = model.get("localization")
	_localization = localization
	_current_model = model
	_filtered_tools_by_category = ToolsTabSearchService.build_filtered_tools_by_category(model, _get_search_query())
	var editor_scale = float(model.get("editor_scale", 1.0))

	if not is_equal_approx(_current_scale, editor_scale):
		_current_scale = editor_scale
		_view_binding_service.apply_editor_scale(
			_tool_tree,
			_tool_preview_panel,
			_top_shadow,
			_bottom_shadow,
			_search_edit,
			editor_scale,
			TREE_TEXT_COLUMN,
			TREE_CHECK_COLUMN
		)

	_view_binding_service.apply_header_state(
		_tool_count_label,
		_search_edit,
		_view_state_service.build_header_state(localization, model, _filtered_tools_by_category)
	)

	var tree_signature = _view_state_service.build_tree_signature(model, _get_search_query())
	_refresh_tree_state(model, tree_signature)


func _render_tool_tree(model: Dictionary) -> void:
	_tree_syncing = true
	_tree_renderer.render_tool_tree(_tool_tree, model, _filtered_tools_by_category, _get_search_query())
	_tree_syncing = false
	call_deferred("_update_tree_shadow_visibility")


func _refresh_tree_state(model: Dictionary, tree_signature: String) -> void:
	if tree_signature != _last_tree_signature:
		_last_tree_signature = tree_signature
		_render_tool_tree(model)
		_refresh_preview()
		if _has_tree_selection():
			_queue_selection_sync()
		return

	_refresh_preview()


func _on_tree_item_collapsed(item: TreeItem) -> void:
	if _tree_syncing or item == null:
		return
	var metadata = item.get_metadata(TREE_TEXT_COLUMN)
	if not (metadata is Dictionary):
		return
	var kind = str(metadata.get("kind", ""))
	var key = str(metadata.get("key", ""))
	if key.is_empty():
		return
	tree_collapse_changed.emit(kind, key, item.collapsed)


func _on_search_text_changed(_new_text: String) -> void:
	if _current_model.is_empty():
		return
	_filtered_tools_by_category = ToolsTabSearchService.build_filtered_tools_by_category(_current_model, _get_search_query())
	_render_tool_tree(_current_model)
	_refresh_preview()
	if _has_tree_selection():
		_queue_selection_sync()


func _on_tree_gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_action = _click_dispatch_service.resolve_keyboard_action(event as InputEventKey, _tool_tree.get_selected())
		if _apply_tree_interaction_action(key_action):
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_action = _click_dispatch_service.resolve_mouse_action(event as InputEventMouseButton, _tool_tree)
	if _apply_tree_interaction_action(mouse_action):
		get_viewport().set_input_as_handled()

func _show_tree_context_menu(item: TreeItem, global_pos: Vector2) -> void:
	var metadata = item.get_metadata(TREE_TEXT_COLUMN)
	if not (metadata is Dictionary):
		return
	var meta := metadata as Dictionary
	_context_menu_metadata = meta
	_context_menu_target = item
	_context_menu.clear()
	var entries = _context_menu_service.build_entries(
		_localization,
		meta,
		item.get_child_count() > 0,
		_CONTEXT_MENU_ACTION_IDS,
		USER_TOOL_CUSTOM_ROOT
	)
	for entry in entries:
		if str(entry.get("type", "")) == "separator":
			_context_menu.add_separator()
			continue
		_add_context_menu_item(str(entry.get("label", "")), int(entry.get("id", -1)), bool(entry.get("disabled", false)))
	_context_menu.popup(Rect2i(int(global_pos.x), int(global_pos.y), 0, 0))


func _on_context_menu_id_pressed(id: int) -> void:
	_apply_context_menu_action(
		_context_menu_service.resolve_action(
			id,
			_context_menu_metadata,
			_current_model,
			_CONTEXT_MENU_ACTION_IDS,
			USER_TOOL_CUSTOM_ROOT
		)
	)


func _apply_context_menu_action(action: Dictionary) -> void:
	match str(action.get("type", "")):
		"clipboard":
			DisplayServer.clipboard_set(str(action.get("text", "")))
		"delete_user_tool":
			var script_path := str(action.get("script_path", ""))
			if not script_path.is_empty():
				delete_user_tool_requested.emit(script_path)
		"collapse_subtree":
			if is_instance_valid(_context_menu_target):
				var collapsed := bool(action.get("collapsed", false))
				_tree_syncing = true
				_tree_state_service.set_subtree_collapsed(_context_menu_target, collapsed)
				_tree_syncing = false
				_tree_state_service.sync_subtree_collapsed_to_settings(
					_context_menu_target,
					TREE_TEXT_COLUMN,
					_current_model.get("settings", {}),
					Callable(self, "_emit_tree_collapse_changed")
				)


func _add_context_menu_item(label: String, id: int, disabled: bool = false) -> void:
	var index := _context_menu.get_item_count()
	_context_menu.add_item(label, id)
	_context_menu.set_item_disabled(index, disabled)


func _process(_delta: float) -> void:
	_update_tree_shadow_visibility()


func _update_tree_shadow_visibility() -> void:
	if not is_instance_valid(_tool_tree):
		_top_shadow.visible = false
		_bottom_shadow.visible = false
		return
	var scroll: Vector2 = _tool_tree.get_scroll()
	var root = _tool_tree.get_root()
	var has_items := root != null and root.get_first_child() != null
	_top_shadow.visible = scroll.y > 0.5
	_bottom_shadow.visible = has_items and _tree_state_service.tree_has_hidden_content_below(_tool_tree, root, TREE_TEXT_COLUMN)


func _get_search_query() -> String:
	return _search_edit.text.strip_edges().to_lower()


func _apply_selection_metadata(metadata) -> void:
	_selection_state = ToolsTabSelectionSupport.build_state_from_metadata(metadata)
	_refresh_preview()


func _clear_selection_metadata() -> void:
	_selection_state = ToolsTabSelectionSupport.empty_state()
	_last_preview_key = ""


func _restore_tree_selection() -> void:
	if not ToolsTabSelectionSupport.has_selection(_selection_state):
		return
	var root = _tool_tree.get_root()
	if root == null:
		return
	var item = _tree_state_service.find_item_by_selection(root, TREE_TEXT_COLUMN, _selection_state)
	if item == null:
		_clear_selection_metadata()
		_refresh_preview()
		return
	_tool_tree.set_selected(item, TREE_TEXT_COLUMN)
	_apply_selection_metadata(item.get_metadata(TREE_TEXT_COLUMN))


func _queue_selection_sync() -> void:
	if _selection_sync_queued:
		return
	_selection_sync_queued = true
	call_deferred("_restore_tree_selection_deferred")


func _restore_tree_selection_deferred() -> void:
	_selection_sync_queued = false
	_restore_tree_selection()


func _handle_tree_click_deferred(mouse_position: Vector2) -> void:
	_apply_tree_interaction_action(
		_click_dispatch_service.resolve_deferred_click(_tool_tree, mouse_position, TREE_TEXT_COLUMN, TREE_CHECK_COLUMN)
	)


func _apply_tree_interaction_action(action: Dictionary) -> bool:
	match str(action.get("type", "")):
		"toggle_item_collapsed":
			var selected_item = action.get("item")
			if selected_item is TreeItem:
				var tree_item := selected_item as TreeItem
				tree_item.collapsed = not tree_item.collapsed
				_on_tree_item_collapsed(tree_item)
				return true
		"show_context_menu":
			var menu_item = action.get("item")
			if menu_item is TreeItem:
				_show_tree_context_menu(menu_item as TreeItem, action.get("global_position", Vector2.ZERO))
				return true
		"collapse_subtree":
			var collapse_item = action.get("item")
			if collapse_item is TreeItem:
				_apply_subtree_collapse_action(collapse_item as TreeItem, bool(action.get("collapsed", false)))
				return true
		"deferred_click":
			call_deferred("_handle_tree_click_deferred", action.get("position", Vector2.ZERO))
			return true
		"select_metadata":
			_apply_selection_metadata(action.get("metadata"))
			return true
		"toggle_entry":
			_emit_toggle_action(action)
			return true
	return false


func _apply_subtree_collapse_action(item: TreeItem, collapsed: bool) -> void:
	_tree_syncing = true
	_tree_state_service.set_subtree_collapsed(item, collapsed)
	_tree_syncing = false
	_tree_state_service.sync_subtree_collapsed_to_settings(
		item,
		TREE_TEXT_COLUMN,
		_current_model.get("settings", {}),
		Callable(self, "_emit_tree_collapse_changed")
	)


func _emit_toggle_action(action: Dictionary) -> void:
	match str(action.get("kind", "")):
		"domain":
			domain_toggled.emit(str(action.get("key", "")), bool(action.get("enabled", false)))
		"category":
			category_toggled.emit(str(action.get("key", "")), bool(action.get("enabled", false)))
		"tool":
			tool_toggled.emit(str(action.get("key", "")), bool(action.get("enabled", false)))


func _has_tree_selection() -> bool:
	return ToolsTabSelectionSupport.has_selection(_selection_state)


func _emit_tree_collapse_changed(kind: String, key: String, collapsed: bool) -> void:
	tree_collapse_changed.emit(kind, key, collapsed)


func _refresh_preview() -> void:
	if _localization == null:
		return
	var preview_state = _view_state_service.build_preview_state(
		_localization,
		_current_model,
		_filtered_tools_by_category,
		_selection_state,
		_last_preview_key
	)
	_last_preview_key = str(preview_state.get("preview_key", ""))
	_view_binding_service.apply_preview_state(_tool_preview_title, _tool_preview_text, preview_state)
