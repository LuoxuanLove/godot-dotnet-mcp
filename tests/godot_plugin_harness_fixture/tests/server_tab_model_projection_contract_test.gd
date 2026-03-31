extends RefCounted

const ServerTabModelProjection = preload("res://addons/godot_dotnet_mcp/ui/server_tab_model_projection.gd")


class FakeLocalization extends RefCounted:
	var _texts := {
		"plugin_overview_title": "Overview",
		"settings": "Settings",
		"advanced_settings": "Advanced",
		"plugin_overview_health_label": "Health",
		"plugin_overview_service_label": "Service",
		"plugin_overview_config_label": "Config",
		"plugin_overview_activity_label": "Activity",
		"central_server_section_title": "Central Server",
		"central_server_status_label": "Attach Status",
		"central_server_endpoint_label": "Attach Endpoint",
		"central_server_project_label": "Project",
		"central_server_session_label": "Session",
		"central_server_message_label": "Message",
		"central_server_message_idle": "Idle",
		"central_server_status_attached": "Attached",
		"central_server_status_disabled": "Disabled",
		"central_server_local_status_label": "Local Status",
		"central_server_local_command_label": "Command",
		"central_server_install_version_label": "Install Version",
		"central_server_install_dir_label": "Install Dir",
		"central_server_install_source_label": "Install Source",
		"central_server_detect_button": "Detect",
		"central_server_install_button": "Install",
		"central_server_upgrade_button": "Upgrade",
		"central_server_start_button": "Start",
		"central_server_stop_button": "Stop",
		"central_server_open_install_dir_button": "Open Install Dir",
		"central_server_open_logs_button": "Open Logs",
		"central_server_process_status_running": "Running",
		"central_server_process_install_ready": "Ready",
		"central_server_process_install_available": "Install Available",
		"central_server_process_install_unavailable": "Install Missing",
		"central_server_process_detect_missing": "Missing",
		"port": "Port",
		"log_level": "Log Level",
		"log_level_debug": "Debug",
		"log_level_info": "Info",
		"permission_level": "Permission",
		"permission_level_developer": "Developer",
		"permission_level_evolution": "Evolution",
		"language": "Language",
		"btn_start": "Start",
		"btn_close": "Close",
		"btn_restart": "Restart",
		"btn_reload_plugin": "Reload Plugin",
		"status_running": "Running",
		"status_stopped": "Stopped",
		"self_diag_title": "Self Diagnostics",
		"self_diag_copy": "Copy",
		"self_diag_clear": "Clear",
		"self_diag_empty": "No incidents",
		"self_diag_status_warning": "Warning",
		"self_diag_status_ok": "OK",
		"self_diag_last_operation_none": "No operation",
		"self_diag_latest_incident_none": "No incident",
		"self_diag_active_incidents": "Incidents %d",
		"self_diag_tool_load_errors": "Tool load errors %d",
		"self_diag_last_operation": "Last op %s",
		"self_diag_latest_incident": "Latest %s",
		"self_diag_category_runtime": "Runtime",
		"self_diag_code_transport_failed": "Transport failed",
		"tool_profile_full": "Full",
		"tool_profile_default": "Default",
		"tool_profile_slim": "Slim",
		"tool_profile_custom_short": "Custom",
		"total_connections_short": "total",
		"last_request_none": "Never",
	}

	func get_text(key: String) -> String:
		return str(_texts.get(key, key))

	func get_available_language_codes() -> Array:
		return ["en", "zh_CN"]

	func get_language_display_name(language_code: String, _current_language: String) -> String:
		match language_code:
			"zh_CN":
				return "简体中文"
			"en":
				return "English"
			_:
				return language_code


func run_case(_tree: SceneTree) -> Dictionary:
	var projection_builder = ServerTabModelProjection.new()
	var localization = FakeLocalization.new()
	var projection = projection_builder.build_projection({
		"localization": localization,
		"settings": {
			"host": "127.0.0.1",
			"port": 3210,
		},
		"log_levels": ["debug", "info"],
		"current_log_level": "debug",
		"permission_levels": ["developer", "evolution"],
		"current_permission_level": "developer",
		"languages": {
			"en": "English",
			"zh_CN": "简体中文",
		},
		"current_language": "zh_CN",
		"tool_profile_id": "full",
		"is_running": true,
		"self_diagnostic_copy_text": "copy payload",
		"self_diagnostics": {
			"status": "warning",
			"summary": "Degraded",
			"active_incident_count": 2,
			"tool_loader": {
				"tool_load_error_count": 1,
			},
			"last_operation": {
				"kind": "reload",
				"duration_ms": 12.5,
			},
			"latest_incident": {
				"code": "transport_failed",
				"message": "Socket reset",
			},
			"recent_incidents": [
				{
					"category": "runtime",
					"code": "transport_failed",
					"message": "Socket reset",
				}
			],
		},
		"central_server_attach": {
			"status": "attached",
			"enabled": true,
			"endpoint": "http://127.0.0.1:5600/mcp",
			"project_id": "demo",
			"session_id": "session-42",
			"message": "Connected",
			"last_error": "",
		},
		"central_server_process": {
			"status": "running",
			"launch_available": true,
			"install_available": true,
			"local_install_ready": true,
			"local_install_dir": "C:/runtime",
			"install_version": "0.6.0-dev",
			"install_source_dir": "C:/source",
			"source_runtime_dir": "",
			"source_runtime_version": "",
			"detected_command": "godot-dotnet-mcp.exe",
			"log_file_path": "C:/runtime/server.log",
			"pid": 42,
		},
		"stats": {
			"active_connections": 3,
			"total_requests": 12,
			"total_connections": 5,
			"last_request_at_unix": 1710000000,
			"last_request_method": "tools/list",
		},
	})

	var overview: Dictionary = projection.get("overview", {})
	if str(overview.get("health_text", "")).find("Warning · Degraded (2)") == -1:
		return _failure("Server tab projection should summarize diagnostics in overview health text.")
	if str(overview.get("service_text", "")) != "Running · http://127.0.0.1:3210/mcp":
		return _failure("Server tab projection should build the service overview from host and port.")
	if str(overview.get("central_server_text", "")).find("session-42") == -1:
		return _failure("Server tab projection should include the central server session in the overview.")
	if str(overview.get("config_text", "")).find("Full · Developer · Debug · 简体中文") == -1:
		return _failure("Server tab projection should summarize profile, permission, log level and language.")

	var diagnostics: Dictionary = projection.get("self_diagnostics", {})
	if str(diagnostics.get("badge_text", "")) != "Warning":
		return _failure("Server tab projection should translate the diagnostics badge text.")
	if bool(diagnostics.get("clear_disabled", true)):
		return _failure("Server tab projection should keep the clear button enabled when incidents exist.")
	if str(diagnostics.get("summary", "")).find("Incidents 2") == -1:
		return _failure("Server tab projection should include incident counts in the diagnostics summary.")
	if str(diagnostics.get("details", "")).find("Runtime | Transport failed | Socket reset") == -1:
		return _failure("Server tab projection should format recent incidents for the diagnostics details.")

	var attach_projection: Dictionary = projection.get("central_server_attach", {})
	if str(attach_projection.get("status_value", "")) != "Attached":
		return _failure("Server tab projection should translate the central server attach status.")
	if str(attach_projection.get("message_value", "")) != "Connected":
		return _failure("Server tab projection should preserve the central server message.")

	var process_projection: Dictionary = projection.get("central_server_process", {})
	if str(process_projection.get("local_status_value", "")).find("Running (PID 42) · Ready") == -1:
		return _failure("Server tab projection should include PID and install state in the local server status.")
	if not bool(process_projection.get("start_button_disabled", false)):
		return _failure("Server tab projection should disable local server start while already running.")
	if bool(process_projection.get("stop_button_disabled", true)):
		return _failure("Server tab projection should keep local server stop enabled when a PID exists.")

	var log_level_option: Dictionary = projection.get("log_level_option", {})
	if int(log_level_option.get("selected_index", -1)) != 0:
		return _failure("Server tab projection should preserve the selected log level.")
	var permission_option: Dictionary = projection.get("permission_level_option", {})
	if int(permission_option.get("selected_index", -1)) != 0:
		return _failure("Server tab projection should preserve the selected permission level.")
	var language_option: Dictionary = projection.get("language_option", {})
	if int(language_option.get("selected_index", -1)) != 1:
		return _failure("Server tab projection should preserve the selected language.")

	return {
		"name": "server_tab_model_projection_contracts",
		"success": true,
		"error": "",
		"details": {
			"overview_length": str(overview.get("config_text", "")).length(),
			"language_options": (language_option.get("items", []) as Array).size(),
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "server_tab_model_projection_contracts",
		"success": false,
		"error": message,
	}
