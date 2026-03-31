@tool
extends RefCounted

const ToolPermissionPolicy = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_permission_policy.gd")


func build_projection(model: Dictionary) -> Dictionary:
	var localization = model.get("localization")
	var settings: Dictionary = model.get("settings", {})
	var languages: Dictionary = model.get("languages", {})
	var stats: Dictionary = model.get("stats", {})
	var self_diagnostics: Dictionary = model.get("self_diagnostics", {})
	var central_server_attach: Dictionary = model.get("central_server_attach", {})
	var central_server_process: Dictionary = model.get("central_server_process", {})
	var is_running = bool(model.get("is_running", false))

	return {
		"titles": _build_titles(localization),
		"overview": {
			"health_text": _build_overview_health_text(self_diagnostics, localization),
			"service_text": _build_overview_service_text(is_running, settings, localization),
			"central_server_text": _build_overview_central_server_text(central_server_attach, central_server_process, localization),
			"config_text": _build_overview_config_text(model, localization),
			"activity_text": _build_overview_activity_text(stats, localization),
		},
		"self_diagnostics": _build_self_diagnostics_projection(model, localization),
		"central_server_attach": _build_central_server_attach_projection(central_server_attach, localization),
		"central_server_process": _build_central_server_process_projection(central_server_process, localization),
		"port": int(settings.get("port", 3000)),
		"log_level_option": _build_log_level_option_model(model, localization),
		"permission_level_option": _build_permission_level_option_model(model, localization),
		"language_option": _build_language_option_model(model, languages, localization),
		"actions": {
			"start_disabled": false,
			"restart_disabled": not is_running,
			"start_text": _text(localization, "btn_close") if is_running else _text(localization, "btn_start"),
			"restart_text": _text(localization, "btn_restart"),
			"full_reload_text": _text(localization, "btn_reload_plugin"),
		},
	}


func _build_titles(localization) -> Dictionary:
	return {
		"status_section_title": _text(localization, "plugin_overview_title"),
		"settings_section_title": _text(localization, "settings"),
		"advanced_section_title": _text(localization, "advanced_settings"),
		"server_state_title": _text(localization, "plugin_overview_health_label"),
		"endpoint_title": _text(localization, "plugin_overview_service_label"),
		"connections_title": _text(localization, "central_server_section_title"),
		"requests_title": _text(localization, "plugin_overview_config_label"),
		"last_request_title": _text(localization, "plugin_overview_activity_label"),
		"port_label": _text(localization, "port"),
		"log_level_label": _text(localization, "log_level"),
		"permission_level_label": _text(localization, "permission_level"),
		"language_label": _text(localization, "language"),
	}


func _build_self_diagnostics_projection(model: Dictionary, localization) -> Dictionary:
	var diagnostics = model.get("self_diagnostics", {})
	var projection := {
		"title": _text(localization, "self_diag_title"),
		"copy_button_text": _text(localization, "self_diag_copy"),
		"clear_button_text": _text(localization, "self_diag_clear"),
		"copy_text": str(model.get("self_diagnostic_copy_text", "")),
		"badge_text": "",
		"summary": _text(localization, "self_diag_empty"),
		"details": "",
		"clear_disabled": true,
	}
	if not (diagnostics is Dictionary) or (diagnostics as Dictionary).is_empty():
		return projection

	var diag := diagnostics as Dictionary
	var status = str(diag.get("status", "ok"))
	projection["badge_text"] = _get_self_diag_status_text(status, localization)
	projection["badge_color"] = _get_self_diag_status_color(status)

	var active_incidents = int(diag.get("active_incident_count", 0))
	projection["clear_disabled"] = active_incidents <= 0
	var tool_loader = diag.get("tool_loader", {})
	var tool_load_error_count = 0
	if tool_loader is Dictionary:
		tool_load_error_count = int((tool_loader as Dictionary).get("tool_load_error_count", 0))
	var last_operation_text = _text(localization, "self_diag_last_operation_none")
	var latest_incident_text = _text(localization, "self_diag_latest_incident_none")
	var last_operation = diag.get("last_operation", {})
	if last_operation is Dictionary and not (last_operation as Dictionary).is_empty():
		last_operation_text = "%s (%s ms)" % [
			str((last_operation as Dictionary).get("kind", "")),
			str((last_operation as Dictionary).get("duration_ms", 0.0))
		]
	var latest_incident = diag.get("latest_incident", {})
	if latest_incident is Dictionary and not (latest_incident as Dictionary).is_empty():
		var latest_incident_dict := latest_incident as Dictionary
		latest_incident_text = "%s | %s" % [
			_get_self_diag_code_text(str(latest_incident_dict.get("code", "")), localization),
			str(latest_incident_dict.get("message", ""))
		]

	projection["summary"] = "%s | %s | %s | %s" % [
		_text(localization, "self_diag_active_incidents") % active_incidents,
		_text(localization, "self_diag_tool_load_errors") % tool_load_error_count,
		_text(localization, "self_diag_last_operation") % last_operation_text,
		_text(localization, "self_diag_latest_incident") % latest_incident_text
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
	projection["details"] = _text(localization, "self_diag_empty") if recent_lines.is_empty() else "\n".join(recent_lines)
	return projection


func _build_central_server_attach_projection(central_server_attach: Dictionary, localization) -> Dictionary:
	var status = str(central_server_attach.get("status", "idle"))
	var endpoint = str(central_server_attach.get("endpoint", ""))
	var project_id = str(central_server_attach.get("project_id", ""))
	var session_id = str(central_server_attach.get("session_id", ""))
	var message = str(central_server_attach.get("message", ""))
	var last_error = str(central_server_attach.get("last_error", ""))
	var enabled = bool(central_server_attach.get("enabled", true))

	return {
		"section_title": _text(localization, "central_server_section_title"),
		"status_title": _text(localization, "central_server_status_label"),
		"endpoint_title": _text(localization, "central_server_endpoint_label"),
		"project_title": _text(localization, "central_server_project_label"),
		"session_title": _text(localization, "central_server_session_label"),
		"message_title": _text(localization, "central_server_message_label"),
		"status_value": _resolve_central_server_status_text(status, enabled, localization),
		"endpoint_value": endpoint if not endpoint.is_empty() else "-",
		"project_value": project_id if not project_id.is_empty() else "-",
		"session_value": session_id if not session_id.is_empty() else "-",
		"message_value": last_error if not last_error.is_empty() else (message if not message.is_empty() else _text(localization, "central_server_message_idle")),
	}


func _build_central_server_process_projection(central_server_process: Dictionary, localization) -> Dictionary:
	var status = str(central_server_process.get("status", "idle"))
	var launch_available = bool(central_server_process.get("launch_available", false))
	var install_available = bool(central_server_process.get("install_available", false))
	var local_install_ready = bool(central_server_process.get("local_install_ready", false))
	var install_dir = str(central_server_process.get("local_install_dir", ""))
	var install_version = str(central_server_process.get("install_version", ""))
	var install_source_dir = str(central_server_process.get("install_source_dir", ""))
	var source_runtime_dir = str(central_server_process.get("source_runtime_dir", ""))
	var source_runtime_version = str(central_server_process.get("source_runtime_version", ""))
	var detected_command = str(central_server_process.get("detected_command", ""))
	var log_file_path = str(central_server_process.get("log_file_path", ""))
	var pid = int(central_server_process.get("pid", 0))

	var status_text = _resolve_central_server_process_status_text(status, localization)
	if pid > 0:
		status_text += " (PID %d)" % pid
	if local_install_ready:
		status_text += " · %s" % _text(localization, "central_server_process_install_ready")
	elif install_available:
		status_text += " · %s" % _text(localization, "central_server_process_install_available")
	else:
		status_text += " · %s" % _text(localization, "central_server_process_install_unavailable")

	return {
		"local_status_title": _text(localization, "central_server_local_status_label"),
		"local_command_title": _text(localization, "central_server_local_command_label"),
		"install_version_title": _text(localization, "central_server_install_version_label"),
		"install_dir_title": _text(localization, "central_server_install_dir_label"),
		"install_source_title": _text(localization, "central_server_install_source_label"),
		"detect_button_text": _text(localization, "central_server_detect_button"),
		"install_button_text": _text(localization, "central_server_upgrade_button") if local_install_ready else _text(localization, "central_server_install_button"),
		"start_button_text": _text(localization, "central_server_start_button"),
		"stop_button_text": _text(localization, "central_server_stop_button"),
		"open_install_dir_button_text": _text(localization, "central_server_open_install_dir_button"),
		"open_logs_button_text": _text(localization, "central_server_open_logs_button"),
		"local_status_value": status_text,
		"install_version_value": install_version if not install_version.is_empty() else (source_runtime_version if not source_runtime_version.is_empty() else "-"),
		"install_dir_value": install_dir if not install_dir.is_empty() else _text(localization, "central_server_process_detect_missing"),
		"install_source_value": install_source_dir if not install_source_dir.is_empty() else (source_runtime_dir if not source_runtime_dir.is_empty() else _text(localization, "central_server_process_detect_missing")),
		"local_command_value": detected_command if not detected_command.is_empty() else _text(localization, "central_server_process_detect_missing"),
		"install_button_disabled": not install_available,
		"start_button_disabled": not launch_available or status == "running" or status == "starting",
		"stop_button_disabled": pid <= 0,
		"open_install_dir_button_disabled": install_dir.is_empty(),
		"open_logs_button_disabled": log_file_path.is_empty(),
	}


func _build_log_level_option_model(model: Dictionary, localization) -> Dictionary:
	return _build_option_model(
		model.get("log_levels", []),
		str(model.get("current_log_level", "info")),
		func(value: String) -> String:
			var key = "log_level_%s" % value
			var translated = _text(localization, key)
			return translated if translated != key else value.capitalize()
	)


func _build_permission_level_option_model(model: Dictionary, localization) -> Dictionary:
	return _build_option_model(
		model.get("permission_levels", []),
		str(model.get("current_permission_level", ToolPermissionPolicy.PERMISSION_EVOLUTION)),
		func(value: String) -> String:
			var key = "permission_level_%s" % value
			var translated = _text(localization, key)
			return translated if translated != key else value.capitalize()
	)


func _build_language_option_model(model: Dictionary, languages: Dictionary, localization) -> Dictionary:
	var current_language = str(model.get("current_language", "en"))
	var language_codes: Array = []
	if localization != null and localization.has_method("get_available_language_codes"):
		language_codes = localization.get_available_language_codes()
	else:
		language_codes = languages.keys()
		language_codes.sort()
	return _build_option_model(
		language_codes,
		current_language,
		func(value: String) -> String:
			if localization != null and localization.has_method("get_language_display_name"):
				return localization.get_language_display_name(value, current_language)
			return value.capitalize()
	)


func _build_option_model(values: Array, current_value: String, display_name_resolver: Callable) -> Dictionary:
	var items: Array[Dictionary] = []
	var selected_index = -1
	for index in range(values.size()):
		var value = str(values[index])
		items.append({
			"text": str(display_name_resolver.call(value)),
			"value": value,
		})
		if value == current_value:
			selected_index = index
	return {
		"items": items,
		"selected_index": selected_index,
	}


func _build_overview_health_text(self_diagnostics: Dictionary, localization) -> String:
	var status = str(self_diagnostics.get("status", "ok"))
	var summary = str(self_diagnostics.get("summary", ""))
	var active_incidents = int(self_diagnostics.get("active_incident_count", 0))
	var status_text = status.capitalize()
	var translated_status_key = "self_diag_status_%s" % status
	var translated_status = _text(localization, translated_status_key)
	if translated_status != translated_status_key:
		status_text = translated_status
	if active_incidents > 0:
		return "%s · %s (%d)" % [status_text, summary, active_incidents]
	return "%s · %s" % [status_text, summary]


func _build_overview_service_text(is_running: bool, settings: Dictionary, localization) -> String:
	var service_state = _text(localization, "status_running") if is_running else _text(localization, "status_stopped")
	var endpoint = "http://%s:%d/mcp" % [settings.get("host", "127.0.0.1"), int(settings.get("port", 3000))]
	return "%s · %s" % [service_state, endpoint]


func _build_overview_central_server_text(central_server_attach: Dictionary, central_server_process: Dictionary, localization) -> String:
	var attach_text = _resolve_central_server_status_text(
		str(central_server_attach.get("status", "idle")),
		bool(central_server_attach.get("enabled", true)),
		localization
	)
	var process_text = _resolve_central_server_process_status_text(
		str(central_server_process.get("status", "idle")),
		localization
	)
	if bool(central_server_process.get("local_install_ready", false)):
		process_text += " / %s" % _text(localization, "central_server_process_install_ready")
	elif bool(central_server_process.get("install_available", false)):
		process_text += " / %s" % _text(localization, "central_server_process_install_available")

	var summary_parts: Array[String] = [attach_text, process_text]
	var session_id = str(central_server_attach.get("session_id", ""))
	if not session_id.is_empty():
		summary_parts.append(session_id)
	return " · ".join(summary_parts)


func _build_overview_config_text(model: Dictionary, localization) -> String:
	var profile_id = str(model.get("tool_profile_id", "default"))
	var permission_level = str(model.get("current_permission_level", ToolPermissionPolicy.PERMISSION_EVOLUTION))
	var log_level = str(model.get("current_log_level", "info"))
	var current_language = str(model.get("current_language", "en"))
	var profile_text = _get_overview_profile_text(profile_id, localization)
	var permission_key = "permission_level_%s" % permission_level
	var permission_text = _text(localization, permission_key)
	if permission_text == permission_key:
		permission_text = permission_level.capitalize()
	var log_key = "log_level_%s" % log_level
	var log_text = _text(localization, log_key)
	if log_text == log_key:
		log_text = log_level.capitalize()
	var language_text = _get_overview_language_text(current_language, localization)
	return "%s · %s · %s · %s" % [profile_text, permission_text, log_text, language_text]


func _get_overview_profile_text(profile_id: String, localization) -> String:
	match profile_id:
		"slim":
			return _text(localization, "tool_profile_slim")
		"default", "":
			return _text(localization, "tool_profile_default")
		"full":
			return _text(localization, "tool_profile_full")
		_:
			return _text(localization, "tool_profile_custom_short")


func _get_overview_language_text(current_language: String, localization) -> String:
	if current_language.is_empty():
		current_language = "en"
	if localization != null and localization.has_method("get_language_display_name"):
		return localization.get_language_display_name(current_language, current_language)
	return current_language.capitalize()


func _build_overview_activity_text(stats: Dictionary, localization) -> String:
	var active_connections = int(stats.get("active_connections", 0))
	var total_requests = int(stats.get("total_requests", 0))
	var total_connections = int(stats.get("total_connections", 0))
	var last_request_at = int(stats.get("last_request_at_unix", 0))
	var last_method = str(stats.get("last_request_method", ""))
	var last_request_text = _text(localization, "last_request_none") if last_request_at <= 0 else "%s %s" % [
		Time.get_datetime_string_from_unix_time(last_request_at),
		last_method
	]
	var parts: PackedStringArray = PackedStringArray()
	parts.append("%d / %d" % [active_connections, total_requests])
	parts.append("%d %s" % [total_connections, _text(localization, "total_connections_short")])
	parts.append(last_request_text)
	return " · ".join(parts)


func _resolve_central_server_process_status_text(status: String, localization) -> String:
	var key = "central_server_process_status_%s" % status
	var translated = _text(localization, key)
	return translated if translated != key else status.capitalize()


func _resolve_central_server_status_text(status: String, enabled: bool, localization) -> String:
	if not enabled:
		return _text(localization, "central_server_status_disabled")
	var key = "central_server_status_%s" % status
	var translated = _text(localization, key)
	return translated if translated != key else status.capitalize()


func _get_self_diag_status_text(status: String, localization) -> String:
	match status:
		"error":
			return _text(localization, "self_diag_status_error")
		"warning":
			return _text(localization, "self_diag_status_warning")
		_:
			return _text(localization, "self_diag_status_ok")


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
	var translated = _text(localization, key)
	return translated if translated != key else category


func _get_self_diag_code_text(code: String, localization) -> String:
	var key = "self_diag_code_%s" % code
	var translated = _text(localization, key)
	return translated if translated != key else code


func _text(localization, key: String) -> String:
	if localization != null and localization.has_method("get_text"):
		return str(localization.get_text(key))
	return key
