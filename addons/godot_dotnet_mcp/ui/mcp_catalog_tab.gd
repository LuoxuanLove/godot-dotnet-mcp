@tool
extends VBoxContainer

signal copy_requested(text: String, source: String)

@onready var _margin: MarginContainer = %Margin
@onready var _content: VBoxContainer = %Content
@onready var _header_card: PanelContainer = %HeaderCard
@onready var _header_margin: MarginContainer = %HeaderMargin
@onready var _header_body: VBoxContainer = %HeaderBody
@onready var _header_title: Label = %HeaderTitle
@onready var _header_description: Label = %HeaderDescription
@onready var _header_counts: Label = %HeaderCounts
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
var _localization = null
var _catalog_mode := "resources"


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	resized.connect(_on_resized)


func set_catalog_mode(mode: String) -> void:
	_catalog_mode = mode if mode in ["resources", "prompts"] else "resources"
	_current_signature = ""


func apply_model(model: Dictionary) -> void:
	_localization = model.get("localization")
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
	_rebuild_entries(_resources_list, model.get("mcp_resources", []), "resource")
	_rebuild_entries(_templates_list, model.get("mcp_resource_templates", []), "template")
	_rebuild_entries(_prompts_list, model.get("mcp_prompts", []), "prompt")


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
	_resources_card.visible = _catalog_mode == "resources"
	_templates_card.visible = _catalog_mode == "resources"
	_prompts_card.visible = _catalog_mode == "prompts"


func _rebuild_entries(container: VBoxContainer, entries, entry_kind: String) -> void:
	for child in container.get_children():
		child.queue_free()
	if not (entries is Array) or (entries as Array).is_empty():
		container.add_child(_create_empty_label(entry_kind))
		return
	for entry in entries:
		if entry is Dictionary:
			container.add_child(_create_entry_card(entry as Dictionary, entry_kind))


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

	return panel


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


func _build_signature(model: Dictionary) -> String:
	return JSON.stringify({
		"language": str(model.get("current_language", "")),
		"mode": _catalog_mode,
		"resources": model.get("mcp_resources", []),
		"templates": model.get("mcp_resource_templates", []),
		"prompts": model.get("mcp_prompts", []),
		"counts": model.get("mcp_catalog_counts", {})
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
	_header_description.add_theme_color_override("font_color", _get_description_text_color())
	_header_counts.add_theme_color_override("font_color", _get_meta_text_color())
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
