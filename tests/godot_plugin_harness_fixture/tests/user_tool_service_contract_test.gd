extends RefCounted

const UserExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/user/executor.gd")
const UserToolServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_service.gd")
const UserDataPathsScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_user_data_paths.gd")
const CUSTOM_TOOLS_DIR := "res://addons/godot_dotnet_mcp/custom_tools"
const BACKUP_DIR := "res://addons/godot_dotnet_mcp/custom_tools/.backup"
const AUDIT_LOG_PATH := UserDataPathsScript.USER_TOOL_AUDIT_LOG_PATH
const USER_TOOLS_ENABLED_SETTING := "godot_dotnet_mcp/user_tools/enable_runtime_loading"


var _service = null
var _created_script_path := ""
var _legacy_prefixed_script_path := ""
var _invalid_name_script_path := ""
var _reload_invalid_name_script_path := ""
var _invalid_script_path := ""
var _backup_path := ""
var _backup_uid_path := ""
var _latest_deleted_meta_path := "%s/latest_deleted.json" % BACKUP_DIR


func run_case(_tree: SceneTree) -> Dictionary:
	_service = UserToolServiceScript.new()

	var tool_name = "user_tool_contract_%d_%d" % [int(Time.get_unix_time_from_system()), randi()]
	var create_result: Dictionary = _service.create_tool_scaffold(
		tool_name,
		"",
		"User tool service contract test",
		true,
		"user_tool_service_contract_test"
	)
	if not bool(create_result.get("success", false)):
		return _failure("User tool scaffold creation should succeed.")

	var create_data: Dictionary = create_result.get("data", {}) as Dictionary
	_created_script_path = str(create_data.get("script_path", ""))
	var declared_tool_name := str(create_data.get("declared_tool_name", ""))
	var public_tool_name := str(create_data.get("public_tool_name", ""))
	if _created_script_path.is_empty():
		return _failure("Created user tool should report a script path.")
	if not FileAccess.file_exists(_created_script_path):
		return _failure("Created user tool script should exist on disk.")
	if declared_tool_name.is_empty() or declared_tool_name.begins_with("user_"):
		return _failure("Created user tool should normalize the internal declared tool name.")
	if public_tool_name != "user_%s" % declared_tool_name:
		return _failure("Created user tool should report the public User-domain tool name.")
	if str(create_data.get("tool_name", "")) != declared_tool_name:
		return _failure("Created user tool should keep tool_name aligned with the normalized declared tool name.")

	var tools: Array[Dictionary] = _service.list_user_tools()
	if not _contains_script_path(tools, _created_script_path):
		return _failure("User tool catalog should include the created scaffold.")
	var created_entry := _find_script_entry(tools, _created_script_path)
	if not _array_has_string(created_entry.get("declared_tool_names", []), declared_tool_name):
		return _failure("User tool catalog should report declared tool names for scaffolds.")
	if not _array_has_string(created_entry.get("normalized_tool_names", []), declared_tool_name):
		return _failure("User tool catalog should report normalized tool names for scaffolds.")
	if not _array_has_string(created_entry.get("public_tool_names", []), public_tool_name):
		return _failure("User tool catalog should report public tool names for scaffolds.")
	if _count_array_items(created_entry.get("tool_name_warnings", [])) != 0:
		return _failure("Current scaffolds should not report user tool naming warnings.")

	var legacy_logical_name := "legacy_prefixed_%d_%d" % [int(Time.get_unix_time_from_system()), randi()]
	_legacy_prefixed_script_path = "%s/user_%s.gd" % [CUSTOM_TOOLS_DIR, legacy_logical_name]
	var legacy_file := FileAccess.open(_legacy_prefixed_script_path, FileAccess.WRITE)
	if legacy_file == null:
		return _failure("User tool naming diagnostics fixture should create a legacy prefixed script.")
	legacy_file.store_string(_build_legacy_prefixed_tool(legacy_logical_name))
	legacy_file.close()

	tools = _service.list_user_tools()
	var legacy_entry := _find_script_entry(tools, _legacy_prefixed_script_path)
	if legacy_entry.is_empty():
		return _failure("User tool catalog should include legacy prefixed tool fixtures.")
	if not _array_has_string(legacy_entry.get("declared_tool_names", []), "user_%s" % legacy_logical_name):
		return _failure("User tool catalog should preserve declared prefixed tool names.")
	if not _array_has_string(legacy_entry.get("normalized_tool_names", []), legacy_logical_name):
		return _failure("User tool catalog should report normalized names for prefixed declarations.")
	if not _array_has_string(legacy_entry.get("public_tool_names", []), "user_%s" % legacy_logical_name):
		return _failure("User tool catalog should report public names for prefixed declarations.")
	if not _has_warning_code(legacy_entry.get("tool_name_warnings", []), "user_prefix_normalized"):
		return _failure("User tool catalog should warn when declared names include the public user_ prefix.")

	_invalid_name_script_path = "%s/invalid_mcp_name_%d.gd" % [CUSTOM_TOOLS_DIR, randi()]
	var invalid_name_file := FileAccess.open(_invalid_name_script_path, FileAccess.WRITE)
	if invalid_name_file == null:
		return _failure("User tool naming diagnostics fixture should create an invalid-name script.")
	invalid_name_file.store_string(_build_invalid_name_tool())
	invalid_name_file.close()

	tools = _service.list_user_tools()
	var invalid_name_entry := _find_script_entry(tools, _invalid_name_script_path)
	if invalid_name_entry.is_empty():
		return _failure("User tool catalog should include invalid-name tool fixtures for diagnostics.")
	if not _has_warning_code(invalid_name_entry.get("tool_name_warnings", []), "invalid_mcp_public_tool_name"):
		return _failure("User tool catalog should warn when public names violate MCP 2025-11-25 naming guidance.")

	var compatibility_report: Dictionary = _service.get_compatibility_report()
	if int(compatibility_report.get("user_tool_count", 0)) <= 0:
		return _failure("Compatibility report should include at least one user tool.")
	if not _contains_script_path((compatibility_report.get("compatible", []) as Array), _created_script_path):
		return _failure("Compatibility report should include the created scaffold as compatible.")
	if not _contains_script_path((compatibility_report.get("needs_review", []) as Array), _legacy_prefixed_script_path):
		return _failure("Compatibility report should route user tool naming warnings to needs_review.")
	if not _contains_script_path((compatibility_report.get("needs_review", []) as Array), _invalid_name_script_path):
		return _failure("Compatibility report should route invalid MCP public user tool names to needs_review.")
	var legacy_compat_entry := _find_script_entry(compatibility_report.get("needs_review", []) as Array, _legacy_prefixed_script_path)
	if int(legacy_compat_entry.get("naming_warning_count", 0)) <= 0:
		return _failure("Compatibility report should count user tool naming warnings.")
	var invalid_create_result: Dictionary = _service.create_tool_scaffold(
		("a").repeat(140),
		"",
		"Invalid MCP public name",
		true,
		"user_tool_service_contract_test"
	)
	if bool(invalid_create_result.get("success", false)):
		return _failure("User tool scaffold creation should reject invalid MCP public tool names.")
	if str((invalid_create_result.get("data", {}) as Dictionary).get("public_tool_name", "")).length() <= 128:
		return _failure("Invalid scaffold rejection should report the rejected overlong public tool name.")
	var reload_guard_result := _verify_failed_reload_removes_public_user_tool()
	if not bool(reload_guard_result.get("success", false)):
		return reload_guard_result
	var scan_backoff_result := _verify_user_executor_scan_backoff()
	if not bool(scan_backoff_result.get("success", false)):
		return scan_backoff_result

	var audit_entries: Array[Dictionary] = _service.get_audit_entries(20, "create_user_tool")
	if not _contains_script_path(audit_entries, _created_script_path):
		return _failure("Audit log should record the create_user_tool action for the scaffold.")

	_invalid_script_path = "%s/runtime_diagnostics_invalid_%d.gd" % [CUSTOM_TOOLS_DIR, randi()]
	var invalid_file := FileAccess.open(_invalid_script_path, FileAccess.WRITE)
	if invalid_file == null:
		return _failure("User tool runtime diagnostics fixture should create an invalid script.")
	invalid_file.store_string("extends RefCounted\n\nfunc not_a_user_tool() -> void:\n\tpass\n")
	invalid_file.close()
	var diagnostics: Dictionary = _service.get_runtime_diagnostics({
		"enabled": true,
		"watching": true,
		"known_script_count": 2,
		"last_error": ""
	}, 5, [
		{
			"script_path": "res://addons/godot_dotnet_mcp/custom_tools/runtime_healthy_user_tool.gd",
			"runtime_domain": "user/runtime_healthy_user_tool",
			"version": 2,
			"state": "loaded",
			"active_calls": 0,
			"pending_reload": false,
			"removed_pending": false,
			"last_loaded_at_unix": 0,
			"last_error": null,
			"discovery_source": "plugin_flow",
			"last_refresh_reason": "initialize"
		},
		{
			"script_path": "res://addons/godot_dotnet_mcp/custom_tools/runtime_failed_user_tool.gd",
			"runtime_domain": "user/runtime_failed_user_tool",
			"version": 3,
			"state": "reload_failed",
			"active_calls": 0,
			"pending_reload": false,
			"removed_pending": false,
			"last_loaded_at_unix": 0,
			"last_error": "Duplicate user tool logical name: duplicated_tool",
			"discovery_source": "watcher",
			"last_refresh_reason": "file_changed"
		},
		{
			"script_path": "res://addons/godot_dotnet_mcp/custom_tools/runtime_reload_failed_user_tool.gd",
			"runtime_domain": "user/runtime_reload_failed_user_tool",
			"version": 4,
			"state": "reload_failed",
			"active_calls": 0,
			"pending_reload": false,
			"removed_pending": false,
			"last_loaded_at_unix": 0,
			"last_error": "Missing dependency while reloading user tool",
			"discovery_source": "watcher",
			"last_refresh_reason": "file_changed"
		},
		{
			"script_path": "res://addons/godot_dotnet_mcp/custom_tools/runtime_unknown_user_tool.gd",
			"runtime_domain": "user/runtime_unknown_user_tool",
			"version": 5,
			"state": "load_failed",
			"active_calls": 0,
			"pending_reload": false,
			"removed_pending": false,
			"last_loaded_at_unix": 0,
			"last_error": "unknown",
			"discovery_source": "watcher",
			"last_refresh_reason": "file_changed"
		},
		{
			"script_path": "res://addons/godot_dotnet_mcp/custom_tools/runtime_invalid_name_user_tool.gd",
			"runtime_domain": "user/runtime_invalid_name_user_tool",
			"version": 6,
			"state": "reload_failed",
			"active_calls": 0,
			"pending_reload": false,
			"removed_pending": false,
			"last_loaded_at_unix": 0,
			"last_error": "User tool declared an invalid MCP public tool name: user_bad/name",
			"discovery_source": "watcher",
			"last_refresh_reason": "file_changed"
		}
	])
	if int(diagnostics.get("discovered_script_count", 0)) < 2:
		return _failure("Runtime diagnostics should report discovered user tool scripts.")
	if int(diagnostics.get("failed_load_count", 0)) < 2:
		return _failure("Runtime diagnostics should report failed user tool script loads.")
	if not _contains_failed_load(diagnostics.get("failed_loads", []), _invalid_script_path):
		return _failure("Runtime diagnostics should identify failed user tool script paths.")
	var invalid_failure := _find_failed_load(diagnostics.get("failed_loads", []), _invalid_script_path)
	if str(invalid_failure.get("diagnostic_code", "")) != "missing_user_tool_definitions":
		return _failure("Runtime diagnostics should classify invalid user tool scripts with missing definition guidance.")
	if str(invalid_failure.get("recommended_action", "")).find("get_tools()") == -1:
		return _failure("Runtime diagnostics should explain how to recover missing user tool definitions.")
	if int(diagnostics.get("runtime_failed_count", 0)) != 3:
		return _failure("Runtime diagnostics should report executor-level runtime failures without counting healthy null-error slots.")
	if not _contains_failed_load(diagnostics.get("failed_loads", []), "res://addons/godot_dotnet_mcp/custom_tools/runtime_failed_user_tool.gd"):
		return _failure("Runtime diagnostics should merge executor-level reload failures into failed loads.")
	var duplicate_failure := _find_failed_load(diagnostics.get("failed_loads", []), "res://addons/godot_dotnet_mcp/custom_tools/runtime_failed_user_tool.gd")
	if str(duplicate_failure.get("diagnostic_code", "")) != "duplicate_user_tool_logical_name":
		return _failure("Runtime diagnostics should classify duplicate user tool logical names.")
	if str(duplicate_failure.get("next_tool_hint", "")).find("plugin_evolution_runtime_diagnostics") == -1:
		return _failure("Runtime diagnostics should provide a follow-up tool hint for duplicate failures.")
	var reload_failure := _find_failed_load(diagnostics.get("failed_loads", []), "res://addons/godot_dotnet_mcp/custom_tools/runtime_reload_failed_user_tool.gd")
	if str(reload_failure.get("diagnostic_code", "")) != "user_tool_runtime_reload_failed":
		return _failure("Runtime diagnostics should classify reload_failed runtime entries before generic missing-definition guidance.")
	if str(reload_failure.get("recommended_action", "")).find("reload error") == -1:
		return _failure("Runtime diagnostics should explain how to recover generic reload_failed runtime entries.")
	var unknown_failure := _find_failed_load(diagnostics.get("failed_loads", []), "res://addons/godot_dotnet_mcp/custom_tools/runtime_unknown_user_tool.gd")
	if str(unknown_failure.get("diagnostic_code", "")) != "user_tool_load_unknown":
		return _failure("Runtime diagnostics should classify empty runtime load errors as unknown user tool loads.")
	var invalid_name_runtime_failure := _find_failed_load(diagnostics.get("failed_loads", []), "res://addons/godot_dotnet_mcp/custom_tools/runtime_invalid_name_user_tool.gd")
	if str(invalid_name_runtime_failure.get("diagnostic_code", "")) != "invalid_mcp_public_tool_name":
		return _failure("Runtime diagnostics should classify invalid MCP public user tool names.")
	if str(invalid_name_runtime_failure.get("recommended_action", "")).find("ASCII") == -1:
		return _failure("Runtime diagnostics should explain how to recover invalid MCP public user tool names.")
	if _contains_failed_load(diagnostics.get("failed_loads", []), "res://addons/godot_dotnet_mcp/custom_tools/runtime_healthy_user_tool.gd"):
		return _failure("Runtime diagnostics should not turn healthy null-error runtime slots into failed loads.")
	if int(diagnostics.get("runtime_state_count", 0)) != 5:
		return _failure("Runtime diagnostics should preserve runtime state snapshot entries.")
	var watch_status = diagnostics.get("watch", {})
	if not (watch_status is Dictionary) or not bool((watch_status as Dictionary).get("watching", false)):
		return _failure("Runtime diagnostics should preserve watcher status.")
	if int(diagnostics.get("recent_audit_count", 0)) < 1:
		return _failure("Runtime diagnostics should include recent audit entries.")

	var delete_result: Dictionary = _service.delete_tool(_created_script_path, true, "user_tool_service_contract_test")
	if not bool(delete_result.get("success", false)):
		return _failure("User tool deletion should succeed.")

	var delete_data: Dictionary = delete_result.get("data", {}) as Dictionary
	_backup_path = str(delete_data.get("backup_path", ""))
	_backup_uid_path = str(delete_data.get("backup_uid_path", ""))
	if _backup_path.is_empty() or not FileAccess.file_exists(_backup_path):
		return _failure("Deleting the user tool should create a backup file.")
	if FileAccess.file_exists(_created_script_path):
		return _failure("Deleted user tool script should no longer exist.")

	var restore_result: Dictionary = _service.restore_latest_backup(true, "user_tool_service_contract_test")
	if not bool(restore_result.get("success", false)):
		return _failure("User tool restore should succeed.")
	if not FileAccess.file_exists(_created_script_path):
		return _failure("Restored user tool script should exist on disk.")

	return {
		"name": "user_tool_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_name": tool_name,
			"script_path": _created_script_path,
			"backup_path": _backup_path,
			"audit_count": audit_entries.size()
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	_remove_path(_created_script_path)
	_remove_path("%s.uid" % _created_script_path)
	_remove_path(_legacy_prefixed_script_path)
	_remove_path("%s.uid" % _legacy_prefixed_script_path)
	_remove_path(_invalid_name_script_path)
	_remove_path("%s.uid" % _invalid_name_script_path)
	_remove_path(_reload_invalid_name_script_path)
	_remove_path("%s.uid" % _reload_invalid_name_script_path)
	_remove_path(_invalid_script_path)
	_remove_path("%s.uid" % _invalid_script_path)
	_remove_path(_backup_path)
	_remove_path(_backup_uid_path)
	_remove_path(_latest_deleted_meta_path)
	_remove_path(AUDIT_LOG_PATH)
	_service = null
	_created_script_path = ""
	_legacy_prefixed_script_path = ""
	_invalid_name_script_path = ""
	_reload_invalid_name_script_path = ""
	_invalid_script_path = ""
	_backup_path = ""
	_backup_uid_path = ""


func _contains_script_path(entries: Array, script_path: String) -> bool:
	for entry in entries:
		if entry is Dictionary:
			if str(entry.get("script_path", "")) == script_path:
				return true
			var payload = entry.get("payload", {})
			if payload is Dictionary and str((payload as Dictionary).get("script_path", "")) == script_path:
				return true
			var data = entry.get("data", {})
			if data is Dictionary and str((data as Dictionary).get("script_path", "")) == script_path:
				return true
	return false


func _find_script_entry(entries: Array, script_path: String) -> Dictionary:
	for entry in entries:
		if entry is Dictionary and str((entry as Dictionary).get("script_path", "")) == script_path:
			return (entry as Dictionary)
	return {}


func _array_has_string(values, expected: String) -> bool:
	if not (values is Array):
		return false
	for value in values:
		if str(value) == expected:
			return true
	return false


func _has_warning_code(warnings, expected_code: String) -> bool:
	if not (warnings is Array):
		return false
	for warning in warnings:
		if warning is Dictionary and str((warning as Dictionary).get("code", "")) == expected_code:
			return true
	return false


func _count_array_items(values) -> int:
	return (values as Array).size() if values is Array else 0


func _contains_failed_load(entries, script_path: String) -> bool:
	return not _find_failed_load(entries, script_path).is_empty()


func _find_failed_load(entries, script_path: String) -> Dictionary:
	if not (entries is Array):
		return {}
	for entry in entries:
		if entry is Dictionary and str((entry as Dictionary).get("script_path", "")) == script_path:
			return entry as Dictionary
	return {}


func _verify_failed_reload_removes_public_user_tool() -> Dictionary:
	var previous_setting_exists := ProjectSettings.has_setting(USER_TOOLS_ENABLED_SETTING)
	var previous_setting_value = ProjectSettings.get_setting(USER_TOOLS_ENABLED_SETTING, false)
	ProjectSettings.set_setting(USER_TOOLS_ENABLED_SETTING, true)

	_reload_invalid_name_script_path = "%s/reload_invalid_mcp_name_%d.gd" % [CUSTOM_TOOLS_DIR, randi()]
	var logical_name := "reload_valid_%d" % randi()
	var valid_file := FileAccess.open(_reload_invalid_name_script_path, FileAccess.WRITE)
	if valid_file == null:
		_restore_user_tools_enabled_setting(previous_setting_exists, previous_setting_value)
		return _failure("User tool reload guard fixture should create a valid script.")
	valid_file.store_string(_build_reload_guard_user_tool(logical_name))
	valid_file.close()

	var executor = UserExecutorScript.new()
	var initial_tools: Array[Dictionary] = executor.get_tools()
	if not _array_has_tool_name(initial_tools, logical_name):
		_restore_user_tools_enabled_setting(previous_setting_exists, previous_setting_value)
		return _failure("User tool executor should expose the initial valid custom tool.")

	var invalid_file := FileAccess.open(_reload_invalid_name_script_path, FileAccess.WRITE)
	if invalid_file == null:
		_restore_user_tools_enabled_setting(previous_setting_exists, previous_setting_value)
		return _failure("User tool reload guard fixture should rewrite the script with an invalid name.")
	invalid_file.store_string(_build_invalid_name_tool())
	invalid_file.close()
	executor.request_reload_by_script(_reload_invalid_name_script_path, "contract_invalid_name_reload")
	var reloaded_tools: Array[Dictionary] = executor.get_tools()
	var runtime_state := executor.get_runtime_state_snapshot()
	_restore_user_tools_enabled_setting(previous_setting_exists, previous_setting_value)

	if _array_has_tool_name(reloaded_tools, logical_name):
		return _failure("Failed user tool reload should remove the previously exposed public tool name.")
	if _array_has_tool_name(reloaded_tools, "bad/name"):
		return _failure("Failed user tool reload should never expose the invalid tool name.")
	var reload_state := _find_script_entry(runtime_state, _reload_invalid_name_script_path)
	if str(reload_state.get("state", "")) != "reload_failed":
		return _failure("Failed user tool reload should retain a reload_failed runtime diagnostic state.")
	if str(reload_state.get("last_error", "")).find("invalid MCP public tool name") == -1:
		return _failure("Failed user tool reload should explain the invalid MCP public tool name.")
	return {"success": true}


func _verify_user_executor_scan_backoff() -> Dictionary:
	var source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/tools/user/executor.gd")
	if source.find("const _INVENTORY_RESCAN_INTERVAL_MSEC := 5000") == -1:
		return _failure("User tool executor should keep low-frequency fallback inventory rescans to avoid duplicating the watcher scan loop.")
	if source.find("UserToolScanService") == -1:
		return _failure("User tool executor should reuse UserToolScanService for fallback inventory scans.")
	if source.find("func _collect_script_paths") != -1:
		return _failure("User tool executor should not keep a second recursive custom_tools directory scanner.")
	if source.find("if _pending_refresh:") == -1 or source.find("now_msec - _last_scan_msec >= _RELOAD_DEBOUNCE_MSEC") == -1:
		return _failure("User tool executor should keep the short debounce only for explicit pending refreshes.")
	if source.find("now_msec - _last_scan_msec >= _INVENTORY_RESCAN_INTERVAL_MSEC") == -1:
		return _failure("User tool executor should use the longer inventory rescan interval for idle fallback scans.")

	var previous_setting_exists := ProjectSettings.has_setting(USER_TOOLS_ENABLED_SETTING)
	var previous_setting_value = ProjectSettings.get_setting(USER_TOOLS_ENABLED_SETTING, false)
	ProjectSettings.set_setting(USER_TOOLS_ENABLED_SETTING, true)
	var executor = UserExecutorScript.new()
	executor._last_scan_msec = Time.get_ticks_msec()
	executor._pending_refresh = false
	var before_idle_scan_msec := int(executor._last_scan_msec)
	executor.tick(0.0)
	if int(executor._last_scan_msec) != before_idle_scan_msec:
		_restore_user_tools_enabled_setting(previous_setting_exists, previous_setting_value)
		return _failure("User tool executor should not run idle fallback inventory scans inside the long rescan interval.")
	executor._pending_refresh = true
	executor._last_scan_msec = Time.get_ticks_msec() - 500
	executor.tick(0.0)
	var pending_cleared := not bool(executor._pending_refresh)
	_restore_user_tools_enabled_setting(previous_setting_exists, previous_setting_value)
	if not pending_cleared:
		return _failure("User tool executor should still process explicit pending refreshes after the short debounce.")
	return {"success": true}


func _restore_user_tools_enabled_setting(previous_exists: bool, previous_value) -> void:
	if previous_exists:
		ProjectSettings.set_setting(USER_TOOLS_ENABLED_SETTING, previous_value)
	else:
		ProjectSettings.set_setting(USER_TOOLS_ENABLED_SETTING, null)


func _array_has_tool_name(entries: Array, expected_name: String) -> bool:
	for entry in entries:
		if entry is Dictionary and str((entry as Dictionary).get("name", "")) == expected_name:
			return true
	return false


func _remove_path(path: String) -> void:
	if path.is_empty():
		return
	var global_path = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(global_path):
		DirAccess.remove_absolute(global_path)


func _build_legacy_prefixed_tool(logical_name: String) -> String:
	return """@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

const _SCAFFOLD_VERSION := "0.4.0"


func get_registration() -> Dictionary:
	return {
		"category": "user",
		"domain_key": "user",
		"hot_reloadable": true,
		"display_name": "Legacy Prefixed Tool"
	}


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "user_%s",
			"description": "Legacy prefixed user tool",
			"inputSchema": {"type": "object", "properties": {}}
		}
	]


func execute(tool_name_value: String, _args: Dictionary) -> Dictionary:
	match tool_name_value:
		"%s":
			return {"success": true}
		_:
			return {"success": false, "error": "Unknown user tool: %%s" %% tool_name_value}
""" % [logical_name, logical_name]


func _build_reload_guard_user_tool(logical_name: String) -> String:
	return """@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

const _SCAFFOLD_VERSION := "0.4.0"


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "%s",
			"description": "Reload guard user tool",
			"inputSchema": {"type": "object", "properties": {}}
		}
	]


func execute(tool_name_value: String, _args: Dictionary) -> Dictionary:
	match tool_name_value:
		"%s":
			return {"success": true}
		_:
			return {"success": false, "error": "Unknown user tool: %%s" %% tool_name_value}
""" % [logical_name, logical_name]


func _build_invalid_name_tool() -> String:
	return """@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

const _SCAFFOLD_VERSION := "0.4.0"


func get_registration() -> Dictionary:
	return {
		"category": "user",
		"domain_key": "user",
		"hot_reloadable": true,
		"display_name": "Invalid Name Tool"
	}


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "bad/name",
			"description": "Invalid public user tool name",
			"inputSchema": {"type": "object", "properties": {}}
		}
	]


func execute(tool_name_value: String, _args: Dictionary) -> Dictionary:
	return {"success": false, "error": "Unknown user tool: %s" % tool_name_value}
"""


func _failure(message: String) -> Dictionary:
	return {
		"name": "user_tool_service_contracts",
		"success": false,
		"error": message
	}
