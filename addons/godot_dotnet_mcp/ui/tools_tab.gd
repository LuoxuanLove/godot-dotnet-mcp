@tool
extends VBoxContainer

signal tool_toggled(tool_name: String, enabled: bool)
signal delete_user_tool_requested(script_path: String)
signal category_toggled(category: String, enabled: bool)
signal domain_toggled(domain_key: String, enabled: bool)
signal tree_collapse_changed(kind: String, key: String, collapsed: bool)

const SystemTreeCatalog = preload("res://addons/godot_dotnet_mcp/plugin/runtime/system_tree_catalog.gd")
const TreeCollapseState = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tree_collapse_state.gd")
const ToolsTabContextMenuSupport = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_context_menu_support.gd")
const ToolsTabModelSupport = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_model_support.gd")
const ToolsTabSearchService = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_search_service.gd")
const ToolsTabSelectionSupport = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_selection_support.gd")
const ToolsTabPreviewBuilder = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_preview_builder.gd")

const TREE_TEXT_COLUMN := 0
const TREE_CHECK_COLUMN := 1
const SYSTEM_CATEGORY := "system"
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


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_search_edit.text_changed.connect(_on_search_text_changed)
	_tool_tree.item_collapsed.connect(_on_tree_item_collapsed)
	_tool_tree.gui_input.connect(_on_tree_gui_input)
	_tool_tree.set_allow_reselect(true)
	_tool_preview_text.editable = false
	_tool_preview_text.selecting_enabled = true
	_tool_preview_text.context_menu_enabled = true
	_tool_preview_text.set_line_wrapping_mode(TextEdit.LINE_WRAPPING_BOUNDARY)
	_tool_preview_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var top_pane = _content_split.get_node("TopPane") as Control
	var bottom_pane = _content_split.get_node("BottomPane") as Control
	var tool_list_panel = _content_split.get_node("TopPane/ToolListOuterMargin/ToolListPanel") as Control
	top_pane.clip_contents = true
	bottom_pane.clip_contents = true
	tool_list_panel.clip_contents = true
	_tool_preview_panel.clip_contents = true
	_configure_tree_shadow(_top_shadow, false)
	_configure_tree_shadow(_bottom_shadow, true)
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
		_apply_editor_scale(editor_scale)

	_apply_localized_copy(localization, model)

	var tree_signature = _build_tree_signature(model)
	_refresh_tree_state(model, tree_signature)


func _render_tool_tree(model: Dictionary) -> void:
	_tree_syncing = true
	_tool_tree.clear()
	_tool_tree.set_column_clip_content(TREE_TEXT_COLUMN, true)
	_tool_tree.set_column_clip_content(TREE_CHECK_COLUMN, true)
	var root = _tool_tree.create_item()
	if root == null:
		_tree_syncing = false
		call_deferred("_update_tree_shadow_visibility")
		return

	_create_root_group_item(root, model, SYSTEM_CATEGORY)
	_create_root_group_item(root, model, "user")

	_tree_syncing = false
	call_deferred("_update_tree_shadow_visibility")


func _create_root_group_item(parent: TreeItem, model: Dictionary, category: String) -> void:
	var settings: Dictionary = model.get("settings", {})
	var counts = ToolsTabModelSupport.count_category(model, _filtered_tools_by_category, category)
	var item = _tool_tree.create_item(parent)
	if item == null:
		return
	var root_label = ToolsTabModelSupport.get_category_label(model.get("localization"), category)
	var root_text = "%s    %d/%d" % [root_label, counts["enabled"], counts["total"]]
	if counts["enabled"] > 0 and counts["enabled"] < counts["total"]:
		root_text += " %s" % model.get("localization").get_text("tools_partial_suffix")
	var root_tooltip = ToolsTabModelSupport.get_group_tooltip(model.get("localization"), ToolsTabModelSupport.get_category_label_key(category))
	_configure_info_row(item, root_text, ToolsTabContextMenuSupport.build_tree_node_metadata(TreeCollapseState.KIND_ROOT, category, root_label, category, {
		"category": category,
		"label_key": ToolsTabModelSupport.get_category_label_key(category)
	}), TreeCollapseState.is_node_collapsed(settings, TreeCollapseState.KIND_ROOT, category))
	if not root_tooltip.is_empty():
		item.set_tooltip_text(TREE_TEXT_COLUMN, root_tooltip)
	for tool_def in ToolsTabModelSupport.get_filtered_tool_definitions(_filtered_tools_by_category, category):
		_create_tool_item(item, model, category, tool_def)


func _apply_localized_copy(localization, model: Dictionary) -> void:
	_tool_count_label.text = localization.get_text("tools_enabled") % ToolsTabModelSupport.count_enabled_tools(model, _filtered_tools_by_category)
	_search_edit.placeholder_text = localization.get_text("tool_search_placeholder")


func _refresh_tree_state(model: Dictionary, tree_signature: String) -> void:
	if tree_signature != _last_tree_signature:
		_last_tree_signature = tree_signature
		_render_tool_tree(model)
		_refresh_preview()
		if _has_tree_selection():
			_queue_selection_sync()
		return

	_refresh_preview()


func _configure_info_row(item: TreeItem, text: String, metadata: Dictionary, collapsed: bool) -> void:
	item.set_text(TREE_TEXT_COLUMN, text)
	item.set_selectable(TREE_TEXT_COLUMN, true)
	item.set_metadata(TREE_TEXT_COLUMN, metadata)
	item.set_custom_color(TREE_TEXT_COLUMN, Color(0.6, 0.6, 0.6))
	item.collapsed = collapsed


func _configure_action_item(item: TreeItem, action_name: String, parent_tool: String) -> void:
	var action_display_name := ToolsTabModelSupport.get_action_display_name(_localization, parent_tool, action_name)
	item.set_text(TREE_TEXT_COLUMN, action_display_name)
	item.set_selectable(TREE_TEXT_COLUMN, true)
	item.set_metadata(TREE_TEXT_COLUMN, ToolsTabContextMenuSupport.build_tree_node_metadata("action", parent_tool + "." + action_name, action_display_name, action_name, {
		"action": action_name,
		"tool": parent_tool,
		"parent_tool": parent_tool,
		"description_key": SystemTreeCatalog.get_action_desc_key(parent_tool, action_name)
	}))
	item.set_custom_color(TREE_TEXT_COLUMN, Color(0.45, 0.45, 0.45))


func _configure_item_toggle(item: TreeItem, checked: bool) -> void:
	item.set_cell_mode(TREE_CHECK_COLUMN, TreeItem.CELL_MODE_CHECK)
	item.set_editable(TREE_CHECK_COLUMN, true)
	item.set_selectable(TREE_CHECK_COLUMN, false)
	item.set_checked(TREE_CHECK_COLUMN, checked)


func _configure_item_text(item: TreeItem, text: String, metadata: Dictionary, tooltip: String = "") -> void:
	item.set_text(TREE_TEXT_COLUMN, text)
	item.set_selectable(TREE_TEXT_COLUMN, true)
	item.set_metadata(TREE_TEXT_COLUMN, metadata)
	if not tooltip.is_empty():
		item.set_tooltip_text(TREE_TEXT_COLUMN, tooltip)


func _create_domain_item(root: TreeItem, model: Dictionary, domain_key: String, label_key: String, categories: Array) -> void:
	var settings: Dictionary = model.get("settings", {})
	var counts = ToolsTabModelSupport.count_categories(model, _filtered_tools_by_category, categories)
	var item = _tool_tree.create_item(root)
	if item == null:
		return
	_configure_item_toggle(item, ToolsTabModelSupport.is_domain_fully_enabled(model, _filtered_tools_by_category, categories))
	var domain_label = model.get("localization").get_text(label_key)
	var domain_text = "%s    %d/%d" % [domain_label, counts["enabled"], counts["total"]]
	if counts["enabled"] > 0 and counts["enabled"] < counts["total"]:
		domain_text += " %s" % model.get("localization").get_text("tools_partial_suffix")
	var domain_tooltip = ToolsTabModelSupport.get_group_tooltip(model.get("localization"), label_key)
	_configure_item_text(item, domain_text, ToolsTabContextMenuSupport.build_tree_node_metadata("domain", domain_key, domain_label, domain_key, {"label_key": label_key}), domain_tooltip)
	item.collapsed = TreeCollapseState.is_node_collapsed(settings, TreeCollapseState.KIND_DOMAIN, domain_key)

	for category in categories:
		_create_category_item(item, model, str(category))


func _create_category_item(parent: TreeItem, model: Dictionary, category: String) -> void:
	var settings: Dictionary = model.get("settings", {})
	var counts = ToolsTabModelSupport.count_category(model, _filtered_tools_by_category, category)
	var item = _tool_tree.create_item(parent)
	if item == null:
		return
	_configure_item_toggle(item, ToolsTabModelSupport.is_category_fully_enabled(model, _filtered_tools_by_category, category))
	var label_key = ToolsTabModelSupport.get_category_label_key(category)
	var load_error_messages = ToolsTabModelSupport.get_category_load_error_messages(model, category)
	var category_label = ToolsTabModelSupport.get_category_label(model.get("localization"), category)
	var category_text = "%s    %d/%d" % [category_label, counts["enabled"], counts["total"]]
	if counts["enabled"] > 0 and counts["enabled"] < counts["total"]:
		category_text += " %s" % model.get("localization").get_text("tools_partial_suffix")
	if not load_error_messages.is_empty():
		category_text += " %s" % model.get("localization").get_text("tools_load_error_suffix")
	var category_tooltip = ToolsTabModelSupport.get_group_tooltip(model.get("localization"), label_key)
	if not load_error_messages.is_empty():
		if not category_tooltip.is_empty():
			category_tooltip += "\n\n"
		category_tooltip += "\n".join(load_error_messages)
	_configure_item_text(item, category_text, ToolsTabContextMenuSupport.build_tree_node_metadata("category", category, category_label, category, {"label_key": label_key}), category_tooltip)
	if not load_error_messages.is_empty():
		item.set_custom_color(TREE_TEXT_COLUMN, Color(0.9, 0.35, 0.35))
	item.collapsed = TreeCollapseState.is_node_collapsed(settings, TreeCollapseState.KIND_CATEGORY, category)

	for tool_def in ToolsTabModelSupport.get_filtered_tool_definitions(_filtered_tools_by_category, category):
		_create_tool_item(item, model, category, tool_def)


func _create_tool_item(parent: TreeItem, model: Dictionary, category: String, tool_def: Dictionary) -> void:
	var tool_name = str(tool_def.get("name", ""))
	var full_name = "%s_%s" % [category, tool_name]
	var item = _tool_tree.create_item(parent)
	if item == null:
		return
	_configure_tool_row(item, model, full_name, category, tool_name, tool_def)
	if category == SYSTEM_CATEGORY:
		var has_children := SystemTreeCatalog.SYSTEM_TOOL_ATOMIC_CHILDREN.has(full_name)
		if has_children:
			var settings: Dictionary = model.get("settings", {})
			item.collapsed = TreeCollapseState.is_node_collapsed(settings, TreeCollapseState.KIND_TOOL, full_name)
		var visited := {}
		visited[full_name] = true
		_create_atomic_tool_children(item, model, full_name, visited)


func _configure_tool_row(item: TreeItem, model: Dictionary, full_name: String, category: String, tool_name: String, tool_def: Dictionary) -> void:
	var localization = model.get("localization")
	_configure_item_toggle(item, not model.get("settings", {}).get("disabled_tools", []).has(full_name))
	var tool_display_name = ToolsTabModelSupport.get_tool_display_name(localization, full_name, tool_name)
	_configure_item_text(item, tool_display_name, ToolsTabContextMenuSupport.build_tree_node_metadata("tool", full_name, tool_display_name, full_name, {
		"category": category,
		"tool_name": tool_name,
		"source": str(tool_def.get("source", "builtin")),
		"script_path": str(tool_def.get("script_path", "")),
		"runtime_domain": str(tool_def.get("runtime_domain", "")),
		"runtime_version": int(tool_def.get("runtime_version", 0)),
		"runtime_state": str(tool_def.get("state", "")),
		"pending_reload": bool(tool_def.get("pending_reload", false)),
		"last_error": tool_def.get("last_error", null),
		"discovery_source": str(tool_def.get("discovery_source", "")),
		"last_refresh_reason": str(tool_def.get("last_refresh_reason", ""))
	}), ToolsTabModelSupport.get_tool_description(localization, full_name, tool_def))


func _create_atomic_tool_children(parent: TreeItem, model: Dictionary, system_full_name: String, visited: Dictionary = {}) -> void:
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
		if not ToolsTabSearchService.matches_atomic_tool_search(model, atomic_full_name, atomic_tool_def, _get_search_query()):
			continue
		var category = ToolsTabModelSupport.extract_category_from_full_name(model, atomic_full_name)
		var tool_name = str(atomic_tool_def.get("name", ""))
		if category.is_empty() or tool_name.is_empty():
			continue

		var item = _tool_tree.create_item(parent)
		if item == null:
			continue
		# Atomic tool: info-only row, no checkbox
		var atomic_display_name = ToolsTabModelSupport.get_tool_display_name(_localization, atomic_full_name, tool_name)
		_configure_info_row(item, atomic_display_name,
			ToolsTabContextMenuSupport.build_tree_node_metadata("atomic", atomic_full_name, atomic_display_name, atomic_full_name, {
				"category": category,
				"tool_name": tool_name
			}),
			TreeCollapseState.is_node_collapsed(model.get("settings", {}), TreeCollapseState.KIND_ATOMIC, atomic_full_name))

		if category == SYSTEM_CATEGORY:
			var next_visited = visited.duplicate()
			next_visited[atomic_full_name] = true
			_create_atomic_tool_children(item, model, atomic_full_name, next_visited)

		# Third level: action leaf nodes
		for action_name in actions:
			var action_item = _tool_tree.create_item(item)
			if action_item != null:
				_configure_action_item(action_item, str(action_name), atomic_full_name)


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
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_SPACE:
				var selected := _tool_tree.get_selected()
				if selected != null and selected.get_child_count() > 0:
					selected.collapsed = not selected.collapsed
					_on_tree_item_collapsed(selected)
					get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		var item = _tool_tree.get_item_at_position(mouse_event.position)
		if item != null:
			_show_tree_context_menu(item, _tool_tree.get_global_transform().origin + mouse_event.position)
			get_viewport().set_input_as_handled()
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.shift_pressed:
		var item: TreeItem = _tool_tree.get_item_at_position(mouse_event.position)
		if item != null and item.get_child_count() > 0:
			# gui_input fires BEFORE Tree's internal _gui_input(), so item.collapsed
			# is still the OLD state here. Toggle to opposite = desired new state.
			var want_collapsed: bool = not item.collapsed
			_tree_syncing = true
			_set_subtree_collapsed(item, want_collapsed)
			_tree_syncing = false
			_sync_subtree_collapsed_to_settings(item, want_collapsed)
			get_viewport().set_input_as_handled()
			return
	call_deferred("_handle_tree_click_deferred", mouse_event.position)


func _set_subtree_collapsed(item: TreeItem, collapsed: bool) -> void:
	item.collapsed = collapsed
	var child := item.get_first_child()
	while child != null:
		_set_subtree_collapsed(child, collapsed)
		child = child.get_next()


func _sync_subtree_collapsed_to_settings(item: TreeItem, want_collapsed: bool) -> void:
	if item == null:
		return
	_sync_item_collapsed_to_settings(item, want_collapsed)
	var child := item.get_first_child()
	while child != null:
		_sync_subtree_collapsed_to_settings(child, want_collapsed)
		child = child.get_next()


func _sync_item_collapsed_to_settings(item: TreeItem, want_collapsed: bool) -> void:
	var metadata = item.get_metadata(TREE_TEXT_COLUMN)
	if not (metadata is Dictionary):
		return
	var meta := metadata as Dictionary
	var kind := str(meta.get("kind", ""))
	var key := str(meta.get("key", ""))
	var settings: Dictionary = _current_model.get("settings", {})
	if key.is_empty() or not TreeCollapseState.EXPANDABLE_KINDS.has(kind):
		return
	var is_saved_collapsed: bool = TreeCollapseState.is_node_collapsed(settings, kind, key)
	if is_saved_collapsed != want_collapsed:
		tree_collapse_changed.emit(kind, key, want_collapsed)


func _show_tree_context_menu(item: TreeItem, global_pos: Vector2) -> void:
	var metadata = item.get_metadata(TREE_TEXT_COLUMN)
	if not (metadata is Dictionary):
		return
	var meta := metadata as Dictionary
	_context_menu_metadata = meta
	_context_menu_target = item
	_context_menu.clear()
	var entries = ToolsTabContextMenuSupport.build_context_menu_entries(_localization, meta, item.get_child_count() > 0, {
		"copy_localized_name": _CTX_COPY_LOCALIZED_NAME,
		"copy_english_id": _CTX_COPY_ENGLISH_ID,
		"copy_schema": _CTX_COPY_SCHEMA,
		"delete_tool": _CTX_DELETE_TOOL,
		"expand_all": _CTX_EXPAND_ALL,
		"collapse_all": _CTX_COLLAPSE_ALL,
		"user_tool_root": USER_TOOL_CUSTOM_ROOT
	})
	for entry in entries:
		if str(entry.get("type", "")) == "separator":
			_context_menu.add_separator()
			continue
		_add_context_menu_item(str(entry.get("label", "")), int(entry.get("id", -1)), bool(entry.get("disabled", false)))
	_context_menu.popup(Rect2i(int(global_pos.x), int(global_pos.y), 0, 0))


func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		_CTX_COPY_LOCALIZED_NAME:
			DisplayServer.clipboard_set(ToolsTabContextMenuSupport.get_context_menu_localized_name(_context_menu_metadata))
		_CTX_COPY_ENGLISH_ID:
			DisplayServer.clipboard_set(ToolsTabContextMenuSupport.get_context_menu_english_id(_context_menu_metadata))
		_CTX_COPY_SCHEMA:
			var full_name = str(_context_menu_metadata.get("key", ""))
			var tool_def = ToolsTabModelSupport.get_tool_def_by_full_name(_current_model, full_name)
			var schema = tool_def.get("inputSchema", {})
			DisplayServer.clipboard_set(JSON.stringify(schema, "\t"))
		_CTX_DELETE_TOOL:
			var script_path = ToolsTabContextMenuSupport.get_context_menu_user_tool_script_path(_context_menu_metadata, USER_TOOL_CUSTOM_ROOT)
			if not script_path.is_empty():
				delete_user_tool_requested.emit(script_path)
		_CTX_EXPAND_ALL:
			if is_instance_valid(_context_menu_target):
				_tree_syncing = true
				_set_subtree_collapsed(_context_menu_target, false)
				_tree_syncing = false
				_sync_subtree_collapsed_to_settings(_context_menu_target, false)
		_CTX_COLLAPSE_ALL:
			if is_instance_valid(_context_menu_target):
				_tree_syncing = true
				_set_subtree_collapsed(_context_menu_target, true)
				_tree_syncing = false
				_sync_subtree_collapsed_to_settings(_context_menu_target, true)


func _add_context_menu_item(label: String, id: int, disabled: bool = false) -> void:
	var index := _context_menu.get_item_count()
	_context_menu.add_item(label, id)
	_context_menu.set_item_disabled(index, disabled)


func _configure_tree_shadow(shadow: ColorRect, invert: bool) -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.58);
uniform bool invert_gradient = false;

void fragment() {
	float amount = 1.0 - UV.y;
	if (invert_gradient) {
		amount = UV.y;
	}
	float alpha = pow(amount, 1.35) * shadow_color.a;
	COLOR = vec4(shadow_color.rgb, alpha);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("shadow_color", Color(0.0, 0.0, 0.0, 0.58))
	material.set_shader_parameter("invert_gradient", invert)
	shadow.material = material
	shadow.color = Color.WHITE
	shadow.anchor_left = 0.0
	shadow.anchor_right = 1.0
	shadow.offset_left = -12.0
	shadow.offset_right = 12.0
	shadow.z_index = 8
	if invert:
		shadow.anchor_top = 1.0
		shadow.anchor_bottom = 1.0
		shadow.offset_top = -18.0
		shadow.offset_bottom = 0.0
	else:
		shadow.anchor_top = 0.0
		shadow.anchor_bottom = 0.0
		shadow.offset_top = 0.0
		shadow.offset_bottom = 18.0


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
	_bottom_shadow.visible = has_items and _tree_has_hidden_content_below(root)


func _apply_editor_scale(scale: float) -> void:
	_current_scale = scale

	_tool_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tool_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Tree content scrolls internally, so its minimum height must stay low enough
	# for the split container to keep search, divider and preview from overlapping.
	_tool_tree.custom_minimum_size.y = 96.0 * scale
	_tool_tree.custom_minimum_size.x = 0.0
	_tool_tree.set_column_expand(TREE_TEXT_COLUMN, true)
	_tool_tree.set_column_expand(TREE_CHECK_COLUMN, false)
	_tool_tree.set_column_custom_minimum_width(TREE_TEXT_COLUMN, int(round(320 * scale)))
	_tool_tree.set_column_custom_minimum_width(TREE_CHECK_COLUMN, int(round(44 * scale)))
	_tool_preview_panel.custom_minimum_size.y = 88.0 * scale
	_top_shadow.offset_left = -12.0 * scale
	_top_shadow.offset_right = 12.0 * scale
	_top_shadow.custom_minimum_size.y = 14.0 * scale
	_top_shadow.offset_bottom = 14.0 * scale
	_bottom_shadow.offset_left = -12.0 * scale
	_bottom_shadow.offset_right = 12.0 * scale
	_bottom_shadow.custom_minimum_size.y = 14.0 * scale
	_bottom_shadow.offset_top = -14.0 * scale

	_search_edit.custom_minimum_size.y = 30.0 * scale


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
	var item = _find_item_by_selection(root)
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
	var column = _tool_tree.get_column_at_position(mouse_position)
	if column < 0:
		return
	var item = _tool_tree.get_item_at_position(mouse_position)
	if item == null:
		return
	if column == TREE_TEXT_COLUMN:
		_apply_selection_metadata(item.get_metadata(TREE_TEXT_COLUMN))
		return
	if column == TREE_CHECK_COLUMN:
		_emit_toggle_for_item(item)


func _emit_toggle_for_item(item: TreeItem) -> void:
	var metadata = item.get_metadata(TREE_TEXT_COLUMN)
	if not (metadata is Dictionary):
		return
	var enabled = item.is_checked(TREE_CHECK_COLUMN)
	match str(metadata.get("kind", "")):
		"domain":
			domain_toggled.emit(str(metadata.get("key", "")), enabled)
		"category":
			category_toggled.emit(str(metadata.get("key", "")), enabled)
		"tool":
			tool_toggled.emit(str(metadata.get("key", "")), enabled)


func _has_tree_selection() -> bool:
	return ToolsTabSelectionSupport.has_selection(_selection_state)


func _find_item_by_selection(item: TreeItem) -> TreeItem:
	if item == null:
		return null
	var metadata = item.get_metadata(TREE_TEXT_COLUMN)
	if ToolsTabSelectionSupport.metadata_matches_state(metadata, _selection_state):
		return item

	var child = item.get_first_child()
	while child != null:
		var found = _find_item_by_selection(child)
		if found != null:
			return found
		child = child.get_next()
	return null


func _tree_has_hidden_content_below(root: TreeItem) -> bool:
	var last_item = _find_last_visible_tree_item(root)
	if last_item == null:
		return false
	var rect = _tool_tree.get_item_area_rect(last_item, TREE_TEXT_COLUMN, -1)
	return rect.position.y + rect.size.y > _tool_tree.size.y + 1.0


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


func _refresh_preview() -> void:
	if _localization == null:
		return
	_tool_preview_title.text = _localization.get_text("tool_preview_title")
	# Build a key representing the current selection to detect changes
	var current_preview_key := ToolsTabSelectionSupport.build_preview_key(_selection_state)
	var selection_changed := current_preview_key != _last_preview_key
	_last_preview_key = current_preview_key
	# Preserve scroll position when re-rendering without a selection change
	var saved_v_scroll := _tool_preview_text.get_v_scroll() if not selection_changed else 0
	_tool_preview_text.clear()
	_tool_preview_text.set_text(ToolsTabPreviewBuilder.build_preview_text({
		"localization": _localization,
		"current_model": _current_model,
		"filtered_tools_by_category": _filtered_tools_by_category,
		"selected_tree_kind": str(_selection_state.get("kind", "")),
		"selected_tree_key": str(_selection_state.get("key", "")),
		"selected_tool_category": str(_selection_state.get("category", "")),
		"selected_tool_name": str(_selection_state.get("tool_name", ""))
	}))
	_tool_preview_text.set_v_scroll(saved_v_scroll)


func _build_tree_signature(model: Dictionary) -> String:
	var tools_by_category = model.get("tools_by_category", {})
	var parts: Array[String] = [
		_get_search_query(),
		JSON.stringify(model.get("settings", {}).get("disabled_tools", [])),
		JSON.stringify(TreeCollapseState.get_collapsed_nodes(model.get("settings", {}))),
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
