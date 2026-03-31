@tool
extends RefCounted
class_name ClientDetectorBase

const STATUS_MISSING := "missing"

var _client_id := ""
var _path_resolver = null
var _runtime_inspector = null
var _config_entry_inspector = null


func configure(client_id: String, path_resolver, runtime_inspector, config_entry_inspector) -> void:
	_client_id = client_id
	_path_resolver = path_resolver
	_runtime_inspector = runtime_inspector
	_config_entry_inspector = config_entry_inspector


func get_client_id() -> String:
	return _client_id


func detect(_running_processes: PackedStringArray) -> Dictionary:
	return {
		"id": _client_id,
		"status": STATUS_MISSING
	}


func dispose() -> void:
	_client_id = ""
	_path_resolver = null
	_runtime_inspector = null
	_config_entry_inspector = null


func _build_common_result(resolved: Dictionary, runtime_state: Dictionary, entry_state: Dictionary) -> Dictionary:
	return {
		"id": _client_id,
		"status": STATUS_MISSING,
		"config_path": "",
		"executable_path": str(resolved.get("path", "")),
		"detected_via": str(resolved.get("detected_via", "")),
		"using_manual_path": bool(resolved.get("using_manual_path", false)),
		"has_manual_path": bool(resolved.get("has_manual_path", false)),
		"manual_path_invalid": bool(resolved.get("manual_path_invalid", false)),
		"manual_path": str(resolved.get("manual_path", "")),
		"write_supported": false,
		"auto_add_supported": false,
		"launch_supported": false,
		"path_pick_supported": false,
		"path_clear_supported": false,
		"config_entry_status": entry_state,
		"runtime_status": runtime_state
	}
