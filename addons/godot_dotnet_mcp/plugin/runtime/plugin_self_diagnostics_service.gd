@tool
extends RefCounted
class_name PluginSelfDiagnosticsService

const MCPRuntimeDebugStore = preload("res://addons/godot_dotnet_mcp/tools/shared/mcp_runtime_debug_store.gd")
const PluginInstanceFreshness = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_instance_freshness.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")


func build_health_response(context: Dictionary) -> Dictionary:
	return {
		"success": true,
		"data": build_health_snapshot(context)
	}


func build_errors_response(severity: String = "", category: String = "", limit: int = 20) -> Dictionary:
	var incidents = PluginSelfDiagnosticStore.get_incidents(severity, category, limit)
	return {
		"success": true,
		"data": {
			"count": incidents.size(),
			"incidents": incidents
		}
	}


func build_timeline_response(limit: int = 20) -> Dictionary:
	var timeline = PluginSelfDiagnosticStore.get_timeline(limit)
	return {
		"success": true,
		"data": {
			"count": timeline.size(),
			"timeline": timeline
		}
	}


func build_clear_response() -> Dictionary:
	PluginSelfDiagnosticStore.clear()
	return {"success": true, "message": "Plugin self diagnostics cleared"}


func build_health_snapshot(context: Dictionary) -> Dictionary:
	var server_controller = context.get("server_controller", null)
	var bridge_status = MCPRuntimeDebugStore.get_bridge_status()
	var tool_load_errors: Array = []
	var server_running := false
	var connection_stats := {}
	var reload_status := {}
	var performance_summary := {}
	if server_controller != null:
		if server_controller.has_method("get_tool_load_errors"):
			var load_errors = server_controller.get_tool_load_errors()
			if load_errors is Array:
				tool_load_errors = (load_errors as Array).duplicate(true)
		if server_controller.has_method("is_running"):
			server_running = bool(server_controller.is_running())
		if server_controller.has_method("get_connection_stats"):
			var stats = server_controller.get_connection_stats()
			if stats is Dictionary:
				connection_stats = (stats as Dictionary).duplicate(true)
		if server_controller.has_method("get_reload_status"):
			var status = server_controller.get_reload_status()
			if status is Dictionary:
				reload_status = (status as Dictionary).duplicate(true)
		if server_controller.has_method("get_performance_summary"):
			var summary = server_controller.get_performance_summary()
			if summary is Dictionary:
				performance_summary = (summary as Dictionary).duplicate(true)
	return PluginSelfDiagnosticStore.get_health_snapshot({
		"freshness": PluginInstanceFreshness.get_freshness_snapshot(),
		"autoload": {
			"installed": bool(bridge_status.get("installed", false)),
			"autoload_name": str(bridge_status.get("autoload_name", str(context.get("runtime_bridge_autoload_name", "")))),
			"autoload_path": str(bridge_status.get("autoload_path", "")),
			"message": str(bridge_status.get("message", "")),
			"root_instance_present": bool(context.get("runtime_bridge_root_instance_present", false))
		},
		"server": {
			"running": server_running,
			"connection_stats": connection_stats
		},
		"dock": {
			"present": bool(context.get("dock_present", false)),
			"dock_count": int(context.get("dock_count", 0)),
			"stale_dock_count": maxi(int(context.get("dock_count", 0)) - 1, 0)
		},
		"idle_process": _copy_dictionary(context.get("process_performance_status", {})),
		"user_tool_watch": _copy_dictionary(context.get("user_tool_watch_status", {})),
		"tool_loader": {
			"tool_load_error_count": tool_load_errors.size(),
			"tool_load_errors": tool_load_errors,
			"reload_status": reload_status,
			"performance": performance_summary
		}
	})


func _copy_dictionary(value) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
