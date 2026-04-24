@tool
extends RefCounted
class_name ServerTabModelProjectionService

const DEFAULT_HOST := "127.0.0.1"
const DEFAULT_PORT := 3000
const DEFAULT_LOG_LEVEL := "info"
const DEFAULT_LANGUAGE := "en"
const MAX_SELF_DIAGNOSTIC_LINES := 3


func project(model: Dictionary) -> Dictionary:
	var localization = model.get("localization")
	var settings: Dictionary = model.get("settings", {})
	var stats: Dictionary = model.get("stats", {})
	var self_diagnostics: Dictionary = model.get("self_diagnostics", {})
	var is_running := bool(model.get("is_running", false))

	return {
		"overview": {
			"health_text": _build_overview_health_text(self_diagnostics, localization),
			"service_text": _build_overview_service_text(is_running, settings, localization),
			"connections_text": _build_overview_connections_text(stats),
			"config_text": _build_overview_config_text(model, localization),
			"activity_text": _build_overview_activity_text(stats, localization)
		},
		"self_diagnostics": _project_self_diagnostics(model, self_diagnostics, localization),
		"options": {
			"log_levels": _project_enum_options(model.get("log_levels", []), _normalize_log_level(str(model.get("current_log_level", DEFAULT_LOG_LEVEL))), localization, "log_level"),
			"languages": _project_language_options(model, localization)
		}
	}


func _build_overview_health_text(self_diagnostics: Dictionary, localization) -> String:
	var status = str(self_diagnostics.get("status", "ok"))
	var summary = str(self_diagnostics.get("summary", ""))
	var active_incidents = int(self_diagnostics.get("active_incident_count", 0))
	var status_text = _get_self_diag_status_text(status, localization)
	if active_incidents > 0:
		return "%s · %s (%d)" % [status_text, summary, active_incidents]
	return "%s · %s" % [status_text, summary]


func _build_overview_service_text(is_running: bool, settings: Dictionary, localization) -> String:
	var service_state_key := "status_running" if is_running else "status_stopped"
	var service_state := _get_localized_text(localization, service_state_key, service_state_key.capitalize())
	var endpoint = "http://%s:%d/mcp" % [settings.get("host", DEFAULT_HOST), int(settings.get("port", DEFAULT_PORT))]
	return "%s · %s" % [service_state, endpoint]


func _build_overview_connections_text(stats: Dictionary) -> String:
	var active_connections = int(stats.get("active_connections", 0))
	var total_connections = int(stats.get("total_connections", 0))
	return "%d / %d" % [active_connections, total_connections]


func _build_overview_config_text(model: Dictionary, localization) -> String:
	var profile_id = str(model.get("tool_profile_id", "default"))
	var log_level = _normalize_log_level(str(model.get("current_log_level", DEFAULT_LOG_LEVEL)))
	var current_language = str(model.get("current_language", DEFAULT_LANGUAGE))
	var profile_text = _get_overview_profile_text(profile_id, localization)
	var log_text = _get_localized_text(localization, "log_level_%s" % log_level, log_level.capitalize())
	var language_text = _get_overview_language_text(current_language, localization)
	return "%s · %s · %s" % [profile_text, log_text, language_text]


func _normalize_log_level(level: String) -> String:
	var normalized := level.to_lower().strip_edges()
	if normalized == "trace":
		return "debug"
	match normalized:
		"debug", "info", "warning", "error":
			return normalized
		_:
			return DEFAULT_LOG_LEVEL


func _get_overview_profile_text(profile_id: String, localization) -> String:
	match profile_id:
		"slim":
			return _get_localized_text(localization, "tool_profile_slim", "Slim")
		"default", "":
			return _get_localized_text(localization, "tool_profile_default", "Default")
		"full":
			return _get_localized_text(localization, "tool_profile_full", "Full")
		_:
			return _get_localized_text(localization, "tool_profile_custom_short", "Custom")


func _get_overview_language_text(current_language: String, localization) -> String:
	if current_language.is_empty():
		current_language = DEFAULT_LANGUAGE
	if localization != null and localization.has_method("get_language_display_name"):
		return str(localization.get_language_display_name(current_language, current_language))
	return current_language.capitalize()


func _build_overview_activity_text(stats: Dictionary, localization) -> String:
	var active_connections = int(stats.get("active_connections", 0))
	var total_requests = int(stats.get("total_requests", 0))
	var total_connections = int(stats.get("total_connections", 0))
	var last_request_at = int(stats.get("last_request_at_unix", 0))
	var last_method = str(stats.get("last_request_method", ""))
	var last_request_text = _get_localized_text(localization, "last_request_none", "") if last_request_at <= 0 else "%s %s" % [
		Time.get_datetime_string_from_unix_time(last_request_at),
		last_method
	]
	var parts: PackedStringArray = PackedStringArray()
	parts.append("%d / %d" % [active_connections, total_requests])
	parts.append("%d %s" % [total_connections, _get_localized_text(localization, "total_connections_short", "Connections")])
	parts.append(last_request_text)
	return " · ".join(parts)


func _project_self_diagnostics(model: Dictionary, diagnostics: Dictionary, localization) -> Dictionary:
	if not (diagnostics is Dictionary) or diagnostics.is_empty():
		return {
			"badge_text": "",
			"badge_color": _get_self_diag_status_color("ok"),
			"summary_text": _get_localized_text(localization, "self_diag_empty", ""),
			"details_text": "",
			"clear_disabled": true,
			"copy_text": str(model.get("self_diagnostic_copy_text", ""))
		}

	var diag := diagnostics as Dictionary
	var status = str(diag.get("status", "ok"))
	var active_incidents = int(diag.get("active_incident_count", 0))
	var tool_loader = diag.get("tool_loader", {})
	var tool_load_error_count = 0
	if tool_loader is Dictionary:
		tool_load_error_count = int((tool_loader as Dictionary).get("tool_load_error_count", 0))

	var last_operation_text = _get_localized_text(localization, "self_diag_last_operation_none", "")
	var last_operation = diag.get("last_operation", {})
	if last_operation is Dictionary and not (last_operation as Dictionary).is_empty():
		last_operation_text = "%s (%s ms)" % [
			str((last_operation as Dictionary).get("kind", "")),
			str((last_operation as Dictionary).get("duration_ms", 0.0))
		]

	var latest_incident_text = _get_localized_text(localization, "self_diag_latest_incident_none", "")
	var latest_incident = diag.get("latest_incident", {})
	if latest_incident is Dictionary and not (latest_incident as Dictionary).is_empty():
		var latest_incident_dict := latest_incident as Dictionary
		latest_incident_text = "%s | %s" % [
			_get_self_diag_code_text(str(latest_incident_dict.get("code", "")), localization),
			str(latest_incident_dict.get("message", ""))
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
		if recent_lines.size() >= MAX_SELF_DIAGNOSTIC_LINES:
			break

	return {
		"badge_text": _get_self_diag_status_text(status, localization),
		"badge_color": _get_self_diag_status_color(status),
		"summary_text": "%s | %s | %s | %s" % [
			_get_localized_text(localization, "self_diag_active_incidents", "Active incidents: %d") % active_incidents,
			_get_localized_text(localization, "self_diag_tool_load_errors", "Tool load errors: %d") % tool_load_error_count,
			_get_localized_text(localization, "self_diag_last_operation", "Last operation: %s") % last_operation_text,
			_get_localized_text(localization, "self_diag_latest_incident", "Latest incident: %s") % latest_incident_text
		],
		"details_text": _get_localized_text(localization, "self_diag_empty", "") if recent_lines.is_empty() else "\n".join(recent_lines),
		"clear_disabled": active_incidents <= 0,
		"copy_text": str(model.get("self_diagnostic_copy_text", ""))
	}


func _project_enum_options(values, current_value: String, localization, key_prefix: String) -> Array:
	var options: Array = []
	if not (values is Array):
		return options

	for raw_value in values:
		var value := str(raw_value)
		var key := "%s_%s" % [key_prefix, value]
		options.append({
			"text": _get_localized_text(localization, key, value.capitalize()),
			"value": value,
			"selected": value == current_value
		})
	return options


func _project_language_options(model: Dictionary, localization) -> Array:
	var current_language = str(model.get("current_language", DEFAULT_LANGUAGE))
	var language_codes: Array = []
	if localization != null and localization.has_method("get_available_language_codes"):
		language_codes = localization.get_available_language_codes()
	else:
		var languages: Dictionary = model.get("languages", {})
		language_codes = languages.keys()
		language_codes.sort()

	var options: Array = []
	for raw_code in language_codes:
		var language_code := str(raw_code)
		options.append({
			"text": _get_language_display_name(localization, language_code, current_language),
			"value": language_code,
			"selected": language_code == current_language
		})
	return options


func _get_language_display_name(localization, language_code: String, current_language: String) -> String:
	if language_code.is_empty():
		language_code = DEFAULT_LANGUAGE
	if localization != null and localization.has_method("get_language_display_name"):
		return str(localization.get_language_display_name(language_code, current_language))
	return language_code.capitalize()


func _get_localized_text(localization, key: String, fallback: String = "") -> String:
	if localization != null and localization.has_method("get_text"):
		var translated := str(localization.get_text(key))
		if not translated.is_empty() and translated != key:
			return translated
	return fallback if not fallback.is_empty() else key


func _get_self_diag_status_text(status: String, localization) -> String:
	match status:
		"error":
			return _get_localized_text(localization, "self_diag_status_error", "Error")
		"warning":
			return _get_localized_text(localization, "self_diag_status_warning", "Warning")
		_:
			return _get_localized_text(localization, "self_diag_status_ok", "Ok")


func _get_self_diag_status_color(status: String) -> Color:
	match status:
		"error":
			return Color(0.9, 0.3, 0.3)
		"warning":
			return Color(0.95, 0.7, 0.2)
		_:
			return Color(0.2, 0.8, 0.2)


func _get_self_diag_category_text(category: String, localization) -> String:
	return _get_localized_text(localization, "self_diag_category_%s" % category, category)


func _get_self_diag_code_text(code: String, localization) -> String:
	return _get_localized_text(localization, "self_diag_code_%s" % code, code)
