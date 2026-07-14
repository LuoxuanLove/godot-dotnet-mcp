@tool
extends VBoxContainer

signal copy_requested(text: String, source: String)
signal preview_requested(kind: String, id: String, arguments: Dictionary)

const TREE_TEXT_COLUMN := 0
const TREE_TEXT_MIN_WIDTH := 180.0
const TREE_TEXT_MAX_WIDTH := 300.0
const TREE_HORIZONTAL_CHROME_WIDTH := 56.0
const MAX_PROTOCOL_ICON_SRC_LENGTH := 8192
const MAX_PROTOCOL_ICON_BASE64_LENGTH := 6144
const MAX_ICON_TEXTURE_CACHE_ENTRIES := 64
const KIND_RESOURCE := "resource"
const KIND_TEMPLATE := "template"
const KIND_PROMPT := "prompt"

const _CTX_COPY_LOCALIZED_NAME := 0
const _CTX_COPY_ENGLISH_ID := 1
const _CTX_PREVIEW := 2
const _CTX_CLEAR_ARGUMENTS := 3
const _CTX_COPY_PREVIEW := 4
const _CTX_EXPAND_ALL := 10
const _CTX_COLLAPSE_ALL := 11

@onready var _header_card: PanelContainer = %HeaderCard
@onready var _header_margin: MarginContainer = %HeaderMargin
@onready var _header_content: VBoxContainer = %HeaderContent
@onready var _header_counts: Label = %HeaderCounts
@onready var _content_split: VSplitContainer = %ContentSplit
@onready var _search_edit: LineEdit = %CatalogSearchEdit
@onready var _catalog_tree_panel: PanelContainer = %CatalogTreePanel
@onready var _catalog_tree: Tree = %CatalogTree
@onready var _preview_panel: PanelContainer = %PreviewPanel
@onready var _preview_margin: MarginContainer = %PreviewMargin
@onready var _preview_content: VBoxContainer = %PreviewContent
@onready var _preview_title: Label = %PreviewTitle
@onready var _argument_inputs: VBoxContainer = %ArgumentInputs
@onready var _preview_text: TextEdit = %PreviewText

var _current_scale := -1.0
var _current_signature := ""
var _current_model: Dictionary = {}
var _localization = null
var _catalog_mode := "resources"
var _argument_values: Dictionary = {}
var _template_argument_values: Dictionary = {}
var _icon_texture_cache: Dictionary = {}
var _icon_texture_cache_order: Array[String] = []
var _selected_kind := ""
var _selected_id := ""
var _selected_entry: Dictionary = {}
var _tree_syncing := false
var _last_preview: Dictionary = {}
var _context_menu: PopupMenu = null
var _context_menu_metadata: Dictionary = {}
var _context_menu_target: TreeItem = null


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_search_edit.text_changed.connect(_on_search_text_changed)
	_catalog_tree.item_selected.connect(_on_tree_item_selected)
	_catalog_tree.gui_input.connect(_on_tree_gui_input)
	_catalog_tree.set_allow_reselect(true)
	_catalog_tree.theme_type_variation = "TreeSecondary"
	_preview_text.editable = false
	_preview_text.selecting_enabled = true
	_preview_text.context_menu_enabled = true
	_preview_text.set_line_wrapping_mode(TextEdit.LINE_WRAPPING_BOUNDARY)
	_preview_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_context_menu = PopupMenu.new()
	add_child(_context_menu)
	_context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	resized.connect(_on_resized)
	_show_empty_preview()


func set_catalog_mode(mode: String) -> void:
	_catalog_mode = mode if mode in ["resources", "prompts"] else "resources"
	_selected_kind = ""
	_selected_id = ""
	_selected_entry.clear()
	_current_signature = ""


func apply_model(model: Dictionary) -> void:
	_localization = model.get("localization")
	_current_model = model
	_last_preview = model.get("mcp_catalog_preview", {}) if model.get("mcp_catalog_preview", {}) is Dictionary else {}
	var editor_scale := float(model.get("editor_scale", 1.0))
	if not is_equal_approx(_current_scale, editor_scale):
		_apply_editor_scale(editor_scale)
	else:
		_apply_responsive_layout()
	_apply_localized_copy(model)
	var signature := _build_signature(model)
	if signature != _current_signature:
		_current_signature = signature
		_render_tree(model)
	_sync_detail_panel()


func _apply_localized_copy(model: Dictionary) -> void:
	if _localization == null:
		return
	var counts: Dictionary = model.get("mcp_catalog_counts", {})
	if _catalog_mode == "prompts":
		_header_counts.text = _localization.get_text("mcp_prompts_counts") % int(counts.get("prompts", 0))
		_search_edit.placeholder_text = _localization.get_text("mcp_catalog_search_prompts")
	else:
		_header_counts.text = _localization.get_text("mcp_resources_counts") % [
			int(counts.get("resources", 0)),
			int(counts.get("resource_templates", 0))
		]
		_search_edit.placeholder_text = _localization.get_text("mcp_catalog_search_resources")


func _on_search_text_changed(_value: String) -> void:
	_current_signature = ""
	if not _current_model.is_empty():
		_render_tree(_current_model)
		_sync_detail_panel()


func _render_tree(model: Dictionary) -> void:
	_tree_syncing = true
	_catalog_tree.clear()
	_catalog_tree.set_column_clip_content(TREE_TEXT_COLUMN, true)
	var root := _catalog_tree.create_item()
	var entries_rendered := 0
	for group in _active_groups(model):
		if not (group is Dictionary):
			continue
		var visible_children: Array[Dictionary] = []
		for raw_child in (group as Dictionary).get("children", []):
			if not (raw_child is Dictionary):
				continue
			var entry := _entry_from_presentation_node(raw_child as Dictionary)
			var kind := _entry_kind_from_presentation_node(raw_child as Dictionary)
			if entry.is_empty() or not _presentation_entry_visible_for_search(raw_child as Dictionary, entry, kind):
				continue
			visible_children.append({
				"node": raw_child,
				"entry": entry,
				"kind": kind
			})
		if visible_children.is_empty():
			continue
		entries_rendered += visible_children.size()
		var group_item := _catalog_tree.create_item(root)
		_configure_group_item(group_item, group as Dictionary, visible_children.size())
		for visible in visible_children:
			_create_entry_item(group_item, (visible.get("entry", {}) as Dictionary), str(visible.get("kind", "")), visible.get("node", {}) as Dictionary)
	if entries_rendered == 0:
		_create_empty_item(root)
	_tree_syncing = false
	_restore_or_select_first_entry()


func _active_groups(model: Dictionary) -> Array:
	if _catalog_mode == "prompts":
		var prompt_presentation = model.get("mcp_prompt_presentation", {})
		if prompt_presentation is Dictionary:
			var prompt_groups = (prompt_presentation as Dictionary).get("promptTree", [])
			if prompt_groups is Array:
				return prompt_groups as Array
		return _fallback_prompt_groups(model)
	var resource_presentation = model.get("mcp_resource_presentation", {})
	if resource_presentation is Dictionary:
		var resource_groups = (resource_presentation as Dictionary).get("resourceTree", [])
		if resource_groups is Array:
			return resource_groups as Array
	return _fallback_resource_groups(model)


func _fallback_resource_groups(model: Dictionary) -> Array:
	return [{
		"id": "resources",
		"label": _text("mcp_catalog_resources"),
		"label_key": "mcp_catalog_resources",
		"kind": "resource_group",
		"children": _raw_entries_to_nodes(model.get("mcp_resources", []), "resource_entry")
	}, {
		"id": "resource_templates",
		"label": _text("mcp_catalog_resource_templates"),
		"label_key": "mcp_catalog_resource_templates",
		"kind": "resource_group",
		"children": _raw_entries_to_nodes(model.get("mcp_resource_templates", []), "resource_template")
	}]


func _fallback_prompt_groups(model: Dictionary) -> Array:
	return [{
		"id": "prompts",
		"label": _text("mcp_catalog_prompts"),
		"label_key": "mcp_catalog_prompts",
		"kind": "prompt_group",
		"children": _raw_entries_to_nodes(model.get("mcp_prompts", []), "prompt_entry")
	}]


func _raw_entries_to_nodes(entries, kind: String) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	if not (entries is Array):
		return nodes
	for entry in entries as Array:
		if not (entry is Dictionary):
			continue
		nodes.append({
			"id": _entry_id(entry as Dictionary, KIND_PROMPT if kind == "prompt_entry" else (KIND_TEMPLATE if kind == "resource_template" else KIND_RESOURCE)),
			"kind": kind,
			"visibility": "public",
			"callability": "not_callable",
			"source": "prompts/list" if kind == "prompt_entry" else ("resources/templates/list" if kind == "resource_template" else "resources/list"),
			"entry": (entry as Dictionary).duplicate(true),
			"children": []
		})
	return nodes


func _configure_group_item(item: TreeItem, group: Dictionary, visible_count: int) -> void:
	var label := _group_label(group)
	item.set_text(TREE_TEXT_COLUMN, "%s    %d" % [label, visible_count])
	item.set_selectable(TREE_TEXT_COLUMN, false)
	item.set_metadata(TREE_TEXT_COLUMN, {
		"kind": "group",
		"id": str(group.get("id", "")),
		"group": group.duplicate(true)
	})
	item.collapsed = false if not _get_search_query().is_empty() else false
	item.set_tooltip_text(TREE_TEXT_COLUMN, label)


func _create_entry_item(parent: TreeItem, entry: Dictionary, entry_kind: String, node: Dictionary) -> TreeItem:
	var item := _catalog_tree.create_item(parent)
	var id := _entry_id(entry, entry_kind)
	var title := _entry_title(entry, entry_kind)
	item.set_text(TREE_TEXT_COLUMN, title)
	item.set_tooltip_text(TREE_TEXT_COLUMN, _entry_tooltip(entry, entry_kind))
	item.set_metadata(TREE_TEXT_COLUMN, {
		"kind": entry_kind,
		"id": id,
		"entry": entry.duplicate(true),
		"node": node.duplicate(true)
	})
	if _selected_kind == entry_kind and _selected_id == id:
		item.select(TREE_TEXT_COLUMN)
	for raw_child in _safe_array(node.get("children", [])):
		if raw_child is Dictionary:
			_create_info_node_item(item, raw_child as Dictionary)
	return item


func _create_info_node_item(parent: TreeItem, node: Dictionary) -> TreeItem:
	var item := _catalog_tree.create_item(parent)
	var label := _presentation_node_label(node)
	item.set_text(TREE_TEXT_COLUMN, label)
	item.set_selectable(TREE_TEXT_COLUMN, false)
	item.set_metadata(TREE_TEXT_COLUMN, {
		"kind": str(node.get("kind", "info")),
		"id": str(node.get("id", "")),
		"node": node.duplicate(true)
	})
	item.set_custom_color(TREE_TEXT_COLUMN, _get_hint_text_color())
	item.set_tooltip_text(TREE_TEXT_COLUMN, _presentation_node_tooltip(node))
	for raw_child in _safe_array(node.get("children", [])):
		if raw_child is Dictionary:
			_create_info_node_item(item, raw_child as Dictionary)
	return item


func _create_empty_item(root: TreeItem) -> void:
	var item := _catalog_tree.create_item(root)
	item.set_text(TREE_TEXT_COLUMN, _text("mcp_catalog_empty"))
	item.set_selectable(TREE_TEXT_COLUMN, false)
	item.set_custom_color(TREE_TEXT_COLUMN, _get_hint_text_color())


func _restore_or_select_first_entry() -> void:
	var selected := _catalog_tree.get_selected()
	if selected != null and _is_entry_item(selected):
		_apply_selection_from_item(selected)
		return
	var first := _find_first_entry_item()
	if first != null:
		first.select(TREE_TEXT_COLUMN)
		_apply_selection_from_item(first)
		return
	_selected_kind = ""
	_selected_id = ""
	_selected_entry.clear()


func _find_first_entry_item() -> TreeItem:
	var root := _catalog_tree.get_root()
	if root == null:
		return null
	return _find_first_entry_item_recursive(root)


func _find_first_entry_item_recursive(item: TreeItem) -> TreeItem:
	if item == null:
		return null
	if _is_entry_item(item):
		return item
	var child := item.get_first_child()
	while child != null:
		var found := _find_first_entry_item_recursive(child)
		if found != null:
			return found
		child = child.get_next()
	return null


func _is_entry_item(item: TreeItem) -> bool:
	var metadata = item.get_metadata(TREE_TEXT_COLUMN)
	return metadata is Dictionary and [KIND_RESOURCE, KIND_TEMPLATE, KIND_PROMPT].has(str((metadata as Dictionary).get("kind", "")))


func _on_tree_item_selected() -> void:
	if _tree_syncing:
		return
	var item := _catalog_tree.get_selected()
	if item == null or not _is_entry_item(item):
		return
	_apply_selection_from_item(item)
	_sync_detail_panel()


func _apply_selection_from_item(item: TreeItem) -> void:
	var metadata := item.get_metadata(TREE_TEXT_COLUMN) as Dictionary
	_selected_kind = str(metadata.get("kind", ""))
	_selected_id = str(metadata.get("id", ""))
	_selected_entry = (metadata.get("entry", {}) as Dictionary).duplicate(true)


func _on_tree_gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_SPACE:
			var selected := _catalog_tree.get_selected()
			if selected != null and selected.get_child_count() > 0:
				selected.collapsed = not selected.collapsed
				get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		var item := _catalog_tree.get_item_at_position(mouse_event.position)
		if item != null:
			_show_tree_context_menu(item, _get_tree_context_menu_screen_position(mouse_event.position))
			get_viewport().set_input_as_handled()
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.shift_pressed:
		return
	var item := _catalog_tree.get_item_at_position(mouse_event.position)
	if item != null and item.get_child_count() > 0:
		var want_collapsed := not item.collapsed
		_tree_syncing = true
		_set_subtree_collapsed(item, want_collapsed)
		_tree_syncing = false
		get_viewport().set_input_as_handled()


func _show_tree_context_menu(item: TreeItem, screen_position: Vector2) -> Rect2i:
	var metadata = item.get_metadata(TREE_TEXT_COLUMN)
	if not (metadata is Dictionary):
		return Rect2i()
	var meta := metadata as Dictionary
	_context_menu_metadata = meta
	_context_menu_target = item
	if _is_entry_item(item):
		_apply_selection_from_item(item)
		_catalog_tree.set_selected(item, TREE_TEXT_COLUMN)
		_sync_detail_panel()
	_context_menu.clear()
	var has_children := item.get_child_count() > 0
	_add_context_menu_item(_text("tool_ctx_copy_localized_name"), _CTX_COPY_LOCALIZED_NAME)
	_add_context_menu_item(_text("tool_ctx_copy_english_id"), _CTX_COPY_ENGLISH_ID)
	_context_menu.add_separator()
	_add_context_menu_item(_text("btn_expand_all"), _CTX_EXPAND_ALL, not has_children)
	_add_context_menu_item(_text("btn_collapse_all"), _CTX_COLLAPSE_ALL, not has_children)
	if _is_entry_metadata(meta):
		_context_menu.add_separator()
		_add_context_menu_item(_text("mcp_catalog_preview"), _CTX_PREVIEW, str(meta.get("id", "")).is_empty())
		_add_context_menu_item(_text("mcp_catalog_clear_arguments"), _CTX_CLEAR_ARGUMENTS, not _has_argument_controls_for_selection() or not _has_any_arguments_for_selection())
		_add_context_menu_item(_text("mcp_catalog_copy_preview"), _CTX_COPY_PREVIEW, _preview_body_text(_current_preview_for_selection()).strip_edges().is_empty())
	var popup_rect := _get_tree_context_menu_popup_rect(screen_position)
	_context_menu.popup(popup_rect)
	return popup_rect


func _get_tree_context_menu_screen_position(local_position: Vector2) -> Vector2:
	return _catalog_tree.get_screen_transform() * local_position


func _get_tree_context_menu_popup_rect(screen_position: Vector2) -> Rect2i:
	return Rect2i(int(screen_position.x), int(screen_position.y), 0, 0)


func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		_CTX_COPY_LOCALIZED_NAME:
			copy_requested.emit(_get_context_menu_localized_name(), _get_context_menu_localized_name())
		_CTX_COPY_ENGLISH_ID:
			copy_requested.emit(_get_context_menu_english_id(), _get_context_menu_localized_name())
		_CTX_PREVIEW:
			_emit_preview_for_selection()
		_CTX_CLEAR_ARGUMENTS:
			_clear_arguments_for_selection()
		_CTX_COPY_PREVIEW:
			_copy_preview_for_selection()
		_CTX_EXPAND_ALL:
			if is_instance_valid(_context_menu_target):
				_tree_syncing = true
				_set_subtree_collapsed(_context_menu_target, false)
				_tree_syncing = false
		_CTX_COLLAPSE_ALL:
			if is_instance_valid(_context_menu_target):
				_tree_syncing = true
				_set_subtree_collapsed(_context_menu_target, true)
				_tree_syncing = false


func _add_context_menu_item(label: String, id: int, disabled: bool = false) -> void:
	var index := _context_menu.get_item_count()
	_context_menu.add_item(label, id)
	_context_menu.set_item_disabled(index, disabled)


func _set_subtree_collapsed(item: TreeItem, collapsed: bool) -> void:
	item.collapsed = collapsed
	var child := item.get_first_child()
	while child != null:
		_set_subtree_collapsed(child, collapsed)
		child = child.get_next()


func _is_entry_metadata(metadata: Dictionary) -> bool:
	return [KIND_RESOURCE, KIND_TEMPLATE, KIND_PROMPT].has(str(metadata.get("kind", "")))


func _get_context_menu_localized_name() -> String:
	var entry := _context_menu_entry()
	if not entry.is_empty():
		return _entry_title(entry, str(_context_menu_metadata.get("kind", "")))
	var group = _context_menu_metadata.get("group", {})
	if group is Dictionary:
		return _group_label(group as Dictionary)
	var node = _context_menu_metadata.get("node", {})
	if node is Dictionary:
		return _presentation_node_label(node as Dictionary)
	return str(_context_menu_metadata.get("id", ""))


func _get_context_menu_english_id() -> String:
	return str(_context_menu_metadata.get("id", ""))


func _context_menu_entry() -> Dictionary:
	var entry = _context_menu_metadata.get("entry", {})
	if entry is Dictionary:
		return (entry as Dictionary).duplicate(true)
	return {}


func _has_argument_controls_for_selection() -> bool:
	return _selected_kind == KIND_PROMPT or _selected_kind == KIND_TEMPLATE


func _emit_preview_for_selection() -> void:
	if _selected_id.is_empty():
		return
	preview_requested.emit(_selected_kind, _selected_id, _selection_argument_values())


func _clear_arguments_for_selection() -> void:
	_store_selection_argument_values({})
	_sync_detail_panel()


func _copy_preview_for_selection() -> void:
	var preview := _current_preview_for_selection()
	var text := _preview_body_text(preview)
	if text.strip_edges().is_empty():
		return
	copy_requested.emit(text, "%s %s" % [_entry_title(_selected_entry, _selected_kind), _text("mcp_catalog_preview_title")])


func _sync_detail_panel() -> void:
	if _selected_entry.is_empty() or _selected_kind.is_empty():
		_show_empty_preview()
		return
	_preview_title.text = _entry_title(_selected_entry, _selected_kind)
	_rebuild_argument_inputs()
	var preview := _current_preview_for_selection()
	_preview_text.text = _build_detail_text(preview)


func _show_empty_preview() -> void:
	if _preview_title != null:
		_preview_title.text = _text("mcp_catalog_select_entry")
	if _argument_inputs != null:
		_clear_children(_argument_inputs)
	if _preview_text != null:
		_preview_text.text = _text("mcp_catalog_select_entry_hint")


func _rebuild_argument_inputs() -> void:
	_clear_children(_argument_inputs)
	if _selected_kind == KIND_PROMPT:
		_add_prompt_argument_inputs()
	elif _selected_kind == KIND_TEMPLATE:
		_add_template_argument_inputs()


func _add_prompt_argument_inputs() -> void:
	var arguments = _selected_entry.get("arguments", [])
	if not (arguments is Array) or (arguments as Array).is_empty():
		return
	var values := _selection_argument_values()
	for raw_arg in arguments as Array:
		if not (raw_arg is Dictionary):
			continue
		var arg := raw_arg as Dictionary
		var name := str(arg.get("name", "")).strip_edges()
		if name.is_empty():
			continue
		_add_argument_row(name, str(arg.get("description", _text("mcp_catalog_argument_placeholder"))), bool(arg.get("required", false)), str(values.get(name, "")))


func _add_template_argument_inputs() -> void:
	var placeholders := _template_placeholders(_selected_id)
	var values := _selection_argument_values()
	for name in placeholders:
		_add_argument_row(name, _text("mcp_catalog_template_argument_placeholder") % name, true, str(values.get(name, "")))


func _add_argument_row(argument_name: String, description: String, required: bool, value: String) -> void:
	var row := HBoxContainer.new()
	row.name = "Arg_%s" % argument_name
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", int(round(6 * _scale())))
	_argument_inputs.add_child(row)

	var label := Label.new()
	label.name = "ArgumentLabel"
	label.text = "%s%s" % [argument_name, " *" if required else ""]
	label.custom_minimum_size.x = 94.0 * _scale()
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = description
	row.add_child(label)

	var input := LineEdit.new()
	input.name = "ArgumentInput_%s" % argument_name
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.placeholder_text = description
	input.text = value
	input.text_changed.connect(func(new_value: String) -> void:
		var values := _selection_argument_values()
		values[argument_name] = new_value
		_store_selection_argument_values(values)
		_refresh_argument_dependent_detail()
	)
	row.add_child(input)


func _refresh_argument_dependent_detail() -> void:
	_preview_text.text = _build_detail_text({})


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _on_copy_id_pressed() -> void:
	if _selected_id.is_empty():
		return
	copy_requested.emit(_selected_id, _entry_title(_selected_entry, _selected_kind))


func _on_preview_pressed() -> void:
	_emit_preview_for_selection()


func _on_clear_arguments_pressed() -> void:
	_clear_arguments_for_selection()


func _on_copy_preview_pressed() -> void:
	_copy_preview_for_selection()


func _build_detail_text(preview: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append(_entry_title(_selected_entry, _selected_kind))
	lines.append(_selected_id)
	var description := str(_selected_entry.get("description", "")).strip_edges()
	if not description.is_empty():
		lines.append("")
		lines.append(description)
	lines.append("")
	lines.append(_entry_meta(_selected_entry, _selected_kind))
	if _selected_kind == KIND_TEMPLATE:
		var resolved_uri := _resolved_template_uri()
		lines.append("")
		lines.append("%s: %s" % [_text("mcp_catalog_resolved_uri"), resolved_uri if not resolved_uri.is_empty() else _text("mcp_catalog_template_missing_arguments")])
	if not preview.is_empty():
		lines.append("")
		lines.append(_text("mcp_catalog_preview_title"))
		if bool(preview.get("success", false)):
			lines.append(_preview_body_text(preview))
		else:
			lines.append(_text("mcp_catalog_preview_error") % str(preview.get("error", "")))
	return _filter_detail_lines(lines)


func _filter_detail_lines(lines: Array[String]) -> String:
	var filtered: Array[String] = []
	var previous_empty := false
	for line in lines:
		var text := str(line)
		if text.is_empty():
			if previous_empty:
				continue
			previous_empty = true
			filtered.append("")
			continue
		previous_empty = false
		filtered.append(text)
	return "\n".join(filtered)


func _protocol_metadata_lines(entry: Dictionary, entry_kind: String) -> Array[String]:
	var lines: Array[String] = []
	lines.append("%s: %s" % [_text("mcp_catalog_kind"), _diagnostic_kind(entry, entry_kind)])
	lines.append("%s: %s" % [_text("mcp_catalog_source"), str(entry.get("_presentation_source", ""))])
	lines.append("%s: %s" % [_text("mcp_catalog_visibility"), str(entry.get("_presentation_visibility", ""))])
	lines.append("%s: %s" % [_text("mcp_catalog_callability"), str(entry.get("_presentation_callability", ""))])
	lines.append("%s: %s" % [_text("mcp_catalog_group"), _entry_group(entry, entry_kind)])
	lines.append("%s: %s" % [_text("mcp_catalog_icon_status"), _entry_icon_status(entry)])
	lines.append("%s: %s" % [_text("mcp_catalog_preview_status"), _entry_preview_status(entry_kind)])
	var metadata = entry.get("_presentation_metadata", {})
	if metadata is Dictionary and not (metadata as Dictionary).is_empty():
		var metadata_summary := _summarize_presentation_metadata(metadata as Dictionary)
		if not metadata_summary.is_empty():
			lines.append("%s: %s" % [_text("mcp_catalog_metadata"), metadata_summary])
	return lines


func _summarize_presentation_metadata(metadata: Dictionary) -> String:
	var visible_metadata := metadata.duplicate(true)
	visible_metadata.erase("icons")
	if visible_metadata.is_empty():
		return ""
	return JSON.stringify(visible_metadata)


func _entry_visible_for_search(entry: Dictionary, entry_kind: String) -> bool:
	var query := _get_search_query()
	if query.is_empty():
		return true
	var searchable: Array[String] = [
		_entry_title(entry, entry_kind),
		_entry_id(entry, entry_kind),
		str(entry.get("description", "")),
		str(entry.get("mimeType", "")),
		str(entry.get("resource_kind", "")),
		str(entry.get("prompt_kind", "")),
		str(entry.get("_presentation_source", "")),
		str(entry.get("_presentation_group", ""))
	]
	for arg in entry.get("arguments", []):
		if arg is Dictionary:
			searchable.append(str((arg as Dictionary).get("name", "")))
			searchable.append(str((arg as Dictionary).get("description", "")))
	for text in searchable:
		if str(text).to_lower().contains(query):
			return true
	return false


func _presentation_entry_visible_for_search(node: Dictionary, entry: Dictionary, entry_kind: String) -> bool:
	if _entry_visible_for_search(entry, entry_kind):
		return true
	var query := _get_search_query()
	if query.is_empty():
		return true
	return _presentation_node_visible_for_search(node, query)


func _presentation_node_visible_for_search(node: Dictionary, query: String) -> bool:
	if query.is_empty():
		return true
	if _presentation_node_matches_search(node, query):
		return true
	for child in _safe_array(node.get("children", [])):
		if child is Dictionary and _presentation_node_visible_for_search(child as Dictionary, query):
			return true
	return false


func _presentation_node_matches_search(node: Dictionary, query: String) -> bool:
	var searchable: Array[String] = [
		_presentation_node_label(node),
		str(node.get("id", "")),
		str(node.get("kind", "")),
		str(node.get("source", "")),
		str(node.get("visibility", "")),
		str(node.get("callability", ""))
	]
	var metadata = node.get("metadata", {})
	if metadata is Dictionary:
		for key in (metadata as Dictionary).keys():
			searchable.append(str(key))
			searchable.append(str((metadata as Dictionary).get(key, "")))
	for text in searchable:
		if str(text).to_lower().contains(query):
			return true
	return false


func _presentation_node_label(node: Dictionary) -> String:
	var label := str(node.get("label", "")).strip_edges()
	if not label.is_empty():
		return label
	var metadata = node.get("metadata", {})
	if metadata is Dictionary:
		var name := str((metadata as Dictionary).get("name", "")).strip_edges()
		if not name.is_empty():
			return name
	return str(node.get("id", ""))


func _presentation_node_tooltip(node: Dictionary) -> String:
	var parts: Array[String] = [_presentation_node_label(node), str(node.get("id", ""))]
	var metadata = node.get("metadata", {})
	if metadata is Dictionary:
		var description := str((metadata as Dictionary).get("description", "")).strip_edges()
		if not description.is_empty():
			parts.append(description)
	return "\n".join(parts)


func _get_search_query() -> String:
	return _search_edit.text.strip_edges().to_lower() if _search_edit != null else ""


func _entry_from_presentation_node(node: Dictionary) -> Dictionary:
	var entry = node.get("entry", {})
	if entry is Dictionary:
		var result := (entry as Dictionary).duplicate(true)
		result["_presentation_kind"] = str(node.get("kind", ""))
		result["_presentation_visibility"] = str(node.get("visibility", ""))
		result["_presentation_callability"] = str(node.get("callability", ""))
		result["_presentation_source"] = str(node.get("source", ""))
		result["_presentation_group"] = str(node.get("resource_group", node.get("prompt_kind", "")))
		result["_presentation_child_count"] = (node.get("children", []) as Array).size()
		result["_presentation_metadata"] = node.get("metadata", {})
		return result
	return {}


func _entry_kind_from_presentation_node(node: Dictionary) -> String:
	match str(node.get("kind", "")):
		"resource_template":
			return KIND_TEMPLATE
		"resource_entry":
			return KIND_RESOURCE
		"prompt_entry":
			return KIND_PROMPT
		_:
			if _catalog_mode == "prompts":
				return KIND_PROMPT
			return KIND_RESOURCE


func _group_label(group: Dictionary) -> String:
	var label_key := str(group.get("label_key", "")).strip_edges()
	if _localization != null and not label_key.is_empty():
		var localized := str(_localization.get_text(label_key))
		if not localized.is_empty() and localized != label_key:
			return localized
	return str(group.get("label", group.get("id", "")))


func _entry_id(entry: Dictionary, entry_kind: String) -> String:
	if entry_kind == KIND_PROMPT:
		return str(entry.get("name", ""))
	var uri_template := str(entry.get("uriTemplate", "")).strip_edges()
	if not uri_template.is_empty():
		return uri_template
	return str(entry.get("uri", ""))


func _entry_title(entry: Dictionary, entry_kind: String) -> String:
	var fallback := _entry_id(entry, entry_kind)
	return str(entry.get("title", entry.get("name", fallback)))


func _entry_tooltip(entry: Dictionary, entry_kind: String) -> String:
	var parts: Array[String] = [_entry_title(entry, entry_kind), _entry_id(entry, entry_kind)]
	var description := str(entry.get("description", "")).strip_edges()
	if not description.is_empty():
		parts.append(description)
	return "\n".join(parts)


func _entry_meta(entry: Dictionary, entry_kind: String) -> String:
	var lines := _protocol_metadata_lines(entry, entry_kind)
	if entry_kind == KIND_PROMPT:
		var args: Array[String] = []
		for arg in entry.get("arguments", []):
			if arg is Dictionary:
				args.append(str((arg as Dictionary).get("name", "")))
		if not args.is_empty():
			lines.append("%s: %s" % [_text("mcp_catalog_arguments"), ", ".join(args)])
	else:
		lines.append("%s: %s" % [_text("mcp_catalog_mime_type"), str(entry.get("mimeType", ""))])
	return " | ".join(lines)


func _diagnostic_kind(entry: Dictionary, entry_kind: String) -> String:
	var presentation_kind := str(entry.get("_presentation_kind", "")).strip_edges()
	if not presentation_kind.is_empty():
		return presentation_kind
	if entry_kind == KIND_PROMPT:
		return str(entry.get("prompt_kind", "prompt"))
	return str(entry.get("resource_kind", entry_kind))


func _entry_group(entry: Dictionary, entry_kind: String) -> String:
	if entry_kind == KIND_PROMPT:
		return str(entry.get("prompt_kind", entry.get("_presentation_group", "")))
	return str(entry.get("resource_group", entry.get("_presentation_group", "")))


func _entry_icon_src(entry: Dictionary) -> String:
	var icons = entry.get("icons", [])
	if not (icons is Array):
		return ""
	for raw_icon in icons as Array:
		if not (raw_icon is Dictionary):
			continue
		var src := str((raw_icon as Dictionary).get("src", "")).strip_edges()
		if not src.is_empty():
			return src
	return ""


func _entry_icon_status(entry: Dictionary) -> String:
	var src := _entry_icon_src(entry)
	if src.is_empty():
		return _text("mcp_catalog_icon_missing")
	if src.length() > MAX_PROTOCOL_ICON_SRC_LENGTH:
		return _text("mcp_catalog_icon_rejected")
	return _text("mcp_catalog_icon_available") if _texture_from_icon_src(src) != null else _text("mcp_catalog_icon_rejected")


func _entry_preview_status(entry_kind: String) -> String:
	if entry_kind == KIND_TEMPLATE and not _has_required_preview_arguments():
		return _text("mcp_catalog_template_missing_arguments")
	return _text("mcp_catalog_preview_available")


func _texture_from_icon_src(src: String) -> Texture2D:
	if src.is_empty() or src.length() > MAX_PROTOCOL_ICON_SRC_LENGTH:
		return null
	if _icon_texture_cache.has(src):
		_touch_icon_texture_cache_key(src)
		return _icon_texture_cache.get(src)
	var texture: Texture2D = null
	var svg_prefix := "data:image/svg+xml;base64,"
	if src.begins_with(svg_prefix):
		var encoded := src.substr(svg_prefix.length())
		if encoded.length() <= MAX_PROTOCOL_ICON_BASE64_LENGTH:
			var bytes := Marshalls.base64_to_raw(encoded)
			if not bytes.is_empty():
				var svg_text := bytes.get_string_from_utf8().strip_edges()
				if svg_text.begins_with("<svg"):
					var image := Image.new()
					if image.load_svg_from_buffer(bytes) == OK:
						texture = ImageTexture.create_from_image(image)
	if texture != null:
		_store_icon_texture(src, texture)
	return texture


func _store_icon_texture(src: String, texture: Texture2D) -> void:
	_icon_texture_cache[src] = texture
	_touch_icon_texture_cache_key(src)
	while _icon_texture_cache_order.size() > MAX_ICON_TEXTURE_CACHE_ENTRIES:
		var evicted_src := _icon_texture_cache_order.pop_front()
		_icon_texture_cache.erase(evicted_src)


func _touch_icon_texture_cache_key(src: String) -> void:
	var existing_index := _icon_texture_cache_order.find(src)
	if existing_index >= 0:
		_icon_texture_cache_order.remove_at(existing_index)
	_icon_texture_cache_order.append(src)


func _selection_argument_values() -> Dictionary:
	if _selected_kind == KIND_PROMPT:
		return (_argument_values.get(_selected_id, {}) as Dictionary).duplicate(true)
	if _selected_kind == KIND_TEMPLATE:
		return (_template_argument_values.get(_selected_id, {}) as Dictionary).duplicate(true)
	return {}


func _store_selection_argument_values(values: Dictionary) -> void:
	if _selected_kind == KIND_PROMPT:
		_argument_values[_selected_id] = values.duplicate(true)
	elif _selected_kind == KIND_TEMPLATE:
		_template_argument_values[_selected_id] = values.duplicate(true)
	_current_signature = ""


func _has_any_arguments_for_selection() -> bool:
	for value in _selection_argument_values().values():
		if not str(value).strip_edges().is_empty():
			return true
	return false


func _preview_requires_arguments() -> bool:
	return _selected_kind == KIND_TEMPLATE and not _template_placeholders(_selected_id).is_empty()


func _has_required_preview_arguments() -> bool:
	if _selected_kind != KIND_TEMPLATE:
		return true
	var values := _selection_argument_values()
	for placeholder in _template_placeholders(_selected_id):
		if str(values.get(placeholder, "")).strip_edges().is_empty():
			return false
	return true


func _template_placeholders(template: String) -> Array[String]:
	var placeholders: Array[String] = []
	var search_from := 0
	while true:
		var start := template.find("{", search_from)
		if start == -1:
			break
		var end := template.find("}", start + 1)
		if end == -1:
			break
		var name := template.substr(start + 1, end - start - 1).strip_edges()
		if not name.is_empty() and not placeholders.has(name):
			placeholders.append(name)
		search_from = end + 1
	return placeholders


func _resolved_template_uri() -> String:
	if _selected_kind != KIND_TEMPLATE:
		return ""
	var uri := _selected_id
	var values := _selection_argument_values()
	for placeholder in _template_placeholders(uri):
		var value := str(values.get(placeholder, "")).strip_edges()
		if value.is_empty():
			return ""
		uri = uri.replace("{%s}" % placeholder, value)
	return uri


func _current_preview_for_selection() -> Dictionary:
	if _last_preview.is_empty():
		return {}
	var preview_kind := str(_last_preview.get("kind", ""))
	if preview_kind != _selected_kind:
		return {}
	if str(_last_preview.get("id", "")) != _selected_id:
		return {}
	if _selected_kind in [KIND_PROMPT, KIND_TEMPLATE]:
		var expected := _normalize_arguments(_selection_argument_values())
		var actual = _last_preview.get("arguments", {})
		if not (actual is Dictionary) or _normalize_arguments(actual as Dictionary) != expected:
			return {}
	return _last_preview


func _normalize_arguments(arguments: Dictionary) -> Dictionary:
	var normalized := {}
	for key in arguments.keys():
		var name := str(key)
		var value := str(arguments.get(key, "")).strip_edges()
		if value.is_empty():
			continue
		normalized[name] = value
	return normalized


func _preview_body_text(preview: Dictionary) -> String:
	if preview.is_empty() or not bool(preview.get("success", false)):
		return ""
	var text := str(preview.get("text", ""))
	return text if not text.strip_edges().is_empty() else _text("mcp_catalog_preview_empty")


func _build_signature(model: Dictionary) -> String:
	return "\n".join([
		"language=%s" % _signature_scalar(str(model.get("current_language", ""))),
		"mode=%s" % _signature_scalar(_catalog_mode),
		"search=%s" % _signature_scalar(_get_search_query()),
		"selected=%s" % _signature_scalar("%s:%s" % [_selected_kind, _selected_id]),
		"resources=%s" % _signature_value(model.get("mcp_resources", [])),
		"templates=%s" % _signature_value(model.get("mcp_resource_templates", [])),
		"prompts=%s" % _signature_value(model.get("mcp_prompts", [])),
		"resource_presentation=%s" % _signature_value(model.get("mcp_resource_presentation", {})),
		"prompt_presentation=%s" % _signature_value(model.get("mcp_prompt_presentation", {})),
		"counts=%s" % _signature_value(model.get("mcp_catalog_counts", {})),
		"preview=%s" % _signature_value(model.get("mcp_catalog_preview", {})),
		"argument_values=%s" % _signature_value(_argument_values),
		"template_argument_values=%s" % _signature_value(_template_argument_values)
	])


func _signature_value(value) -> String:
	if value == null:
		return "n:"
	if value is bool:
		return "b:%s" % ("1" if bool(value) else "0")
	if value is int or value is float:
		return "num:%s" % str(value)
	if value is Dictionary:
		var dict_value := value as Dictionary
		var keys: Array[String] = []
		for key in dict_value.keys():
			keys.append(str(key))
		keys.sort()
		var entries: Array[String] = []
		for key in keys:
			entries.append("%s=%s" % [_signature_scalar(key), _signature_value(dict_value.get(key))])
		return "d:{%s}" % "|".join(entries)
	if value is Array:
		var entries: Array[String] = []
		for item in value as Array:
			entries.append(_signature_value(item))
		return "a:[%s]" % "|".join(entries)
	return "s:%s" % _signature_scalar(str(value))


func _signature_scalar(value: String) -> String:
	return "%s:%s" % [value.length(), value]


func _apply_editor_scale(scale: float) -> void:
	_current_scale = scale
	_apply_visual_style(scale)
	_apply_spacing(scale)

	_catalog_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalog_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_catalog_tree.custom_minimum_size.y = 96.0 * scale
	_catalog_tree.custom_minimum_size.x = 0.0
	_catalog_tree.set_column_expand(TREE_TEXT_COLUMN, true)
	_apply_responsive_layout()

	_preview_panel.custom_minimum_size.y = 148.0 * scale
	var desired_split := 560.0 * scale
	if size.y > 0.0:
		desired_split = max(420.0 * scale, size.y * 0.62)
	_content_split.split_offset = int(round(desired_split))

	_search_edit.custom_minimum_size.y = 0.0
	_header_counts.remove_theme_font_size_override("font_size")
	_preview_title.remove_theme_font_size_override("font_size")
	_preview_text.remove_theme_font_size_override("font_size")


func _apply_responsive_layout() -> void:
	if _catalog_tree == null:
		return
	var scale: float = _scale()
	_configure_tree_columns(scale)


func _configure_tree_columns(scale: float) -> void:
	if _catalog_tree == null:
		return
	var available_width: float = size.x
	if available_width <= 0.0:
		var parent_control := get_parent() as Control
		if parent_control != null:
			available_width = parent_control.size.x
	var tree_width: float = max(available_width - TREE_HORIZONTAL_CHROME_WIDTH * scale, TREE_TEXT_MIN_WIDTH * scale)
	var text_width: float = min(max(tree_width, TREE_TEXT_MIN_WIDTH * scale), TREE_TEXT_MAX_WIDTH * scale)
	_catalog_tree.set_column_custom_minimum_width(TREE_TEXT_COLUMN, int(round(text_width)))


func _apply_spacing(scale: float) -> void:
	add_theme_constant_override("separation", int(round(8 * scale)))
	_set_margin_constants(_header_margin, 14, 10, 14, 10, scale)
	_header_content.add_theme_constant_override("separation", int(round(8 * scale)))
	_argument_inputs.add_theme_constant_override("separation", int(round(4 * scale)))
	_set_margin_constants(_content_split.get_node_or_null("TopPane/SearchOuterMargin") as MarginContainer, 10, 8, 10, 6, scale)
	_set_margin_constants(_content_split.get_node_or_null("TopPane/TreeOuterMargin") as MarginContainer, 10, 4, 10, 6, scale)
	_set_margin_constants(_content_split.get_node_or_null("TopPane/TreeOuterMargin/CatalogTreePanel/CatalogTreeMargin") as MarginContainer, 0, 6, 0, 6, scale)
	_set_margin_constants(_content_split.get_node_or_null("BottomPane/PreviewOuterMargin") as MarginContainer, 10, 2, 10, 6, scale)
	_set_margin_constants(_preview_margin, 0, 2, 0, 12, scale)


func _set_margin_constants(margin: MarginContainer, left: int, top: int, right: int, bottom: int, scale: float) -> void:
	if margin == null:
		return
	margin.add_theme_constant_override("margin_left", int(round(left * scale)))
	margin.add_theme_constant_override("margin_top", int(round(top * scale)))
	margin.add_theme_constant_override("margin_right", int(round(right * scale)))
	margin.add_theme_constant_override("margin_bottom", int(round(bottom * scale)))


func _apply_visual_style(_scale_value: float) -> void:
	begin_bulk_theme_override()
	_header_card.add_theme_stylebox_override("panel", _make_theme_style("panel", "PanelContainer", 0, 0))
	_catalog_tree_panel.add_theme_stylebox_override("panel", _make_theme_style("panel", "Tree", 0, 0))
	_preview_panel.add_theme_stylebox_override("panel", _make_theme_style("panel", "PanelContainer", 0, 0))
	_search_edit.add_theme_stylebox_override("normal", _make_theme_style("normal", "LineEdit", 10, 6))
	_search_edit.add_theme_stylebox_override("focus", _make_theme_style("focus", "LineEdit", 10, 6))
	_header_counts.add_theme_color_override("font_color", get_theme_color("font_color", "Label"))
	_header_counts.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_search_edit.add_theme_color_override("font_color", get_theme_color("font_color", "LineEdit"))
	_search_edit.add_theme_color_override("font_placeholder_color", _get_meta_text_color())
	_catalog_tree.add_theme_color_override("font_color", get_theme_color("font_color", "Tree"))
	_catalog_tree.add_theme_color_override("font_selected_color", get_theme_color("font_selected_color", "Tree"))
	_catalog_tree.add_theme_color_override("guide_color", _get_meta_text_color())
	_catalog_tree.remove_theme_constant_override("v_separation")
	_preview_title.add_theme_color_override("font_color", get_theme_color("font_color", "Label"))
	_preview_text.add_theme_color_override("font_color", get_theme_color("font_color", "TextEdit"))
	_preview_text.add_theme_color_override("font_readonly_color", get_theme_color("font_readonly_color", "TextEdit"))
	_preview_text.add_theme_stylebox_override("normal", _make_theme_style("normal", "TextEdit", 8, 6))
	_preview_text.add_theme_stylebox_override("focus", _make_theme_style("focus", "TextEdit", 8, 6))
	_preview_text.add_theme_stylebox_override("read_only", _make_theme_style("read_only", "TextEdit", 8, 6))
	_preview_text.remove_theme_constant_override("line_spacing")
	end_bulk_theme_override()


func _make_theme_style(style_name: String, theme_type: String, horizontal_margin: int, vertical_margin: int) -> StyleBox:
	var base_style := get_theme_stylebox(style_name, theme_type)
	var style := base_style.duplicate() as StyleBox if base_style != null else StyleBoxEmpty.new()
	style.content_margin_left = horizontal_margin
	style.content_margin_right = horizontal_margin
	style.content_margin_top = vertical_margin
	style.content_margin_bottom = vertical_margin
	return style


func _scale() -> float:
	return _current_scale if _current_scale > 0.0 else 1.0


func _text(key: String) -> String:
	if _localization != null:
		return _localization.get_text(key)
	return key


func _safe_array(value) -> Array:
	if value is Array:
		return value as Array
	return []


func _get_description_text_color() -> Color:
	var base := get_theme_color("font_color", "Label")
	var disabled := get_theme_color("font_disabled_color", "Editor")
	return base.lerp(disabled, 0.18)


func _get_hint_text_color() -> Color:
	var base := get_theme_color("font_color", "Label")
	var disabled := get_theme_color("font_disabled_color", "Editor")
	return base.lerp(disabled, 0.34)


func _get_meta_text_color() -> Color:
	var base := get_theme_color("font_color", "Label")
	var disabled := get_theme_color("font_disabled_color", "Editor")
	return base.lerp(disabled, 0.48)


func _on_resized() -> void:
	_apply_responsive_layout()
