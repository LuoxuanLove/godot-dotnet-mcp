@tool
extends RefCounted
class_name ClientConfigFileTransaction

const ClientConfigInspectionServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_inspection_service.gd")
const ClientConfigFileSupportScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_file_support.gd")

var _serializer = null
var _inspection_service = null
var _file_support = null


func configure(serializer) -> ClientConfigFileTransaction:
	_serializer = serializer
	_file_support = ClientConfigFileSupportScript.new()
	_inspection_service = ClientConfigInspectionServiceScript.new()
	_inspection_service.configure(_serializer, _file_support)
	return self


func preflight_write_config(config_type: String, filepath: String, new_config: String) -> Dictionary:
	return _inspection_service.preflight_write_config(config_type, filepath, new_config)


func write_config_file(config_type: String, filepath: String, new_config: String, options: Dictionary = {}) -> Dictionary:
	var prepared = _serializer.prepare_new_config(new_config, config_type)
	if not bool(prepared.get("success", false)):
		prepared["config_type"] = config_type
		prepared["path"] = filepath
		return prepared

	var preflight = options.get("preflight", {})
	if not (preflight is Dictionary) or preflight.is_empty():
		preflight = preflight_write_config(config_type, filepath, new_config)
	if not bool(preflight.get("success", false)):
		return preflight

	var preflight_status = str(preflight.get("status", "missing"))
	var allow_incompatible_overwrite = bool(options.get("allow_incompatible_overwrite", false))
	if _serializer.preflight_requires_confirmation(preflight_status) and not allow_incompatible_overwrite:
		return {
			"success": false,
			"error": "precheck_confirmation_required",
			"path": filepath,
			"status": preflight_status,
			"backup_path": str(preflight.get("backup_path", _file_support.get_backup_path(filepath)))
		}

	var new_servers: Dictionary = prepared.get("new_servers", {})
	var final_config: Dictionary = {}
	var had_existing_file = bool(preflight.get("has_existing_file", FileAccess.file_exists(filepath)))
	var backup_path := ""

	if had_existing_file:
		var backup_result = _file_support.backup_existing_file(filepath)
		if not bool(backup_result.get("success", false)):
			return {
				"success": false,
				"error": "backup_error",
				"path": filepath,
				"backup_path": str(backup_result.get("backup_path", _file_support.get_backup_path(filepath)))
			}
		backup_path = str(backup_result.get("backup_path", ""))

	final_config = _read_mergeable_root(preflight_status, filepath)
	if final_config == null:
		return {
			"success": false,
			"error": "precheck_read_error",
			"path": filepath
		}
	if final_config.is_empty():
		final_config = {}

	var container_key = _serializer.get_server_container_key(config_type)
	var merged_servers = final_config.get(container_key, {})
	if not (merged_servers is Dictionary):
		merged_servers = {}

	for server_name in new_servers.keys():
		merged_servers[server_name] = new_servers[server_name]
	final_config[container_key] = merged_servers

	var dir_result = _ensure_target_directory(filepath)
	if not bool(dir_result.get("success", false)):
		return dir_result

	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		var rollback_result = _file_support.rollback_config_write(filepath, backup_path, had_existing_file)
		return _file_support.merge_rollback_result({
			"success": false,
			"error": "write_error",
			"path": filepath,
			"backup_path": backup_path
		}, rollback_result)

	file.store_string(JSON.stringify(final_config, "  "))
	file.close()

	var verify_result = _file_support.verify_written_config(_serializer, config_type, filepath, new_servers)
	if not bool(verify_result.get("success", false)):
		var rollback_result = _file_support.rollback_config_write(filepath, backup_path, had_existing_file)
		verify_result["config_type"] = config_type
		verify_result["path"] = filepath
		verify_result["backup_path"] = backup_path
		return _file_support.merge_rollback_result(verify_result, rollback_result)

	return {
		"success": true,
		"config_type": config_type,
		"path": filepath,
		"preflight_status": preflight_status,
		"backup_path": backup_path,
		"verified": true,
		"verified_servers": verify_result.get("verified_servers", [])
	}


func inspect_config_entry(config_type: String, filepath: String, server_name: String = "godot-mcp") -> Dictionary:
	return _inspection_service.inspect_config_entry(config_type, filepath, server_name)


func remove_config_entry(
	config_type: String,
	filepath: String,
	options: Dictionary = {},
	server_name: String = "godot-mcp"
) -> Dictionary:
	var inspection = options.get("inspection", {})
	if not (inspection is Dictionary) or inspection.is_empty():
		inspection = inspect_config_entry(config_type, filepath, server_name)
	if not bool(inspection.get("success", false)):
		return inspection

	var status = str(inspection.get("status", "missing_file"))
	if status == "missing_file" or status == "empty" or status == "missing_server":
		return {
			"success": true,
			"config_type": config_type,
			"path": filepath,
			"removed": false,
			"noop_reason": status,
			"server_name": server_name
		}

	if status == "invalid_json" or status == "incompatible_root" or status == "incompatible_mcp_servers" or status == "incompatible_mcp":
		return {
			"success": false,
			"config_type": config_type,
			"path": filepath,
			"error": "remove_blocked_%s" % status,
			"backup_path": str(inspection.get("backup_path", _file_support.get_backup_path(filepath))),
			"server_name": server_name
		}

	var root_result = _read_root_dictionary(filepath)
	if not bool(root_result.get("success", false)):
		root_result["config_type"] = config_type
		root_result["path"] = filepath
		root_result["server_name"] = server_name
		return root_result

	var root: Dictionary = root_result.get("root", {})
	var container_key = _serializer.get_server_container_key(config_type)
	var mcp_servers = root.get(container_key, {})
	if not (mcp_servers is Dictionary):
		return {
			"success": false,
			"config_type": config_type,
			"path": filepath,
			"error": _get_incompatible_remove_error(config_type),
			"server_name": server_name
		}

	var backup_result = _file_support.backup_existing_file(filepath)
	if not bool(backup_result.get("success", false)):
		return {
			"success": false,
			"config_type": config_type,
			"path": filepath,
			"error": "backup_error",
			"backup_path": str(backup_result.get("backup_path", _file_support.get_backup_path(filepath))),
			"server_name": server_name
		}
	var backup_path = str(backup_result.get("backup_path", ""))

	mcp_servers.erase(server_name)
	if mcp_servers.is_empty():
		root.erase(container_key)
	else:
		root[container_key] = mcp_servers

	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		var rollback_result = _file_support.rollback_config_write(filepath, backup_path, true)
		return _file_support.merge_rollback_result({
			"success": false,
			"config_type": config_type,
			"path": filepath,
			"error": "write_error",
			"backup_path": backup_path,
			"server_name": server_name
		}, rollback_result)
	file.store_string(JSON.stringify(root, "  "))
	file.close()

	var verify_result = _file_support.verify_removed_config(_serializer, config_type, filepath, server_name)
	if not bool(verify_result.get("success", false)):
		var rollback_result = _file_support.rollback_config_write(filepath, backup_path, true)
		verify_result["config_type"] = config_type
		verify_result["path"] = filepath
		verify_result["backup_path"] = backup_path
		verify_result["server_name"] = server_name
		return _file_support.merge_rollback_result(verify_result, rollback_result)

	return {
		"success": true,
		"config_type": config_type,
		"path": filepath,
		"removed": true,
		"backup_path": backup_path,
		"server_name": server_name
	}


func _read_mergeable_root(preflight_status: String, filepath: String):
	if preflight_status != "mergeable":
		return {}

	var existing_read = _file_support.read_text_file(filepath)
	if not bool(existing_read.get("success", false)):
		return null

	var existing_text = str(existing_read.get("text", ""))
	if existing_text.strip_edges().is_empty():
		return {}

	var json = JSON.new()
	if json.parse(existing_text) == OK and json.get_data() is Dictionary:
		return json.get_data()
	return {}


func _ensure_target_directory(filepath: String) -> Dictionary:
	var dir_path = filepath.get_base_dir()
	if DirAccess.dir_exists_absolute(dir_path):
		return {"success": true}

	var err = DirAccess.make_dir_recursive_absolute(dir_path)
	if err != OK:
		return {"success": false, "error": "dir_error", "path": dir_path}
	return {"success": true}


func _read_root_dictionary(filepath: String) -> Dictionary:
	var read_result = _file_support.read_text_file(filepath)
	if not bool(read_result.get("success", false)):
		return {"success": false, "error": "precheck_read_error"}

	var json = JSON.new()
	if json.parse(str(read_result.get("text", ""))) != OK:
		return {"success": false, "error": "remove_blocked_invalid_json"}

	var root = json.get_data()
	if not (root is Dictionary):
		return {"success": false, "error": "remove_blocked_incompatible_root"}

	return {
		"success": true,
		"root": root
	}


func _get_incompatible_remove_error(config_type: String) -> String:
	return "remove_blocked_incompatible_mcp" if config_type == "opencode" else "remove_blocked_incompatible_mcp_servers"
