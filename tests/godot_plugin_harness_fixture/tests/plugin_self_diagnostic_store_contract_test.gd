extends RefCounted

# {"name": "plugin_self_diagnostic_store_contracts"}

const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	PluginSelfDiagnosticStore.clear()

	var operation = PluginSelfDiagnosticStore.begin_operation("server_start", "auto_start")
	var operation_id := str(operation.get("operation_id", ""))
	PluginSelfDiagnosticStore.record_operation_phase_duration(operation_id, "settings_projection", 12.5)
	PluginSelfDiagnosticStore.record_operation_phase_duration(operation_id, "tool_loader.preload", 1875.25, {"tool_count": 42})
	PluginSelfDiagnosticStore.record_operation_phase_duration(operation_id, "http_server.tcp_listen", 3.0)

	var finished = PluginSelfDiagnosticStore.end_operation(operation_id, true)
	finished["duration_ms"] = 3200.0
	var incident = PluginSelfDiagnosticStore.record_slow_operation(finished, "server_runtime_controller", "auto_start")
	if incident.is_empty():
		return _failure("Slow operation should record an incident when operation duration exceeds the threshold.")
	if str(incident.get("code", "")) != "operation_duration_slow":
		return _failure("Slow operation incident should use the generic operation_duration_slow code.")
	if str(incident.get("message", "")).find("tool_loader.preload") == -1:
		return _failure("Slow operation incident should name the slowest phase in its message.")

	var context = incident.get("context", {})
	if not (context is Dictionary):
		return _failure("Slow operation incident should expose context.")
	var context_dict := context as Dictionary
	var slowest_phase = context_dict.get("slowest_phase", {})
	if not (slowest_phase is Dictionary):
		return _failure("Slow operation incident should expose slowest_phase.")
	if str((slowest_phase as Dictionary).get("phase", "")) != "tool_loader.preload":
		return _failure("Slowest phase should be the recorded phase with the highest duration.")
	var phase_timings = context_dict.get("phase_timings", [])
	if not (phase_timings is Array) or (phase_timings as Array).size() != 3:
		return _failure("Slow operation incident should include all phase timings.")

	var snapshot = PluginSelfDiagnosticStore.get_health_snapshot({})
	var copy_text = PluginSelfDiagnosticStore.build_copy_text(snapshot)
	if copy_text.find("Slowest operation phase: tool_loader.preload") == -1:
		return _failure("Self diagnostics copy text should include the slowest operation phase.")
	if copy_text.find("Slowest incident phase: tool_loader.preload") == -1:
		return _failure("Self diagnostics copy text should include the slowest incident phase.")

	PluginSelfDiagnosticStore.clear()
	return {
		"name": "plugin_self_diagnostic_store_contracts",
		"success": true,
		"error": "",
		"details": {
			"slowest_phase": str((slowest_phase as Dictionary).get("phase", "")),
			"phase_count": (phase_timings as Array).size()
		}
	}


func _failure(message: String) -> Dictionary:
	PluginSelfDiagnosticStore.clear()
	return {
		"name": "plugin_self_diagnostic_store_contracts",
		"success": false,
		"error": message
	}