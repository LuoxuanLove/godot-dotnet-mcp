extends RefCounted

const UserToolServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_service.gd")
const CUSTOM_TOOLS_DIR := "res://addons/godot_dotnet_mcp/custom_tools"
const BACKUP_DIR := "res://addons/godot_dotnet_mcp/custom_tools/.backup"
const AUDIT_LOG_PATH := "user://godot_dotnet_mcp_user_tool_audit.log"


var _service = null
var _created_script_path := ""
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
	if _created_script_path.is_empty():
		return _failure("Created user tool should report a script path.")
	if not FileAccess.file_exists(_created_script_path):
		return _failure("Created user tool script should exist on disk.")

	var tools: Array[Dictionary] = _service.list_user_tools()
	if not _contains_script_path(tools, _created_script_path):
		return _failure("User tool catalog should include the created scaffold.")

	var compatibility_report: Dictionary = _service.get_compatibility_report()
	if int(compatibility_report.get("user_tool_count", 0)) <= 0:
		return _failure("Compatibility report should include at least one user tool.")
	if not _contains_script_path((compatibility_report.get("compatible", []) as Array), _created_script_path):
		return _failure("Compatibility report should include the created scaffold as compatible.")

	var audit_entries: Array[Dictionary] = _service.get_audit_entries(20, "create_user_tool")
	if not _contains_script_path(audit_entries, _created_script_path):
		return _failure("Audit log should record the create_user_tool action for the scaffold.")

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
	_remove_path(_backup_path)
	_remove_path(_backup_uid_path)
	_remove_path(_latest_deleted_meta_path)
	_remove_path(AUDIT_LOG_PATH)
	_service = null
	_created_script_path = ""
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


func _remove_path(path: String) -> void:
	if path.is_empty():
		return
	var global_path = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(global_path):
		DirAccess.remove_absolute(global_path)


func _failure(message: String) -> Dictionary:
	return {
		"name": "user_tool_service_contracts",
		"success": false,
		"error": message
	}
