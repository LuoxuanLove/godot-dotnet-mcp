extends RefCounted

# {"name": "tool_loader_lifecycle_tick_budget_service_contracts"}

const TickBudgetServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_lifecycle_tick_budget_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var source_guard := _verify_tool_loader_delegates_lifecycle_tick_budget()
	if not source_guard.is_empty():
		return _failure(source_guard)

	var service = TickBudgetServiceScript.new()
	var idle_wait: Dictionary = service.accumulate(0.25, false)
	if bool(idle_wait.get("should_tick", true)) or float(idle_wait.get("interval_seconds", 0.0)) != 0.5:
		return _failure("Lifecycle tick budget should wait until the idle interval is reached.", idle_wait)
	var idle_tick: Dictionary = service.accumulate(0.25, false)
	if not bool(idle_tick.get("should_tick", false)) or float(idle_tick.get("tick_delta_seconds", 0.0)) != 0.5:
		return _failure("Lifecycle tick budget should emit accumulated idle deltas at 0.5s.", idle_tick)

	var active_tick: Dictionary = service.accumulate(0.05, true)
	if not bool(active_tick.get("should_tick", false)) or float(active_tick.get("interval_seconds", 0.0)) != 0.05:
		return _failure("Lifecycle tick budget should use the faster LSP interval when diagnostics are active.", active_tick)

	var capped_tick: Dictionary = service.accumulate(9.0, false)
	if not bool(capped_tick.get("should_tick", false)) or float(capped_tick.get("tick_delta_seconds", 0.0)) != 2.0:
		return _failure("Lifecycle tick budget should cap accumulated deltas.", capped_tick)

	service.reset()
	var after_reset: Dictionary = service.accumulate(0.1, false)
	if bool(after_reset.get("should_tick", true)) or float(after_reset.get("accumulator_seconds", -1.0)) != 0.1:
		return _failure("Lifecycle tick budget reset should clear the accumulator.", after_reset)

	var perf := {"lifecycle_tick_count": 2, "lifecycle_tick_max_ms": 3.5}
	service.record_performance(perf, 2.25, 0.5, 0.5)
	if int(perf.get("lifecycle_tick_count", 0)) != 3 or float(perf.get("lifecycle_tick_last_ms", 0.0)) != 2.25 or float(perf.get("lifecycle_tick_max_ms", 0.0)) != 3.5:
		return _failure("Lifecycle tick budget should update performance counters without lowering max.", perf)
	service.record_performance(perf, 4.0, 0.05, 0.1)
	if float(perf.get("lifecycle_tick_max_ms", 0.0)) != 4.0 or float(perf.get("lifecycle_tick_interval_seconds", 0.0)) != 0.05:
		return _failure("Lifecycle tick budget should track latest interval and max duration.", perf)

	return {"success": true, "name": "tool_loader_lifecycle_tick_budget_service_contracts"}


func _verify_tool_loader_delegates_lifecycle_tick_budget() -> String:
	var loader_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/tools/core/tool_loader.gd")
	var service_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/tools/core/tool_loader_lifecycle_tick_budget_service.gd")
	var factory_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/tools/core/tool_loader_service_factory.gd")
	if loader_source.is_empty() or service_source.is_empty() or factory_source.is_empty():
		return "Tool loader lifecycle tick budget sources should be readable."
	for required in [
		"_service_factory.ensure_services(",
		"_lifecycle_tick_budget_service.accumulate(",
		"_lifecycle_tick_budget_service.record_performance("
	]:
		if loader_source.find(required) == -1:
			return "MCPToolLoader should delegate lifecycle tick budget responsibility: %s" % required
	for forbidden in [
		"var _lifecycle_tick_accumulator",
		"const IDLE_LIFECYCLE_TICK_INTERVAL_SECONDS",
		"func _get_lifecycle_tick_interval_seconds()",
		"func _record_lifecycle_tick_performance("
	]:
		if loader_source.find(forbidden) != -1:
			return "MCPToolLoader should not retain lifecycle tick budget internals: %s" % forbidden
	for required_factory in [
		"ToolLoaderLifecycleTickBudgetServiceScript",
		'"lifecycle_tick_budget_service": _ensure(current, "lifecycle_tick_budget_service", ToolLoaderLifecycleTickBudgetServiceScript)'
	]:
		if factory_source.find(required_factory) == -1:
			return "ToolLoaderServiceFactory should own lifecycle tick budget construction: %s" % required_factory
	for required_service in [
		"func accumulate(delta: float, has_active_lsp_request: bool)",
		"func resolve_interval_seconds(has_active_lsp_request: bool)",
		"func record_performance(performance: Dictionary, elapsed_ms: float, interval_seconds: float, tick_delta: float)"
	]:
		if service_source.find(required_service) == -1:
			return "ToolLoaderLifecycleTickBudgetService should own lifecycle tick budget method: %s" % required_service
	return ""


func _failure(message: String, details: Dictionary = {}) -> Dictionary:
	return {"success": false, "name": "tool_loader_lifecycle_tick_budget_service_contracts", "error": message, "details": details}
