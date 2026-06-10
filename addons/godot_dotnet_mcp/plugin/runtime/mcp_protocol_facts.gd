@tool
extends RefCounted

const FACTS_PATH := "res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.json"

static func get_all() -> Dictionary:
	return _load_facts().duplicate(true)


static func get_protocol_version() -> String:
	return str(get_all().get("protocol_version", ""))


static func get_tool_schema_version() -> String:
	return str(get_all().get("tool_schema_version", ""))


static func get_server_name() -> String:
	return str(get_all().get("server_name", ""))


static func get_server_description() -> String:
	return str(get_all().get("server_description", ""))


static func get_server_version() -> String:
	return str(get_all().get("server_version", ""))


static func get_error_codes() -> Dictionary:
	var error_codes = get_all().get("error_codes", {})
	if error_codes is Dictionary:
		return (error_codes as Dictionary).duplicate(true)
	return {}


static func get_error_code(key: String) -> String:
	var error_codes = get_error_codes()
	return str(error_codes.get(key, key))


static func build_server_info() -> Dictionary:
	return {
		"name": get_server_name(),
		"description": get_server_description(),
		"version": get_server_version()
	}


static func build_server_facts() -> Dictionary:
	return {
		"server_name": get_server_name(),
		"server_description": get_server_description(),
		"server_version": get_server_version(),
		"protocol_version": get_protocol_version(),
		"tool_schema_version": get_tool_schema_version()
	}


static func _load_facts() -> Dictionary:
	if not FileAccess.file_exists(FACTS_PATH):
		push_error("[MCP] Protocol facts file is missing: %s" % FACTS_PATH)
		return _default_facts()

	var raw_text := FileAccess.get_file_as_string(FACTS_PATH)
	if raw_text.is_empty():
		push_error("[MCP] Protocol facts file is empty: %s" % FACTS_PATH)
		return _default_facts()

	var json := JSON.new()
	if json.parse(raw_text) != OK:
		push_error("[MCP] Failed to parse protocol facts: %s" % json.get_error_message())
		return _default_facts()

	var data = json.get_data()
	if not (data is Dictionary):
		push_error("[MCP] Protocol facts file must contain a dictionary payload.")
		return _default_facts()

	var facts: Dictionary = data
	var error_codes := {}
	var raw_error_codes = facts.get("error_codes", {})
	if raw_error_codes is Dictionary:
		error_codes = (raw_error_codes as Dictionary).duplicate(true)

	return {
		"protocol_version": str(facts.get("protocol_version", "")),
		"tool_schema_version": str(facts.get("tool_schema_version", "")),
		"server_name": str(facts.get("server_name", "")),
		"server_description": str(facts.get("server_description", "")),
		"server_version": str(facts.get("server_version", "")),
		"error_codes": error_codes
	}


static func _default_facts() -> Dictionary:
	return {
		"protocol_version": "2025-11-25",
		"tool_schema_version": "2026-06-08.33",
		"server_name": "godot-dotnet-mcp",
		"server_description": "Godot editor MCP server for resource-first project context, automation, diagnostics, and validation.",
		"server_version": "1.4.0",
		"error_codes": {
			"bridge_version_mismatch": "bridge_version_mismatch",
			"runtime_not_running": "runtime_not_running",
			"runtime_control_disabled": "runtime_control_disabled",
			"runtime_session_lost": "runtime_session_lost",
			"runtime_command_timeout": "runtime_command_timeout",
			"runtime_bridge_unavailable": "runtime_bridge_unavailable",
			"runtime_capture_failed": "runtime_capture_failed",
			"invalid_argument": "invalid_argument",
			"permission_denied": "permission_denied",
			"tool_load_failed": "tool_load_failed",
			"tool_runtime_missing": "tool_runtime_missing",
			"tool_execution_failed": "tool_execution_failed",
			"project_lifecycle_action_required": "project_lifecycle_action_required",
			"project_lifecycle_marker_validation_requires_async": "project_lifecycle_marker_validation_requires_async",
			"run_log_failure_marker_matched": "run_log_failure_marker_matched",
			"run_log_marker_timeout": "run_log_marker_timeout",
			"parse_error": "parse_error",
			"missing_executable": "missing_executable",
			"invalid_working_directory": "invalid_working_directory",
			"precheck_read_error": "precheck_read_error",
			"backup_error": "backup_error",
			"write_error": "write_error",
			"dir_error": "dir_error",
			"resource_not_found": "resource_not_found",
			"prompt_not_found": "prompt_not_found",
			"dap_unavailable": "dap_unavailable",
			"dap_response_failed": "dap_response_failed",
			"dap_invalid_session_state": "dap_invalid_session_state",
			"dap_invalid_settings": "dap_invalid_settings",
			"dap_limit_exceeded": "dap_limit_exceeded"
		}
	}
