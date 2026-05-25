@tool
extends VBoxContainer

signal port_changed(value: int)
signal log_level_changed(level: String)
signal language_changed(language_code: String)
signal update_source_changed(source: String)
signal update_custom_branch_changed(branch: String)
signal update_check_requested
signal update_apply_requested

const SettingsTabModelProjectionServiceScript = preload("res://addons/godot_dotnet_mcp/ui/settings_tab_model_projection.gd")
const LAYOUT_WIDTH_BUCKET := 48.0
const SETTING_LABEL_WIDTH := 112.0
const SETTING_FIELD_WIDTH := 150.0
const UPDATE_APPLY_FALLBACK_TEXT := "同步"
const UPDATE_DESCRIPTION_FALLBACK_ZH := "选择更新方式后会自动发现 GitHub 分支、发布版和标签，然后可同步选中目标。"
const UPDATE_DESCRIPTION_FALLBACK_EN := "Choose an update mode; branches, releases, and tags are discovered automatically."
const UPDATE_DESCRIPTION_AUTO_ZH := "选择更新方式后会自动发现 GitHub 分支、发布版和标签，然后可同步选中目标。"
const UPDATE_DESCRIPTION_AUTO_EN := "Choose an update mode; branches, releases, and tags are discovered automatically."

@onready var _margin: MarginContainer = %Margin
@onready var _content: VBoxContainer = %Content
@onready var _general_card: PanelContainer = %GeneralCard
@onready var _general_card_margin: MarginContainer = %GeneralCardMargin
@onready var _general_card_body: VBoxContainer = %GeneralCardBody
@onready var _general_title: Label = %GeneralTitle
@onready var _port_label: Label = %PortLabel
@onready var _port_spin: SpinBox = %PortSpin
@onready var _log_level_label: Label = %LogLevelLabel
@onready var _log_level_option: OptionButton = %LogLevelOption
@onready var _language_label: Label = %LanguageLabel
@onready var _language_option: OptionButton = %LanguageOption
@onready var _updates_card: PanelContainer = %UpdatesCard
@onready var _updates_card_margin: MarginContainer = %UpdatesCardMargin
@onready var _updates_card_body: VBoxContainer = %UpdatesCardBody
@onready var _updates_title: Label = %UpdatesTitle
@onready var _updates_description: Label = %UpdatesDescription
@onready var _source_option_label: Label = %SourceOptionLabel
@onready var _source_option: OptionButton = %SourceOption
@onready var _custom_branch_row: HBoxContainer = %CustomBranchRow
@onready var _custom_branch_label: Label = %CustomBranchLabel
@onready var _custom_branch_value: OptionButton = %CustomBranchValue
@onready var _updates_status: Label = %UpdatesStatus
@onready var _check_button: Button = %CheckButton
@onready var _prepare_button: Button = %PrepareButton
@onready var _apply_button: Button = %ApplyButton

var _language_syncing := false
var _log_level_syncing := false
var _source_syncing := false
var _custom_branch_syncing := false
var _current_scale := -1.0
var _current_layout_key := -1
var _layout_update_queued := false
var _projection_service := SettingsTabModelProjectionServiceScript.new()


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	resized.connect(_on_resized)
	_port_spin.value_changed.connect(_on_port_spin_changed)
	_log_level_option.item_selected.connect(_on_log_level_option_selected)
	_language_option.item_selected.connect(_on_language_option_selected)
	_source_option.item_selected.connect(_on_source_option_selected)
	_custom_branch_value.item_selected.connect(_on_custom_branch_option_selected)
	_check_button.pressed.connect(_on_check_button_pressed)
	_apply_button.pressed.connect(_on_apply_button_pressed)
	_check_button.text = ""
	_check_button.visible = false
	_check_button.disabled = true
	_prepare_button.text = ""
	_prepare_button.visible = false
	_prepare_button.disabled = true
	_apply_button.text = UPDATE_APPLY_FALLBACK_TEXT
	_apply_button.disabled = true
	_apply_fill_width_flags()


func apply_model(model: Dictionary) -> void:
	if not is_node_ready() or not _has_required_controls():
		return
	var localization = model.get("localization")
	if localization == null:
		return
	var editor_scale := float(model.get("editor_scale", 1.0))
	if not is_equal_approx(_current_scale, editor_scale):
		_apply_editor_scale(editor_scale)
	else:
		_apply_responsive_layout()

	var projection: Dictionary = _projection_service.project(model)
	var settings: Dictionary = projection.get("settings", {})
	var options: Dictionary = projection.get("options", {})
	var updates: Dictionary = projection.get("updates", {})

	_general_title.text = localization.get_text("settings_general_title")
	_port_label.text = localization.get_text("port")
	_log_level_label.text = localization.get_text("log_level")
	_language_label.text = localization.get_text("language")
	_updates_title.text = localization.get_text("settings_updates_title")
	_updates_description.text = _get_update_description_text(localization)
	_source_option_label.text = localization.get_text("settings_update_source_label")
	_custom_branch_label.text = localization.get_text("settings_update_custom_branch")
	_check_button.text = ""
	_check_button.visible = false
	_prepare_button.text = ""
	_apply_button.text = _get_update_apply_text(localization)

	_port_spin.set_value_no_signal(int(settings.get("port", 3000)))
	_log_level_syncing = true
	_apply_projected_options(_log_level_option, options.get("log_levels", []))
	_log_level_syncing = false
	_language_syncing = true
	_apply_projected_options(_language_option, options.get("languages", []))
	_language_syncing = false
	_source_syncing = true
	_apply_projected_options(_source_option, options.get("update_sources", []))
	_source_syncing = false
	_custom_branch_syncing = true
	_apply_projected_options(_custom_branch_value, options.get("update_branches", []))
	_custom_branch_syncing = false

	_updates_status.text = str(updates.get("status_text", ""))
	var update_source := str(updates.get("source", "latest_stable"))
	_apply_update_source_rows(update_source)
	_check_button.disabled = true
	_prepare_button.disabled = true
	_prepare_button.visible = false
	_apply_button.disabled = not bool(updates.get("apply_enabled", false))


func _has_required_controls() -> bool:
	for control in [
		_margin,
		_content,
		_general_card,
		_general_title,
		_port_label,
		_port_spin,
		_log_level_label,
		_log_level_option,
		_language_label,
		_language_option,
		_updates_card,
		_updates_title,
		_updates_description,
		_source_option_label,
		_source_option,
		_custom_branch_row,
		_custom_branch_label,
		_custom_branch_value,
		_updates_status,
		_check_button,
		_prepare_button,
		_apply_button,
	]:
		if control == null:
			return false
	return true


func _apply_fill_width_flags() -> void:
	for control in [
		_content,
		_general_card,
		_updates_card,
		_port_spin,
		_log_level_option,
		_language_option,
		_source_option,
		_custom_branch_value,
		_check_button,
		_prepare_button,
		_apply_button,
	]:
		if control != null:
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _get_update_apply_text(localization) -> String:
	var text := str(localization.get_text("settings_update_apply"))
	if text == "应用":
		return UPDATE_APPLY_FALLBACK_TEXT
	return text


func _get_update_description_text(localization) -> String:
	var text := str(localization.get_text("settings_updates_description"))
	if text.contains("准备和应用暂未实现"):
		return UPDATE_DESCRIPTION_AUTO_ZH
	if text.contains("点击检查"):
		return UPDATE_DESCRIPTION_AUTO_ZH
	if text.contains("Check"):
		return UPDATE_DESCRIPTION_AUTO_EN
	return text


func _apply_update_source_rows(source: String) -> void:
	if _custom_branch_row != null:
		_custom_branch_row.visible = source == "custom_branch"


func _apply_projected_options(option_button: OptionButton, projected_items: Array) -> void:
	option_button.clear()
	var selected_index := -1
	for item_index in range(projected_items.size()):
		var item: Dictionary = projected_items[item_index]
		option_button.add_item(str(item.get("text", "")), item_index)
		option_button.set_item_metadata(item_index, item.get("value", ""))
		option_button.set_item_disabled(item_index, bool(item.get("disabled", false)))
		if bool(item.get("selected", false)):
			selected_index = item_index
	if selected_index >= 0:
		option_button.select(selected_index)
	elif option_button.get_item_count() > 0:
		option_button.select(0)


func _on_port_spin_changed(value: float) -> void:
	port_changed.emit(int(value))


func _on_language_option_selected(index: int) -> void:
	if _language_syncing:
		return
	language_changed.emit(str(_language_option.get_item_metadata(index)))


func _on_log_level_option_selected(index: int) -> void:
	if _log_level_syncing:
		return
	log_level_changed.emit(str(_log_level_option.get_item_metadata(index)))


func _on_source_option_selected(index: int) -> void:
	if _source_syncing:
		return
	var source := str(_source_option.get_item_metadata(index))
	_apply_update_source_rows(source)
	update_source_changed.emit(source)


func _on_custom_branch_option_selected(index: int) -> void:
	if _custom_branch_syncing:
		return
	var branch := str(_custom_branch_value.get_item_metadata(index))
	if branch.is_empty():
		return
	update_custom_branch_changed.emit(branch)



func _on_check_button_pressed() -> void:
	update_check_requested.emit()


func _on_apply_button_pressed() -> void:
	update_apply_requested.emit()


func _apply_editor_scale(scale: float) -> void:
	_current_scale = scale
	_current_layout_key = -1
	_margin.add_theme_constant_override("margin_left", int(round(12 * scale)))
	_margin.add_theme_constant_override("margin_right", int(round(12 * scale)))
	_margin.add_theme_constant_override("margin_top", int(round(12 * scale)))
	_margin.add_theme_constant_override("margin_bottom", int(round(12 * scale)))
	_content.add_theme_constant_override("separation", int(round(12 * scale)))
	_apply_visual_style(scale)
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	var available_width: float = _content.size.x
	if available_width <= 0.0:
		available_width = size.x
	if available_width <= 0.0:
		return
	var scale: float = _current_scale if _current_scale > 0.0 else 1.0
	var bucket_size: float = max(16.0, LAYOUT_WIDTH_BUCKET * scale)
	var layout_bucket: int = int(floor(available_width / bucket_size))
	var ultra_narrow_layout: bool = available_width < 360.0 * scale
	var narrow_layout: bool = available_width < 560.0 * scale
	var layout_key := layout_bucket * 100 + (1 if ultra_narrow_layout else 0) + (2 if narrow_layout else 0)
	if _current_layout_key == layout_key:
		return
	_current_layout_key = layout_key

	var horizontal_margin: float = 10.0 * scale if ultra_narrow_layout else (12.0 * scale if narrow_layout else 14.0 * scale)
	var row_spacing: float = 6.0 * scale if ultra_narrow_layout else 8.0 * scale
	var label_width: float = SETTING_LABEL_WIDTH * scale
	var field_width: float = SETTING_FIELD_WIDTH * scale
	for card_margin in [_general_card_margin, _updates_card_margin]:
		card_margin.add_theme_constant_override("margin_left", int(round(horizontal_margin)))
		card_margin.add_theme_constant_override("margin_right", int(round(horizontal_margin)))
		card_margin.add_theme_constant_override("margin_top", int(round(12 * scale)))
		card_margin.add_theme_constant_override("margin_bottom", int(round(12 * scale)))
	for row in _get_setting_rows():
		row.add_theme_constant_override("separation", int(round(row_spacing)))
	for label in [_port_label, _log_level_label, _language_label, _source_option_label, _custom_branch_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.custom_minimum_size.x = label_width
	for field in [_port_spin, _log_level_option, _language_option, _source_option, _custom_branch_value]:
		field.custom_minimum_size.x = field_width
		field.custom_minimum_size.y = 0.0
	for button in [_check_button, _prepare_button, _apply_button]:
		button.custom_minimum_size.x = 0.0
		button.custom_minimum_size.y = 0.0


func _apply_visual_style(scale: float) -> void:
	begin_bulk_theme_override()
	_general_card.add_theme_stylebox_override("panel", _make_theme_panel_style(scale))
	_updates_card.add_theme_stylebox_override("panel", _make_theme_panel_style(scale))
	for card_body in [_general_card_body, _updates_card_body]:
		card_body.add_theme_constant_override("separation", int(round(10 * scale)))
	for title in [_general_title, _updates_title]:
		title.add_theme_color_override("font_color", get_theme_color("font_color", "Label"))
		title.remove_theme_font_size_override("font_size")
	for label in [_port_label, _log_level_label, _language_label, _source_option_label, _custom_branch_label]:
		label.add_theme_color_override("font_color", _get_muted_text_color())
	for label in [_updates_description, _updates_status]:
		label.add_theme_color_override("font_color", get_theme_color("font_color", "Label"))
	end_bulk_theme_override()


func _make_theme_panel_style(_scale: float) -> StyleBox:
	var style := get_theme_stylebox("panel", "PanelContainer").duplicate() as StyleBox
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style


func _get_setting_rows() -> Array[HBoxContainer]:
	return [
		%PortRow,
		%LogLevelRow,
		%LanguageRow,
		%UpdateSourceRow,
		%CustomBranchRow,
		%UpdateButtonsRow,
	]


func _get_muted_text_color() -> Color:
	return get_theme_color("font_disabled_color", "Editor")


func _on_resized() -> void:
	if _layout_update_queued:
		return
	_layout_update_queued = true
	call_deferred("_apply_queued_responsive_layout")


func _apply_queued_responsive_layout() -> void:
	_layout_update_queued = false
	_apply_responsive_layout()
