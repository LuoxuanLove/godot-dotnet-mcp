@tool
extends VBoxContainer

signal copy_requested(text: String, source: String)
signal preview_requested(kind: String, id: String, arguments: Dictionary)

@onready var _margin: MarginContainer = %Margin
@onready var _content: VBoxContainer = %Content
@onready var _header_card: PanelContainer = %HeaderCard
@onready var _header_margin: MarginContainer = %HeaderMargin
@onready var _header_body: VBoxContainer = %HeaderBody
@onready var _header_title: Label = %HeaderTitle
@onready var _header_description: Label = %HeaderDescription
@onready var _header_counts: Label = %HeaderCounts
@onready var _view_mode_row: HBoxContainer = %ViewModeRow
@onready var _catalog_view_button: Button = %CatalogViewButton
@onready var _diagnostics_view_button: Button = %DiagnosticsViewButton
@onready var _resources_card: PanelContainer = %ResourcesCard
@onready var _resources_margin: MarginContainer = %ResourcesMargin
@onready var _resources_body: VBoxContainer = %ResourcesBody
@onready var _resources_title: Label = %ResourcesTitle
@onready var _resources_list: VBoxContainer = %ResourcesList
@onready var _templates_card: PanelContainer = %TemplatesCard
@onready var _templates_margin: MarginContainer = %TemplatesMargin
@onready var _templates_body: VBoxContainer = %TemplatesBody
@onready var _templates_title: Label = %TemplatesTitle
@onready var _templates_list: VBoxContainer = %TemplatesList
@onready var _prompts_card: PanelContainer = %PromptsCard
@onready var _prompts_margin: MarginContainer = %PromptsMargin
@onready var _prompts_body: VBoxContainer = %PromptsBody
@onready var _prompts_title: Label = %PromptsTitle
@onready var _prompts_list: VBoxContainer = %PromptsList

var _current_scale := -1.0
var _current_signature := ""
var _current_model: Dictionary = {}
var _localization = null
var _catalog_mode := "resources"
var _active_view := "catalog"
var _argument_values: Dictionary = {}
var _icon_texture_cache: Dictionary = {}
var _view_buttons: Dictionary = {}

const MAX_PROTOCOL_ICON_SRC_LENGTH := 8192
const MAX_PROTOCOL_ICON_BASE64_LENGTH := 6144
const MAX_PROTOCOL_ICON_DECODED_BYTES := 4096
const VIEW_CATALOG := "catalog"
const VIEW_DIAGNOSTICS := "diagnostics"


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_view_buttons = {
		VIEW_CATALOG: _catalog_view_button,
		VIEW_DIAGNOSTICS: _diagnostics_view_button
	}
	_catalog_view_button.pressed.connect(_on_view_button_pressed.bind(VIEW_CATALOG))
	_diagnostics_view_button.pressed.connect(_on_view_button_pressed.bind(VIEW_DIAGNOSTICS))
	resized.connect(_on_resized)


func set_catalog_mode(mode: String) -> void:
	_catalog_mode = mode if mode in ["resources", "prompts"] else "resources"
	_current_signature = ""


func set_catalog_view(view: String) -> void:
	_active_view = view if view in [VIEW_CATALOG, VIEW_DIAGNOSTICS] else VIEW_CATALOG
	_sync_view_buttons()
	_current_signature = ""


func apply_model(model: Dictionary) -> void:
	_localization = model.get("localization")
	_current_model = model
	var editor_scale := float(model.get("editor_scale", 1.0))
	if not is_equal_approx(_current_scale, editor_scale):
		_apply_editor_scale(editor_scale)
	else:
		_apply_responsive_layout()
	_apply_localized_copy(model)
	var signature := _build_signature(model)
	if signature == _current_signature:
		return
	_current_signature = signature
	_rebuild_resource_catalog(model)
	_rebuild_prompt_catalog(model)


func _apply_localized_copy(model: Dictionary) -> void:
	if _localization == null:
		return
	var counts: Dictionary = model.get("mcp_catalog_counts", {})
	if _catalog_mode == "prompts":
		_header_title.text = _localization.get_text("mcp_prompts_title")
		_header_description.text = _localization.get_text("mcp_prompts_description")
		_header_counts.text = _localization.get_text("mcp_prompts_counts") % int(counts.get("prompts", 0))
	else:
		_header_title.text = _localization.get_text("mcp_resources_title")
		_header_description.text = _localization.get_text("mcp_resources_description")
		_header_counts.text = _localization.get_text("mcp_resources_counts") % [
			int(counts.get("resources", 0)),
			int(counts.get("resource_templates", 0))
		]
	_resources_title.text = _localization.get_text("mcp_catalog_resources")
	_templates_title.text = _localization.get_text("mcp_catalog_resource_templates")
	_prompts_title.text = _localization.get_text("mcp_catalog_prompts")
	_catalog_view_button.text = _localization.get_text("mcp_catalog_view_catalog")
	_diagnostics_view_button.text = _localization.get_text("mcp_catalog_view_diagnostics")
	_refresh_view_button_tooltips()
	_sync_view_buttons()
	_resources_card.visible = _catalog_mode == "resources"
	_templates_card.visible = _catalog_mode == "resources"
	_prompts_card.visible = _catalog_mode == "prompts"


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
		_rebuild_resource_catalog(_current_model)
		_rebuild_prompt_catalog(_current_model)


func _rebuild_entries(container: VBoxContainer, entries, entry_kind: String) -> void:
	for child in container.get_children():
		child.queue_free()
	if not (entries is Array) or (entries as Array).is_empty():
		container.add_child(_create_empty_label(entry_kind))
		return
	for entry in entries:
		if entry is Dictionary:
			container.add_child(_create_entry_card(entry as Dictionary, entry_kind))


func _rebuild_resource_catalog(model: Dictionary) -> void:
	var presentation = model.get("mcp_resource_presentation", {})
	if not (presentation is Dictionary) or (presentation as Dictionary).is_empty():
		_rebuild_entries(_resources_list, model.get("mcp_resources", []), "resource")
		_rebuild_entries(_templates_list, model.get("mcp_resource_templates", []), "template")
		return
	var groups: Array = (presentation as Dictionary).get("resourceTree", [])
	var resource_groups: Array[Dictionary] = []
	var template_groups: Array[Dictionary] = []
	for raw_group in groups:
		if not (raw_group is Dictionary):
			continue
		var group := raw_group as Dictionary
		if _group_contains_kind(group, "resource_template"):
			template_groups.append(group)
		else:
			resource_groups.append(group)
	_rebuild_grouped_entries(_resources_list, resource_groups, "resource")
	_rebuild_grouped_entries(_templates_list, template_groups, "template")


func _rebuild_prompt_catalog(model: Dictionary) -> void:
	var presentation = model.get("mcp_prompt_presentation", {})
	if not (presentation is Dictionary) or (presentation as Dictionary).is_empty():
		_rebuild_entries(_prompts_list, model.get("mcp_prompts", []), "prompt")
		return
	var groups: Array = (presentation as Dictionary).get("promptTree", [])
	var prompt_groups: Array[Dictionary] = []
	for raw_group in groups:
		if raw_group is Dictionary:
			prompt_groups.append(raw_group as Dictionary)
	_rebuild_grouped_entries(_prompts_list, prompt_groups, "prompt")


func _rebuild_grouped_entries(container: VBoxContainer, groups: Array, fallback_entry_kind: String) -> void:
	for child in container.get_children():
		child.queue_free()
	if groups.is_empty():
		container.add_child(_create_empty_label(fallback_entry_kind))
		return
	for raw_group in groups:
		if not (raw_group is Dictionary):
			continue
		var group := raw_group as Dictionary
		var children: Array = group.get("children", [])
		if children.is_empty():
			continue
		container.add_child(_create_group_section(group, fallback_entry_kind))


func _create_group_section(group: Dictionary, fallback_entry_kind: String) -> Control:
	var section := VBoxContainer.new()
	section.name = "Group_%s" % str(group.get("id", "")).replace("-", "_")
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", int(round(6 * _scale())))
	section.set_meta("mcp_catalog_group_id", str(group.get("id", "")))
	section.set_meta("mcp_catalog_group_kind", str(group.get("kind", "")))

	var header := HBoxContainer.new()
	header.name = "GroupHeader"
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", int(round(6 * _scale())))
	section.add_child(header)

	var title := Label.new()
	title.name = "GroupTitle"
	title.text = _group_label(group)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_color_override("font_color", get_theme_color("font_color", "Label"))
	header.add_child(title)

	var count := Label.new()
	count.name = "GroupCount"
	count.text = str(int(group.get("count", (group.get("children", []) as Array).size())))
	count.add_theme_color_override("font_color", _get_meta_text_color())
	header.add_child(count)

	for raw_child in group.get("children", []):
		if not (raw_child is Dictionary):
			continue
		var node := raw_child as Dictionary
		var entry := _entry_from_presentation_node(node)
		if entry.is_empty():
			continue
		section.add_child(_create_entry_card(entry, _entry_kind_from_presentation_node(node, fallback_entry_kind)))
	return section


func _group_label(group: Dictionary) -> String:
	var label_key := str(group.get("label_key", "")).strip_edges()
	if _localization != null and not label_key.is_empty():
		var localized := str(_localization.get_text(label_key))
		if not localized.is_empty() and localized != label_key:
			return localized
	return str(group.get("label", group.get("id", "")))


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


func _entry_kind_from_presentation_node(node: Dictionary, fallback_entry_kind: String) -> String:
	match str(node.get("kind", "")):
		"resource_template":
			return "template"
		"resource_entry":
			return "resource"
		"prompt_entry":
			return "prompt"
		_:
			return fallback_entry_kind


func _group_contains_kind(group: Dictionary, node_kind: String) -> bool:
	for raw_child in group.get("children", []):
		if raw_child is Dictionary and str((raw_child as Dictionary).get("kind", "")) == node_kind:
			return true
	return false


func _create_empty_label(entry_kind: String) -> Control:
	var label := Label.new()
	label.name = "Empty%sLabel" % entry_kind.capitalize()
	label.text = _localization.get_text("mcp_catalog_empty") if _localization != null else ""
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", _get_hint_text_color())
	return label


func _create_entry_card(entry: Dictionary, entry_kind: String) -> Control:
	var panel := PanelContainer.new()
	panel.name = "%sCard" % _entry_id(entry, entry_kind).replace(":", "_").replace("/", "_").replace(".", "_").replace("{", "").replace("}", "")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.set_meta("mcp_catalog_kind", entry_kind)
	panel.set_meta("mcp_catalog_id", _entry_id(entry, entry_kind))
	panel.add_theme_stylebox_override("panel", _make_framed_panel_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(round(10 * _scale())))
	margin.add_theme_constant_override("margin_top", int(round(8 * _scale())))
	margin.add_theme_constant_override("margin_right", int(round(10 * _scale())))
	margin.add_theme_constant_override("margin_bottom", int(round(8 * _scale())))
	panel.add_child(margin)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(round(5 * _scale())))
	margin.add_child(body)

	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", int(round(8 * _scale())))
	body.add_child(top_row)

	_add_entry_icon(top_row, entry, entry_kind)

	var title := Label.new()
	title.name = "Title"
	title.text = _entry_title(entry, entry_kind)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top_row.add_child(title)

	var copy_button := Button.new()
	copy_button.name = "CopyIdButton"
	copy_button.text = _localization.get_text("mcp_catalog_copy_id") if _localization != null else "Copy"
	copy_button.tooltip_text = _entry_id(entry, entry_kind)
	copy_button.pressed.connect(func() -> void:
		copy_requested.emit(_entry_id(entry, entry_kind), _entry_title(entry, entry_kind))
	)
	top_row.add_child(copy_button)

	var id_label := Label.new()
	id_label.name = "Identifier"
	id_label.text = _entry_id(entry, entry_kind)
	id_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	id_label.add_theme_color_override("font_color", _get_meta_text_color())
	body.add_child(id_label)

	var description := str(entry.get("description", "")).strip_edges()
	if not description.is_empty():
		var desc_label := Label.new()
		desc_label.name = "Description"
		desc_label.text = description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_color_override("font_color", _get_description_text_color())
		body.add_child(desc_label)

	var meta_text := _entry_meta(entry, entry_kind)
	if not meta_text.is_empty():
		var meta_label := Label.new()
		meta_label.name = "Metadata"
		meta_label.text = meta_text
		meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		meta_label.add_theme_color_override("font_color", _get_hint_text_color())
		body.add_child(meta_label)

	_add_entry_actions(body, entry, entry_kind)

	return panel


func _add_entry_icon(row: HBoxContainer, entry: Dictionary, entry_kind: String) -> void:
	var icon_src := _entry_icon_src(entry)
	if icon_src.is_empty():
		return
	var icon_size := int(round(18 * _scale()))
	var texture := _texture_from_icon_src(icon_src)
	if texture != null:
		var icon := TextureRect.new()
		icon.name = "ProtocolIcon"
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = texture
		icon.tooltip_text = _entry_icon_tooltip(entry, entry_kind)
		icon.set_meta("mcp_icon_src", icon_src)
		row.add_child(icon)
		return
	var fallback := Label.new()
	fallback.name = "ProtocolIcon"
	fallback.custom_minimum_size = Vector2(icon_size, icon_size)
	fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback.text = "[]"
	fallback.tooltip_text = _entry_icon_tooltip(entry, entry_kind)
	fallback.add_theme_color_override("font_color", _get_meta_text_color())
	fallback.set_meta("mcp_icon_src", icon_src)
	row.add_child(fallback)


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


func _entry_icon_tooltip(entry: Dictionary, entry_kind: String) -> String:
	return "%s: %s" % [_entry_title(entry, entry_kind), _entry_meta(entry, entry_kind)]


func _texture_from_icon_src(src: String) -> Texture2D:
	if src.length() > MAX_PROTOCOL_ICON_SRC_LENGTH:
		return null
	if _icon_texture_cache.has(src):
		return _icon_texture_cache.get(src)
	var texture: Texture2D = null
	var svg_prefix := "data:image/svg+xml;base64,"
	if src.begins_with(svg_prefix):
		var encoded := src.substr(svg_prefix.length())
		if encoded.length() <= MAX_PROTOCOL_ICON_BASE64_LENGTH:
			var bytes := Marshalls.base64_to_raw(encoded)
			if not bytes.is_empty() and bytes.size() <= MAX_PROTOCOL_ICON_DECODED_BYTES:
				var svg_text := bytes.get_string_from_utf8().strip_edges()
				if svg_text.begins_with("<svg"):
					var image := Image.new()
					if image.load_svg_from_buffer(bytes) == OK:
						texture = ImageTexture.create_from_image(image)
	if texture != null:
		_icon_texture_cache[src] = texture
	return texture


func _add_entry_actions(body: VBoxContainer, entry: Dictionary, entry_kind: String) -> void:
	var id := _entry_id(entry, entry_kind)
	if entry_kind == "template":
		var action_row := HBoxContainer.new()
		action_row.name = "ActionRow"
		action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_row.add_theme_constant_override("separation", int(round(6 * _scale())))
		body.add_child(action_row)
		var preview_button := Button.new()
		preview_button.name = "PreviewButton"
		preview_button.text = _text("mcp_catalog_preview")
		preview_button.tooltip_text = id
		preview_button.disabled = true
		action_row.add_child(preview_button)
		var hint := Label.new()
		hint.name = "PreviewUnavailable"
		hint.text = _text("mcp_catalog_template_preview_unavailable")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_color_override("font_color", _get_hint_text_color())
		body.add_child(hint)
		return
	if entry_kind == "prompt":
		_add_prompt_argument_inputs(body, entry)

	var action_row := HBoxContainer.new()
	action_row.name = "ActionRow"
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_theme_constant_override("separation", int(round(6 * _scale())))
	body.add_child(action_row)

	var preview_button := Button.new()
	preview_button.name = "PreviewButton"
	preview_button.text = _text("mcp_catalog_preview")
	preview_button.tooltip_text = id
	preview_button.pressed.connect(func() -> void:
		preview_requested.emit(entry_kind, id, _collect_entry_arguments(entry, entry_kind))
	)
	action_row.add_child(preview_button)

	_add_preview_panel(body, entry, entry_kind, id)


func _add_prompt_argument_inputs(body: VBoxContainer, entry: Dictionary) -> void:
	var arguments = entry.get("arguments", [])
	if not (arguments is Array) or (arguments as Array).is_empty():
		return
	var args_box := VBoxContainer.new()
	args_box.name = "ArgumentInputs"
	args_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	args_box.add_theme_constant_override("separation", int(round(4 * _scale())))
	body.add_child(args_box)
	var prompt_name := _entry_id(entry, "prompt")
	if not _argument_values.has(prompt_name):
		_argument_values[prompt_name] = {}
	var prompt_values: Dictionary = _argument_values.get(prompt_name, {})
	for raw_arg in arguments:
		if not (raw_arg is Dictionary):
			continue
		var arg := raw_arg as Dictionary
		var arg_name := str(arg.get("name", "")).strip_edges()
		if arg_name.is_empty():
			continue
		var row := HBoxContainer.new()
		row.name = "Arg_%s" % arg_name
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", int(round(6 * _scale())))
		args_box.add_child(row)

		var label := Label.new()
		label.name = "ArgumentLabel"
		label.text = "%s%s" % [arg_name, " *" if bool(arg.get("required", false)) else ""]
		label.custom_minimum_size.x = 92.0 * _scale()
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(label)

		var input := LineEdit.new()
		input.name = "ArgumentInput_%s" % arg_name
		input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		input.placeholder_text = str(arg.get("description", _text("mcp_catalog_argument_placeholder")))
		input.text = str(prompt_values.get(arg_name, ""))
		input.text_changed.connect(func(value: String) -> void:
			var values: Dictionary = _argument_values.get(prompt_name, {})
			values[arg_name] = value
			_argument_values[prompt_name] = values
			_current_signature = ""
			_clear_prompt_preview_panels(prompt_name)
		)
		row.add_child(input)


func _collect_entry_arguments(entry: Dictionary, entry_kind: String) -> Dictionary:
	if entry_kind != "prompt":
		return {}
	var prompt_name := _entry_id(entry, entry_kind)
	var values: Dictionary = _argument_values.get(prompt_name, {})
	return values.duplicate(true)


func _add_preview_panel(body: VBoxContainer, entry: Dictionary, entry_kind: String, id: String) -> void:
	var preview := _current_preview_for(entry, entry_kind, id)
	if preview.is_empty():
		return
	var panel := PanelContainer.new()
	panel.name = "PreviewPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.set_meta("_mcp_catalog_kind", entry_kind)
	panel.set_meta("_mcp_catalog_id", id)
	panel.add_theme_stylebox_override("panel", _make_framed_panel_style())
	body.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(round(8 * _scale())))
	margin.add_theme_constant_override("margin_top", int(round(6 * _scale())))
	margin.add_theme_constant_override("margin_right", int(round(8 * _scale())))
	margin.add_theme_constant_override("margin_bottom", int(round(6 * _scale())))
	panel.add_child(margin)

	var preview_body := VBoxContainer.new()
	preview_body.name = "PreviewBody"
	preview_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_body.add_theme_constant_override("separation", int(round(5 * _scale())))
	margin.add_child(preview_body)

	var title_row := HBoxContainer.new()
	title_row.name = "PreviewTitleRow"
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_theme_constant_override("separation", int(round(6 * _scale())))
	preview_body.add_child(title_row)

	var title := Label.new()
	title.name = "PreviewTitle"
	title.text = _text("mcp_catalog_preview_title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", _get_meta_text_color())
	title_row.add_child(title)

	var preview_text := _preview_text(preview)
	var copy_button := Button.new()
	copy_button.name = "CopyPreviewButton"
	copy_button.text = _text("mcp_catalog_copy_preview")
	copy_button.disabled = preview_text.strip_edges().is_empty()
	copy_button.pressed.connect(func() -> void:
		copy_requested.emit(preview_text, "%s %s" % [_entry_title_from_preview(preview), _text("mcp_catalog_preview_title")])
	)
	title_row.add_child(copy_button)

	var content := Label.new()
	content.name = "PreviewText"
	content.text = preview_text if bool(preview.get("success", false)) else _text("mcp_catalog_preview_error") % str(preview.get("error", ""))
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_theme_color_override("font_color", _get_description_text_color())
	preview_body.add_child(content)


func _current_preview_for(entry: Dictionary, entry_kind: String, id: String) -> Dictionary:
	var preview = _last_preview()
	if not (preview is Dictionary):
		return {}
	var preview_dict := preview as Dictionary
	if str(preview_dict.get("kind", "")) != entry_kind:
		return {}
	if str(preview_dict.get("id", "")) != id:
		return {}
	if entry_kind == "prompt" and not _preview_arguments_match_current(entry, entry_kind, preview_dict):
		return {}
	return preview_dict


func _clear_prompt_preview_panels(prompt_name: String) -> void:
	if _prompts_list == null:
		return
	for child in _prompts_list.get_children():
		if not (child is Node):
			continue
		var preview_panel := (child as Node).find_child("PreviewPanel", true, false)
		if preview_panel == null:
			continue
		if str(preview_panel.get_meta("_mcp_catalog_kind", "")) == "prompt" and str(preview_panel.get_meta("_mcp_catalog_id", "")) == prompt_name:
			preview_panel.queue_free()


func _preview_arguments_match_current(entry: Dictionary, entry_kind: String, preview: Dictionary) -> bool:
	var expected := _normalize_arguments(_collect_entry_arguments(entry, entry_kind))
	var preview_arguments = preview.get("arguments", {})
	if not (preview_arguments is Dictionary):
		return expected.is_empty()
	return _normalize_arguments(preview_arguments as Dictionary) == expected


func _normalize_arguments(arguments: Dictionary) -> Dictionary:
	var normalized := {}
	for key in arguments.keys():
		var name := str(key)
		var value := str(arguments.get(key, "")).strip_edges()
		if value.is_empty():
			continue
		normalized[name] = value
	return normalized


func _last_preview():
	return get_meta("_mcp_catalog_preview", {})


func _preview_text(preview: Dictionary) -> String:
	if not bool(preview.get("success", false)):
		return ""
	var text := str(preview.get("text", ""))
	return text if not text.strip_edges().is_empty() else _text("mcp_catalog_preview_empty")


func _entry_title_from_preview(preview: Dictionary) -> String:
	var title := str(preview.get("title", "")).strip_edges()
	if not title.is_empty():
		return title
	return str(preview.get("id", ""))


func _entry_id(entry: Dictionary, entry_kind: String) -> String:
	if entry_kind == "prompt":
		return str(entry.get("name", ""))
	var uri_template := str(entry.get("uriTemplate", "")).strip_edges()
	if not uri_template.is_empty():
		return uri_template
	return str(entry.get("uri", ""))


func _entry_title(entry: Dictionary, entry_kind: String) -> String:
	var fallback := _entry_id(entry, entry_kind)
	return str(entry.get("title", entry.get("name", fallback)))


func _entry_meta(entry: Dictionary, entry_kind: String) -> String:
	if _active_view == VIEW_DIAGNOSTICS:
		return _entry_diagnostics_meta(entry, entry_kind)
	if entry_kind == "prompt":
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


func _entry_diagnostics_meta(entry: Dictionary, entry_kind: String) -> String:
	var parts: Array[String] = []
	parts.append("%s: %s" % [_text("mcp_catalog_kind"), _diagnostic_kind(entry, entry_kind)])
	var source := str(entry.get("_presentation_source", "")).strip_edges()
	if not source.is_empty():
		parts.append("%s: %s" % [_text("mcp_catalog_source"), source])
	var visibility := str(entry.get("_presentation_visibility", "")).strip_edges()
	if not visibility.is_empty():
		parts.append("%s: %s" % [_text("mcp_catalog_visibility"), visibility])
	var callability := str(entry.get("_presentation_callability", "")).strip_edges()
	if not callability.is_empty():
		parts.append("%s: %s" % [_text("mcp_catalog_callability"), callability])
	var group := str(entry.get("resource_group", entry.get("_presentation_group", ""))).strip_edges()
	if entry_kind == "prompt":
		group = str(entry.get("prompt_kind", entry.get("_presentation_group", ""))).strip_edges()
	if not group.is_empty():
		parts.append("%s: %s" % [_text("mcp_catalog_group"), group])
	if entry_kind == "prompt":
		parts.append("%s: %d" % [_text("mcp_catalog_arguments"), _safe_array(entry.get("arguments", [])).size()])
	else:
		var mime := str(entry.get("mimeType", "")).strip_edges()
		if not mime.is_empty():
			parts.append("%s: %s" % [_text("mcp_catalog_mime_type"), mime])
	return " | ".join(parts)


func _diagnostic_kind(entry: Dictionary, entry_kind: String) -> String:
	var presentation_kind := str(entry.get("_presentation_kind", "")).strip_edges()
	if not presentation_kind.is_empty():
		return presentation_kind
	if entry_kind == "prompt":
		return str(entry.get("prompt_kind", "prompt"))
	return str(entry.get("resource_kind", entry_kind))


func _build_signature(model: Dictionary) -> String:
	set_meta("_mcp_catalog_preview", model.get("mcp_catalog_preview", {}))
	return JSON.stringify({
		"language": str(model.get("current_language", "")),
		"mode": _catalog_mode,
		"view": _active_view,
		"resources": model.get("mcp_resources", []),
		"templates": model.get("mcp_resource_templates", []),
		"prompts": model.get("mcp_prompts", []),
		"resource_presentation": model.get("mcp_resource_presentation", {}),
		"prompt_presentation": model.get("mcp_prompt_presentation", {}),
		"counts": model.get("mcp_catalog_counts", {}),
		"preview": model.get("mcp_catalog_preview", {}),
		"argument_values": _argument_values
	})


func _apply_editor_scale(scale: float) -> void:
	_current_scale = scale
	_apply_responsive_layout()
	_apply_visual_style(scale)


func _apply_responsive_layout() -> void:
	var scale := _scale()
	var narrow := size.x > 0.0 and size.x < 360.0 * scale
	var horizontal_margin := 10.0 * scale if narrow else 14.0 * scale
	_margin.add_theme_constant_override("margin_left", int(round(horizontal_margin)))
	_margin.add_theme_constant_override("margin_right", int(round(horizontal_margin)))
	_margin.add_theme_constant_override("margin_top", int(round(12 * scale)))
	_margin.add_theme_constant_override("margin_bottom", int(round(12 * scale)))
	_content.add_theme_constant_override("separation", int(round((10.0 if narrow else 12.0) * scale)))
	_view_mode_row.add_theme_constant_override("separation", int(round((4.0 if narrow else 6.0) * scale)))
	_configure_view_mode_button(_catalog_view_button, VIEW_CATALOG, 76.0 if narrow else 96.0, scale)
	_configure_view_mode_button(_diagnostics_view_button, VIEW_DIAGNOSTICS, 86.0 if narrow else 104.0, scale)


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


func _apply_visual_style(scale: float) -> void:
	begin_bulk_theme_override()
	for card in [_header_card, _resources_card, _templates_card, _prompts_card]:
		card.add_theme_stylebox_override("panel", _make_framed_panel_style())
	for margin in [_header_margin, _resources_margin, _templates_margin, _prompts_margin]:
		margin.add_theme_constant_override("margin_left", int(round(14 * scale)))
		margin.add_theme_constant_override("margin_right", int(round(14 * scale)))
		margin.add_theme_constant_override("margin_top", int(round(12 * scale)))
		margin.add_theme_constant_override("margin_bottom", int(round(12 * scale)))
	for body in [_header_body, _resources_body, _templates_body, _prompts_body]:
		body.add_theme_constant_override("separation", int(round(8 * scale)))
	for title in [_header_title, _resources_title, _templates_title, _prompts_title]:
		title.add_theme_color_override("font_color", get_theme_color("font_color", "Label"))
		title.remove_theme_font_size_override("font_size")
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_header_description.add_theme_color_override("font_color", _get_description_text_color())
	_header_counts.add_theme_color_override("font_color", _get_meta_text_color())
	_header_description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_header_counts.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
