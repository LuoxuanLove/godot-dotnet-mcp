extends RefCounted

const ServerPanelScene = preload("res://addons/godot_dotnet_mcp/ui/server_panel.tscn")
const ServerTabViewBindingService = preload("res://addons/godot_dotnet_mcp/ui/server_tab_view_binding_service.gd")

var _instance: VBoxContainer = null


func run_case(tree: SceneTree) -> Dictionary:
	var service = ServerTabViewBindingService.new()
	_instance = ServerPanelScene.instantiate() as VBoxContainer
	if _instance == null:
		return _failure("Server tab view binding test could not instantiate server panel scene.")
	tree.root.add_child(_instance)
	await tree.process_frame

	var status_section_title = _instance.find_child("StatusSectionTitle", true, false) as Label
	var settings_section_title = _instance.find_child("SettingsSectionTitle", true, false) as Label
	var advanced_section_title = _instance.find_child("AdvancedSectionTitle", true, false) as Label
	var server_state_title = _instance.find_child("ServerStateTitle", true, false) as Label
	var endpoint_title = _instance.find_child("EndpointTitle", true, false) as Label
	var connections_title = _instance.find_child("ConnectionsTitle", true, false) as Label
	var requests_title = _instance.find_child("RequestsTitle", true, false) as Label
	var last_request_title = _instance.find_child("LastRequestTitle", true, false) as Label
	var port_label = _instance.find_child("PortLabel", true, false) as Label
	var log_level_label = _instance.find_child("LogLevelLabel", true, false) as Label
	var permission_level_label = _instance.find_child("PermissionLevelLabel", true, false) as Label
	var language_label = _instance.find_child("LanguageLabel", true, false) as Label
	var state_value = _instance.find_child("ServerStateValue", true, false) as Label
	var endpoint_value = _instance.find_child("EndpointValue", true, false) as Label
	var connections_value = _instance.find_child("ConnectionsValue", true, false) as Label
	var requests_value = _instance.find_child("RequestsValue", true, false) as Label
	var last_request_value = _instance.find_child("LastRequestValue", true, false) as Label
	var self_diag_title = _instance.find_child("SelfDiagnosticsTitle", true, false) as Label
	var self_diag_badge = _instance.find_child("SelfDiagnosticsBadge", true, false) as Label
	var self_diag_copy_button = _instance.find_child("SelfDiagnosticsCopyButton", true, false) as Button
	var self_diag_clear_button = _instance.find_child("SelfDiagnosticsClearButton", true, false) as Button
	var self_diag_summary = _instance.find_child("SelfDiagnosticsSummary", true, false) as Label
	var self_diag_details = _instance.find_child("SelfDiagnosticsDetails", true, false) as Label
	var central_server_section_title = _instance.find_child("CentralServerSectionTitle", true, false) as Label
	var central_server_status_title = _instance.find_child("CentralServerStatusTitle", true, false) as Label
	var central_server_endpoint_title = _instance.find_child("CentralServerEndpointTitle", true, false) as Label
	var central_server_project_title = _instance.find_child("CentralServerProjectTitle", true, false) as Label
	var central_server_session_title = _instance.find_child("CentralServerSessionTitle", true, false) as Label
	var central_server_message_title = _instance.find_child("CentralServerMessageTitle", true, false) as Label
	var central_server_status_value = _instance.find_child("CentralServerStatusValue", true, false) as Label
	var central_server_endpoint_value = _instance.find_child("CentralServerEndpointValue", true, false) as Label
	var central_server_project_value = _instance.find_child("CentralServerProjectValue", true, false) as Label
	var central_server_session_value = _instance.find_child("CentralServerSessionValue", true, false) as Label
	var central_server_message_value = _instance.find_child("CentralServerMessageValue", true, false) as Label
	var central_server_local_status_title = _instance.find_child("CentralServerLocalStatusTitle", true, false) as Label
	var central_server_local_status_value = _instance.find_child("CentralServerLocalStatusValue", true, false) as Label
	var central_server_local_command_title = _instance.find_child("CentralServerLocalCommandTitle", true, false) as Label
	var central_server_local_command_value = _instance.find_child("CentralServerLocalCommandValue", true, false) as Label
	var central_server_install_version_title = _instance.find_child("CentralServerInstallVersionTitle", true, false) as Label
	var central_server_install_version_value = _instance.find_child("CentralServerInstallVersionValue", true, false) as Label
	var central_server_install_dir_title = _instance.find_child("CentralServerInstallDirTitle", true, false) as Label
	var central_server_install_dir_value = _instance.find_child("CentralServerInstallDirValue", true, false) as Label
	var central_server_install_source_title = _instance.find_child("CentralServerInstallSourceTitle", true, false) as Label
	var central_server_install_source_value = _instance.find_child("CentralServerInstallSourceValue", true, false) as Label
	var central_server_detect_button = _instance.find_child("CentralServerDetectButton", true, false) as Button
	var central_server_install_button = _instance.find_child("CentralServerInstallButton", true, false) as Button
	var central_server_start_button = _instance.find_child("CentralServerStartButton", true, false) as Button
	var central_server_stop_button = _instance.find_child("CentralServerStopButton", true, false) as Button
	var central_server_open_install_dir_button = _instance.find_child("CentralServerOpenInstallDirButton", true, false) as Button
	var central_server_open_logs_button = _instance.find_child("CentralServerOpenLogsButton", true, false) as Button
	var log_level_option = _instance.find_child("LogLevelOption", true, false) as OptionButton

	if status_section_title == null or settings_section_title == null or advanced_section_title == null:
		return _failure("Server tab view binding test could not resolve section title controls.")
	if self_diag_title == null or self_diag_badge == null or self_diag_copy_button == null or self_diag_clear_button == null:
		return _failure("Server tab view binding test could not resolve diagnostics controls.")
	if central_server_section_title == null or central_server_detect_button == null or log_level_option == null:
		return _failure("Server tab view binding test could not resolve central server or option controls.")

	service.apply_titles(
		status_section_title,
		settings_section_title,
		advanced_section_title,
		server_state_title,
		endpoint_title,
		connections_title,
		requests_title,
		last_request_title,
		port_label,
		log_level_label,
		permission_level_label,
		language_label,
		{
			"status_section_title": "Overview",
			"settings_section_title": "Settings",
			"advanced_section_title": "Advanced",
			"server_state_title": "Health",
			"endpoint_title": "Service",
			"connections_title": "Central Server",
			"requests_title": "Config",
			"last_request_title": "Activity",
			"port_label": "Port",
			"log_level_label": "Log Level",
			"permission_level_label": "Permission",
			"language_label": "Language"
		}
	)
	service.apply_overview(
		state_value,
		endpoint_value,
		connections_value,
		requests_value,
		last_request_value,
		{
			"health_text": "Warning · Degraded",
			"service_text": "Running · http://127.0.0.1:3000/mcp",
			"central_server_text": "Attached · Running",
			"config_text": "Default · Evolution · Debug · English",
			"activity_text": "2 / 12 · 5 total · tools/list"
		}
	)
	service.apply_option_model(log_level_option, {
		"items": [
			{"text": "Debug", "value": "debug"},
			{"text": "Info", "value": "info"}
		],
		"selected_index": 1
	})
	service.apply_self_diagnostics_projection(
		self_diag_title,
		self_diag_badge,
		self_diag_copy_button,
		self_diag_clear_button,
		self_diag_summary,
		self_diag_details,
		{
			"title": "Self Diagnostics",
			"copy_button_text": "Copy",
			"clear_button_text": "Clear",
			"badge_text": "Warning",
			"badge_color": Color(0.95, 0.7, 0.2),
			"summary": "Incidents 2",
			"details": "Runtime | transport_failed | Socket reset",
			"clear_disabled": false
		}
	)
	service.apply_central_server_attach_projection(
		central_server_section_title,
		central_server_status_title,
		central_server_endpoint_title,
		central_server_project_title,
		central_server_session_title,
		central_server_message_title,
		central_server_status_value,
		central_server_endpoint_value,
		central_server_project_value,
		central_server_session_value,
		central_server_message_value,
		{
			"section_title": "Central Server",
			"status_title": "Attach Status",
			"endpoint_title": "Attach Endpoint",
			"project_title": "Project",
			"session_title": "Session",
			"message_title": "Message",
			"status_value": "Attached",
			"endpoint_value": "http://127.0.0.1:5600/mcp",
			"project_value": "demo",
			"session_value": "session-42",
			"message_value": "Connected"
		}
	)
	service.apply_central_server_process_projection(
		central_server_local_status_title,
		central_server_local_status_value,
		central_server_local_command_title,
		central_server_local_command_value,
		central_server_install_version_title,
		central_server_install_version_value,
		central_server_install_dir_title,
		central_server_install_dir_value,
		central_server_install_source_title,
		central_server_install_source_value,
		central_server_detect_button,
		central_server_install_button,
		central_server_start_button,
		central_server_stop_button,
		central_server_open_install_dir_button,
		central_server_open_logs_button,
		{
			"local_status_title": "Local Status",
			"local_command_title": "Command",
			"install_version_title": "Install Version",
			"install_dir_title": "Install Dir",
			"install_source_title": "Install Source",
			"detect_button_text": "Detect",
			"install_button_text": "Install",
			"start_button_text": "Start",
			"stop_button_text": "Stop",
			"open_install_dir_button_text": "Open Install Dir",
			"open_logs_button_text": "Open Logs",
			"local_status_value": "Running (PID 42) · Ready",
			"install_version_value": "0.6.0-dev",
			"install_dir_value": "C:/runtime",
			"install_source_value": "C:/source",
			"local_command_value": "godot-dotnet-mcp.exe",
			"install_button_disabled": false,
			"start_button_disabled": true,
			"stop_button_disabled": false,
			"open_install_dir_button_disabled": false,
			"open_logs_button_disabled": false
		}
	)

	if status_section_title.text != "Overview" or endpoint_title.text != "Service":
		return _failure("Server tab view binding service should apply section and field titles.")
	if state_value.text != "Warning · Degraded" or requests_value.text.find("Default") == -1:
		return _failure("Server tab view binding service should apply overview summary values.")
	if log_level_option.get_item_count() != 2 or log_level_option.get_selected_id() != 1:
		return _failure("Server tab view binding service should apply option models and keep the selected entry.")
	if self_diag_badge.text != "Warning" or self_diag_clear_button.disabled:
		return _failure("Server tab view binding service should apply diagnostics badge text and button enabled state.")
	if central_server_status_value.text != "Attached" or central_server_message_value.text != "Connected":
		return _failure("Server tab view binding service should apply central server attach values.")
	if central_server_start_button.disabled != true or central_server_stop_button.disabled != false:
		return _failure("Server tab view binding service should apply central server process button states.")
	if central_server_local_status_value.text.find("PID 42") == -1:
		return _failure("Server tab view binding service should apply local server process details.")

	return {
		"name": "server_tab_view_binding_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"log_level_item_count": log_level_option.get_item_count(),
			"selected_log_level_index": log_level_option.get_selected_id(),
			"central_server_status": central_server_status_value.text
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	if _instance != null and is_instance_valid(_instance):
		var self_diag_badge = _instance.find_child("SelfDiagnosticsBadge", true, false) as Label
		if self_diag_badge != null:
			self_diag_badge.remove_theme_color_override("font_color")
		_instance.queue_free()
	_instance = null
	await tree.process_frame
	await tree.process_frame


func _failure(message: String) -> Dictionary:
	return {
		"name": "server_tab_view_binding_service_contracts",
		"success": false,
		"error": message
	}
