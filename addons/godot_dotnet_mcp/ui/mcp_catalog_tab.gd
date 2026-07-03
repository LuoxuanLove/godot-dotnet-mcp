@tool
extends VBoxContainer

signal copy_requested(text: String, source: String)
signal preview_requested(kind: String, id: String, arguments: Dictionary)

const TREE_TEXT_COLUMN := 0
const TREE_META_COLUMN := 1
const TREE_TEXT_MIN_WIDTH := 180.0
const TREE_TEXT_MAX_WIDTH := 340.0
const TREE_META_MIN_WIDTH := 80.0
const TREE_META_MAX_WIDTH := 150.0
const TREE_HORIZONTAL_CHROME_WIDTH := 48.0
const MAX_PROTOCOL_ICON_SRC_LENGTH := 8192
const MAX_PROTOCOL_ICON_BASE64_LENGTH := 6144
const MAX_ICON_TEXTURE_CACHE_ENTRIES := 64
const VIEW_CATALOG := "catalog"
const VIEW_DIAGNOSTICS := "diagnostics"
const KIND_RESOURCE := "resource"
const KIND_TEMPLATE := "template"
const KIND_PROMPT := "prompt"

@onready var _header_card: PanelContainer = %HeaderCard
@onready var _header_margin: MarginContainer = %HeaderMargin
@onready var _header_content: VBoxContainer = %HeaderContent
@onready var _header_title: Label = %HeaderTitle
@onready var _header_description: Label = %HeaderDescription
@onready var _header_counts: Label = %HeaderCounts
@onready var _view_mode_row: HBoxContainer = %ViewModeRow
@onready var _catalog_view_button: Button = %CatalogViewButton
@onready var _diagnostics_view_button: Button = %DiagnosticsViewButton
@onready var _content_split: VSplitContainer = %ContentSplit
@onready var _search_edit: LineEdit = %CatalogSearchEdit
@onready var _catalog_tree_panel: PanelContainer = %CatalogTreePanel
@onready var _catalog_tree: Tree = %CatalogTree
@onready var _preview_panel: PanelContainer = %PreviewPanel
@onready var _preview_margin: MarginContainer = %PreviewMargin
@onready var _preview_content: VBoxContainer = %PreviewContent
@onready var _preview_title: Label = %PreviewTitle
@onready var _argument_inputs: VBoxContainer = %ArgumentInputs
@onready var _action_row: HBoxContainer = %ActionRow
@onready var _copy_id_button: Button = %CopyIdButton
@onready var _preview_button: Button = %PreviewButton
@onready var _clear_arguments_button: Button = %ClearArgumentsButton
@onready var _copy_preview_button: Button = %CopyPreviewButton
@onready var _preview_text: TextEdit = %PreviewText

var _current_scale := -1.0
var _current_signature := ""
var _current_model: Dictionary = {}
var _localization = null
var _catalog_mode := "resources"
var _active_view := VIEW_CATALOG
var _argument_values: Dictionary = {}
var _template_argument_values: Dictionary = {}
var _icon_texture_cache: Dictionary = {}
var _icon_texture_cache_order: Array[String] = []
var _view_buttons: Dictionary = {}
var _selected_kind := ""
var _selected_id := ""
var _selected_entry: Dictionary = {}
var _tree_syncing := false
var _last_preview: Dictionary = {}


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_view_buttons = {
		VIEW_CATALOG: _catalog_view_button,
		VIEW_DIAGNOSTICS: _diagnostics_view_button
	}
	_catalog_view_button.pressed.connect(_on_view_button_pressed.bind(VIEW_CATALOG))
	_diagnostics_view_button.pressed.connect(_on_view_button_pressed.bind(VIEW_DIAGNOSTICS))
	_search_edit.text_changed.connect(_on_search_text_changed)
	_catalog_tree.item_selected.connect(_on_tree_item_selected)
	_catalog_tree.set_allow_reselect(true)
	_catalog_tree.theme_type_variation = "TreeSecondary"
	_preview_text.editable = false
	_preview_text.selecting_enabled = true
	_preview_text.context_menu_enabled = true
	_preview_text.set_line_wrapping_mode(TextEdit.LINE_WRAPPING_BOUNDARY)
	_preview_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_copy_id_button.pressed.connect(_on_copy_id_pressed)
	_preview_button.pressed.connect(_on_preview_pressed)
	_clear_arguments_button.pressed.connect(_on_clear_arguments_pressed)
	_copy_preview_button.pressed.connect(_on_copy_preview_pressed)
	resized.connect(_on_resized)
	_show_empty_preview()


func set_catalog_mode(mode: String) -> void:
	_catalog_mode = mode if mode in ["resources", "prompts"] else "resources"
	_selected_kind = ""
	_selected_id = ""
	_selected_entry.clear()
	_current_signature = ""


func set_catalog_view(view: String) -> void:
	_active_view = view if view in [VIEW_CATALOG, VIEW_DIAGNOSTICS] else VIEW_CATALOG
	_sync_view_buttons()
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
		_header_title.text = _localization.get_text("mcp_prompts_title")
		_header_description.text = _localization.get_text("mcp_prompts_description")
		_header_counts.text = _localization.get_text("mcp_prompts_counts") % int(counts.get("prompts", 0))
		_catalog_view_button.text = _localization.get_text("mcp_catalog_view_workflows")
		_search_edit.placeholder_text = _localization.get_text("mcp_catalog_search_prompts")
	else:
		_header_title.text = _localization.get_text("mcp_resources_title")
		_header_description.text = _localization.get_text("mcp_resources_description")
		_header_counts.text = _localization.get_text("mcp_resources_counts") % [
			int(counts.get("resources", 0)),
			int(counts.get("resource_templates", 0))
		]
		_catalog_view_button.text = _localization.get_text("mcp_catalog_view_catalog")
		_search_edit.placeholder_text = _localization.get_text("mcp_catalog_search_resources")
	_diagnostics_view_button.text = _localization.get_text("mcp_catalog_view_diagnostics")
	_copy_id_button.text = _localization.get_text("mcp_catalog_copy_id")
	_preview_button.text = _localization.get_text("mcp_catalog_preview")
	_clear_arguments_button.text = _localization.get_text("mcp_catalog_clear_arguments")
	_copy_preview_button.text = _localization.get_text("mcp_catalog_copy_preview")
	_refresh_view_button_tooltips()
	_sync_view_buttons()


func _sync_view_buttons() -> void:
	for view in _view_buttons.keys():
		var button := _view_buttons.get(view) as Button
		if button != null:
			button.button_pressed = str(view) == _active_view


func _on_view_button_pressed(view: String) -> void:
	if _active_view == view:
		_sync_view_buttons()
		return
	set_catalog_view(view)
	if not _current_model.is_empty():
		_render_tree(_current_model)
		_sync_detail_panel()


func _on_search_text_changed(_value: String) -> void:
	_current_signature = ""
	if not _current_model.is_empty():
		_render_tree(_current_model)
		_sync_detail_panel()


func _render_tree(model: Dictionary) -> void:
	_tree_syncing = true
	_catalog_tree.clear()
	_catalog_tree.set_column_clip_content(TREE_TEXT_COLUMN, true)
	_catalog_tree.set_column_clip_content(TREE_META_COLUMN, true)
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
			if entry.is_empty() or not _entry_visible_for_search(entry, kind):
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
	item.set_selectable(TREE_META_COLUMN, false)
	item.set_metadata(TREE_TEXT_COLUMN, {
		"kind": "group",
		"id": str(group.get("id", "")),
		"group": group.duplicate(true)
	})
	item.set_custom_color(TREE_META_COLUMN, _get_meta_text_color())
	item.set_text(TREE_META_COLUMN, str(group.get("id", "")))
	item.collapsed = false if not _get_search_query().is_empty() else false
	item.set_tooltip_text(TREE_TEXT_COLUMN, label)


func _create_entry_item(parent: TreeItem, entry: Dictionary, entry_kind: String, node: Dictionary) -> TreeItem:
	var item := _catalog_tree.create_item(parent)
	var id := _entry_id(entry, entry_kind)
	var title := _entry_title(entry, entry_kind)
	var meta := _entry_tree_meta(entry, entry_kind)
	item.set_text(TREE_TEXT_COLUMN, title)
	item.set_text(TREE_META_COLUMN, meta)
	item.set_tooltip_text(TREE_TEXT_COLUMN, _entry_tooltip(entry, entry_kind))
	item.set_tooltip_text(TREE_META_COLUMN, id)
	item.set_metadata(TREE_TEXT_COLUMN, {
		"kind": entry_kind,
		"id": id,
		"entry": entry.duplicate(true),
		"node": node.duplicate(true)
	})
	var icon_texture := _texture_from_icon_src(_entry_icon_src(entry))
	if icon_texture != null:
		item.set_icon(TREE_TEXT_COLUMN, icon_texture)
	item.set_custom_color(TREE_META_COLUMN, _get_meta_text_color())
	if _active_view == VIEW_DIAGNOSTICS:
		item.set_custom_color(TREE_TEXT_COLUMN, _get_description_text_color())
	if entry_kind == KIND_TEMPLATE:
		item.set_custom_color(TREE_META_COLUMN, _get_hint_text_color())
	if _selected_kind == entry_kind and _selected_id == id:
		item.select(TREE_TEXT_COLUMN)
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
	var child := root.get_first_child()
	while child != null:
		if _is_entry_item(child):
			return child
		var nested := child.get_first_child()
		while nested != null:
			if _is_entry_item(nested):
				return nested
			nested = nested.get_next()
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


func _sync_detail_panel() -> void:
	if _selected_entry.is_empty() or _selected_kind.is_empty():
		_show_empty_preview()
		return
	_preview_title.text = _entry_title(_selected_entry, _selected_kind)
	_rebuild_argument_inputs()
	_copy_id_button.visible = true
	_copy_id_button.disabled = _selected_id.is_empty()
	_copy_id_button.tooltip_text = _selected_id
	_preview_button.visible = true
	_preview_button.disabled = false
	_preview_button.tooltip_text = _selected_id
	_clear_arguments_button.visible = _selected_kind == KIND_PROMPT or _selected_kind == KIND_TEMPLATE
	_clear_arguments_button.disabled = not _has_any_arguments_for_selection()
	_copy_preview_button.visible = true
	var preview := _current_preview_for_selection()
	var preview_text := _preview_body_text(preview)
	_copy_preview_button.disabled = preview_text.strip_edges().is_empty()
	_copy_preview_button.tooltip_text = _text("mcp_catalog_copy_preview")
	_preview_text.text = _build_detail_text(preview)


func _show_empty_preview() -> void:
	if _preview_title != null:
		_preview_title.text = _text("mcp_catalog_select_entry")
	if _argument_inputs != null:
		_clear_children(_argument_inputs)
	if _copy_id_button != null:
		_copy_id_button.visible = false
	if _preview_button != null:
		_preview_button.visible = false
	if _clear_arguments_button != null:
		_clear_arguments_button.visible = false
	if _copy_preview_button != null:
		_copy_preview_button.visible = false
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
	_clear_arguments_button.disabled = not _has_any_arguments_for_selection()
	_copy_preview_button.disabled = true
	_preview_text.text = _build_detail_text({})


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _on_copy_id_pressed() -> void:
	if _selected_id.is_empty():
		return
	copy_requested.emit(_selected_id, _entry_title(_selected_entry, _selected_kind))


func _on_preview_pressed() -> void:
	if _selected_id.is_empty():
		return
	preview_requested.emit(_selected_kind, _selected_id, _selection_argument_values())


func _on_clear_arguments_pressed() -> void:
	_store_selection_argument_values({})
	_sync_detail_panel()


func _on_copy_preview_pressed() -> void:
	var preview := _current_preview_for_selection()
	var text := _preview_body_text(preview)
	if text.strip_edges().is_empty():
		return
	copy_requested.emit(text, "%s %s" % [_entry_title(_selected_entry, _selected_kind), _text("mcp_catalog_preview_title")])


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
	if _active_view == VIEW_DIAGNOSTICS:
		lines.append("")
		lines.append(_text("mcp_catalog_diagnostics_section"))
		for line in _diagnostics_lines(_selected_entry, _selected_kind):
			lines.append(line)
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


func _diagnostics_lines(entry: Dictionary, entry_kind: String) -> Array[String]:
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
		lines.append("%s: %s" % [_text("mcp_catalog_metadata"), JSON.stringify(metadata)])
	return lines


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


func _entry_tree_meta(entry: Dictionary, entry_kind: String) -> String:
	if _active_view == VIEW_DIAGNOSTICS:
		return _diagnostic_kind(entry, entry_kind)
	if entry_kind == KIND_PROMPT:
		return "%s %d" % [_text("mcp_catalog_arguments"), _safe_array(entry.get("arguments", [])).size()]
	if entry_kind == KIND_TEMPLATE:
		return _text("mcp_catalog_resource_templates")
	var mime := str(entry.get("mimeType", "")).strip_edges()
	return mime if not mime.is_empty() else str(entry.get("resource_kind", entry_kind))


func _entry_tooltip(entry: Dictionary, entry_kind: String) -> String:
	var parts: Array[String] = [_entry_title(entry, entry_kind), _entry_id(entry, entry_kind)]
	var description := str(entry.get("description", "")).strip_edges()
	if not description.is_empty():
		parts.append(description)
	return "\n".join(parts)


func _entry_meta(entry: Dictionary, entry_kind: String) -> String:
	if _active_view == VIEW_DIAGNOSTICS:
		return " | ".join(_diagnostics_lines(entry, entry_kind))
	if entry_kind == KIND_PROMPT:
		var args: Array[String] = []
		for arg in entry.get("arguments", []):
			if arg is Dictionary:
				args.append(str((arg as Dictionary).get("name", "")))
		if args.is_empty():
			return "%s: %s" % [_text("mcp_catalog_kind"), str(entry.get("prompt_kind", "prompt"))]
		return "%s: %s | %s: %s" % [
			_text("mcp_catalog_kind"),
			str(entry.get("prompt_kind", "prompt")),
			_text("mcp_catalog_arguments"),
			", ".join(args)
		]
	return "%s: %s | %s: %s" % [
		_text("mcp_catalog_kind"),
		str(entry.get("resource_kind", entry_kind)),
		_text("mcp_catalog_mime_type"),
		str(entry.get("mimeType", ""))
	]


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
	return _text("mcp_catalog_icon_available")


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
		"view=%s" % _signature_scalar(_active_view),
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
	_apply_responsive_layout()
	_apply_visual_style(scale)


func _apply_responsive_layout() -> void:
	var scale := _scale()
	var narrow := size.x > 0.0 and size.x < 380.0 * scale
	add_theme_constant_override("separation", int(round((6.0 if narrow else 8.0) * scale)))
	_header_margin.add_theme_constant_override("margin_left", int(round((10.0 if narrow else 14.0) * scale)))
	_header_margin.add_theme_constant_override("margin_right", int(round((10.0 if narrow else 14.0) * scale)))
	_header_margin.add_theme_constant_override("margin_top", int(round(10 * scale)))
	_header_margin.add_theme_constant_override("margin_bottom", int(round(10 * scale)))
	_header_content.add_theme_constant_override("separation", int(round((6.0 if narrow else 8.0) * scale)))
	_view_mode_row.add_theme_constant_override("separation", int(round((4.0 if narrow else 6.0) * scale)))
	_configure_view_mode_button(_catalog_view_button, VIEW_CATALOG, 86.0 if narrow else 110.0, scale)
	_configure_view_mode_button(_diagnostics_view_button, VIEW_DIAGNOSTICS, 86.0 if narrow else 116.0, scale)
	_argument_inputs.add_theme_constant_override("separation", int(round(4 * scale)))
	_action_row.add_theme_constant_override("separation", int(round(6 * scale)))
	_preview_margin.add_theme_constant_override("margin_left", int(round(10 * scale)))
	_preview_margin.add_theme_constant_override("margin_right", int(round(10 * scale)))
	_preview_margin.add_theme_constant_override("margin_top", int(round(8 * scale)))
	_preview_margin.add_theme_constant_override("margin_bottom", int(round(10 * scale)))
	_configure_tree_columns(scale)


func _configure_tree_columns(scale: float) -> void:
	if _catalog_tree == null:
		return
	var available_width := max(size.x - TREE_HORIZONTAL_CHROME_WIDTH * scale, 240.0 * scale)
	var meta_width := clamp(available_width * 0.28, TREE_META_MIN_WIDTH * scale, TREE_META_MAX_WIDTH * scale)
	var text_width := clamp(available_width - meta_width, TREE_TEXT_MIN_WIDTH * scale, TREE_TEXT_MAX_WIDTH * scale)
	_catalog_tree.set_column_custom_minimum_width(TREE_TEXT_COLUMN, int(round(text_width)))
	_catalog_tree.set_column_custom_minimum_width(TREE_META_COLUMN, int(round(meta_width)))


func _configure_view_mode_button(button: Button, view: String, min_width: float, scale: float) -> void:
	if button == null:
		return
	button.custom_minimum_size.x = min_width * scale
	button.tooltip_text = button.text if not button.text.strip_edges().is_empty() else view


func _refresh_view_button_tooltips() -> void:
	_configure_view_button_tooltip(_catalog_view_button, VIEW_CATALOG)
	_configure_view_button_tooltip(_diagnostics_view_button, VIEW_DIAGNOSTICS)


func _configure_view_button_tooltip(button: Button, view: String) -> void:
	if button == null:
		return
	button.tooltip_text = button.text if not button.text.strip_edges().is_empty() else view


func _apply_visual_style(_scale_value: float) -> void:
	begin_bulk_theme_override()
	for panel in [_header_card, _catalog_tree_panel, _preview_panel]:
		if panel != null:
			panel.add_theme_stylebox_override("panel", _make_framed_panel_style())
	for label in [_header_title, _preview_title]:
		if label != null:
			label.add_theme_color_override("font_color", get_theme_color("font_color", "Label"))
			label.remove_theme_font_size_override("font_size")
	_header_description.add_theme_color_override("font_color", _get_description_text_color())
	_header_counts.add_theme_color_override("font_color", _get_meta_text_color())
	_preview_text.add_theme_color_override("font_color", _get_description_text_color())
	end_bulk_theme_override()


func _make_framed_panel_style() -> StyleBox:
	var base_style := get_theme_stylebox("panel", "Tree")
	var style := base_style.duplicate() as StyleBox if base_style != null else StyleBoxFlat.new()
	if style is StyleBoxFlat:
		var flat_style := style as StyleBoxFlat
		flat_style.border_color = get_theme_color("separator_color", "Editor")
		flat_style.set_border_width_all(1)
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
