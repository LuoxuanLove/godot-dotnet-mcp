extends RefCounted

const ToolExecutionObserverScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_execution_observer.gd")
const ToolActivityRegistryScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_activity_registry.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var observer = ToolExecutionObserverScript.new()
	var registry = ToolActivityRegistryScript.new()
	observer.set_activity_registry(registry)

	var activity_record: Dictionary = observer.begin_tool_activity("system", "project_state", {
		"summary": true
	}, {
		"agent_id": "observer-contract-agent",
		"notes": "activity context should be retained"
	})
	if str(activity_record.get("call_id", "")).is_empty():
		return _failure("Tool execution observer should begin registry activity records.")

	var success_result: Dictionary = observer.finalize_tool_execution("system", "project_state", {
		"summary": true
	}, _started_before_now(), {
		"success": true,
		"data": {"summary": true},
		"activity": {"user_supplied": true}
	})
	if not bool(success_result.get("success", false)):
		return _failure("Tool execution observer should preserve successful tool results.")

	var finished_success: Dictionary = observer.finish_tool_activity(success_result, activity_record)
	var activity_summary = finished_success.get("activity", {})
	if not ToolActivityRegistryScript.is_protocol_activity_summary(activity_summary):
		return _failure("Tool execution observer should attach protocol activity summaries.")
	var success_data = finished_success.get("data", {})
	if not (success_data is Dictionary) or not (((success_data as Dictionary).get("activity", {}) as Dictionary).get("user_supplied", false)):
		return _failure("Tool execution observer should move non-protocol activity payloads into data.")

	var recent_status: Dictionary = registry.get_status()
	var recent_records = recent_status.get("recent", [])
	if not (recent_records is Array) or (recent_records as Array).is_empty():
		return _failure("Tool activity registry should retain observer-completed calls.")
	var recent_record: Dictionary = (recent_records as Array)[0]
	var agent_context = recent_record.get("agent_context", {})
	if not (agent_context is Dictionary) or str((agent_context as Dictionary).get("agent_id", "")) != "observer-contract-agent":
		return _failure("Tool execution observer should pass sanitized agent context into activity records.")

	var failure_result: Dictionary = observer.finalize_tool_execution("debug", "dotnet", {
		"action": "status"
	}, _started_before_now(), {
		"success": false,
		"error": "boom",
		"data": "raw-detail"
	})
	var failure_data = failure_result.get("data", {})
	if not (failure_data is Dictionary):
		return _failure("Tool execution observer should normalize failure data into a dictionary.")
	if str((failure_data as Dictionary).get("details", "")) != "raw-detail":
		return _failure("Tool execution observer should preserve non-dictionary failure details.")
	if str((failure_data as Dictionary).get("tool_name", "")) != "debug_dotnet":
		return _failure("Tool execution observer should add the canonical failing tool name.")
	if str((failure_data as Dictionary).get("action", "")) != "status":
		return _failure("Tool execution observer should preserve the failing action.")
	if str((failure_data as Dictionary).get("error_type", "")) != "tool_execution_failed":
		return _failure("Tool execution observer should add a standard failure error_type.")
	if str((failure_data as Dictionary).get("domain", "")) != "debug":
		return _failure("Tool execution observer should add the failing domain.")
	if not (failure_data as Dictionary).has("elapsed_ms"):
		return _failure("Tool execution observer should add elapsed_ms to failures.")

	var plain_failure: Dictionary = observer.finalize_tool_execution("system", "project_state", {}, _started_before_now(), "bad")
	var plain_failure_data = plain_failure.get("data", {})
	if bool(plain_failure.get("success", true)):
		return _failure("Tool execution observer should convert non-dictionary results into failures.")
	if not (plain_failure_data is Dictionary) or str((plain_failure_data as Dictionary).get("tool_name", "")) != "system_project_state":
		return _failure("Tool execution observer should normalize non-dictionary failures with tool metadata.")

	var metrics := observer.get_tool_call_metrics()
	var usage := observer.get_tool_usage_stats()
	if _find_metric(metrics, "system_project_state").is_empty():
		return _failure("Tool execution observer should expose per-tool call metrics.")
	var debug_usage := _find_usage(usage, "debug_dotnet")
	if debug_usage.is_empty() or int(debug_usage.get("call_count", 0)) < 1:
		return _failure("Tool execution observer should expose per-tool usage stats.")

	return {
		"success": true,
		"name": "tool_execution_observer_contracts",
		"metric_count": metrics.size(),
		"usage_count": usage.size()
	}


func _started_before_now() -> int:
	return Time.get_ticks_usec() - 1000


func _find_metric(metrics: Array[Dictionary], tool_name: String) -> Dictionary:
	for metric in metrics:
		if str(metric.get("tool_name", "")) == tool_name:
			return metric
	return {}


func _find_usage(stats: Array[Dictionary], tool_name: String) -> Dictionary:
	for entry in stats:
		if str(entry.get("tool_name", "")) == tool_name:
			return entry
	return {}


func _failure(message: String, extra: Dictionary = {}) -> Dictionary:
	var data := extra.duplicate(true)
	data["message"] = message
	return {
		"success": false,
		"name": "tool_execution_observer_contracts",
		"error": message,
		"data": data
	}
