extends RefCounted

# {"name": "plugin_self_diagnostics_service_contracts"}

const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const PluginSelfDiagnosticsServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostics_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var source_guard := _verify_plugin_entrypoint_delegates_self_diagnostics()
	if not source_guard.is_empty():
		return _failure(source_guard)

	PluginSelfDiagnosticStore.clear()
	PluginSelfDiagnosticStore.record_incident(
		"warning",
		"test",
		"diagnostic_contract_warning",
		"Contract warning",
		"plugin",
		"contract",
		"",
		"",
		"",
		true,
		"Inspect contract",
		{"source": "plugin_self_diagnostics_service_contracts"}
	)

	var service = PluginSelfDiagnosticsServiceScript.new()
	var health := service.build_health_response({
		"runtime_bridge_autoload_name": "MCPRuntimeBridge",
		"runtime_bridge_root_instance_present": true,
		"dock_present": true,
		"dock_count": 2,
		"process_performance_status": {"tick_count": 1},
		"user_tool_watch_status": {"status": "idle"}
	})
	if not bool(health.get("success", false)):
		return _failure("PluginSelfDiagnosticsService health response should succeed.")
	var health_data := health.get("data", {}) as Dictionary
	if str(health_data.get("status", "")) != "warning":
		return _failure("PluginSelfDiagnosticsService health response should surface warning status.", {"health": health_data})
	if int(health_data.get("active_incident_count", 0)) <= 0:
		return _failure("PluginSelfDiagnosticsService health response should include active incident count.")
	if not ((health_data.get("dock", {}) as Dictionary).get("stale_dock_count", -1) == 1):
		return _failure("PluginSelfDiagnosticsService should derive stale dock count from context.")

	var errors := service.build_errors_response("warning", "test", 10)
	if not bool(errors.get("success", false)):
		return _failure("PluginSelfDiagnosticsService errors response should succeed.")
	if int((errors.get("data", {}) as Dictionary).get("count", 0)) != 1:
		return _failure("PluginSelfDiagnosticsService errors response should preserve filtered incident count.")

	var timeline := service.build_timeline_response(10)
	if not bool(timeline.get("success", false)):
		return _failure("PluginSelfDiagnosticsService timeline response should succeed.")
	if int((timeline.get("data", {}) as Dictionary).get("count", 0)) <= 0:
		return _failure("PluginSelfDiagnosticsService timeline response should include diagnostic events.")

	var clear := service.build_clear_response()
	if not bool(clear.get("success", false)):
		return _failure("PluginSelfDiagnosticsService clear response should succeed.")
	if int((service.build_errors_response("", "", 10).get("data", {}) as Dictionary).get("count", 0)) != 0:
		return _failure("PluginSelfDiagnosticsService clear response should clear incidents.")

	return {"name": "plugin_self_diagnostics_service_contracts", "success": true, "error": ""}


func _verify_plugin_entrypoint_delegates_self_diagnostics() -> String:
	var plugin_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin.gd")
	var service_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostics_service.gd")
	if plugin_source.is_empty() or service_source.is_empty():
		return "Plugin self diagnostics sources should be readable."
	for required in [
		"PluginSelfDiagnosticsServiceScript.new()",
		"_ensure_plugin_self_diagnostics_service().build_health_response(",
		"_ensure_plugin_self_diagnostics_service().build_errors_response(",
		"_ensure_plugin_self_diagnostics_service().build_timeline_response(",
		"_ensure_plugin_self_diagnostics_service().build_clear_response()",
		"_ensure_plugin_self_diagnostics_service().build_health_snapshot("
	]:
		if plugin_source.find(required) == -1:
			return "plugin.gd should delegate self diagnostics responsibility: %s" % required
	for forbidden in [
		"PluginSelfDiagnosticStore.get_incidents(severity, category, limit)",
		"PluginSelfDiagnosticStore.get_timeline(limit)",
		"\"tool_load_error_count\": tool_load_errors.size()",
		"\"stale_dock_count\": maxi(dock_count - 1, 0)"
	]:
		if plugin_source.find(forbidden) != -1:
			return "plugin.gd should not retain self diagnostics internals: %s" % forbidden
	for required_service in [
		"func build_health_response(context: Dictionary)",
		"func build_errors_response(severity: String = \"\", category: String = \"\", limit: int = 20)",
		"func build_timeline_response(limit: int = 20)",
		"func build_health_snapshot(context: Dictionary)"
	]:
		if service_source.find(required_service) == -1:
			return "PluginSelfDiagnosticsService should own self diagnostics method: %s" % required_service
	return ""


func _failure(message: String, details: Dictionary = {}) -> Dictionary:
	return {"name": "plugin_self_diagnostics_service_contracts", "success": false, "error": message, "details": details}
