@tool
extends RefCounted

## Helper and collection operations used by system implementations.
## Kept out of AtomicBridgeExecutionService so that service remains execution-only.

const AtomicBridgeSupportScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_support.gd")

var _support = AtomicBridgeSupportScript.new()


func extract_data(result: Dictionary) -> Dictionary:
	var d = result.get("data", {})
	if d is Dictionary:
		return d
	return {}


func extract_array(result: Dictionary, key: String) -> Array:
	var d := extract_data(result)
	var v = d.get(key, [])
	if v is Array:
		return v
	return []


func collect_files(filter: String, atomic_caller: Callable = Callable()) -> Array:
	var result := _call_collection_atomic(atomic_caller, "filesystem_directory", {
		"action": "get_files",
		"path": "res://",
		"filter": filter,
		"recursive": true
	})
	return extract_array(result, "files")


func collect_file_count(filter: String, atomic_caller: Callable = Callable()) -> int:
	var result := _call_collection_atomic(atomic_caller, "filesystem_directory", {
		"action": "get_files",
		"path": "res://",
		"filter": filter,
		"recursive": true,
		"count_only": true
	})
	var data := extract_data(result)
	return int(data.get("count", 0))


func collect_file_counts(filters: Array, atomic_caller: Callable = Callable()) -> Dictionary:
	var result := _call_collection_atomic(atomic_caller, "filesystem_directory", {
		"action": "get_files",
		"path": "res://",
		"filters": filters,
		"recursive": true,
		"count_only": true
	})
	var data := extract_data(result)
	var counts_raw = data.get("counts_by_filter", {})
	if counts_raw is Dictionary:
		return (counts_raw as Dictionary).duplicate(true)
	return {}


func build_issue(severity: String, issue_type: String, message: String, extra: Dictionary = {}) -> Dictionary:
	return _support.build_issue(severity, issue_type, message, extra)


func append_unique_issue(issues: Array, issue: Dictionary) -> void:
	_support.append_unique_issue(issues, issue)


func has_severity(issues: Array, severity: String) -> bool:
	return _support.has_severity(issues, severity)


func normalize_dependency_path(raw_path: String) -> String:
	return _support.normalize_dependency_path(raw_path)


func normalize_resource_path(path: String, source_path: String = "") -> String:
	return _support.normalize_resource_path(path, source_path)


func parse_dependency_reference(raw_path: String, source_path: String = "") -> Dictionary:
	return _support.parse_dependency_reference(raw_path, source_path)


func resource_path_exists(path: String) -> bool:
	return _support.resource_path_exists(path)


func _call_collection_atomic(atomic_caller: Callable, full_name: String, args: Dictionary) -> Dictionary:
	if atomic_caller.is_valid():
		var result = atomic_caller.call(full_name, args)
		if result is Dictionary:
			return result
	return {}
