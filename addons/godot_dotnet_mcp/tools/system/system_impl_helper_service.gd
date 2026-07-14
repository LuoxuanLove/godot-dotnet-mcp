@tool
extends RefCounted
class_name SystemImplHelperService

## Shared helper surface for system impl modules.
## Keeps data extraction, collection helpers, and issue/dependency helpers off
## the AtomicBridge compatibility facade while preserving bridge.call_atomic.

const AtomicBridgeHelperServiceScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_helper_service.gd")

var _bridge = null
var _helper_service = AtomicBridgeHelperServiceScript.new()


func configure(bridge) -> void:
	_bridge = bridge


func extract_data(result: Dictionary) -> Dictionary:
	return _helper_service.extract_data(result)


func extract_array(result: Dictionary, key: String) -> Array:
	return _helper_service.extract_array(result, key)


func collect_files(filter: String) -> Array:
	return _helper_service.collect_files(filter, _atomic_caller())


func collect_file_count(filter: String) -> int:
	return _helper_service.collect_file_count(filter, _atomic_caller())


func collect_file_counts(filters: Array) -> Dictionary:
	return _helper_service.collect_file_counts(filters, _atomic_caller())


func build_issue(severity: String, issue_type: String, message: String, extra: Dictionary = {}) -> Dictionary:
	return _helper_service.build_issue(severity, issue_type, message, extra)


func append_unique_issue(issues: Array, issue: Dictionary) -> void:
	_helper_service.append_unique_issue(issues, issue)


func has_severity(issues: Array, severity: String) -> bool:
	return _helper_service.has_severity(issues, severity)


func normalize_dependency_path(raw_path: String) -> String:
	return _helper_service.normalize_dependency_path(raw_path)


func normalize_resource_path(path: String, source_path: String = "") -> String:
	return _helper_service.normalize_resource_path(path, source_path)


func parse_dependency_reference(raw_path: String, source_path: String = "") -> Dictionary:
	return _helper_service.parse_dependency_reference(raw_path, source_path)


func resource_path_exists(path: String) -> bool:
	return _helper_service.resource_path_exists(path)


func _atomic_caller() -> Callable:
	if _bridge != null and _bridge.has_method("call_atomic"):
		return Callable(_bridge, "call_atomic")
	return Callable()
