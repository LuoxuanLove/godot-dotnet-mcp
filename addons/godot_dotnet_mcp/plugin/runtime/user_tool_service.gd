@tool
extends RefCounted
class_name UserToolService

const UserToolCatalogService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_catalog_service.gd")
const UserToolMaintenanceService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_maintenance_service.gd")
const MCPUserDataPaths = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_user_data_paths.gd")
const CUSTOM_TOOLS_DIR := "res://addons/godot_dotnet_mcp/custom_tools"
const USER_CATEGORY := "user"
const USER_DOMAIN := "user"
const SCAFFOLD_VERSION := "0.4.0"

var _session_id := ""
var _catalog_service := UserToolCatalogService.new()
var _maintenance_service := UserToolMaintenanceService.new()


func _init() -> void:
	_session_id = _build_session_id()
	_catalog_service.configure(CUSTOM_TOOLS_DIR, USER_CATEGORY, USER_DOMAIN, SCAFFOLD_VERSION)
	_maintenance_service.configure(
		CUSTOM_TOOLS_DIR,
		"res://addons/godot_dotnet_mcp/custom_tools/.backup",
		MCPUserDataPaths.USER_TOOL_AUDIT_LOG_PATH,
		_session_id,
		SCAFFOLD_VERSION
	)


func list_user_tools() -> Array[Dictionary]:
	if not _ensure_catalog_service():
		return []
	return _catalog_service.list_user_tools()


func create_tool_scaffold(tool_name: String, display_name: String, description: String, authorized: bool, agent_hint: String = "") -> Dictionary:
	if not _ensure_maintenance_service():
		return {"success": false, "error": "User tool maintenance service is unavailable"}
	return _maintenance_service.create_tool_scaffold(tool_name, display_name, description, authorized, agent_hint)


func delete_tool(script_path: String, authorized: bool, agent_hint: String = "") -> Dictionary:
	if not _ensure_maintenance_service():
		return {"success": false, "error": "User tool maintenance service is unavailable"}
	return _maintenance_service.delete_tool(script_path, authorized, agent_hint)


func restore_latest_backup(authorized: bool, agent_hint: String = "") -> Dictionary:
	if not _ensure_maintenance_service():
		return {"success": false, "error": "User tool maintenance service is unavailable"}
	return _maintenance_service.restore_latest_backup(authorized, agent_hint)


func get_audit_entries(limit: int = 20, filter_action: String = "", filter_session: String = "") -> Array[Dictionary]:
	if not _ensure_maintenance_service():
		return []
	return _maintenance_service.get_audit_entries(limit, filter_action, filter_session)


func get_compatibility_report() -> Dictionary:
	if not _ensure_catalog_service():
		return {
			"current_scaffold_version": SCAFFOLD_VERSION,
			"user_tool_count": 0,
			"compatible_count": 0,
			"compatible": [],
			"needs_review_count": 0,
			"needs_review": []
		}
	return _catalog_service.get_compatibility_report()


func get_runtime_diagnostics(watch_status: Dictionary = {}, audit_limit: int = 10, runtime_state: Array = []) -> Dictionary:
	var user_tools := list_user_tools()
	var loadable: Array[Dictionary] = []
	var failed: Array[Dictionary] = []
	for tool in user_tools:
		var item := tool.duplicate(true)
		if bool(item.get("loadable", false)):
			loadable.append(item)
		else:
			failed.append({
				"script_path": str(item.get("script_path", "")),
				"display_name": str(item.get("display_name", "")),
				"load_error": str(item.get("load_error", "unknown")),
				"scaffold_version": str(item.get("scaffold_version", "unknown"))
			})
	var runtime_failures := _collect_runtime_failures(runtime_state)
	failed.append_array(runtime_failures)
	var compatibility := get_compatibility_report()
	var recent_audit := get_audit_entries(audit_limit)
	var runtime_summary := _summarize_runtime_state(runtime_state)
	var failed_load_count := failed.size()
	return {
		"custom_tools_dir": CUSTOM_TOOLS_DIR,
		"runtime_loading_enabled": bool(watch_status.get("enabled", false)),
		"watch": watch_status.duplicate(true),
		"discovered_script_count": user_tools.size(),
		"loadable_count": loadable.size(),
		"failed_load_count": failed_load_count,
		"failed_loads": failed,
		"runtime_state_count": runtime_state.size(),
		"runtime_state": _duplicate_runtime_state(runtime_state),
		"runtime_failed_count": int(runtime_summary.get("failed_count", 0)),
		"runtime_failure_count": int(runtime_summary.get("failed_count", 0)),
		"runtime_pending_count": int(runtime_summary.get("pending_count", 0)),
		"runtime_active_call_count": int(runtime_summary.get("active_call_count", 0)),
		"tool_count": _count_registered_tools(loadable),
		"compatibility": {
			"current_scaffold_version": str(compatibility.get("current_scaffold_version", SCAFFOLD_VERSION)),
			"compatible_count": int(compatibility.get("compatible_count", 0)),
			"needs_review_count": int(compatibility.get("needs_review_count", 0))
		},
		"recent_audit_count": recent_audit.size(),
		"recent_audit": recent_audit
	}


func _collect_runtime_failures(runtime_state: Array) -> Array[Dictionary]:
	var failures: Array[Dictionary] = []
	var seen := {}
	for entry in runtime_state:
		if not (entry is Dictionary):
			continue
		var state_entry: Dictionary = (entry as Dictionary).duplicate(true)
		var state := str(state_entry.get("state", ""))
		var last_error := _string_or_empty(state_entry.get("last_error", ""))
		if state != "reload_failed" and last_error.is_empty():
			continue
		var script_path := str(state_entry.get("script_path", ""))
		var key := "%s|%s|%s" % [script_path, state, last_error]
		if seen.has(key):
			continue
		seen[key] = true
		failures.append({
			"script_path": script_path,
			"display_name": "",
			"load_error": last_error if not last_error.is_empty() else state,
			"scaffold_version": "runtime",
			"runtime_state": state,
			"runtime_domain": str(state_entry.get("runtime_domain", "")),
			"runtime_version": int(state_entry.get("version", 0)),
			"discovery_source": str(state_entry.get("discovery_source", "")),
			"last_refresh_reason": str(state_entry.get("last_refresh_reason", ""))
		})
	return failures


func _summarize_runtime_state(runtime_state: Array) -> Dictionary:
	var summary := {
		"failed_count": 0,
		"pending_count": 0,
		"active_call_count": 0
	}
	for entry in runtime_state:
		if not (entry is Dictionary):
			continue
		var state_entry: Dictionary = entry
		var state := str(state_entry.get("state", ""))
		var last_error := _string_or_empty(state_entry.get("last_error", ""))
		if state == "reload_failed" or not last_error.is_empty():
			summary["failed_count"] = int(summary.get("failed_count", 0)) + 1
		if bool(state_entry.get("pending_reload", false)) or state in ["reload_pending", "waiting_quiesce"]:
			summary["pending_count"] = int(summary.get("pending_count", 0)) + 1
		summary["active_call_count"] = int(summary.get("active_call_count", 0)) + int(state_entry.get("active_calls", 0))
	return summary


func _duplicate_runtime_state(runtime_state: Array) -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for entry in runtime_state:
		if entry is Dictionary:
			snapshot.append((entry as Dictionary).duplicate(true))
	return snapshot


func _string_or_empty(value) -> String:
	if value == null:
		return ""
	return str(value)


func _count_registered_tools(user_tools: Array[Dictionary]) -> int:
	var count := 0
	for tool in user_tools:
		var names = tool.get("tool_names", [])
		if names is Array:
			count += (names as Array).size()
	return count


func _build_session_id() -> String:
	var timestamp := Time.get_datetime_string_from_system(false, true).replace(":", "").replace("-", "").replace("T", "_")
	return "%s_%010d" % [timestamp, randi()]


func _ensure_catalog_service() -> bool:
	if _catalog_service != null and is_instance_valid(_catalog_service):
		return true
	_catalog_service = UserToolCatalogService.new()
	if _catalog_service == null:
		return false
	_catalog_service.configure(CUSTOM_TOOLS_DIR, USER_CATEGORY, USER_DOMAIN, SCAFFOLD_VERSION)
	return true


func _ensure_maintenance_service() -> bool:
	if _maintenance_service != null and is_instance_valid(_maintenance_service):
		return true
	_maintenance_service = UserToolMaintenanceService.new()
	if _maintenance_service == null:
		return false
	_maintenance_service.configure(
		CUSTOM_TOOLS_DIR,
		"res://addons/godot_dotnet_mcp/custom_tools/.backup",
		MCPUserDataPaths.USER_TOOL_AUDIT_LOG_PATH,
		_session_id,
		SCAFFOLD_VERSION
	)
	return true
