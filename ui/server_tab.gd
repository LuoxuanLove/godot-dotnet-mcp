@tool
extends VBoxContainer

signal port_changed(value: int)
signal auto_start_toggled(enabled: bool)
signal debug_toggled(enabled: bool)
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
@onready var _debug_check: CheckBox = %DebugCheck
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
var _current_scale := -1.0


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_port_spin.value_changed.connect(_on_port_spin_changed)
	_auto_start_check.toggled.connect(_on_auto_start_check_toggled)
	_debug_check.toggled.connect(_on_debug_check_toggled)
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

	_status_section_title.text = localization.get_text("server_status")
	_settings_section_title.text = localization.get_text("settings")
	_server_state_title.text = localization.get_text("server_state_label")
	_endpoint_title.text = localization.get_text("endpoint")
	_connections_title.text = localization.get_text("active_connections")
	_requests_title.text = localization.get_text("total_requests")
	_last_request_title.text = localization.get_text("last_request")
	_port_label.text = localization.get_text("port")
	_language_label.text = localization.get_text("language")
	_auto_start_check.text = localization.get_text("auto_start")
	_debug_check.text = localization.get_text("debug_log")

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
	_debug_check.set_pressed_no_signal(bool(settings.get("debug_mode", true)))
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


func _on_auto_start_check_toggled(pressed: bool) -> void:
	auto_start_toggled.emit(pressed)


func _on_debug_check_toggled(pressed: bool) -> void:
	debug_toggled.emit(pressed)


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

	var status_grid = get_node("Scroll/Margin/Content/StatusGrid") as GridContainer
	status_grid.add_theme_constant_override("h_separation", int(round(12 * scale)))
	status_grid.add_theme_constant_override("v_separation", int(round(8 * scale)))

	var settings_grid = get_node("Scroll/Margin/Content/SettingsGrid") as GridContainer
	settings_grid.add_theme_constant_override("h_separation", int(round(12 * scale)))
	settings_grid.add_theme_constant_override("v_separation", int(round(8 * scale)))

	var language_row = get_node("Scroll/Margin/Content/LanguageRow") as HBoxContainer
	language_row.add_theme_constant_override("separation", int(round(8 * scale)))

	var buttons = get_node("Scroll/Margin/Content/Buttons") as HBoxContainer
	buttons.add_theme_constant_override("separation", int(round(8 * scale)))

	for title_label in [_server_state_title, _endpoint_title, _connections_title, _requests_title, _last_request_title]:
		title_label.custom_minimum_size.x = 96.0 * scale

	_port_spin.custom_minimum_size.y = 32.0 * scale
	_language_option.custom_minimum_size.y = 32.0 * scale

	for button in [_start_button, _restart_button, _stop_button, _full_reload_button]:
		button.custom_minimum_size.y = 32.0 * scale
