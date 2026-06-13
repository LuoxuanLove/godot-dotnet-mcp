@tool
extends RefCounted
class_name ToolLoaderStatusService


func build_tool_loader_status(tool_count: int, exposed_tool_count: int, category_count: int, tool_load_error_count: int) -> Dictionary:
	var status := "ready"
	var healthy := true
	if category_count <= 0 and tool_load_error_count <= 0:
		status = "empty_registry"
		healthy = false
	elif tool_count <= 0 or exposed_tool_count <= 0:
		status = "no_visible_tools"
		healthy = false
	elif tool_load_error_count > 0:
		status = "degraded"
	return {
		"initialized": category_count > 0 or tool_count > 0 or tool_load_error_count > 0,
		"healthy": healthy,
		"status": status,
		"tool_count": tool_count,
		"exposed_tool_count": exposed_tool_count,
		"category_count": category_count,
		"tool_load_error_count": tool_load_error_count
	}


func build_performance_summary(performance: Dictionary, tool_call_metrics) -> Dictionary:
	return {
		"startup_ms": performance.get("startup_ms", 0.0),
		"definition_scan_ms": performance.get("definition_scan_ms", 0.0),
		"preload_ms": performance.get("preload_ms", 0.0),
		"reload_total_ms": performance.get("reload_total_ms", 0.0),
		"reload_count": performance.get("reload_count", 0),
		"tool_calls": tool_call_metrics
	}


func make_reload_status(action: String, performance_summary: Dictionary, reloaded_domains: Array = [], skipped_domains: Array = [], failed_domains: Array = [], elapsed_ms: float = 0.0) -> Dictionary:
	return {
		"action": action,
		"reloaded_domains": reloaded_domains.duplicate(),
		"skipped_domains": skipped_domains.duplicate(),
		"failed_domains": failed_domains.duplicate(true),
		"elapsed_ms": elapsed_ms,
		"timestamp_unix": int(Time.get_unix_time_from_system()),
		"performance": performance_summary.duplicate(true)
	}
