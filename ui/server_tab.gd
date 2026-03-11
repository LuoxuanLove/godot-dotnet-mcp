@tool
extends VBoxContainer

signal port_changed(value: int)
signal auto_start_toggled(enabled: bool)
signal log_level_changed(level: String)
signal permission_level_changed(level: String)
signal language_changed(language_code: String)
signal start_requested
signal restart_requested
signal stop_requested
signal full_reload_requested

@onready var _state_value: Label = %ServerStateValue
@onready var _endpoint_value: Label = %EndpointValue
@onready var _connections_value: Label = %ConnectionsValue
@onready var _requests_value: Label = %RequestsValue
@onready var _last_request_value: Label = %LastRequestValue
@onready var _port_spin: SpinBox = %PortSpin
@onready var _auto_start_check: CheckBox = %AutoStartCheck
@onready var _log_level_label: Label = %LogLevelLabel
@onready var _log_level_option: OptionButton = %LogLevelOption
@onready var _permission_level_label: Label = %PermissionLevelLabel
@onready var _permission_level_option: OptionButton = %PermissionLevelOption
@onready var _language_label: Label = %LanguageLabel
@onready var _language_option: OptionButton = %LanguageOption
@onready var _start_button: Button = %StartButton
@onready var _restart_button: Button = %RestartButton
@onready var _stop_button: Button = %StopButton
@onready var _full_reload_button: Button = %FullReloadButton
@onready var _status_section_title: Label = %StatusSectionTitle
@onready var _settings_section_title: Label = %SettingsSectionTitle
@onready var _server_state_title: Label = %ServerStateTitle
@onready var _endpoint_title: Label = %EndpointTitle
@onready var _connections_title: Label = %ConnectionsTitle
@onready var _requests_title: Label = %RequestsTitle
@onready var _last_request_title: Label = %LastRequestTitle
@onready var _port_label: Label = %PortLabel

var _language_syncing := false
var _log_level_syncing := false
var _permission_level_syncing := false
var _current_scale := -1.0
var _current_layout_width := -1.0


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	resized.connect(_on_resized)
	_port_spin.value_changed.connect(_on_port_spin_changed)
	_auto_start_check.toggled.connect(_on_auto_start_check_toggled)
	_log_level_option.item_selected.connect(_on_log_level_option_selected)
	_permission_level_option.item_selected.connect(_on_permission_level_option_selected)
	_language_option.item_selected.connect(_on_language_option_selected)
	_start_button.pressed.connect(_on_start_button_pressed)
	_restart_button.pressed.connect(_on_restart_button_pressed)
	_stop_button.pressed.connect(_on_stop_button_pressed)
	_full_reload_button.pressed.connect(_on_full_reload_button_pressed)


func apply_model(model: Dictionary) -> void:
	var localization = model.get("localization")
	var settings: Dictionary = model.get("settings", {})
	var languages: Dictionary = model.get("languages", {})
	var stats: Dictionary = model.get("stats", {})
	var is_running = bool(model.get("is_running", false))
	var editor_scale = float(model.get("editor_scale", 1.0))

	if not is_equal_approx(_current_scale, editor_scale):
		_apply_editor_scale(editor_scale)
	else:
		_apply_responsive_layout()

	_status_section_title.text = localization.get_text("server_status")
	_settings_section_title.text = localization.get_text("settings")
	_server_state_title.text = localization.get_text("server_state_label")
	_endpoint_title.text = localization.get_text("endpoint")
	_connections_title.text = localization.get_text("active_connections")
	_requests_title.text = localization.get_text("total_requests")
	_last_request_title.text = localization.get_text("last_request")
	_port_label.text = localization.get_text("port")
	_log_level_label.text = localization.get_text("log_level")
	_permission_level_label.text = localization.get_text("permission_level")
	_language_label.text = localization.get_text("language")
	_auto_start_check.text = localization.get_text("auto_start")

	_state_value.text = localization.get_text("status_running") if is_running else localization.get_text("status_stopped")
	_endpoint_value.text = "http://%s:%d/mcp" % [settings.get("host", "127.0.0.1"), int(settings.get("port", 3000))]
	_connections_value.text = "%d" % int(stats.get("active_connections", 0))
	_requests_value.text = "%d (%s %d)" % [
		int(stats.get("total_requests", 0)),
		localization.get_text("total_connections_short"),
		int(stats.get("total_connections", 0))
	]

	var last_request_at = int(stats.get("last_request_at_unix", 0))
	var last_method = str(stats.get("last_request_method", ""))
	_last_request_value.text = localization.get_text("last_request_none") if last_request_at <= 0 else "%s %s" % [
		Time.get_datetime_string_from_unix_time(last_request_at),
		last_method
	]

	_port_spin.set_value_no_signal(int(settings.get("port", 3000)))
	_auto_start_check.set_pressed_no_signal(bool(settings.get("auto_start", true)))
	_log_level_syncing = true
	_log_level_option.clear()
	var current_log_level = str(model.get("current_log_level", "info"))
	var selected_log_level = -1
	var log_levels: Array = model.get("log_levels", [])
	for log_index in range(log_levels.size()):
		var level = str(log_levels[log_index])
		var level_key = "log_level_%s" % level
		var level_text = localization.get_text(level_key)
		if level_text == level_key:
			level_text = level.capitalize()
		_log_level_option.add_item(level_text, log_index)
		_log_level_option.set_item_metadata(log_index, level)
		if level == current_log_level:
			selected_log_level = log_index
	if selected_log_level >= 0:
		_log_level_option.select(selected_log_level)
	_log_level_syncing = false

	_permission_level_syncing = true
	_permission_level_option.clear()
	var current_permission_level = str(model.get("current_permission_level", "evolution"))
	var permission_levels: Array = model.get("permission_levels", [])
	var selected_permission_level = -1
	for permission_index in range(permission_levels.size()):
		var level = str(permission_levels[permission_index])
		var level_key = "permission_level_%s" % level
		var level_text = localization.get_text(level_key)
		if level_text == level_key:
			level_text = level.capitalize()
		_permission_level_option.add_item(level_text, permission_index)
		_permission_level_option.set_item_metadata(permission_index, level)
		if level == current_permission_level:
			selected_permission_level = permission_index
	if selected_permission_level >= 0:
		_permission_level_option.select(selected_permission_level)
	_permission_level_syncing = false

	_start_button.disabled = is_running
	_restart_button.disabled = not is_running
	_stop_button.disabled = not is_running
	_start_button.text = localization.get_text("btn_start")
	_restart_button.text = localization.get_text("btn_restart")
	_stop_button.text = localization.get_text("btn_stop")
	_full_reload_button.text = localization.get_text("btn_reload_plugin")

	_language_syncing = true
	_language_option.clear()
	var current_lang = str(model.get("current_language", "en"))
	var selected_index = -1
	var language_codes = languages.keys()
	language_codes.sort()
	var index = 0
	for lang_code in language_codes:
		_language_option.add_item(localization.get_language_display_name(str(lang_code), current_lang), index)
		_language_option.set_item_metadata(index, lang_code)
		if str(lang_code) == current_lang:
			selected_index = index
		index += 1
	if selected_index >= 0:
		_language_option.select(selected_index)
	_language_syncing = false


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


func _on_permission_level_option_selected(index: int) -> void:
	if _permission_level_syncing:
		return
	permission_level_changed.emit(str(_permission_level_option.get_item_metadata(index)))


func _on_auto_start_check_toggled(pressed: bool) -> void:
	auto_start_toggled.emit(pressed)


func _on_start_button_pressed() -> void:
	start_requested.emit()


func _on_restart_button_pressed() -> void:
	restart_requested.emit()


func _on_stop_button_pressed() -> void:
	stop_requested.emit()


func _on_full_reload_button_pressed() -> void:
	full_reload_requested.emit()


func _get_margin_node() -> MarginContainer:
	return get_node_or_null("Scroll/Margin") as MarginContainer


func _get_content_node() -> VBoxContainer:
	return get_node_or_null("Scroll/Margin/Content") as VBoxContainer


func _apply_editor_scale(scale: float) -> void:
	_current_scale = scale

	var margin = _get_margin_node()
	var content = _get_content_node()
	if margin == null or content == null:
		return

	margin.add_theme_constant_override("margin_left", int(round(12 * scale)))
	margin.add_theme_constant_override("margin_right", int(round(12 * scale)))
	margin.add_theme_constant_override("margin_top", int(round(12 * scale)))
	margin.add_theme_constant_override("margin_bottom", int(round(12 * scale)))

	content.add_theme_constant_override("separation", int(round(12 * scale)))

	var status_grid = get_node("Scroll/Margin/Content/StatusCenter/StatusGrid") as GridContainer
	status_grid.add_theme_constant_override("h_separation", int(round(12 * scale)))
	status_grid.add_theme_constant_override("v_separation", int(round(8 * scale)))

	var settings_grid = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/SettingsGrid") as GridContainer
	settings_grid.add_theme_constant_override("h_separation", int(round(12 * scale)))
	settings_grid.add_theme_constant_override("v_separation", int(round(8 * scale)))

	var log_level_row = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/LogLevelRow") as GridContainer
	log_level_row.add_theme_constant_override("h_separation", int(round(8 * scale)))
	log_level_row.add_theme_constant_override("v_separation", int(round(8 * scale)))

	var permission_level_row = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/PermissionLevelRow") as GridContainer
	permission_level_row.add_theme_constant_override("h_separation", int(round(8 * scale)))
	permission_level_row.add_theme_constant_override("v_separation", int(round(8 * scale)))

	var language_row = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/LanguageRow") as GridContainer
	language_row.add_theme_constant_override("h_separation", int(round(8 * scale)))
	language_row.add_theme_constant_override("v_separation", int(round(8 * scale)))

	var buttons = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/Buttons") as GridContainer
	buttons.add_theme_constant_override("h_separation", int(round(8 * scale)))
	buttons.add_theme_constant_override("v_separation", int(round(8 * scale)))

	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	var content = _get_content_node()
	if content == null:
		return

	var available_width = content.size.x
	if available_width <= 0.0:
		available_width = size.x
	if available_width <= 0.0:
		return
	if is_equal_approx(_current_layout_width, available_width):
		return
	_current_layout_width = available_width

	var scale = _current_scale if _current_scale > 0.0 else 1.0
	var ultra_narrow_layout = available_width < 320.0 * scale
	var narrow_layout = available_width < 430.0 * scale
	var compact_layout = available_width < 520.0 * scale
	var horizontal_margin = 8.0 * scale if ultra_narrow_layout else (10.0 * scale if narrow_layout else 12.0 * scale)
	var vertical_margin = 10.0 * scale if ultra_narrow_layout else 12.0 * scale
	var section_spacing = 10.0 * scale if ultra_narrow_layout else 12.0 * scale
	var grid_h_spacing = 8.0 * scale if ultra_narrow_layout else 12.0 * scale
	var grid_v_spacing = 6.0 * scale if ultra_narrow_layout else 8.0 * scale
	var row_spacing = 6.0 * scale if ultra_narrow_layout else 8.0 * scale
	var content_width = min(available_width - horizontal_margin * 2.0, 560.0 * scale)
	content_width = max(content_width, 140.0 * scale)
	var label_width = 132.0 * scale if not narrow_layout else 96.0 * scale
	var field_width = max(120.0 * scale, content_width - label_width - int(round(8 * scale)))
	var status_grid_width = content_width
	var status_columns = 2 if not narrow_layout else 1
	var settings_columns = 2 if not narrow_layout else 1

	var margin = _get_margin_node()
	var status_center = get_node("Scroll/Margin/Content/StatusCenter") as CenterContainer
	var settings_center = get_node("Scroll/Margin/Content/SettingsCenter") as CenterContainer
	var settings_content = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent") as VBoxContainer
	var section_divider = get_node("Scroll/Margin/Content/SectionDivider") as HSeparator
	var status_grid = get_node("Scroll/Margin/Content/StatusCenter/StatusGrid") as GridContainer
	var settings_grid = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/SettingsGrid") as GridContainer
	var log_level_row = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/LogLevelRow") as GridContainer
	var permission_level_row = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/PermissionLevelRow") as GridContainer
	var language_row = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/LanguageRow") as GridContainer
	var buttons = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/Buttons") as GridContainer

	if margin != null:
		margin.add_theme_constant_override("margin_left", int(round(horizontal_margin)))
		margin.add_theme_constant_override("margin_right", int(round(horizontal_margin)))
		margin.add_theme_constant_override("margin_top", int(round(vertical_margin)))
		margin.add_theme_constant_override("margin_bottom", int(round(vertical_margin)))
	content.add_theme_constant_override("separation", int(round(section_spacing)))
	settings_content.add_theme_constant_override("separation", int(round(section_spacing)))
	status_grid.add_theme_constant_override("h_separation", int(round(grid_h_spacing)))
	status_grid.add_theme_constant_override("v_separation", int(round(grid_v_spacing)))
	settings_grid.add_theme_constant_override("h_separation", int(round(grid_h_spacing)))
	settings_grid.add_theme_constant_override("v_separation", int(round(grid_v_spacing)))
	log_level_row.add_theme_constant_override("h_separation", int(round(row_spacing)))
	log_level_row.add_theme_constant_override("v_separation", int(round(row_spacing)))
	permission_level_row.add_theme_constant_override("h_separation", int(round(row_spacing)))
	permission_level_row.add_theme_constant_override("v_separation", int(round(row_spacing)))
	language_row.add_theme_constant_override("h_separation", int(round(row_spacing)))
	language_row.add_theme_constant_override("v_separation", int(round(row_spacing)))
	buttons.add_theme_constant_override("h_separation", int(round(row_spacing)))
	buttons.add_theme_constant_override("v_separation", int(round(row_spacing)))

	status_center.custom_minimum_size.x = status_grid_width
	settings_center.custom_minimum_size.x = content_width
	settings_content.custom_minimum_size.x = content_width
	section_divider.custom_minimum_size.x = content_width
	status_grid.columns = status_columns
	settings_grid.columns = settings_columns
	log_level_row.columns = settings_columns
	permission_level_row.columns = settings_columns
	language_row.columns = settings_columns
	buttons.columns = 1 if narrow_layout else (2 if compact_layout else 3)

	var status_titles = [_server_state_title, _endpoint_title, _connections_title, _requests_title, _last_request_title]
	var settings_titles = [_port_label, _log_level_label, _permission_level_label, _language_label]
	for title_label in status_titles + settings_titles:
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var keep_width = false
		if title_label in status_titles:
			keep_width = status_columns == 2
		else:
			keep_width = settings_columns == 2
		title_label.custom_minimum_size.x = label_width if keep_width else 0.0

	for value_label in [_state_value, _endpoint_value, _connections_value, _requests_value, _last_request_value]:
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value_label.custom_minimum_size.x = field_width if status_columns == 2 else content_width

	_port_spin.custom_minimum_size.y = 32.0 * scale
	_port_spin.custom_minimum_size.x = field_width if settings_columns == 2 else content_width
	_log_level_option.custom_minimum_size.y = 32.0 * scale
	_log_level_option.custom_minimum_size.x = field_width if settings_columns == 2 else content_width
	_permission_level_option.custom_minimum_size.y = 32.0 * scale
	_permission_level_option.custom_minimum_size.x = field_width if settings_columns == 2 else content_width
	_language_option.custom_minimum_size.y = 32.0 * scale
	_language_option.custom_minimum_size.x = field_width if settings_columns == 2 else content_width
	_auto_start_check.custom_minimum_size.x = content_width

	var button_width = content_width if buttons.columns == 1 else (content_width - row_spacing * float(buttons.columns - 1)) / float(buttons.columns)
	for button in [_start_button, _restart_button, _stop_button]:
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.custom_minimum_size.x = button_width
		button.custom_minimum_size.y = (30.0 if ultra_narrow_layout else 32.0) * scale

	_full_reload_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_full_reload_button.custom_minimum_size.x = content_width
	_full_reload_button.custom_minimum_size.y = (30.0 if ultra_narrow_layout else 32.0) * scale

	for button in [_start_button, _restart_button, _stop_button, _full_reload_button]:
		button.custom_minimum_size.y = (30.0 if ultra_narrow_layout else 32.0) * scale


func _on_resized() -> void:
	_apply_responsive_layout()
