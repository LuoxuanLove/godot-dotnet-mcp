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
signal bridge_install_requested
signal bridge_validate_requested
signal bridge_clear_requested
signal copy_requested(text: String, source: String)

@onready var _self_diag_title: Label = %SelfDiagnosticsTitle
@onready var _self_diag_badge: Label = %SelfDiagnosticsBadge
@onready var _self_diag_copy_button: Button = %SelfDiagnosticsCopyButton
@onready var _self_diag_summary: Label = %SelfDiagnosticsSummary
@onready var _self_diag_details: Label = %SelfDiagnosticsDetails
@onready var _self_diag_divider: HSeparator = %SelfDiagnosticsDivider
@onready var _bridge_section_divider: HSeparator = %BridgeSectionDivider
@onready var _bridge_section_title: Label = %BridgeSectionTitle
@onready var _bridge_status_title: Label = %BridgeStatusTitle
@onready var _bridge_status_value: Label = %BridgeStatusValue
@onready var _bridge_path_title: Label = %BridgePathTitle
@onready var _bridge_path_value: Label = %BridgePathValue
@onready var _bridge_version_title: Label = %BridgeVersionTitle
@onready var _bridge_version_value: Label = %BridgeVersionValue
@onready var _bridge_message_title: Label = %BridgeMessageTitle
@onready var _bridge_message_value: Label = %BridgeMessageValue
@onready var _bridge_command_title: Label = %BridgeCommandTitle
@onready var _bridge_command_value: Label = %BridgeCommandValue
@onready var _bridge_install_button: Button = %BridgeInstallButton
@onready var _bridge_validate_button: Button = %BridgeValidateButton
@onready var _bridge_clear_button: Button = %BridgeClearButton
@onready var _overview_buttons: GridContainer = %OverviewButtons
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
@onready var _full_reload_button: Button = %FullReloadButton
@onready var _status_section_title: Label = %StatusSectionTitle
@onready var _settings_section_title: Label = %SettingsSectionTitle
@onready var _advanced_section_title: Label = %AdvancedSectionTitle
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
var _self_diag_copy_text := ""
var _is_running := false


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
	_full_reload_button.pressed.connect(_on_full_reload_button_pressed)
	_bridge_install_button.pressed.connect(_on_bridge_install_button_pressed)
	_bridge_validate_button.pressed.connect(_on_bridge_validate_button_pressed)
	_bridge_clear_button.pressed.connect(_on_bridge_clear_button_pressed)
	_self_diag_copy_button.pressed.connect(_on_self_diag_copy_pressed)


func apply_model(model: Dictionary) -> void:
	var localization = model.get("localization")
	var settings: Dictionary = model.get("settings", {})
	var languages: Dictionary = model.get("languages", {})
	var stats: Dictionary = model.get("stats", {})
	var self_diagnostics: Dictionary = model.get("self_diagnostics", {})
	var bridge_install: Dictionary = model.get("bridge_install", {})
	var is_running = bool(model.get("is_running", false))
	var editor_scale = float(model.get("editor_scale", 1.0))
	_is_running = is_running

	if not is_equal_approx(_current_scale, editor_scale):
		_apply_editor_scale(editor_scale)
	else:
		_apply_responsive_layout()

	_apply_self_diagnostics(model, localization)
	_apply_bridge_install(bridge_install, localization)
	_status_section_title.text = localization.get_text("plugin_overview_title")
	_settings_section_title.text = localization.get_text("settings")
	_advanced_section_title.text = localization.get_text("advanced_settings")
	_server_state_title.text = localization.get_text("plugin_overview_health_label")
	_endpoint_title.text = localization.get_text("plugin_overview_service_label")
	_connections_title.text = localization.get_text("plugin_overview_bridge_label")
	_requests_title.text = localization.get_text("plugin_overview_config_label")
	_last_request_title.text = localization.get_text("plugin_overview_activity_label")
	_port_label.text = localization.get_text("port")
	_log_level_label.text = localization.get_text("log_level")
	_permission_level_label.text = localization.get_text("permission_level")
	_language_label.text = localization.get_text("language")
	_auto_start_check.text = localization.get_text("auto_start")

	_state_value.text = _build_overview_health_text(self_diagnostics, localization)
	_endpoint_value.text = _build_overview_service_text(is_running, settings, localization)
	_connections_value.text = _build_overview_bridge_text(bridge_install, localization)
	_requests_value.text = _build_overview_config_text(model, localization)
	_last_request_value.text = _build_overview_activity_text(stats, localization)

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

	_start_button.disabled = false
	_restart_button.disabled = not is_running
	_start_button.text = localization.get_text("btn_close") if is_running else localization.get_text("btn_start")
	_restart_button.text = localization.get_text("btn_restart")
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


func _apply_bridge_install(bridge_install: Dictionary, localization) -> void:
	var bridge_state = str(bridge_install.get("install_state", "not_configured"))
	var bridge_path = str(bridge_install.get("executable_path", ""))
	var bridge_version = str(bridge_install.get("install_version", ""))
	var bridge_message = str(bridge_install.get("install_message", ""))
	var launch_command = str(bridge_install.get("launch_command", ""))

	_bridge_section_title.text = localization.get_text("bridge_section_title")
	_bridge_status_title.text = localization.get_text("bridge_install_status_label")
	_bridge_path_title.text = localization.get_text("bridge_install_path_label")
	_bridge_version_title.text = localization.get_text("bridge_install_version_label")
	_bridge_message_title.text = localization.get_text("bridge_install_message_label")
	_bridge_command_title.text = localization.get_text("bridge_install_command_label")
	_bridge_install_button.text = localization.get_text("bridge_install_select_button")
	_bridge_validate_button.text = localization.get_text("bridge_install_validate_button")
	_bridge_clear_button.text = localization.get_text("bridge_install_clear_button")

	_bridge_status_value.text = _resolve_bridge_state_text(bridge_state, localization)
	_bridge_path_value.text = bridge_path if not bridge_path.is_empty() else localization.get_text("bridge_install_not_configured")
	_bridge_version_value.text = bridge_version if not bridge_version.is_empty() else "-"
	_bridge_message_value.text = bridge_message if not bridge_message.is_empty() else "-"
	_bridge_command_value.text = launch_command if not launch_command.is_empty() else "-"

	var has_path = not bridge_path.is_empty()
	_bridge_validate_button.disabled = not has_path
	_bridge_clear_button.disabled = not has_path


func _resolve_bridge_state_text(bridge_state: String, localization) -> String:
	match bridge_state:
		"installed":
			return localization.get_text("bridge_install_installed")
		"validating":
			return localization.get_text("bridge_install_validating")
		"invalid":
			return localization.get_text("bridge_install_invalid")
		_:
			return localization.get_text("bridge_install_not_configured")


func _build_overview_health_text(self_diagnostics: Dictionary, localization) -> String:
	var status = str(self_diagnostics.get("status", "ok"))
	var summary = str(self_diagnostics.get("summary", ""))
	var active_incidents = int(self_diagnostics.get("active_incident_count", 0))
	var status_text = status.capitalize()
	if localization != null:
		var translated_status_key = "self_diag_status_%s" % status
		var translated_status = localization.get_text(translated_status_key)
		if translated_status != translated_status_key:
			status_text = translated_status
	if active_incidents > 0:
		return "%s · %s (%d)" % [status_text, summary, active_incidents]
	return "%s · %s" % [status_text, summary]


func _build_overview_service_text(is_running: bool, settings: Dictionary, localization) -> String:
	var service_state = localization.get_text("status_running") if is_running else localization.get_text("status_stopped")
	var endpoint = "http://%s:%d/mcp" % [settings.get("host", "127.0.0.1"), int(settings.get("port", 3000))]
	return "%s · %s" % [service_state, endpoint]


func _build_overview_bridge_text(bridge_install: Dictionary, localization) -> String:
	var bridge_state = _resolve_bridge_state_text(str(bridge_install.get("install_state", "not_configured")), localization)
	var bridge_version = str(bridge_install.get("install_version", ""))
	var bridge_path = str(bridge_install.get("executable_path", ""))
	var path_summary = bridge_path.get_file() if not bridge_path.is_empty() else localization.get_text("bridge_install_not_configured")
	if not bridge_version.is_empty():
		return "%s · %s · %s" % [bridge_state, bridge_version, path_summary]
	return "%s · %s" % [bridge_state, path_summary]


func _build_overview_config_text(model: Dictionary, localization) -> String:
	var profile_id = str(model.get("tool_profile_id", "default"))
	var permission_level = str(model.get("current_permission_level", PluginRuntimeState.PERMISSION_EVOLUTION))
	var log_level = str(model.get("current_log_level", "info"))
	var current_language = str(model.get("current_language", "en"))
	var profile_text = _get_overview_profile_text(profile_id, localization)
	var permission_text = localization.get_text("permission_level_%s" % permission_level)
	if permission_text == "permission_level_%s" % permission_level:
		permission_text = permission_level.capitalize()
	var log_text = localization.get_text("log_level_%s" % log_level)
	if log_text == "log_level_%s" % log_level:
		log_text = log_level.capitalize()
	var language_text = _get_overview_language_text(current_language, localization)
	return "%s · %s · %s · %s" % [profile_text, permission_text, log_text, language_text]


func _get_overview_profile_text(profile_id: String, localization) -> String:
	match profile_id:
		"slim":
			return localization.get_text("tool_profile_slim")
		"default", "":
			return localization.get_text("tool_profile_default")
		"full":
			return localization.get_text("tool_profile_full")
		_:
			return localization.get_text("tool_profile_custom_short")


func _get_overview_language_text(current_language: String, localization) -> String:
	if current_language.is_empty():
		return localization.get_text("language_name_en")
	var language_key = "language_name_%s" % current_language
	var language_text = localization.get_text_for(current_language, language_key)
	if language_text == language_key:
		return current_language.capitalize()
	return language_text


func _build_overview_activity_text(stats: Dictionary, localization) -> String:
	var active_connections = int(stats.get("active_connections", 0))
	var total_requests = int(stats.get("total_requests", 0))
	var total_connections = int(stats.get("total_connections", 0))
	var last_request_at = int(stats.get("last_request_at_unix", 0))
	var last_method = str(stats.get("last_request_method", ""))
	var last_request_text = localization.get_text("last_request_none") if last_request_at <= 0 else "%s %s" % [
		Time.get_datetime_string_from_unix_time(last_request_at),
		last_method
	]
	var parts: PackedStringArray = PackedStringArray()
	parts.append("%d / %d" % [active_connections, total_requests])
	parts.append("%d %s" % [total_connections, localization.get_text("total_connections_short")])
	parts.append(last_request_text)
	return " · ".join(parts)


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
	if _is_running:
		stop_requested.emit()
	else:
		start_requested.emit()


func _on_restart_button_pressed() -> void:
	restart_requested.emit()


func _on_full_reload_button_pressed() -> void:
	full_reload_requested.emit()


func _on_bridge_install_button_pressed() -> void:
	bridge_install_requested.emit()


func _on_bridge_validate_button_pressed() -> void:
	bridge_validate_requested.emit()


func _on_bridge_clear_button_pressed() -> void:
	bridge_clear_requested.emit()


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
	var overview_buttons = get_node("Scroll/Margin/Content/OverviewButtonsCenter/OverviewButtons") as GridContainer
	var self_diag_header = get_node("Scroll/Margin/Content/SelfDiagnosticsHeader") as HBoxContainer
	var bridge_content = get_node("Scroll/Margin/Content/BridgeContentCenter/BridgeContent") as VBoxContainer
	var bridge_status_row = get_node("Scroll/Margin/Content/BridgeContentCenter/BridgeContent/BridgeStatusRow") as GridContainer
	var bridge_buttons = get_node("Scroll/Margin/Content/BridgeContentCenter/BridgeContent/BridgeButtons") as HBoxContainer
	status_grid.add_theme_constant_override("h_separation", int(round(12 * scale)))
	status_grid.add_theme_constant_override("v_separation", int(round(8 * scale)))
	overview_buttons.add_theme_constant_override("separation", int(round(8 * scale)))
	self_diag_header.add_theme_constant_override("separation", int(round(8 * scale)))
	bridge_content.add_theme_constant_override("separation", int(round(8 * scale)))
	bridge_status_row.add_theme_constant_override("h_separation", int(round(12 * scale)))
	bridge_status_row.add_theme_constant_override("v_separation", int(round(8 * scale)))
	bridge_buttons.add_theme_constant_override("separation", int(round(8 * scale)))

	var settings_grid = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/SettingsGrid") as GridContainer
	settings_grid.add_theme_constant_override("h_separation", int(round(12 * scale)))
	settings_grid.add_theme_constant_override("v_separation", int(round(8 * scale)))

	var log_level_row = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/LogLevelRow") as GridContainer
	log_level_row.add_theme_constant_override("h_separation", int(round(8 * scale)))
	log_level_row.add_theme_constant_override("v_separation", int(round(8 * scale)))

	var permission_level_row = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/AdvancedContent/PermissionLevelRow") as GridContainer
	permission_level_row.add_theme_constant_override("h_separation", int(round(8 * scale)))
	permission_level_row.add_theme_constant_override("v_separation", int(round(8 * scale)))

	var language_row = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/LanguageRow") as GridContainer
	language_row.add_theme_constant_override("h_separation", int(round(8 * scale)))
	language_row.add_theme_constant_override("v_separation", int(round(8 * scale)))

	var advanced_content = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/AdvancedContent") as VBoxContainer
	advanced_content.add_theme_constant_override("separation", int(round(8 * scale)))

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
	var overview_buttons_center = get_node("Scroll/Margin/Content/OverviewButtonsCenter") as CenterContainer
	var overview_buttons = get_node("Scroll/Margin/Content/OverviewButtonsCenter/OverviewButtons") as GridContainer
	var bridge_center = get_node("Scroll/Margin/Content/BridgeContentCenter") as CenterContainer
	var bridge_content = get_node("Scroll/Margin/Content/BridgeContentCenter/BridgeContent") as VBoxContainer
	var settings_center = get_node("Scroll/Margin/Content/SettingsCenter") as CenterContainer
	var settings_content = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent") as VBoxContainer
	var section_divider = get_node("Scroll/Margin/Content/SectionDivider") as HSeparator
	var bridge_divider = get_node("Scroll/Margin/Content/BridgeSectionDivider") as HSeparator
	var status_grid = get_node("Scroll/Margin/Content/StatusCenter/StatusGrid") as GridContainer
	var bridge_status_row = get_node("Scroll/Margin/Content/BridgeContentCenter/BridgeContent/BridgeStatusRow") as GridContainer
	var bridge_buttons = get_node("Scroll/Margin/Content/BridgeContentCenter/BridgeContent/BridgeButtons") as HBoxContainer
	var settings_grid = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/SettingsGrid") as GridContainer
	var log_level_row = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/LogLevelRow") as GridContainer
	var advanced_content = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/AdvancedContent") as VBoxContainer
	var permission_level_row = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/AdvancedContent/PermissionLevelRow") as GridContainer
	var language_row = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/LanguageRow") as GridContainer

	if margin != null:
		margin.add_theme_constant_override("margin_left", int(round(horizontal_margin)))
		margin.add_theme_constant_override("margin_right", int(round(horizontal_margin)))
		margin.add_theme_constant_override("margin_top", int(round(vertical_margin)))
		margin.add_theme_constant_override("margin_bottom", int(round(vertical_margin)))
	content.add_theme_constant_override("separation", int(round(section_spacing)))
	overview_buttons.add_theme_constant_override("separation", int(round(row_spacing)))
	bridge_content.add_theme_constant_override("separation", int(round(section_spacing)))
	settings_content.add_theme_constant_override("separation", int(round(section_spacing)))
	status_grid.add_theme_constant_override("h_separation", int(round(grid_h_spacing)))
	status_grid.add_theme_constant_override("v_separation", int(round(grid_v_spacing)))
	bridge_status_row.add_theme_constant_override("h_separation", int(round(grid_h_spacing)))
	bridge_status_row.add_theme_constant_override("v_separation", int(round(grid_v_spacing)))
	bridge_buttons.add_theme_constant_override("separation", int(round(row_spacing)))
	settings_grid.add_theme_constant_override("h_separation", int(round(grid_h_spacing)))
	settings_grid.add_theme_constant_override("v_separation", int(round(grid_v_spacing)))
	log_level_row.add_theme_constant_override("h_separation", int(round(row_spacing)))
	log_level_row.add_theme_constant_override("v_separation", int(round(row_spacing)))
	permission_level_row.add_theme_constant_override("h_separation", int(round(row_spacing)))
	permission_level_row.add_theme_constant_override("v_separation", int(round(row_spacing)))
	language_row.add_theme_constant_override("h_separation", int(round(row_spacing)))
	language_row.add_theme_constant_override("v_separation", int(round(row_spacing)))
	advanced_content.add_theme_constant_override("separation", int(round(section_spacing * 0.75)))

	status_center.custom_minimum_size.x = status_grid_width
	overview_buttons_center.custom_minimum_size.x = content_width
	overview_buttons.custom_minimum_size.x = content_width
	bridge_center.custom_minimum_size.x = content_width
	bridge_content.custom_minimum_size.x = content_width
	settings_center.custom_minimum_size.x = content_width
	settings_content.custom_minimum_size.x = content_width
	section_divider.custom_minimum_size.x = content_width
	bridge_divider.custom_minimum_size.x = content_width
	status_grid.columns = status_columns
	overview_buttons.columns = 1 if narrow_layout else (2 if compact_layout else 3)
	bridge_status_row.columns = 2 if not narrow_layout else 1
	settings_grid.columns = settings_columns
	log_level_row.columns = settings_columns
	permission_level_row.columns = settings_columns
	language_row.columns = settings_columns

	var status_titles = [_server_state_title, _endpoint_title, _connections_title, _requests_title, _last_request_title]
	var settings_titles = [_port_label, _log_level_label, _language_label]
	for title_label in status_titles + settings_titles:
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var keep_width = false
		if title_label in status_titles:
			keep_width = status_columns == 2
		else:
			keep_width = settings_columns == 2
		title_label.custom_minimum_size.x = label_width if keep_width else 0.0

	_permission_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_permission_level_label.custom_minimum_size.x = label_width if settings_columns == 2 else 0.0
	_advanced_section_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_advanced_section_title.custom_minimum_size.x = content_width

	for value_label in [_state_value, _endpoint_value, _connections_value, _requests_value, _last_request_value]:
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value_label.custom_minimum_size.x = field_width if status_columns == 2 else content_width

	for title_label in [_bridge_status_title, _bridge_path_title, _bridge_version_title, _bridge_message_title, _bridge_command_title]:
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_label.custom_minimum_size.x = label_width if bridge_status_row.columns == 2 else 0.0

	for value_label in [_bridge_status_value, _bridge_path_value, _bridge_version_value, _bridge_message_value, _bridge_command_value]:
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value_label.custom_minimum_size.x = field_width if bridge_status_row.columns == 2 else content_width

	_port_spin.custom_minimum_size.y = 32.0 * scale
	_port_spin.custom_minimum_size.x = field_width if settings_columns == 2 else content_width
	_log_level_option.custom_minimum_size.y = 32.0 * scale
	_log_level_option.custom_minimum_size.x = field_width if settings_columns == 2 else content_width
	_permission_level_option.custom_minimum_size.y = 32.0 * scale
	_permission_level_option.custom_minimum_size.x = field_width if settings_columns == 2 else content_width
	_language_option.custom_minimum_size.y = 32.0 * scale
	_language_option.custom_minimum_size.x = field_width if settings_columns == 2 else content_width
	_auto_start_check.custom_minimum_size.x = content_width
	_auto_start_check.custom_minimum_size.y = 32.0 * scale

	var button_width = content_width if overview_buttons.columns == 1 else (content_width - row_spacing * float(overview_buttons.columns - 1)) / float(overview_buttons.columns)
	for button in [_start_button, _restart_button, _full_reload_button]:
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.custom_minimum_size.x = button_width
		button.custom_minimum_size.y = (30.0 if ultra_narrow_layout else 32.0) * scale

	for button in [_bridge_install_button, _bridge_validate_button, _bridge_clear_button]:
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.custom_minimum_size.x = content_width if overview_buttons.columns == 1 else button_width
		button.custom_minimum_size.y = (30.0 if ultra_narrow_layout else 32.0) * scale
	_self_diag_copy_button.custom_minimum_size.y = (30.0 if ultra_narrow_layout else 32.0) * scale
	_self_diag_copy_button.custom_minimum_size.x = 72.0 * scale


func _on_resized() -> void:
	_apply_responsive_layout()


func _apply_self_diagnostics(model: Dictionary, localization) -> void:
	var diagnostics = model.get("self_diagnostics", {})
	_self_diag_copy_text = str(model.get("self_diagnostic_copy_text", ""))
	_self_diag_title.text = localization.get_text("self_diag_title")
	_self_diag_copy_button.text = localization.get_text("self_diag_copy")

	if not (diagnostics is Dictionary) or (diagnostics as Dictionary).is_empty():
		_self_diag_badge.text = ""
		_self_diag_summary.text = localization.get_text("self_diag_empty")
		_self_diag_details.text = ""
		return

	var diag := diagnostics as Dictionary
	var status = str(diag.get("status", "ok"))
	var badge_color = _get_self_diag_status_color(status)
	_self_diag_badge.text = _get_self_diag_status_text(status, localization)
	_self_diag_badge.add_theme_color_override("font_color", badge_color)

	var active_incidents = int(diag.get("active_incident_count", 0))
	var tool_loader = diag.get("tool_loader", {})
	var tool_load_error_count = 0
	if tool_loader is Dictionary:
		tool_load_error_count = int((tool_loader as Dictionary).get("tool_load_error_count", 0))
	var last_operation_text = localization.get_text("self_diag_last_operation_none")
	var last_operation = diag.get("last_operation", {})
	if last_operation is Dictionary and not (last_operation as Dictionary).is_empty():
		last_operation_text = "%s (%s ms)" % [
			str((last_operation as Dictionary).get("kind", "")),
			str((last_operation as Dictionary).get("duration_ms", 0.0))
		]

	_self_diag_summary.text = "%s | %s | %s" % [
		localization.get_text("self_diag_active_incidents") % active_incidents,
		localization.get_text("self_diag_tool_load_errors") % tool_load_error_count,
		localization.get_text("self_diag_last_operation") % last_operation_text
	]

	var recent_lines: Array[String] = []
	for incident in diag.get("recent_incidents", []):
		if not (incident is Dictionary):
			continue
		var incident_dict := incident as Dictionary
		recent_lines.append("%s | %s | %s" % [
			_get_self_diag_category_text(str(incident_dict.get("category", "")), localization),
			_get_self_diag_code_text(str(incident_dict.get("code", "")), localization),
			str(incident_dict.get("message", ""))
		])
		if recent_lines.size() >= 3:
			break
	if recent_lines.is_empty():
		_self_diag_details.text = localization.get_text("self_diag_empty")
	else:
		_self_diag_details.text = "\n".join(recent_lines)


func _get_self_diag_status_text(status: String, localization) -> String:
	match status:
		"error":
			return localization.get_text("self_diag_status_error")
		"warning":
			return localization.get_text("self_diag_status_warning")
		_:
			return localization.get_text("self_diag_status_ok")


func _get_self_diag_status_color(status: String) -> Color:
	match status:
		"error":
			return Color(0.9, 0.3, 0.3)
		"warning":
			return Color(0.95, 0.7, 0.2)
		_:
			return Color(0.2, 0.8, 0.2)


func _get_self_diag_category_text(category: String, localization) -> String:
	var key = "self_diag_category_%s" % category
	var translated = localization.get_text(key)
	return translated if translated != key else category


func _get_self_diag_code_text(code: String, localization) -> String:
	var key = "self_diag_code_%s" % code
	var translated = localization.get_text(key)
	return translated if translated != key else code


func _on_self_diag_copy_pressed() -> void:
	if _self_diag_copy_text.is_empty():
		return
	copy_requested.emit(_self_diag_copy_text, "Plugin Self Diagnostics")
