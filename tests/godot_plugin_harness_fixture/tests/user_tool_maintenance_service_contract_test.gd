extends RefCounted

const UserToolMaintenanceServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_maintenance_service.gd")

var _service = null
var _custom_tools_dir := ""
var _backup_dir := ""
var _audit_log_path := ""
var _created_script_path := ""


func run_case(_tree: SceneTree) -> Dictionary:
	var nonce := int(Time.get_ticks_msec())
	_custom_tools_dir = "res://tests_tmp/user_tool_maintenance_contract_%d/custom_tools" % nonce
	_backup_dir = "res://tests_tmp/user_tool_maintenance_contract_%d/.backup" % nonce
	_audit_log_path = "res://tests_tmp/user_tool_maintenance_contract_%d/audit.log" % nonce

	_service = UserToolMaintenanceServiceScript.new()
	_service.configure(
		_custom_tools_dir,
		_backup_dir,
		_audit_log_path,
		"maintenance_contract_session",
		"0.4.0"
	)

	var unauthorized_result: Dictionary = _service.create_tool_scaffold(
		"Unauthorized Contract Tool",
		"Unauthorized Contract Tool",
		"should require auth",
		false,
		"user_tool_maintenance_contract_test"
	)
	if bool(unauthorized_result.get("success", true)):
		return _failure("scaffold creation requires authorization: expected failure")
	if str(unauthorized_result.get("error", "")) != "User authorization required":
		return _failure("scaffold creation requires authorization: expected authorization error")

	var create_result: Dictionary = _service.create_tool_scaffold(
		"Contract Maintenance Tool",
		"Contract Maintenance Tool",
		"maintenance contract test",
		true,
		"user_tool_maintenance_contract_test"
	)
	if not bool(create_result.get("success", false)):
		return _failure("scaffold creation writes script and audit entry: expected success")
	var create_data = create_result.get("data", {})
	if not (create_data is Dictionary):
		return _failure("scaffold creation writes script and audit entry: missing create data")
	_created_script_path = str((create_data as Dictionary).get("script_path", ""))
	if _created_script_path.is_empty() or not FileAccess.file_exists(_created_script_path):
		return _failure("scaffold creation writes script and audit entry: scaffold script should exist")
	var create_entries: Array[Dictionary] = _service.get_audit_entries(50, "create_user_tool")
	if not _has_success_audit(create_entries, "create_user_tool", _created_script_path):
		return _failure("scaffold creation writes script and audit entry: expected create audit entry")

	var delete_result: Dictionary = _service.delete_tool(_created_script_path, true, "user_tool_maintenance_contract_test")
	if not bool(delete_result.get("success", false)):
		return _failure("delete creates backup before removal: expected success")
	var delete_data = delete_result.get("data", {})
	if not (delete_data is Dictionary):
		return _failure("delete creates backup before removal: missing delete payload")
	var backup_path := str((delete_data as Dictionary).get("backup_path", ""))
	if backup_path.is_empty() or not FileAccess.file_exists(backup_path):
		return _failure("delete creates backup before removal: backup file should exist")
	if FileAccess.file_exists(_created_script_path):
		return _failure("delete creates backup before removal: script should be removed")

	var restore_result: Dictionary = _service.restore_latest_backup(true, "user_tool_maintenance_contract_test")
	if not bool(restore_result.get("success", false)):
		return _failure("restore uses latest backup metadata correctly: expected success")
	var restore_data = restore_result.get("data", {})
	if not (restore_data is Dictionary):
		return _failure("restore uses latest backup metadata correctly: missing restore payload")
	if str((restore_data as Dictionary).get("script_path", "")) != _created_script_path:
		return _failure("restore uses latest backup metadata correctly: restored script path mismatch")
	if not FileAccess.file_exists(_created_script_path):
		return _failure("restore uses latest backup metadata correctly: restored script file should exist")

	for index in range(520):
		_service._append_audit("truncate_probe", true, true, {
			"index": index,
			"script_path": _created_script_path
		}, "", "user_tool_maintenance_contract_test")
	var all_entries: Array[Dictionary] = _service.get_audit_entries(0)
	if all_entries.size() > 500:
		return _failure("audit log truncation respects cap: entry count should not exceed cap")

	var invalid_path_result: Dictionary = _service.delete_tool("res://outside_custom_tools/not_allowed.gd", true, "user_tool_maintenance_contract_test")
	if bool(invalid_path_result.get("success", true)):
		return _failure("invalid script paths are rejected: expected failure")
	if str(invalid_path_result.get("error", "")) != "Invalid user tool script path":
		return _failure("invalid script paths are rejected: expected invalid path error")

	return {
		"name": "user_tool_maintenance_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"audit_entries": all_entries.size(),
			"script_path": _created_script_path
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	if _created_script_path != "" and FileAccess.file_exists(_created_script_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_created_script_path))
	if _created_script_path != "" and FileAccess.file_exists("%s.uid" % _created_script_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s.uid" % _created_script_path))
	_remove_tree(ProjectSettings.globalize_path(_custom_tools_dir.get_base_dir()))
	_service = null
	_created_script_path = ""
	_custom_tools_dir = ""
	_backup_dir = ""
	_audit_log_path = ""


func _has_success_audit(entries: Array[Dictionary], action: String, script_path: String) -> bool:
	for entry in entries:
		if str(entry.get("action", "")) != action:
			continue
		if not bool(entry.get("success", false)):
			continue
		var payload = entry.get("payload", {})
		if payload is Dictionary and str((payload as Dictionary).get("script_path", "")) == script_path:
			return true
	return false


func _remove_tree(path: String) -> void:
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		return
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry = dir.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."]:
			continue
		var child = "%s/%s" % [path, entry]
		if dir.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _failure(message: String) -> Dictionary:
	return {
		"name": "user_tool_maintenance_service_contracts",
		"success": false,
		"error": message
	}
