@tool
extends VBoxContainer

signal port_changed(value: int)
signal log_level_changed(level: String)
signal language_changed(language_code: String)
signal start_requested
signal restart_requested
signal stop_requested
signal full_reload_requested
signal clear_self_diagnostics_requested
signal copy_requested(text: String, source: String)

const ServerTabModelProjectionServiceScript = preload("res://addons/godot_dotnet_mcp/ui/server_tab_model_projection.gd")

@onready var _self_diag_title: Label = %SelfDiagnosticsTitle
@onready var _self_diag_badge: Label = %SelfDiagnosticsBadge
@onready var _self_diag_copy_button: Button = %SelfDiagnosticsCopyButton
@onready var _self_diag_clear_button: Button = %SelfDiagnosticsClearButton
@onready var _self_diag_summary: Label = %SelfDiagnosticsSummary
@onready var _self_diag_details: Label = %SelfDiagnosticsDetails
@onready var _self_diag_divider: HSeparator = %SelfDiagnosticsDivider
@onready var _overview_buttons: GridContainer = %OverviewButtons
@onready var _state_value: Label = %ServerStateValue
@onready var _endpoint_value: Label = %EndpointValue
@onready var _connections_value: Label = %ConnectionsValue
@onready var _requests_value: Label = %RequestsValue
@onready var _last_request_value: Label = %LastRequestValue
@onready var _port_spin: SpinBox = %PortSpin
@onready var _log_level_label: Label = %LogLevelLabel
@onready var _log_level_option: OptionButton = %LogLevelOption
@onready var _language_label: Label = %LanguageLabel
@onready var _language_option: OptionButton = %LanguageOption
@onready var _start_button: Button = %StartButton
@onready var _restart_button: Button = %RestartButton
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
var _current_scale := -1.0
var _current_layout_width := -1.0
var _self_diag_copy_text := ""
var _is_running := false
var _projection_service := ServerTabModelProjectionServiceScript.new()


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	resized.connect(_on_resized)
	_port_spin.value_changed.connect(_on_port_spin_changed)
	_log_level_option.item_selected.connect(_on_log_level_option_selected)
	_language_option.item_selected.connect(_on_language_option_selected)
	_start_button.pressed.connect(_on_start_button_pressed)
	_restart_button.pressed.connect(_on_restart_button_pressed)
	_full_reload_button.pressed.connect(_on_full_reload_button_pressed)
	_self_diag_copy_button.pressed.connect(_on_self_diag_copy_pressed)
	_self_diag_clear_button.pressed.connect(_on_self_diag_clear_pressed)


func apply_model(model: Dictionary) -> void:
	var localization = model.get("localization")
	var settings: Dictionary = model.get("settings", {})
	var is_running := bool(model.get("is_running", false))
	var editor_scale := float(model.get("editor_scale", 1.0))
	_is_running = is_running

	if not is_equal_approx(_current_scale, editor_scale):
		_apply_editor_scale(editor_scale)
	else:
		_apply_responsive_layout()

	var projection: Dictionary = _projection_service.project(model)
	var overview: Dictionary = projection.get("overview", {})
	var self_diagnostics: Dictionary = projection.get("self_diagnostics", {})
	var options: Dictionary = projection.get("options", {})

	_self_diag_title.text = localization.get_text("self_diag_title")
	_self_diag_copy_button.text = localization.get_text("self_diag_copy")
	_self_diag_clear_button.text = localization.get_text("self_diag_clear")
	_status_section_title.text = localization.get_text("plugin_overview_title")
	_settings_section_title.text = localization.get_text("settings")
	_server_state_title.text = localization.get_text("plugin_overview_health_label")
	_endpoint_title.text = localization.get_text("plugin_overview_service_label")
	_connections_title.text = "%s:" % localization.get_text("total_connections_short")
	_requests_title.text = localization.get_text("plugin_overview_config_label")
	_last_request_title.text = localization.get_text("plugin_overview_activity_label")
	_port_label.text = localization.get_text("port")
	_log_level_label.text = localization.get_text("log_level")
	_language_label.text = localization.get_text("language")

	_state_value.text = str(overview.get("health_text", ""))
	_endpoint_value.text = str(overview.get("service_text", ""))
	_connections_value.text = str(overview.get("connections_text", ""))
	_requests_value.text = str(overview.get("config_text", ""))
	_last_request_value.text = str(overview.get("activity_text", ""))

	_port_spin.set_value_no_signal(int(settings.get("port", 3000)))
	_log_level_syncing = true
	_apply_projected_options(_log_level_option, options.get("log_levels", []))
	_log_level_syncing = false

	_start_button.disabled = false
	_restart_button.disabled = not is_running
	_start_button.text = localization.get_text("btn_close") if is_running else localization.get_text("btn_start")
	_restart_button.text = localization.get_text("btn_restart")
	_full_reload_button.text = localization.get_text("btn_reload_plugin")

	_language_syncing = true
	_apply_projected_options(_language_option, options.get("languages", []))
	_language_syncing = false

	_self_diag_copy_text = str(self_diagnostics.get("copy_text", ""))
	_apply_projected_self_diagnostics(self_diagnostics, localization)


func _apply_projected_options(option_button: OptionButton, projected_items: Array) -> void:
	option_button.clear()
	var selected_index := -1
	for item_index in range(projected_items.size()):
		var item: Dictionary = projected_items[item_index]
		option_button.add_item(str(item.get("text", "")), item_index)
		option_button.set_item_metadata(item_index, item.get("value", ""))
		if bool(item.get("selected", false)):
			selected_index = item_index
	if selected_index >= 0:
		option_button.select(selected_index)


func _apply_projected_self_diagnostics(self_diagnostics: Dictionary, localization) -> void:
	var badge_text = str(self_diagnostics.get("badge_text", ""))
	_self_diag_badge.text = badge_text
	_self_diag_summary.text = str(self_diagnostics.get("summary_text", localization.get_text("self_diag_empty")))
	_self_diag_details.text = str(self_diagnostics.get("details_text", ""))
	_self_diag_clear_button.disabled = bool(self_diagnostics.get("clear_disabled", true))
	if badge_text.is_empty():
		return
	_self_diag_badge.add_theme_color_override("font_color", self_diagnostics.get("badge_color", Color(0.2, 0.8, 0.2)))


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


func _on_start_button_pressed() -> void:
	if _is_running:
		stop_requested.emit()
	else:
		start_requested.emit()


func _on_restart_button_pressed() -> void:
	restart_requested.emit()


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
	var overview_buttons = get_node("Scroll/Margin/Content/OverviewButtonsCenter/OverviewButtons") as GridContainer
	var self_diag_header = get_node("Scroll/Margin/Content/SelfDiagnosticsHeader") as HBoxContainer
	status_grid.add_theme_constant_override("h_separation", int(round(12 * scale)))
	status_grid.add_theme_constant_override("v_separation", int(round(8 * scale)))
	overview_buttons.add_theme_constant_override("h_separation", int(round(8 * scale)))
	overview_buttons.add_theme_constant_override("v_separation", int(round(8 * scale)))
	self_diag_header.add_theme_constant_override("separation", int(round(8 * scale)))

	var settings_grid = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/SettingsGrid") as GridContainer
	settings_grid.add_theme_constant_override("h_separation", int(round(12 * scale)))
	settings_grid.add_theme_constant_override("v_separation", int(round(8 * scale)))

	var log_level_row = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/LogLevelRow") as GridContainer
	log_level_row.add_theme_constant_override("h_separation", int(round(8 * scale)))
	log_level_row.add_theme_constant_override("v_separation", int(round(8 * scale)))

	var language_row = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/LanguageRow") as GridContainer
	language_row.add_theme_constant_override("h_separation", int(round(8 * scale)))
	language_row.add_theme_constant_override("v_separation", int(round(8 * scale)))

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
	var settings_center = get_node("Scroll/Margin/Content/SettingsCenter") as CenterContainer
	var settings_content = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent") as VBoxContainer
	var section_divider = get_node("Scroll/Margin/Content/SectionDivider") as HSeparator
	var status_grid = get_node("Scroll/Margin/Content/StatusCenter/StatusGrid") as GridContainer
	var settings_grid = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/SettingsGrid") as GridContainer
	var log_level_row = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/LogLevelRow") as GridContainer
	var language_row = get_node("Scroll/Margin/Content/SettingsCenter/SettingsContent/LanguageRow") as GridContainer

	if margin != null:
		margin.add_theme_constant_override("margin_left", int(round(horizontal_margin)))
		margin.add_theme_constant_override("margin_right", int(round(horizontal_margin)))
		margin.add_theme_constant_override("margin_top", int(round(vertical_margin)))
		margin.add_theme_constant_override("margin_bottom", int(round(vertical_margin)))
	content.add_theme_constant_override("separation", int(round(section_spacing)))
	overview_buttons.add_theme_constant_override("h_separation", int(round(row_spacing)))
	overview_buttons.add_theme_constant_override("v_separation", int(round(row_spacing)))
	settings_content.add_theme_constant_override("separation", int(round(section_spacing)))
	status_grid.add_theme_constant_override("h_separation", int(round(grid_h_spacing)))
	status_grid.add_theme_constant_override("v_separation", int(round(grid_v_spacing)))
	settings_grid.add_theme_constant_override("h_separation", int(round(grid_h_spacing)))
	settings_grid.add_theme_constant_override("v_separation", int(round(grid_v_spacing)))
	log_level_row.add_theme_constant_override("h_separation", int(round(row_spacing)))
	log_level_row.add_theme_constant_override("v_separation", int(round(row_spacing)))
	language_row.add_theme_constant_override("h_separation", int(round(row_spacing)))
	language_row.add_theme_constant_override("v_separation", int(round(row_spacing)))

	status_center.custom_minimum_size.x = status_grid_width
	overview_buttons_center.custom_minimum_size.x = content_width
	overview_buttons.custom_minimum_size.x = content_width
	settings_center.custom_minimum_size.x = content_width
	settings_content.custom_minimum_size.x = content_width
	section_divider.custom_minimum_size.x = content_width
	status_grid.columns = status_columns
	overview_buttons.columns = 1 if narrow_layout else (2 if compact_layout else 3)
	settings_grid.columns = settings_columns
	log_level_row.columns = settings_columns
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

	for value_label in [_state_value, _endpoint_value, _connections_value, _requests_value, _last_request_value]:
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value_label.custom_minimum_size.x = field_width if status_columns == 2 else content_width

	_port_spin.custom_minimum_size.y = 32.0 * scale
	_port_spin.custom_minimum_size.x = field_width if settings_columns == 2 else content_width
	_log_level_option.custom_minimum_size.y = 32.0 * scale
	_log_level_option.custom_minimum_size.x = field_width if settings_columns == 2 else content_width
	_language_option.custom_minimum_size.y = 32.0 * scale
	_language_option.custom_minimum_size.x = field_width if settings_columns == 2 else content_width

	var button_width = content_width if overview_buttons.columns == 1 else (content_width - row_spacing * float(overview_buttons.columns - 1)) / float(overview_buttons.columns)
	for button in [_start_button, _restart_button, _full_reload_button]:
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.custom_minimum_size.x = button_width
		button.custom_minimum_size.y = (30.0 if ultra_narrow_layout else 32.0) * scale
	for button in [_self_diag_copy_button, _self_diag_clear_button]:
		button.custom_minimum_size.y = (30.0 if ultra_narrow_layout else 32.0) * scale
		button.custom_minimum_size.x = 72.0 * scale


func _on_resized() -> void:
	_apply_responsive_layout()


func _on_self_diag_copy_pressed() -> void:
	if _self_diag_copy_text.is_empty():
		return
	var source_name := "Plugin Self Diagnostics"
	if _state_value != null:
		source_name = _self_diag_title.text.strip_edges()
	if source_name.is_empty():
		source_name = "Plugin Self Diagnostics"
	copy_requested.emit(_self_diag_copy_text, source_name)


func _on_self_diag_clear_pressed() -> void:
	clear_self_diagnostics_requested.emit()
