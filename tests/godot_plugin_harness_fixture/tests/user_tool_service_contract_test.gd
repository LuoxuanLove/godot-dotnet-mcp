extends RefCounted

const UserToolServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_service.gd")
const UserDataPathsScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_user_data_paths.gd")
const CUSTOM_TOOLS_DIR := "res://addons/godot_dotnet_mcp/custom_tools"
const BACKUP_DIR := "res://addons/godot_dotnet_mcp/custom_tools/.backup"
const AUDIT_LOG_PATH := UserDataPathsScript.USER_TOOL_AUDIT_LOG_PATH


var _service = null
var _created_script_path := ""
var _legacy_prefixed_script_path := ""
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

	var compatibility_report: Dictionary = _service.get_compatibility_report()
	if int(compatibility_report.get("user_tool_count", 0)) <= 0:
		return _failure("Compatibility report should include at least one user tool.")
	if not _contains_script_path((compatibility_report.get("compatible", []) as Array), _created_script_path):
		return _failure("Compatibility report should include the created scaffold as compatible.")
	if not _contains_script_path((compatibility_report.get("needs_review", []) as Array), _legacy_prefixed_script_path):
		return _failure("Compatibility report should route user tool naming warnings to needs_review.")
	var legacy_compat_entry := _find_script_entry(compatibility_report.get("needs_review", []) as Array, _legacy_prefixed_script_path)
	if int(legacy_compat_entry.get("naming_warning_count", 0)) <= 0:
		return _failure("Compatibility report should count user tool naming warnings.")

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
		}
	])
	if int(diagnostics.get("discovered_script_count", 0)) < 2:
		return _failure("Runtime diagnostics should report discovered user tool scripts.")
	if int(diagnostics.get("failed_load_count", 0)) < 2:
		return _failure("Runtime diagnostics should report failed user tool script loads.")
	if not _contains_failed_load(diagnostics.get("failed_loads", []), _invalid_script_path):
		return _failure("Runtime diagnostics should identify failed user tool script paths.")
	if int(diagnostics.get("runtime_failed_count", 0)) != 1:
		return _failure("Runtime diagnostics should report executor-level runtime failures without counting healthy null-error slots.")
	if not _contains_failed_load(diagnostics.get("failed_loads", []), "res://addons/godot_dotnet_mcp/custom_tools/runtime_failed_user_tool.gd"):
		return _failure("Runtime diagnostics should merge executor-level reload failures into failed loads.")
	if _contains_failed_load(diagnostics.get("failed_loads", []), "res://addons/godot_dotnet_mcp/custom_tools/runtime_healthy_user_tool.gd"):
		return _failure("Runtime diagnostics should not turn healthy null-error runtime slots into failed loads.")
	if int(diagnostics.get("runtime_state_count", 0)) != 2:
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
	_remove_path(_invalid_script_path)
	_remove_path("%s.uid" % _invalid_script_path)
	_remove_path(_backup_path)
	_remove_path(_backup_uid_path)
	_remove_path(_latest_deleted_meta_path)
	_remove_path(AUDIT_LOG_PATH)
	_service = null
	_created_script_path = ""
	_legacy_prefixed_script_path = ""
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
	if not (entries is Array):
		return false
	for entry in entries:
		if entry is Dictionary and str((entry as Dictionary).get("script_path", "")) == script_path:
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


func _failure(message: String) -> Dictionary:
	return {
		"name": "user_tool_service_contracts",
		"success": false,
		"error": message
	}
