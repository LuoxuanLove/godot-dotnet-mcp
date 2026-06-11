extends RefCounted

const StatusServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_status_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var service = StatusServiceScript.new()

	var empty_status: Dictionary = service.build_tool_loader_status(0, 0, 0, 0)
	if bool(empty_status.get("healthy", true)) or str(empty_status.get("status", "")) != "empty_registry":
		return _failure("Tool loader status service should mark an empty registry unhealthy.")
	if bool(empty_status.get("initialized", true)):
		return _failure("Tool loader status service should mark an empty registry uninitialized.")

	var ready_status: Dictionary = service.build_tool_loader_status(12, 5, 3, 0)
	if not bool(ready_status.get("healthy", false)) or str(ready_status.get("status", "")) != "ready":
		return _failure("Tool loader status service should mark visible loaded tools ready.")
	if int(ready_status.get("tool_count", 0)) != 12 or int(ready_status.get("exposed_tool_count", 0)) != 5:
		return _failure("Tool loader status service should preserve tool counts.")

	var degraded_status: Dictionary = service.build_tool_loader_status(12, 5, 3, 2)
	if not bool(degraded_status.get("healthy", false)) or str(degraded_status.get("status", "")) != "degraded":
		return _failure("Tool loader status service should report load errors as degraded without marking the loader unhealthy.")

	var invisible_status: Dictionary = service.build_tool_loader_status(4, 0, 3, 0)
	if bool(invisible_status.get("healthy", true)) or str(invisible_status.get("status", "")) != "no_visible_tools":
		return _failure("Tool loader status service should reject initialized registries with no exposed tools.")

	var performance: Dictionary = service.build_performance_summary({
		"startup_ms": 1.5,
		"definition_scan_ms": 2.5,
		"preload_ms": 3.5,
		"reload_total_ms": 4.5,
		"reload_count": 6
	}, {"total": 7})
	if float(performance.get("reload_total_ms", 0.0)) != 4.5 or int(performance.get("reload_count", 0)) != 6:
		return _failure("Tool loader status service should preserve reload performance metrics.")
	var tool_calls = performance.get("tool_calls", {})
	if not (tool_calls is Dictionary) or int((tool_calls as Dictionary).get("total", 0)) != 7:
		return _failure("Tool loader status service should include tool call metrics.")

	var failed_domains: Array = [{"domain": "broken", "error": "boom"}]
	var reload_status: Dictionary = service.make_reload_status("reload_domain", performance, ["system"], ["user"], failed_domains, 12.25)
	if str(reload_status.get("action", "")) != "reload_domain":
		return _failure("Tool loader status service should preserve the reload action.")
	if not ((reload_status.get("reloaded_domains", []) as Array).has("system")):
		return _failure("Tool loader status service should preserve reloaded domains.")
	var reload_performance = reload_status.get("performance", {})
	if not (reload_performance is Dictionary) or int((reload_performance as Dictionary).get("reload_count", 0)) != 6:
		return _failure("Tool loader status service should embed a performance snapshot.")
	failed_domains[0]["error"] = "mutated"
	var status_failed_domains = reload_status.get("failed_domains", [])
	if str((((status_failed_domains as Array)[0] as Dictionary).get("error", ""))) != "boom":
		return _failure("Tool loader status service should deep-copy failed domain reload details.")

	return {
		"name": "tool_loader_status_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"ready_status": str(ready_status.get("status", "")),
			"degraded_status": str(degraded_status.get("status", "")),
			"reload_action": str(reload_status.get("action", ""))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_loader_status_service_contracts",
		"success": false,
		"error": message
	}
