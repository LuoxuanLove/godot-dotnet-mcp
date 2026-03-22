@tool
extends VBoxContainer

signal tool_toggled(tool_name: String, enabled: bool)
signal delete_user_tool_requested(script_path: String)
signal category_toggled(category: String, enabled: bool)
signal domain_toggled(domain_key: String, enabled: bool)
signal tree_collapse_changed(kind: String, key: String, collapsed: bool)

const SystemTreeCatalog = preload("res://addons/godot_dotnet_mcp/plugin/runtime/system_tree_catalog.gd")
const TreeCollapseState = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tree_collapse_state.gd")

const CATEGORY_LABEL_KEYS := {
	"scene": "cat_scene",
	"node": "cat_node",
	"script": "cat_script",
	"resource": "cat_resource",
	"filesystem": "cat_filesystem",
	"project": "cat_project",
	"editor": "cat_editor",
	"plugin_runtime": "cat_plugin_runtime",
	"plugin_evolution": "cat_plugin_evolution",
	"plugin_developer": "cat_plugin_developer",
	"debug": "cat_debug",
	"animation": "cat_animation",
	"signal": "cat_signal",
	"group": "cat_group",
	"material": "cat_material",
	"shader": "cat_shader",
	"lighting": "cat_lighting",
	"particle": "cat_particle",
	"tilemap": "cat_tilemap",
	"geometry": "cat_geometry",
	"physics": "cat_physics",
	"navigation": "cat_navigation",
	"audio": "cat_audio",
	"ui": "cat_ui",
	"user": "cat_user",
	"system": "cat_system"
}

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
var _selected_tree_kind := ""
var _selected_tree_key := ""
var _selected_tool_category := ""
var _selected_tool_name := ""
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
	var counts = _count_category(model, category)
	var item = _tool_tree.create_item(parent)
	if item == null:
		return
	var root_label = _get_category_label(model.get("localization"), category)
	var root_text = "%s    %d/%d" % [root_label, counts["enabled"], counts["total"]]
	if counts["enabled"] > 0 and counts["enabled"] < counts["total"]:
		root_text += " %s" % model.get("localization").get_text("tools_partial_suffix")
	var root_tooltip = _get_group_tooltip(model.get("localization"), _get_category_label_key(category))
	_configure_info_row(item, root_text, _build_tree_node_metadata(TreeCollapseState.KIND_ROOT, category, root_label, category, {
		"category": category,
		"label_key": _get_category_label_key(category)
	}), TreeCollapseState.is_node_collapsed(settings, TreeCollapseState.KIND_ROOT, category))
	if not root_tooltip.is_empty():
		item.set_tooltip_text(TREE_TEXT_COLUMN, root_tooltip)
	for tool_def in _get_filtered_tool_definitions(model, category):
		if bool(tool_def.get("compatibility_alias", false)):
			continue
		_create_tool_item(item, model, category, tool_def)


func _apply_localized_copy(localization, model: Dictionary) -> void:
	_tool_count_label.text = localization.get_text("tools_enabled") % _count_enabled_tools(model)
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
	var action_display_name := _get_action_display_name(parent_tool, action_name)
	item.set_text(TREE_TEXT_COLUMN, action_display_name)
	item.set_selectable(TREE_TEXT_COLUMN, true)
	item.set_metadata(TREE_TEXT_COLUMN, _build_tree_node_metadata("action", parent_tool + "." + action_name, action_display_name, action_name, {
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
	var counts = _count_categories(model, categories)
	var item = _tool_tree.create_item(root)
	if item == null:
		return
	_configure_item_toggle(item, _is_domain_fully_enabled(model, categories))
	var domain_label = model.get("localization").get_text(label_key)
	var domain_text = "%s    %d/%d" % [domain_label, counts["enabled"], counts["total"]]
	if counts["enabled"] > 0 and counts["enabled"] < counts["total"]:
		domain_text += " %s" % model.get("localization").get_text("tools_partial_suffix")
	var domain_tooltip = _get_group_tooltip(model.get("localization"), label_key)
	_configure_item_text(item, domain_text, _build_tree_node_metadata("domain", domain_key, domain_label, domain_key, {"label_key": label_key}), domain_tooltip)
	item.collapsed = TreeCollapseState.is_node_collapsed(settings, TreeCollapseState.KIND_DOMAIN, domain_key)

	for category in categories:
		_create_category_item(item, model, str(category))


func _create_category_item(parent: TreeItem, model: Dictionary, category: String) -> void:
	var settings: Dictionary = model.get("settings", {})
	var counts = _count_category(model, category)
	var item = _tool_tree.create_item(parent)
	if item == null:
		return
	_configure_item_toggle(item, _is_category_fully_enabled(model, category))
	var label_key = _get_category_label_key(category)
	var load_error_messages = _get_category_load_error_messages(model, category)
	var category_label = _get_category_label(model.get("localization"), category)
	var category_text = "%s    %d/%d" % [category_label, counts["enabled"], counts["total"]]
	if counts["enabled"] > 0 and counts["enabled"] < counts["total"]:
		category_text += " %s" % model.get("localization").get_text("tools_partial_suffix")
	if not load_error_messages.is_empty():
		category_text += " %s" % model.get("localization").get_text("tools_load_error_suffix")
	var category_tooltip = _get_group_tooltip(model.get("localization"), label_key)
	if not load_error_messages.is_empty():
		if not category_tooltip.is_empty():
			category_tooltip += "\n\n"
		category_tooltip += "\n".join(load_error_messages)
	_configure_item_text(item, category_text, _build_tree_node_metadata("category", category, category_label, category, {"label_key": label_key}), category_tooltip)
	if not load_error_messages.is_empty():
		item.set_custom_color(TREE_TEXT_COLUMN, Color(0.9, 0.35, 0.35))
	item.collapsed = TreeCollapseState.is_node_collapsed(settings, TreeCollapseState.KIND_CATEGORY, category)

	for tool_def in _get_filtered_tool_definitions(model, category):
		if bool(tool_def.get("compatibility_alias", false)):
			continue
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
	var tool_display_name = _get_tool_display_name(localization, full_name, tool_name)
	_configure_item_text(item, tool_display_name, _build_tree_node_metadata("tool", full_name, tool_display_name, full_name, {
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
	}), _get_tool_description(localization, full_name, tool_def))


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
		var atomic_tool_def = _get_tool_def_by_full_name(model, atomic_full_name)
		if atomic_tool_def.is_empty():
			continue
		if not _matches_atomic_tool_search(model, atomic_full_name, atomic_tool_def):
			continue
		var category = _extract_category_from_full_name(model, atomic_full_name)
		var tool_name = str(atomic_tool_def.get("name", ""))
		if category.is_empty() or tool_name.is_empty():
			continue

		var item = _tool_tree.create_item(parent)
		if item == null:
			continue
		# Atomic tool: info-only row, no checkbox
		var atomic_display_name = _get_tool_display_name(_localization, atomic_full_name, tool_name)
		_configure_info_row(item, atomic_display_name,
			_build_tree_node_metadata("atomic", atomic_full_name, atomic_display_name, atomic_full_name, {
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


func _count_enabled_tools(model: Dictionary) -> Array:
	var total = 0
	var enabled = 0
	for category in [SYSTEM_CATEGORY, "user"]:
		for tool_def in _get_filtered_tool_definitions(model, category):
			if bool(tool_def.get("compatibility_alias", false)):
				continue
			total += 1
			var full_name = "%s_%s" % [category, tool_def.get("name", "")]
			if not model.get("settings", {}).get("disabled_tools", []).has(full_name):
				enabled += 1
	return [enabled, total]


func _count_categories(model: Dictionary, categories: Array) -> Dictionary:
	var total = 0
	var enabled = 0
	for category in categories:
		var counts = _count_category(model, str(category))
		total += int(counts["total"])
		enabled += int(counts["enabled"])
	return {"total": total, "enabled": enabled}


func _count_category(model: Dictionary, category: String) -> Dictionary:
	var total = 0
	var enabled = 0
	for tool_def in _get_filtered_tool_definitions(model, category):
		if bool(tool_def.get("compatibility_alias", false)):
			continue
		total += 1
		var full_name = "%s_%s" % [category, tool_def.get("name", "")]
		if not model.get("settings", {}).get("disabled_tools", []).has(full_name):
			enabled += 1
	return {"total": total, "enabled": enabled}


func _is_domain_fully_enabled(model: Dictionary, categories: Array) -> bool:
	var counts = _count_categories(model, categories)
	return counts["total"] > 0 and counts["total"] == counts["enabled"]


func _is_category_fully_enabled(model: Dictionary, category: String) -> bool:
	var counts = _count_category(model, category)
	return counts["total"] > 0 and counts["total"] == counts["enabled"]


func _get_category_label(localization, category: String) -> String:
	var key = CATEGORY_LABEL_KEYS.get(category, category)
	var translated = localization.get_text(str(key))
	return translated if translated != key else category.capitalize()


func _get_category_label_key(category: String) -> String:
	return str(CATEGORY_LABEL_KEYS.get(category, category))


func _get_group_tooltip(localization, label_key: String) -> String:
	var desc_key = "%s_desc" % label_key
	var translated = localization.get_text(desc_key)
	return translated if translated != desc_key else ""


func _get_tool_display_name(localization, full_name: String, tool_name: String) -> String:
	var key = "tool_%s_name" % full_name
	var translated = localization.get_text(key)
	return translated if translated != key else _humanize_identifier(tool_name)


func _get_tool_description(localization, full_name: String, tool_def: Dictionary) -> String:
	var key = "tool_%s_desc" % full_name
	var translated = localization.get_text(key)
	if translated != key:
		return translated
	return str(tool_def.get("description", ""))


func _get_action_display_name(parent_tool: String, action_name: String) -> String:
	if _localization != null:
		var specific_key = SystemTreeCatalog.get_action_name_key(parent_tool, action_name)
		var translated = _localization.get_text(specific_key)
		if translated != specific_key:
			return translated
		var generic_key = SystemTreeCatalog.get_generic_action_name_key(action_name)
		translated = _localization.get_text(generic_key)
		if translated != generic_key:
			return translated
	return _humanize_identifier(action_name)


func _get_action_description(parent_tool: String, action_name: String, tool_def: Dictionary) -> String:
	var action_display_name = _get_action_display_name(parent_tool, action_name)
	var parent_display_name = parent_tool
	if not tool_def.is_empty():
		var tool_name = str(tool_def.get("name", ""))
		if not tool_name.is_empty():
			parent_display_name = _get_tool_display_name(_localization, parent_tool, tool_name)
	if _localization != null:
		var specific_key = SystemTreeCatalog.get_action_desc_key(parent_tool, action_name)
		var translated = _localization.get_text(specific_key)
		if translated != specific_key:
			return translated
		var generic_key = SystemTreeCatalog.get_generic_action_desc_key(action_name)
		translated = _localization.get_text(generic_key)
		if translated != generic_key:
			return translated
		var fallback_key = "tool_action_desc_fallback"
		var fallback_template = _localization.get_text(fallback_key)
		if fallback_template != fallback_key:
			var fallback_text = fallback_template % [action_display_name, parent_display_name]
			var tool_description = _get_tool_description(_localization, parent_tool, tool_def)
			if not tool_description.is_empty():
				fallback_text += "\n\n" + tool_description
			return fallback_text
	return ""


func _humanize_identifier(value: String) -> String:
	var parts: Array[String] = []
	for word in value.split("_"):
		if word.is_empty():
			continue
		parts.append(word.substr(0, 1).to_upper() + word.substr(1))
	return " ".join(parts)


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
	var kind = str(meta.get("kind", ""))
	var has_children := item.get_child_count() > 0
	_add_context_menu_item(_localization.get_text("tool_ctx_copy_localized_name"), _CTX_COPY_LOCALIZED_NAME)
	_add_context_menu_item(_localization.get_text("tool_ctx_copy_english_id"), _CTX_COPY_ENGLISH_ID)
	_context_menu.add_separator()
	_add_context_menu_item(_localization.get_text("btn_expand_all"), _CTX_EXPAND_ALL, not has_children)
	_add_context_menu_item(_localization.get_text("btn_collapse_all"), _CTX_COLLAPSE_ALL, not has_children)
	match kind:
		"tool":
			_context_menu.add_separator()
			_add_context_menu_item(_localization.get_text("tool_ctx_copy_schema_json"), _CTX_COPY_SCHEMA)
			if _is_user_tool_metadata(meta):
				_add_context_menu_item(_localization.get_text("btn_delete_user_tool"), _CTX_DELETE_TOOL)
		_:
			pass
	_context_menu.popup(Rect2i(int(global_pos.x), int(global_pos.y), 0, 0))


func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		_CTX_COPY_LOCALIZED_NAME:
			DisplayServer.clipboard_set(_get_context_menu_localized_name())
		_CTX_COPY_ENGLISH_ID:
			DisplayServer.clipboard_set(_get_context_menu_english_id())
		_CTX_COPY_SCHEMA:
			var full_name = str(_context_menu_metadata.get("key", ""))
			var tool_def = _get_tool_def_by_full_name(_current_model, full_name)
			var schema = tool_def.get("inputSchema", {})
			DisplayServer.clipboard_set(JSON.stringify(schema, "\t"))
		_CTX_DELETE_TOOL:
			var script_path = _get_context_menu_user_tool_script_path()
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


func _build_tree_node_metadata(kind: String, key: String, localized_name: String = "", english_id: String = "", extra: Dictionary = {}) -> Dictionary:
	var metadata := {
		"kind": kind,
		"key": key,
		"english_id": english_id if not english_id.is_empty() else key
	}
	if not localized_name.is_empty():
		metadata["localized_name"] = localized_name
	for extra_key in extra.keys():
		metadata[str(extra_key)] = extra[extra_key]
	return metadata


func _get_context_menu_localized_name() -> String:
	var localized_name := str(_context_menu_metadata.get("localized_name", ""))
	if not localized_name.is_empty():
		return localized_name
	return str(_context_menu_metadata.get("key", ""))


func _get_context_menu_english_id() -> String:
	var english_id := str(_context_menu_metadata.get("english_id", ""))
	if not english_id.is_empty():
		return english_id
	return str(_context_menu_metadata.get("key", ""))


func _is_user_tool_metadata(meta: Dictionary) -> bool:
	if str(meta.get("category", "")) != "user":
		return false
	var script_path = str(meta.get("script_path", ""))
	return str(meta.get("source", "")) == "user_tool" and script_path.begins_with(USER_TOOL_CUSTOM_ROOT + "/")


func _get_context_menu_user_tool_script_path() -> String:
	var direct_path = str(_context_menu_metadata.get("script_path", ""))
	if direct_path.begins_with(USER_TOOL_CUSTOM_ROOT + "/"):
		return direct_path
	return ""


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


func _category_matches_search(model: Dictionary, category: String) -> bool:
	var query = _get_search_query()
	if query.is_empty():
		return true
	var category_matches = _get_category_label(model.get("localization"), category).to_lower().contains(query)
	if category_matches:
		return true
	for tool_def in model.get("tools_by_category", {}).get(category, []):
		if _matches_tool_search(model, category, tool_def, query, category_matches):
			return true
	return false


func _get_filtered_tool_definitions(model: Dictionary, category: String) -> Array:
	var filtered: Array = []
	var query = _get_search_query()
	var category_matches = _get_category_label(model.get("localization"), category).to_lower().contains(query)
	for tool_def in model.get("tools_by_category", {}).get(category, []):
		if bool(tool_def.get("compatibility_alias", false)):
			continue
		if _matches_tool_search(model, category, tool_def, query, category_matches):
			filtered.append(tool_def)
	return filtered


func _matches_tool_search(model: Dictionary, category: String, tool_def: Dictionary, query: String, category_matches: bool = false) -> bool:
	if bool(tool_def.get("compatibility_alias", false)):
		return false
	if query.is_empty() or category_matches:
		return true
	var localization = model.get("localization")
	var tool_name = str(tool_def.get("name", ""))
	var full_name = "%s_%s" % [category, tool_name]
	if _get_tool_display_name(localization, full_name, tool_name).to_lower().contains(query):
		return true
	if category != SYSTEM_CATEGORY:
		return false
	return _matches_atomic_tool_search_recursive(model, full_name, {})


func _matches_atomic_tool_search(model: Dictionary, atomic_full_name: String, atomic_tool_def: Dictionary) -> bool:
	var query = _get_search_query()
	if query.is_empty():
		return true
	var localization = model.get("localization")
	var tool_name = str(atomic_tool_def.get("name", ""))
	if _get_tool_display_name(localization, atomic_full_name, tool_name).to_lower().contains(query):
		return true
	var description = _get_tool_description(localization, atomic_full_name, atomic_tool_def)
	return description.to_lower().contains(query)


func _matches_action_search(parent_tool: String, action_name: String, tool_def: Dictionary) -> bool:
	var query = _get_search_query()
	if query.is_empty():
		return true
	if _get_action_display_name(parent_tool, action_name).to_lower().contains(query):
		return true
	if action_name.to_lower().contains(query):
		return true
	var description = _get_action_description(parent_tool, action_name, tool_def)
	return description.to_lower().contains(query)


func _matches_atomic_tool_search_recursive(model: Dictionary, system_full_name: String, visited: Dictionary) -> bool:
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
		var atomic_tool_def = _get_tool_def_by_full_name(model, atomic_full_name)
		if atomic_tool_def.is_empty():
			continue
		if _matches_atomic_tool_search(model, atomic_full_name, atomic_tool_def):
			return true
		for action_name in actions:
			if _matches_action_search(atomic_full_name, str(action_name), atomic_tool_def):
				return true
		var next_visited = visited.duplicate()
		next_visited[atomic_full_name] = true
		if _matches_atomic_tool_search_recursive(model, atomic_full_name, next_visited):
			return true
	return false


func _get_search_query() -> String:
	return _search_edit.text.strip_edges().to_lower()


func _get_category_load_error_messages(model: Dictionary, category: String) -> Array[String]:
	var messages: Array[String] = []
	for error_info in model.get("tool_load_errors", []):
		if not (error_info is Dictionary):
			continue
		var info := error_info as Dictionary
		if str(info.get("category", "")) != category:
			continue
		messages.append(str(info.get("message", "Tool domain load failed")))
	return messages


func _apply_selection_metadata(metadata) -> void:
	_clear_selection_metadata()
	if metadata is Dictionary:
		var metadata_dict := metadata as Dictionary
		_selected_tree_kind = str(metadata_dict.get("kind", ""))
		_selected_tree_key = str(metadata_dict.get("key", ""))
		_selected_tool_category = str(metadata_dict.get("category", ""))
		_selected_tool_name = str(metadata_dict.get("tool_name", ""))
	_refresh_preview()


func _clear_selection_metadata() -> void:
	_selected_tree_kind = ""
	_selected_tree_key = ""
	_selected_tool_category = ""
	_selected_tool_name = ""
	_last_preview_key = ""


func _restore_tree_selection() -> void:
	if _selected_tree_kind.is_empty() or _selected_tree_key.is_empty():
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
	return not _selected_tree_kind.is_empty() and not _selected_tree_key.is_empty()


func _find_item_by_selection(item: TreeItem) -> TreeItem:
	if item == null:
		return null
	var metadata = item.get_metadata(TREE_TEXT_COLUMN)
	if metadata is Dictionary:
		var metadata_dict := metadata as Dictionary
		if str(metadata_dict.get("kind", "")) == _selected_tree_kind and str(metadata_dict.get("key", "")) == _selected_tree_key:
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
	var current_preview_key := "%s|%s|%s" % [_selected_tree_kind, _selected_tree_key, _selected_tool_name]
	var selection_changed := current_preview_key != _last_preview_key
	_last_preview_key = current_preview_key
	# Preserve scroll position when re-rendering without a selection change
	var saved_v_scroll := _tool_preview_text.get_v_scroll() if not selection_changed else 0
	_tool_preview_text.clear()
	_tool_preview_text.set_text(_build_preview_text())
	_tool_preview_text.set_v_scroll(saved_v_scroll)


func _build_preview_text() -> String:
	if _selected_tree_kind.is_empty() or _selected_tree_key.is_empty():
		return str(_localization.get_text("tool_preview_empty"))

	match _selected_tree_kind:
		"domain":
			return _build_domain_preview()
		"root":
			return _build_category_preview()
		"category":
			return _build_category_preview()
		"tool":
			return _build_tool_preview()
		"atomic":
			return _build_atomic_item_preview()
		"action":
			return _build_action_item_preview()
		_:
			return str(_localization.get_text("tool_preview_empty"))


func _build_domain_preview() -> String:
	var domain_def = _find_domain_definition(_selected_tree_key)
	if domain_def.is_empty():
		return str(_localization.get_text("tool_preview_empty"))

	var label_key = str(domain_def.get("label", "domain_other"))
	var categories: Array = domain_def.get("categories", [])
	var lines: Array[String] = [
		"%s: %s" % [_localization.get_text("tool_preview_domain"), _localization.get_text(label_key)],
		"",
		_get_group_tooltip(_localization, label_key),
		"",
		_localization.get_text("tool_preview_category_count") % categories.size()
	]
	for category in categories:
		if not _current_model.get("tools_by_category", {}).has(category):
			continue
		lines.append("- %s" % _get_category_label(_localization, str(category)))
	return "\n".join(_filter_empty_preview_lines(lines))


func _build_category_preview() -> String:
	var category = _selected_tree_key
	var tools: Array = _get_filtered_tool_definitions(_current_model, category)
	var lines: Array[String] = [
		"%s: %s" % [_localization.get_text("tool_preview_category"), _get_category_label(_localization, category)],
		"",
		_get_group_tooltip(_localization, _get_category_label_key(category)),
		"",
		_localization.get_text("tool_preview_tool_count") % _count_previewable_tools(tools)
	]
	for tool_def in tools:
		if bool(tool_def.get("compatibility_alias", false)):
			continue
		var tool_name = str(tool_def.get("name", ""))
		var full_name = "%s_%s" % [category, tool_name]
		lines.append("- %s" % _get_tool_display_name(_localization, full_name, tool_name))
	if category == "user":
		var watch_lines = _build_user_watch_preview_lines()
		if not watch_lines.is_empty():
			lines.append("")
			lines.append(_localization.get_text("tool_preview_watch_section"))
			lines.append_array(watch_lines)
	if category == "system":
		lines.append("")
		var hint_key = "tool_preview_system_category_hint"
		var hint_text = _localization.get_text(hint_key)
		lines.append(hint_text)
	return "\n".join(_filter_empty_preview_lines(lines))


func _build_tool_preview() -> String:
	var category = _selected_tool_category
	var tool_name = _selected_tool_name
	if category.is_empty() or tool_name.is_empty():
		return str(_localization.get_text("tool_preview_empty"))
	var tool_def = _find_tool_definition(category, tool_name)
	if tool_def.is_empty():
		return str(_localization.get_text("tool_preview_empty"))

	var display_name = _get_tool_display_name(_localization, _selected_tree_key, tool_name)
	var description = _get_tool_description(_localization, _selected_tree_key, tool_def)
	var lines: Array[String] = [
		"%s: %s" % [_localization.get_text("tool_preview_tool"), display_name],
		"%s: %s" % [_localization.get_text("tool_preview_tool_id"), _selected_tree_key],
		"%s: %s" % [_localization.get_text("tool_preview_category"), _get_category_label(_localization, category)],
		"",
		_localization.get_text("tool_preview_description"),
		description if not description.is_empty() else _localization.get_text("tool_preview_no_description")
	]

	var actions = _extract_action_values(tool_def)
	if not actions.is_empty():
		lines.append("")
		lines.append(_localization.get_text("tool_preview_actions"))
		for action_value in actions:
			lines.append("- %s" % _get_action_display_name(_selected_tree_key, action_value))

	lines.append("")
	lines.append(_localization.get_text("tool_preview_params"))
	var parameter_lines = _build_parameter_preview_lines(tool_def)
	if parameter_lines.is_empty():
		lines.append(_localization.get_text("tool_preview_no_params"))
	else:
		lines.append_array(parameter_lines)

	if category == "user":
		var runtime_lines = _build_user_runtime_preview_lines(tool_def)
		if not runtime_lines.is_empty():
			lines.append("")
			lines.append(_localization.get_text("tool_preview_runtime_section"))
			lines.append_array(runtime_lines)

	if category == "system":
		lines.append("")
		lines.append(_localization.get_text("tool_preview_atomic_tools"))
		var atomic_lines = _build_atomic_tool_preview_lines(_selected_tree_key, 0, {})
		if atomic_lines.is_empty():
			lines.append(_localization.get_text("tool_preview_no_atomic_tools"))
		else:
			lines.append_array(atomic_lines)
		lines.append("")
		var hint_key = "tool_preview_system_tool_hint"
		var hint_text = _localization.get_text(hint_key)
		lines.append(hint_text)

	return "\n".join(_filter_empty_preview_lines(lines))


func _build_user_runtime_preview_lines(tool_def: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var runtime_domain = str(tool_def.get("runtime_domain", ""))
	if not runtime_domain.is_empty():
		lines.append("%s: %s" % [_localization.get_text("tool_preview_runtime_domain"), runtime_domain])
	var runtime_version = int(tool_def.get("runtime_version", 0))
	if runtime_version > 0:
		lines.append("%s: %d" % [_localization.get_text("tool_preview_runtime_version"), runtime_version])
	var runtime_state = _get_user_runtime_state_label(str(tool_def.get("state", "")))
	if not runtime_state.is_empty():
		lines.append("%s: %s" % [_localization.get_text("tool_preview_runtime_state"), runtime_state])
	lines.append("%s: %s" % [
		_localization.get_text("tool_preview_pending_reload"),
		_localization.get_text("status_enabled") if bool(tool_def.get("pending_reload", false)) else _localization.get_text("status_disabled")
	])
	var discovery_source = _get_user_watch_source_label(str(tool_def.get("discovery_source", "")))
	if not discovery_source.is_empty():
		lines.append("%s: %s" % [_localization.get_text("tool_preview_discovery_source"), discovery_source])
	var last_refresh_reason = _get_user_watch_reason_label(str(tool_def.get("last_refresh_reason", "")))
	if not last_refresh_reason.is_empty():
		lines.append("%s: %s" % [_localization.get_text("tool_preview_last_refresh_reason"), last_refresh_reason])
	var script_path = str(tool_def.get("script_path", ""))
	if not script_path.is_empty():
		lines.append("%s: %s" % [_localization.get_text("tool_preview_script_path"), script_path])
	var last_error = str(tool_def.get("last_error", ""))
	if not last_error.is_empty():
		lines.append("%s: %s" % [_localization.get_text("tool_preview_last_error"), last_error])
	var raw_state = str(tool_def.get("state", ""))
	if raw_state == "reload_failed":
		lines.append(_localization.get_text("tool_preview_reload_failed_keeps_old_version"))
	elif raw_state == "waiting_quiesce":
		lines.append(_localization.get_text("tool_preview_waiting_quiesce"))
	return lines


func _build_user_watch_preview_lines() -> Array[String]:
	var lines: Array[String] = []
	var watch_status: Dictionary = _current_model.get("user_tool_watch", {})
	if not watch_status.is_empty():
		var watching = bool(watch_status.get("watching", false))
		lines.append("%s: %s" % [
			_localization.get_text("tool_preview_watch_status"),
			_localization.get_text("status_enabled") if watching else _localization.get_text("status_disabled")
		])
		lines.append("%s: %d" % [
			_localization.get_text("tool_preview_watch_known_scripts"),
			int(watch_status.get("known_script_count", 0))
		])
		var last_reason = _get_user_watch_reason_label(str(watch_status.get("last_change_reason", "")))
		if not last_reason.is_empty():
			lines.append("%s: %s" % [_localization.get_text("tool_preview_last_refresh_reason"), last_reason])
		var last_error = str(watch_status.get("last_error", ""))
		if not last_error.is_empty():
			lines.append("%s: %s" % [_localization.get_text("tool_preview_watch_last_error"), last_error])
	var invalid_tools: Array[String] = []
	for tool_info in _current_model.get("user_tools", []):
		if not (tool_info is Dictionary):
			continue
		var info := tool_info as Dictionary
		if bool(info.get("loadable", false)):
			continue
		var display_name = str(info.get("display_name", info.get("script_path", "")))
		var load_error = str(info.get("load_error", ""))
		invalid_tools.append("%s (%s)" % [display_name, load_error if not load_error.is_empty() else "invalid"])
	if not invalid_tools.is_empty():
		lines.append("%s: %d" % [_localization.get_text("tool_preview_watch_invalid_scripts"), invalid_tools.size()])
		for invalid_entry in invalid_tools:
			lines.append("- %s" % invalid_entry)
	return lines


func _get_user_runtime_state_label(state: String) -> String:
	if state.is_empty():
		return ""
	var key = "tool_preview_runtime_state_%s" % state
	var translated = _localization.get_text(key)
	if translated != key:
		return translated
	return _humanize_identifier(state)


func _get_user_watch_source_label(source: String) -> String:
	if source.is_empty():
		return ""
	var key = "tool_preview_discovery_source_%s" % source
	var translated = _localization.get_text(key)
	if translated != key:
		return translated
	return _humanize_identifier(source)


func _get_user_watch_reason_label(reason: String) -> String:
	if reason.is_empty():
		return ""
	var key = "tool_preview_watch_reason_%s" % reason
	var translated = _localization.get_text(key)
	if translated != key:
		return translated
	return _humanize_identifier(reason)


func _build_atomic_item_preview() -> String:
	var atomic_full_name = _selected_tree_key
	if atomic_full_name.is_empty():
		return str(_localization.get_text("tool_preview_empty"))
	var tool_def = _get_tool_def_by_full_name(_current_model, atomic_full_name)
	if tool_def.is_empty():
		return str(_localization.get_text("tool_preview_empty"))
	var category = _extract_category_from_full_name(_current_model, atomic_full_name)
	var tool_name = str(tool_def.get("name", ""))
	var display_name = _get_tool_display_name(_localization, atomic_full_name, tool_name)
	var description = _get_tool_description(_localization, atomic_full_name, tool_def)
	var actions = _extract_action_values(tool_def)
	var lines: Array[String] = [
		"%s: %s" % [_localization.get_text("tool_preview_tool"), display_name],
		"%s: %s" % [_localization.get_text("tool_preview_tool_id"), atomic_full_name],
		"%s: %s" % [_localization.get_text("tool_preview_category"), _get_category_label(_localization, category)],
		"",
		_localization.get_text("tool_preview_description"),
		description if not description.is_empty() else _localization.get_text("tool_preview_no_description"),
	]
	if not actions.is_empty():
		lines.append("")
		lines.append(_localization.get_text("tool_preview_actions"))
		for action_value in actions:
			lines.append("- %s" % _get_action_display_name(atomic_full_name, action_value))
	return "\n".join(_filter_empty_preview_lines(lines))


func _build_action_item_preview() -> String:
	var key = _selected_tree_key
	if key.is_empty():
		return str(_localization.get_text("tool_preview_empty"))
	var dot_idx = key.rfind(".")
	if dot_idx < 0:
		return str(_localization.get_text("tool_preview_empty"))
	var parent_tool: String = key.left(dot_idx)
	var action_name: String = key.substr(dot_idx + 1)
	var tool_def = _get_tool_def_by_full_name(_current_model, parent_tool)
	var category = _extract_category_from_full_name(_current_model, parent_tool)
	var tool_name = str(tool_def.get("name", "")) if not tool_def.is_empty() else parent_tool
	var display_name = _get_tool_display_name(_localization, parent_tool, tool_name) if not tool_def.is_empty() else parent_tool
	var lines: Array[String] = [
		"%s: %s" % [_localization.get_text("tool_action"), _get_action_display_name(parent_tool, action_name)],
		"%s: %s" % [_localization.get_text("tool_preview_action_id"), action_name],
		"%s: %s" % [_localization.get_text("tool_preview_parent_tool"), display_name],
		"%s: %s" % [_localization.get_text("tool_preview_category"), _get_category_label(_localization, category)],
		"",
		_localization.get_text("tool_preview_description"),
		_get_action_description(parent_tool, action_name, tool_def),
	]
	if not tool_def.is_empty():
		var param_lines = _build_action_parameter_lines(tool_def)
		if not param_lines.is_empty():
			lines.append("")
			lines.append(_localization.get_text("tool_preview_params"))
			lines.append_array(param_lines)
	return "\n".join(_filter_empty_preview_lines(lines))


func _build_action_parameter_lines(tool_def: Dictionary) -> Array[String]:
	var input_schema = tool_def.get("inputSchema", {})
	if not (input_schema is Dictionary):
		return []
	var properties = (input_schema as Dictionary).get("properties", {})
	if not (properties is Dictionary):
		return []
	var required_lookup: Dictionary = {}
	for required_name in (input_schema as Dictionary).get("required", []):
		required_lookup[str(required_name)] = true
	var property_names: Array = (properties as Dictionary).keys()
	property_names.sort()
	var lines: Array[String] = []
	for property_name in property_names:
		if property_name == "action":
			continue
		var property_def = (properties as Dictionary).get(property_name, {})
		if not (property_def is Dictionary):
			continue
		lines.append("- %s" % _format_parameter_summary(str(property_name), property_def as Dictionary, required_lookup))
	return lines


func _find_domain_definition(domain_key: String) -> Dictionary:
	for domain_def in _current_model.get("domain_defs", []):
		if str(domain_def.get("key", "")) == domain_key:
			return (domain_def as Dictionary).duplicate(true)
	if domain_key == "other":
		return {
			"key": "other",
			"label": "domain_other",
			"categories": []
		}
	return {}


func _find_tool_definition(category: String, tool_name: String) -> Dictionary:
	for tool_def in _current_model.get("tools_by_category", {}).get(category, []):
		if bool(tool_def.get("compatibility_alias", false)):
			continue
		if str(tool_def.get("name", "")) == tool_name:
			return (tool_def as Dictionary).duplicate(true)
	return {}


func _get_tool_def_by_full_name(model: Dictionary, full_name: String) -> Dictionary:
	var category = _extract_category_from_full_name(model, full_name)
	if category.is_empty():
		return {}
	var tool_name = full_name.trim_prefix("%s_" % category)
	for tool_def in model.get("tools_by_category", {}).get(category, []):
		if bool(tool_def.get("compatibility_alias", false)):
			continue
		if str(tool_def.get("name", "")) == tool_name:
			return (tool_def as Dictionary).duplicate(true)
	return {}


func _extract_category_from_full_name(model: Dictionary, full_name: String) -> String:
	for category in model.get("tools_by_category", {}).keys():
		var category_name = str(category)
		if full_name.begins_with("%s_" % category_name):
			return category_name
	return ""


func _build_atomic_tool_preview_lines(system_full_name: String, depth: int = 0, visited: Dictionary = {}) -> Array[String]:
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
		var atomic_tool_def = _get_tool_def_by_full_name(_current_model, atomic_full_name)
		if atomic_tool_def.is_empty():
			continue
		var category = _extract_category_from_full_name(_current_model, atomic_full_name)
		var tool_name = str(atomic_tool_def.get("name", ""))
		if category.is_empty() or tool_name.is_empty():
			continue
		var display_name = _get_tool_display_name(_localization, atomic_full_name, tool_name)
		var indent = "  ".repeat(depth)
		lines.append("%s- %s" % [indent, display_name])
		for action_name in actions:
			lines.append("%s  - %s" % [indent, _get_action_display_name(atomic_full_name, str(action_name))])
		if category == SYSTEM_CATEGORY:
			var next_visited = visited.duplicate()
			next_visited[atomic_full_name] = true
			lines.append_array(_build_atomic_tool_preview_lines(atomic_full_name, depth + 1, next_visited))
	return lines


func _extract_action_values(tool_def: Dictionary) -> Array[String]:
	var actions: Array[String] = []
	var input_schema = tool_def.get("inputSchema", {})
	if not (input_schema is Dictionary):
		return actions
	var properties = (input_schema as Dictionary).get("properties", {})
	if not (properties is Dictionary):
		return actions
	var action_definition = (properties as Dictionary).get("action", {})
	if not (action_definition is Dictionary):
		return actions
	for value in (action_definition as Dictionary).get("enum", []):
		actions.append(str(value))
	return actions


func _build_parameter_preview_lines(tool_def: Dictionary) -> Array[String]:
	var input_schema = tool_def.get("inputSchema", {})
	if not (input_schema is Dictionary):
		return []
	var properties = (input_schema as Dictionary).get("properties", {})
	if not (properties is Dictionary):
		return []

	var required_lookup: Dictionary = {}
	for required_name in (input_schema as Dictionary).get("required", []):
		required_lookup[str(required_name)] = true

	var property_names: Array = (properties as Dictionary).keys()
	property_names.sort()
	var lines: Array[String] = []
	for property_name in property_names:
		var property_def = (properties as Dictionary).get(property_name, {})
		if not (property_def is Dictionary):
			continue
		lines.append("- %s" % _format_parameter_summary(str(property_name), property_def as Dictionary, required_lookup))
	return lines


func _format_parameter_summary(property_name: String, property_def: Dictionary, required_lookup: Dictionary) -> String:
	var parts: Array[String] = [property_name]
	var type_name = str(property_def.get("type", "any"))
	parts.append(type_name)
	if required_lookup.has(property_name):
		parts.append(_localization.get_text("tool_preview_required"))
	if property_def.has("enum"):
		var values: Array[String] = []
		for value in property_def.get("enum", []):
			values.append(str(value))
		parts.append("enum=%s" % ", ".join(values))
	var description = str(property_def.get("description", ""))
	if not description.is_empty():
		parts.append(description)
	return " | ".join(parts)


func _count_previewable_tools(tools: Array) -> int:
	var count := 0
	for tool_def in tools:
		if bool(tool_def.get("compatibility_alias", false)):
			continue
		count += 1
	return count


func _filter_empty_preview_lines(lines: Array[String]) -> Array[String]:
	var filtered: Array[String] = []
	var previous_empty := false
	for line in lines:
		var text = str(line)
		if text.is_empty():
			if previous_empty:
				continue
			previous_empty = true
			filtered.append("")
			continue
		previous_empty = false
		filtered.append(text)
	return filtered


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
