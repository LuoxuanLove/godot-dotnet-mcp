@tool
extends VBoxContainer

const ServerTabModelProjection = preload("res://addons/godot_dotnet_mcp/ui/server_tab_model_projection.gd")
const ServerTabLayoutService = preload("res://addons/godot_dotnet_mcp/ui/server_tab_layout_service.gd")
const ServerTabLayoutNodes = preload("res://addons/godot_dotnet_mcp/ui/server_tab_layout_nodes.gd")
const ServerTabViewBindingService = preload("res://addons/godot_dotnet_mcp/ui/server_tab_view_binding_service.gd")

signal port_changed(value: int)
signal log_level_changed(level: String)
signal permission_level_changed(level: String)
signal language_changed(language_code: String)
signal start_requested
signal restart_requested
signal stop_requested
signal full_reload_requested
signal central_server_detect_requested
signal central_server_install_requested
signal central_server_start_requested
signal central_server_stop_requested
signal central_server_open_install_dir_requested
signal central_server_open_logs_requested
signal clear_self_diagnostics_requested
signal copy_requested(text: String, source: String)

@onready var _self_diag_title: Label = %SelfDiagnosticsTitle
@onready var _self_diag_badge: Label = %SelfDiagnosticsBadge
@onready var _self_diag_copy_button: Button = %SelfDiagnosticsCopyButton
@onready var _self_diag_clear_button: Button = %SelfDiagnosticsClearButton
@onready var _self_diag_summary: Label = %SelfDiagnosticsSummary
@onready var _self_diag_details: Label = %SelfDiagnosticsDetails
@onready var _self_diag_divider: HSeparator = %SelfDiagnosticsDivider
@onready var _central_server_section_divider: HSeparator = %CentralServerSectionDivider
@onready var _central_server_section_title: Label = %CentralServerSectionTitle
@onready var _central_server_status_title: Label = %CentralServerStatusTitle
@onready var _central_server_status_value: Label = %CentralServerStatusValue
@onready var _central_server_endpoint_title: Label = %CentralServerEndpointTitle
@onready var _central_server_endpoint_value: Label = %CentralServerEndpointValue
@onready var _central_server_project_title: Label = %CentralServerProjectTitle
@onready var _central_server_project_value: Label = %CentralServerProjectValue
@onready var _central_server_session_title: Label = %CentralServerSessionTitle
@onready var _central_server_session_value: Label = %CentralServerSessionValue
@onready var _central_server_message_title: Label = %CentralServerMessageTitle
@onready var _central_server_message_value: Label = %CentralServerMessageValue
@onready var _central_server_local_status_title: Label = %CentralServerLocalStatusTitle
@onready var _central_server_local_status_value: Label = %CentralServerLocalStatusValue
@onready var _central_server_local_command_title: Label = %CentralServerLocalCommandTitle
@onready var _central_server_local_command_value: Label = %CentralServerLocalCommandValue
@onready var _central_server_install_version_title: Label = %CentralServerInstallVersionTitle
@onready var _central_server_install_version_value: Label = %CentralServerInstallVersionValue
@onready var _central_server_install_dir_title: Label = %CentralServerInstallDirTitle
@onready var _central_server_install_dir_value: Label = %CentralServerInstallDirValue
@onready var _central_server_install_source_title: Label = %CentralServerInstallSourceTitle
@onready var _central_server_install_source_value: Label = %CentralServerInstallSourceValue
@onready var _central_server_detect_button: Button = %CentralServerDetectButton
@onready var _central_server_install_button: Button = %CentralServerInstallButton
@onready var _central_server_start_button: Button = %CentralServerStartButton
@onready var _central_server_stop_button: Button = %CentralServerStopButton
@onready var _central_server_open_install_dir_button: Button = %CentralServerOpenInstallDirButton
@onready var _central_server_open_logs_button: Button = %CentralServerOpenLogsButton
@onready var _overview_buttons: GridContainer = %OverviewButtons
@onready var _state_value: Label = %ServerStateValue
@onready var _endpoint_value: Label = %EndpointValue
@onready var _connections_value: Label = %ConnectionsValue
@onready var _requests_value: Label = %RequestsValue
@onready var _last_request_value: Label = %LastRequestValue
@onready var _port_spin: SpinBox = %PortSpin
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
var _model_projection := ServerTabModelProjection.new()
var _layout_service := ServerTabLayoutService.new()
var _layout_nodes: ServerTabLayoutNodes = null
var _view_binding_service := ServerTabViewBindingService.new()


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_layout_nodes = ServerTabLayoutNodes.new().populate_from(self)
	resized.connect(_on_resized)
	_port_spin.value_changed.connect(_on_port_spin_changed)
	_log_level_option.item_selected.connect(_on_log_level_option_selected)
	_permission_level_option.item_selected.connect(_on_permission_level_option_selected)
	_language_option.item_selected.connect(_on_language_option_selected)
	_start_button.pressed.connect(_on_start_button_pressed)
	_restart_button.pressed.connect(_on_restart_button_pressed)
	_full_reload_button.pressed.connect(_on_full_reload_button_pressed)
	_central_server_detect_button.pressed.connect(_on_central_server_detect_button_pressed)
	_central_server_install_button.pressed.connect(_on_central_server_install_button_pressed)
	_central_server_start_button.pressed.connect(_on_central_server_start_button_pressed)
	_central_server_stop_button.pressed.connect(_on_central_server_stop_button_pressed)
	_central_server_open_install_dir_button.pressed.connect(_on_central_server_open_install_dir_button_pressed)
	_central_server_open_logs_button.pressed.connect(_on_central_server_open_logs_button_pressed)
	_self_diag_copy_button.pressed.connect(_on_self_diag_copy_pressed)
	_self_diag_clear_button.pressed.connect(_on_self_diag_clear_pressed)


func apply_model(model: Dictionary) -> void:
	var is_running = bool(model.get("is_running", false))
	var editor_scale = float(model.get("editor_scale", 1.0))
	_is_running = is_running

	if not is_equal_approx(_current_scale, editor_scale):
		_apply_editor_scale(editor_scale)
	else:
		_apply_responsive_layout()

	var projection: Dictionary = _model_projection.build_projection(model)
	_apply_overview_projection(projection)
	_apply_settings_projection(projection)


func _apply_overview_projection(projection: Dictionary) -> void:
	var titles: Dictionary = projection.get("titles", {})
	var overview: Dictionary = projection.get("overview", {})
	_self_diag_copy_text = str(projection.get("self_diagnostics", {}).get("copy_text", ""))
	_view_binding_service.apply_self_diagnostics_projection(
		_self_diag_title,
		_self_diag_badge,
		_self_diag_copy_button,
		_self_diag_clear_button,
		_self_diag_summary,
		_self_diag_details,
		projection.get("self_diagnostics", {})
	)
	_view_binding_service.apply_central_server_attach_projection(
		_central_server_section_title,
		_central_server_status_title,
		_central_server_endpoint_title,
		_central_server_project_title,
		_central_server_session_title,
		_central_server_message_title,
		_central_server_status_value,
		_central_server_endpoint_value,
		_central_server_project_value,
		_central_server_session_value,
		_central_server_message_value,
		projection.get("central_server_attach", {})
	)
	_view_binding_service.apply_central_server_process_projection(
		_central_server_local_status_title,
		_central_server_local_status_value,
		_central_server_local_command_title,
		_central_server_local_command_value,
		_central_server_install_version_title,
		_central_server_install_version_value,
		_central_server_install_dir_title,
		_central_server_install_dir_value,
		_central_server_install_source_title,
		_central_server_install_source_value,
		_central_server_detect_button,
		_central_server_install_button,
		_central_server_start_button,
		_central_server_stop_button,
		_central_server_open_install_dir_button,
		_central_server_open_logs_button,
		projection.get("central_server_process", {})
	)
	_view_binding_service.apply_titles(
		_status_section_title,
		_settings_section_title,
		_advanced_section_title,
		_server_state_title,
		_endpoint_title,
		_connections_title,
		_requests_title,
		_last_request_title,
		_port_label,
		_log_level_label,
		_permission_level_label,
		_language_label,
		titles
	)
	_view_binding_service.apply_overview(
		_state_value,
		_endpoint_value,
		_connections_value,
		_requests_value,
		_last_request_value,
		overview
	)


func _apply_settings_projection(projection: Dictionary) -> void:
	var actions: Dictionary = projection.get("actions", {})
	_port_spin.set_value_no_signal(int(projection.get("port", 3000)))
	_log_level_syncing = true
	_view_binding_service.apply_option_model(_log_level_option, projection.get("log_level_option", {}))
	_log_level_syncing = false
	_permission_level_syncing = true
	_view_binding_service.apply_option_model(_permission_level_option, projection.get("permission_level_option", {}))
	_permission_level_syncing = false
	_start_button.disabled = bool(actions.get("start_disabled", false))
	_restart_button.disabled = bool(actions.get("restart_disabled", false))
	_start_button.text = str(actions.get("start_text", ""))
	_restart_button.text = str(actions.get("restart_text", ""))
	_full_reload_button.text = str(actions.get("full_reload_text", ""))
	_language_syncing = true
	_view_binding_service.apply_option_model(_language_option, projection.get("language_option", {}))
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


func _on_start_button_pressed() -> void:
	if _is_running:
		stop_requested.emit()
	else:
		start_requested.emit()


func _on_restart_button_pressed() -> void:
	restart_requested.emit()


func _on_full_reload_button_pressed() -> void:
	full_reload_requested.emit()


func _on_central_server_detect_button_pressed() -> void:
	central_server_detect_requested.emit()


func _on_central_server_install_button_pressed() -> void:
	central_server_install_requested.emit()


func _on_central_server_start_button_pressed() -> void:
	central_server_start_requested.emit()


func _on_central_server_stop_button_pressed() -> void:
	central_server_stop_requested.emit()


func _on_central_server_open_install_dir_button_pressed() -> void:
	central_server_open_install_dir_requested.emit()


func _on_central_server_open_logs_button_pressed() -> void:
	central_server_open_logs_requested.emit()


func _apply_editor_scale(scale: float) -> void:
	_ensure_layout_nodes()
	_current_scale = scale
	_layout_service.apply_editor_scale(_layout_nodes, scale)
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	_ensure_layout_nodes()
	_current_layout_width = _layout_service.apply_responsive_layout(_layout_nodes, _current_scale, _current_layout_width)


func _ensure_layout_nodes() -> void:
	if _layout_nodes == null or not _layout_nodes.is_resolved():
		_layout_nodes = ServerTabLayoutNodes.new().populate_from(self)


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
