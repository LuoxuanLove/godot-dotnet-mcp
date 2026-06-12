extends RefCounted

const DiagnosticsServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_diagnostics_service.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	PluginSelfDiagnosticStore.clear()
	var service = DiagnosticsServiceScript.new()

	service.replace_load_errors([
		{"category": "manifest", "path": "res://manifest.gd", "message": "Manifest failed"}
	])
	var load_errors: Array[Dictionary] = service.get_tool_load_errors()
	load_errors[0]["message"] = "mutated"
	if str(service.get_tool_load_errors()[0].get("message", "")) != "Manifest failed":
		return _failure("Diagnostics service should protect stored load errors from caller mutation.")

	var error_info: Dictionary = service.record_load_error(
		"broken",
		"res://addons/godot_dotnet_mcp/tools/broken_tools.gd",
		"Boom",
		"contract_phase"
	)
	if service.get_tool_load_error_count() != 2 or str(error_info.get("message", "")) != "Boom":
		return _failure("Diagnostics service should append and return load error snapshots.")

	var health: Dictionary = PluginSelfDiagnosticStore.get_health_snapshot({})
	if not _has_incident(health, "tool_domain_load_failed", "contract_phase", "broken"):
		return _failure("Diagnostics service should record tool load incidents with category context.")

	PluginSelfDiagnosticStore.clear()
	service.replace_load_errors([
		{"category": "builtin", "message": "Bad built-in", "path": "res://builtin.gd"},
		"skip me",
		{"category": "user", "message": "Bad user", "path": "res://user.gd", "source": "user"}
	])
	service.sync_load_error_incidents("sync_phase")
	health = PluginSelfDiagnosticStore.get_health_snapshot({})
	if not _has_incident(health, "tool_domain_load_failed", "sync_phase", "builtin"):
		return _failure("Diagnostics service should sync dictionary load errors.")
	if not _has_incident(health, "tool_domain_load_failed", "sync_phase", "user"):
		return _failure("Diagnostics service should preserve load error source/category context.")
	if _count_incidents(health, "tool_domain_load_failed") != 2:
		return _failure("Diagnostics service should ignore non-dictionary load error entries.")

	PluginSelfDiagnosticStore.clear()
	service.record_reload_incident(
		"system",
		"res://addons/godot_dotnet_mcp/tools/system_tools.gd",
		"Reload failed",
		"reload_domain"
	)
	health = PluginSelfDiagnosticStore.get_health_snapshot({})
	if not _has_incident(health, "tool_reload_failed", "reload_domain", "system"):
		return _failure("Diagnostics service should record reload incidents with entry path context.")

	var next_status: Dictionary = {
		"action": "reload_domain",
		"failed_domains": [{"domain": "system", "error": "Reload failed"}]
	}
	var updated: Dictionary = service.update_reload_status(next_status)
	next_status["failed_domains"][0]["error"] = "mutated"
	if str((((updated.get("failed_domains", []) as Array)[0] as Dictionary).get("error", ""))) != "Reload failed":
		return _failure("Diagnostics service should return a deep-copied reload status snapshot.")
	var stored_status: Dictionary = service.get_reload_status()
	if str((((stored_status.get("failed_domains", []) as Array)[0] as Dictionary).get("error", ""))) != "Reload failed":
		return _failure("Diagnostics service should store a deep-copied reload status snapshot.")

	service.clear_load_errors()
	if service.get_tool_load_error_count() != 0:
		return _failure("Diagnostics service should clear load errors without touching reload status.")
	if str(service.get_reload_status().get("action", "")) != "reload_domain":
		return _failure("Diagnostics service clear_load_errors should preserve reload status lifecycle.")

	PluginSelfDiagnosticStore.clear()
	return {
		"name": "tool_loader_diagnostics_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"load_error_count": service.get_tool_load_error_count(),
			"reload_action": str(service.get_reload_status().get("action", ""))
		}
	}


func _has_incident(health: Dictionary, code: String, phase: String, category: String) -> bool:
	for incident in health.get("recent_incidents", []):
		if not (incident is Dictionary):
			continue
		var item := incident as Dictionary
		var context = item.get("context", {})
		if str(item.get("code", "")) == code \
				and str(item.get("phase", "")) == phase \
				and context is Dictionary \
				and str((context as Dictionary).get("category", "")) == category:
			return true
	return false


func _count_incidents(health: Dictionary, code: String) -> int:
	var count := 0
	for incident in health.get("recent_incidents", []):
		if incident is Dictionary and str((incident as Dictionary).get("code", "")) == code:
			count += 1
	return count


func _failure(message: String) -> Dictionary:
	PluginSelfDiagnosticStore.clear()
	return {
		"name": "tool_loader_diagnostics_service_contracts",
		"success": false,
		"error": message
	}
