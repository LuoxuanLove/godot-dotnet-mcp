extends RefCounted

const ToolPermissionPolicy = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_permission_policy.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const MCPRuntimeDebugStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_debug_store.gd")

var _localization
var _runtime_bridge_autoload_name := ""
var _runtime_bridge_autoload_path := ""
var _count_dock_instances := Callable()
var _has_runtime_bridge_root_instance := Callable()
var _is_server_running := Callable()
var _get_connection_stats := Callable()
var _get_tool_load_errors := Callable()
var _get_reload_status := Callable()
var _get_performance_summary := Callable()
var _get_permission_level := Callable()
var _refresh_dock := Callable()
var _show_message := Callable()
var _is_dock_present := Callable()


func configure(localization, autoload_name: String, autoload_path: String, callbacks: Dictionary) -> void:
	_localization = localization
	_runtime_bridge_autoload_name = autoload_name
	_runtime_bridge_autoload_path = autoload_path
	_count_dock_instances = callbacks.get("count_dock_instances", Callable())
	_has_runtime_bridge_root_instance = callbacks.get("has_runtime_bridge_root_instance", Callable())
	_is_server_running = callbacks.get("is_server_running", Callable())
	_get_connection_stats = callbacks.get("get_connection_stats", Callable())
	_get_tool_load_errors = callbacks.get("get_tool_load_errors", Callable())
	_get_reload_status = callbacks.get("get_reload_status", Callable())
	_get_performance_summary = callbacks.get("get_performance_summary", Callable())
	_get_permission_level = callbacks.get("get_permission_level", Callable())
	_refresh_dock = callbacks.get("refresh_dock", Callable())
	_show_message = callbacks.get("show_message", Callable())
	_is_dock_present = callbacks.get("is_dock_present", Callable())


func handle_clear_requested() -> void:
	var result = clear_self_diagnostics_from_tools()
	if bool(result.get("success", false)):
		_call_show_message(_get_text("self_diag_cleared"))
		return
	_call_show_message(str(result.get("error", _get_text("self_diag_clear_failed"))))


func get_self_diagnostic_health_from_tools() -> Dictionary:
	return {
		"success": true,
		"data": build_self_diagnostic_health_snapshot()
	}


func get_self_diagnostic_errors_from_tools(severity: String = "", category: String = "", limit: int = 20) -> Dictionary:
	var incidents = PluginSelfDiagnosticStore.get_incidents(severity, category, limit)
	return {
		"success": true,
		"data": {
			"count": incidents.size(),
			"incidents": incidents
		}
	}


func get_self_diagnostic_timeline_from_tools(limit: int = 20) -> Dictionary:
	var timeline = PluginSelfDiagnosticStore.get_timeline(limit)
	return {
		"success": true,
		"data": {
			"count": timeline.size(),
			"timeline": timeline
		}
	}


func clear_self_diagnostics_from_tools() -> Dictionary:
	if _call_permission_level() != ToolPermissionPolicy.PERMISSION_DEVELOPER:
		return {"success": false, "error": "Developer permission level is required to clear self diagnostics"}
	PluginSelfDiagnosticStore.clear()
	_call_refresh_dock()
	return {"success": true, "message": "Plugin self diagnostics cleared"}


func build_self_diagnostic_health_snapshot() -> Dictionary:
	var bridge_status = MCPRuntimeDebugStore.get_bridge_status()
	var dock_count = _call_count_dock_instances()
	var tool_load_errors = _call_dictionary_array(_get_tool_load_errors)
	return PluginSelfDiagnosticStore.get_health_snapshot({
		"autoload": {
			"installed": bool(bridge_status.get("installed", false)),
			"autoload_name": str(bridge_status.get("autoload_name", _runtime_bridge_autoload_name)),
			"autoload_path": str(bridge_status.get("autoload_path", _runtime_bridge_autoload_path)),
			"message": str(bridge_status.get("message", "")),
			"root_instance_present": _call_bool(_has_runtime_bridge_root_instance)
		},
		"server": {
			"running": _call_bool(_is_server_running),
			"connection_stats": _call_dictionary(_get_connection_stats)
		},
		"dock": {
			"present": _call_bool(_is_dock_present),
			"dock_count": dock_count,
			"stale_dock_count": maxi(dock_count - 1, 0)
		},
		"tool_loader": {
			"tool_load_error_count": tool_load_errors.size(),
			"tool_load_errors": tool_load_errors,
			"reload_status": _call_dictionary(_get_reload_status),
			"performance": _call_dictionary(_get_performance_summary)
		}
	})


func _get_text(key: String) -> String:
	if _localization != null and _localization.has_method("get_text"):
		return _localization.get_text(key)
	return key


func _call_refresh_dock() -> void:
	if _refresh_dock.is_valid():
		_refresh_dock.call()


func _call_show_message(message: String) -> void:
	if _show_message.is_valid():
		_show_message.call(message)


func _call_permission_level() -> String:
	if _get_permission_level.is_valid():
		return str(_get_permission_level.call())
	return ToolPermissionPolicy.PERMISSION_EVOLUTION


func _call_count_dock_instances() -> int:
	if _count_dock_instances.is_valid():
		return int(_count_dock_instances.call())
	return 0


func _call_bool(callback: Callable) -> bool:
	if callback.is_valid():
		return bool(callback.call())
	return false


func _call_dictionary(callback: Callable) -> Dictionary:
	if callback.is_valid():
		var result = callback.call()
		if result is Dictionary:
			return result
	return {}


func _call_dictionary_array(callback: Callable) -> Array:
	if callback.is_valid():
		var result = callback.call()
		if result is Array:
			return result
	return []
