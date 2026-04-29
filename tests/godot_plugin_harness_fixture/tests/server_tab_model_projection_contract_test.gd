extends RefCounted

const ServerTabModelProjectionServiceScript = preload("res://addons/godot_dotnet_mcp/ui/server_tab_model_projection.gd")


class FullLocalization extends RefCounted:
	const TEXTS := {
		"status_running": "Running",
		"status_stopped": "Stopped",
		"tool_profile_default": "Default",
		"tool_profile_custom_short": "Custom",
		"log_level_debug": "Debug",
		"log_level_warning": "Warning",
		"log_level_info": "Info",
		"log_level_error": "Error",
		"self_diag_empty": "Empty diagnostics",
		"self_diag_status_ok": "OK",
		"self_diag_status_warning": "Warning",
		"self_diag_status_error": "Error",
		"self_diag_active_incidents": "Active incidents: %d",
		"self_diag_tool_load_errors": "Tool load errors: %d",
		"self_diag_last_operation": "Last operation: %s",
		"self_diag_latest_incident": "Latest incident: %s",
		"self_diag_last_operation_none": "none",
		"self_diag_latest_incident_none": "none",
		"self_diag_category_runtime": "Runtime",
		"self_diag_category_tool": "Tool",
		"self_diag_code_parse_error": "Parse error",
		"self_diag_code_missing_config": "Missing config",
		"self_diag_code_io_error": "I/O error"
	}

	func get_text(key: String) -> String:
		return str(TEXTS.get(key, key))

	func get_available_language_codes() -> Array:
		return ["zh_CN", "en"]

	func get_language_display_name(language_code: String, _current_language: String) -> String:
		match language_code:
			"en":
				return "English"
			"zh_CN":
				return "Chinese"
			_:
				return language_code.capitalize()


class MinimalLocalization extends RefCounted:
	func get_text(key: String) -> String:
		return str({
			"status_running": "Running",
			"status_stopped": "Stopped",
			"self_diag_empty": "Empty diagnostics",
			"self_diag_status_ok": "OK",
			"self_diag_status_warning": "Warning",
			"self_diag_status_error": "Error",
			"self_diag_last_operation_none": "none",
			"self_diag_latest_incident_none": "none"
		}.get(key, key))


func run_case(_tree: SceneTree) -> Dictionary:
	var service = ServerTabModelProjectionServiceScript.new()

	var projected = service.project(_build_primary_model())
	if str((projected.get("overview", {}) as Dictionary).get("service_text", "")) != "Running · http://10.0.0.8:4100/mcp":
		return _failure("Server tab projection should preserve the overview service text.")
	if str((projected.get("overview", {}) as Dictionary).get("config_text", "")) != "Custom · Warning · English":
		return _failure("Server tab projection should compose the overview config text from the projected values.")
	if str((projected.get("overview", {}) as Dictionary).get("activity_text", "")).find("tools/call") == -1:
		return _failure("Server tab projection should include the latest request method in the activity text.")

	var projected_self_diagnostics: Dictionary = projected.get("self_diagnostics", {})
	if str(projected_self_diagnostics.get("badge_text", "")) != "Warning":
		return _failure("Server tab projection should project the self-diagnostic status badge text.")
	if bool(projected_self_diagnostics.get("clear_disabled", true)):
		return _failure("Server tab projection should keep the clear action enabled while incidents are active.")
	if str(projected_self_diagnostics.get("copy_text", "")) != "active-diagnostics-copy":
		return _failure("Server tab projection should pass through the copy payload.")

	var badge_color: Color = projected_self_diagnostics.get("badge_color", Color())
	if absf(badge_color.r - 0.95) > 0.01 or absf(badge_color.g - 0.7) > 0.01 or absf(badge_color.b - 0.2) > 0.01:
		return _failure("Server tab projection should preserve the warning badge color.")

	var summary_text := str(projected_self_diagnostics.get("summary_text", ""))
	if summary_text != "Active incidents: 2 | Tool load errors: 1 | Last operation: snapshot (12.5 ms) | Latest incident: Parse error | Broken parser":
		return _failure("Server tab projection should build the self-diagnostic summary text.")

	var details_lines: PackedStringArray = str(projected_self_diagnostics.get("details_text", "")).split("\n")
	if details_lines.size() != 3:
		return _failure("Server tab projection should limit self-diagnostic details to the first three incidents.")
	if details_lines[0] != "Runtime | Parse error | First incident" or details_lines[2] != "Runtime | I/O error | Third incident":
		return _failure("Server tab projection should preserve the projected incident detail rows.")

	var options: Dictionary = projected.get("options", {})
	var log_levels: Array = options.get("log_levels", [])
	if log_levels.size() != 4 or not bool((log_levels[2] as Dictionary).get("selected", false)):
		return _failure("Server tab projection should mark the current log level as selected.")
	if str((log_levels[2] as Dictionary).get("text", "")) != "Warning":
		return _failure("Server tab projection should project localized log level labels.")

	var legacy_model := _build_primary_model()
	legacy_model["current_log_level"] = "trace"
	var legacy_projection = service.project(legacy_model)
	var legacy_options: Dictionary = legacy_projection.get("options", {})
	var legacy_log_levels: Array = legacy_options.get("log_levels", [])
	if not bool((legacy_log_levels[0] as Dictionary).get("selected", false)):
		return _failure("Server tab projection should normalize legacy trace settings to debug.")
	if str((legacy_projection.get("overview", {}) as Dictionary).get("config_text", "")).find("Debug") == -1:
		return _failure("Server tab overview should display Debug instead of legacy Trace.")

	var language_options: Array = options.get("languages", [])
	if language_options.size() != 2:
		return _failure("Server tab projection should use the localization-provided language list when available.")
	if str((language_options[0] as Dictionary).get("text", "")) != "Chinese" or not bool((language_options[1] as Dictionary).get("selected", false)):
		return _failure("Server tab projection should project localized language labels and current selection.")

	var empty_projection = service.project(_build_fallback_model())
	var empty_self_diagnostics: Dictionary = empty_projection.get("self_diagnostics", {})
	if str(empty_self_diagnostics.get("badge_text", "")) != "":
		return _failure("Server tab projection should hide the badge when there are no diagnostics.")
	if str(empty_self_diagnostics.get("summary_text", "")) != "Empty diagnostics":
		return _failure("Server tab projection should show the empty-diagnostics copy when there is no data.")
	if str(empty_self_diagnostics.get("details_text", "")) != "":
		return _failure("Server tab projection should keep the details area empty when there are no diagnostics.")
	if not bool(empty_self_diagnostics.get("clear_disabled", false)):
		return _failure("Server tab projection should disable clear when there are no active incidents.")

	var fallback_languages: Array = (empty_projection.get("options", {}) as Dictionary).get("languages", [])
	if fallback_languages.size() != 2:
		return _failure("Server tab projection should fall back to the sorted language dictionary keys.")
	if str((fallback_languages[0] as Dictionary).get("value", "")) != "en" or str((fallback_languages[1] as Dictionary).get("value", "")) != "zh_CN":
		return _failure("Server tab projection should sort the fallback language keys.")

	var empty_activity = str((empty_projection.get("overview", {}) as Dictionary).get("activity_text", ""))
	if empty_activity.find("none") == -1:
		return _failure("Server tab projection should use the no-request fallback when there is no last request time.")

	return {
		"name": "server_tab_model_projection_contracts",
		"success": true,
		"error": "",
		"details": {
			"log_level_options": log_levels.size(),
			"language_options": language_options.size(),
			"details_rows": details_lines.size()
		}
	}


func _build_primary_model() -> Dictionary:
	return {
		"localization": FullLocalization.new(),
		"settings": {
			"host": "10.0.0.8",
			"port": 4100
		},
		"stats": {
			"active_connections": 2,
			"total_connections": 5,
			"total_requests": 9,
			"last_request_at_unix": 1_700_000_000,
			"last_request_method": "tools/call"
		},
		"self_diagnostics": {
			"status": "warning",
			"summary": "Minor issues",
			"active_incident_count": 2,
			"tool_loader": {
				"tool_load_error_count": 1
			},
			"last_operation": {
				"kind": "snapshot",
				"duration_ms": 12.5
			},
			"latest_incident": {
				"code": "parse_error",
				"message": "Broken parser"
			},
			"recent_incidents": [
				{
					"category": "runtime",
					"code": "parse_error",
					"message": "First incident"
				},
				{
					"category": "tool",
					"code": "missing_config",
					"message": "Second incident"
				},
				{
					"category": "runtime",
					"code": "io_error",
					"message": "Third incident"
				},
				{
					"category": "runtime",
					"code": "parse_error",
					"message": "Fourth incident"
				}
			]
		},
		"self_diagnostic_copy_text": "active-diagnostics-copy",
		"is_running": true,
		"tool_profile_id": "custom-profile",
		"current_log_level": "warning",
		"current_language": "en",
		"log_levels": ["debug", "info", "warning", "error"],
		"languages": {
			"zh_CN": true,
			"en": true
		}
	}


func _build_fallback_model() -> Dictionary:
	return {
		"localization": MinimalLocalization.new(),
		"settings": {
			"host": "127.0.0.1",
			"port": 3000
		},
		"stats": {
			"active_connections": 0,
			"total_connections": 0,
			"total_requests": 0,
			"last_request_at_unix": 0,
			"last_request_method": ""
		},
		"self_diagnostics": {},
		"is_running": false,
		"current_language": "es",
		"log_levels": ["info"],
		"languages": {
			"zh_CN": true,
			"en": true
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "server_tab_model_projection_contracts",
		"success": false,
		"error": message
	}
