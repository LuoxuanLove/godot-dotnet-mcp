@tool
extends RefCounted
class_name ClientConfigInspectionService

var _serializer = null
var _file_support = null


func configure(serializer, file_support) -> ClientConfigInspectionService:
	_serializer = serializer
	_file_support = file_support
	return self


func preflight_write_config(config_type: String, filepath: String, new_config: String) -> Dictionary:
	var prepared = _serializer.prepare_new_config(new_config, config_type)
	if not bool(prepared.get("success", false)):
		prepared["config_type"] = config_type
		prepared["path"] = filepath
		return prepared

	var result := {
		"success": true,
		"config_type": config_type,
		"path": filepath,
		"status": "missing",
		"requires_confirmation": false,
		"has_existing_file": FileAccess.file_exists(filepath),
		"backup_path": _file_support.get_backup_path(filepath),
		"server_names": prepared.get("server_names", PackedStringArray())
	}

	if not bool(result.get("has_existing_file", false)):
		return result

	var existing_read = _file_support.read_text_file(filepath)
	if not bool(existing_read.get("success", false)):
		return {
			"success": false,
			"config_type": config_type,
			"path": filepath,
			"error": "precheck_read_error"
		}

	var existing_text = str(existing_read.get("text", ""))
	if existing_text.strip_edges().is_empty():
		result["status"] = "empty"
		return result

	var json = JSON.new()
	if json.parse(existing_text) != OK:
		result["status"] = "invalid_json"
		result["requires_confirmation"] = true
		return result

	var existing_root = json.get_data()
	if not (existing_root is Dictionary):
		result["status"] = "incompatible_root"
		result["requires_confirmation"] = true
		return result

	var container_key = _serializer.get_server_container_key(config_type)
	if existing_root.has(container_key) and not (existing_root.get(container_key) is Dictionary):
		result["status"] = "incompatible_mcp" if config_type == "opencode" else "incompatible_mcp_servers"
		result["requires_confirmation"] = true
		return result

	result["status"] = "mergeable"
	return result


func inspect_config_entry(config_type: String, filepath: String, server_name: String = "godot-mcp") -> Dictionary:
	if not FileAccess.file_exists(filepath):
		return {
			"success": true,
			"config_type": config_type,
			"path": filepath,
			"status": "missing_file",
			"has_server_entry": false,
			"backup_path": _file_support.get_backup_path(filepath),
			"server_name": server_name
		}

	var read_result = _file_support.read_text_file(filepath)
	if not bool(read_result.get("success", false)):
		return {
			"success": false,
			"config_type": config_type,
			"path": filepath,
			"error": "precheck_read_error",
			"server_name": server_name
		}

	var text = str(read_result.get("text", ""))
	if text.strip_edges().is_empty():
		return {
			"success": true,
			"config_type": config_type,
			"path": filepath,
			"status": "empty",
			"has_server_entry": false,
			"backup_path": _file_support.get_backup_path(filepath),
			"server_name": server_name
		}

	var json = JSON.new()
	if json.parse(text) != OK:
		return {
			"success": true,
			"config_type": config_type,
			"path": filepath,
			"status": "invalid_json",
			"has_server_entry": false,
			"backup_path": _file_support.get_backup_path(filepath),
			"server_name": server_name
		}

	var root = json.get_data()
	if not (root is Dictionary):
		return {
			"success": true,
			"config_type": config_type,
			"path": filepath,
			"status": "incompatible_root",
			"has_server_entry": false,
			"backup_path": _file_support.get_backup_path(filepath),
			"server_name": server_name
		}

	var container_key = _serializer.get_server_container_key(config_type)
	var incompatible_status = "incompatible_mcp" if config_type == "opencode" else "incompatible_mcp_servers"
	var mcp_servers = root.get(container_key, {})
	if not (mcp_servers is Dictionary):
		return {
			"success": true,
			"config_type": config_type,
			"path": filepath,
			"status": incompatible_status,
			"has_server_entry": false,
			"backup_path": _file_support.get_backup_path(filepath),
			"server_name": server_name
		}

	if not mcp_servers.has(server_name):
		return {
			"success": true,
			"config_type": config_type,
			"path": filepath,
			"status": "missing_server",
			"has_server_entry": false,
			"backup_path": _file_support.get_backup_path(filepath),
			"server_name": server_name
		}

	return {
		"success": true,
		"config_type": config_type,
		"path": filepath,
		"status": "present",
		"has_server_entry": true,
		"backup_path": _file_support.get_backup_path(filepath),
		"server_name": server_name
	}
