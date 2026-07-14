@tool
extends RefCounted
class_name ToolExecutionObserver

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")

var _activity_registry = null
var _tool_calls: Dictionary = {}


func set_activity_registry(registry) -> void:
	_activity_registry = registry


func get_activity_registry():
	return _activity_registry


func begin_tool_activity(category: String, tool_name: String, args: Dictionary, agent_context: Dictionary) -> Dictionary:
	if _activity_registry == null or not _activity_registry.has_method("begin_call"):
		return {}
	return _activity_registry.begin_call("%s_%s" % [category, tool_name], category, tool_name, args, agent_context, {})


func finalize_tool_execution(category: String, tool_name: String, args: Dictionary, started_usec: int, result) -> Dictionary:
	var elapsed_ms = _elapsed_ms(started_usec)
	_record_tool_call_metric("%s_%s" % [category, tool_name], category, elapsed_ms)

	if result is Dictionary and _as_bool(result.get("success", true)):
		MCPDebugBuffer.record("info", "tool_loader",
			"%s_%s ok (%.0fms)" % [category, tool_name, elapsed_ms],
			"%s_%s" % [category, tool_name])
		return result

	var error_message = "Tool execution failed"
	if result is Dictionary:
		error_message = str(result.get("error", error_message))
		MCPDebugBuffer.record("warning", "tool_loader",
			"%s_%s failed (%.0fms): %s" % [category, tool_name, elapsed_ms, error_message],
			"%s_%s" % [category, tool_name])
		var failure_result: Dictionary = result.duplicate(true)
		var failure_data = failure_result.get("data", {})
		if not (failure_data is Dictionary):
			failure_data = {"details": failure_data}
		failure_data["tool_name"] = "%s_%s" % [category, tool_name]
		failure_data["action"] = str(args.get("action", ""))
		failure_data["error_type"] = str(failure_data.get("error_type", "tool_execution_failed"))
		failure_data["domain"] = category
		failure_data["elapsed_ms"] = elapsed_ms
		failure_data["timestamp_unix"] = int(Time.get_unix_time_from_system())
		failure_result["data"] = failure_data
		return failure_result

	MCPDebugBuffer.record("warning", "tool_loader",
		"%s_%s failed (%.0fms): %s" % [category, tool_name, elapsed_ms, error_message],
		"%s_%s" % [category, tool_name])
	return _failure("tool_execution_failed", category, tool_name, error_message, {
		"action": str(args.get("action", "")),
		"elapsed_ms": elapsed_ms
	})


func finish_tool_activity(result: Dictionary, activity_record: Dictionary) -> Dictionary:
	if activity_record.is_empty() or _activity_registry == null:
		return result
	var out := result.duplicate(true)
	_preserve_non_protocol_activity_payload(out)
	var error_message := ""
	if not bool(out.get("success", true)):
		error_message = str(out.get("error", out.get("message", "")))
	var finished := {}
	if _activity_registry.has_method("finish_call"):
		finished = _activity_registry.finish_call(str(activity_record.get("call_id", "")), bool(out.get("success", true)), error_message)
	if _activity_registry.has_method("summarize_record"):
		out["activity"] = _activity_registry.summarize_record(finished if not finished.is_empty() else activity_record)
	return out


func get_tool_call_metrics() -> Array[Dictionary]:
	var per_tool: Array[Dictionary] = []
	for tool_name in _tool_calls.keys():
		per_tool.append((_tool_calls[tool_name] as Dictionary).duplicate(true))
	per_tool.sort_custom(Callable(self, "_sort_tool_metric"))
	return per_tool


func get_tool_usage_stats() -> Array[Dictionary]:
	var stats: Array[Dictionary] = []
	for tool_name in _tool_calls.keys():
		var metric: Dictionary = _tool_calls[tool_name]
		stats.append({
			"tool_name": str(metric.get("tool_name", tool_name)),
			"category": str(metric.get("category", "")),
			"call_count": int(metric.get("count", 0)),
			"last_called_at_unix": int(metric.get("last_called_at_unix", 0)),
			"total_ms": float(metric.get("total_ms", 0.0)),
			"avg_ms": float(metric.get("avg_ms", 0.0)),
			"last_ms": float(metric.get("last_ms", 0.0))
		})
	stats.sort_custom(Callable(self, "_sort_tool_usage_stats"))
	return stats


func _preserve_non_protocol_activity_payload(out: Dictionary) -> void:
	var existing_activity = out.get("activity", null)
	if existing_activity == null or _is_protocol_activity_summary(existing_activity):
		return
	var existing_data = out.get("data", {})
	if existing_data is Dictionary:
		existing_data = (existing_data as Dictionary).duplicate(true)
	elif out.has("data"):
		existing_data = {"details": existing_data}
	else:
		existing_data = _extract_activity_extra_data(out)
	(existing_data as Dictionary)["activity"] = existing_activity
	out["data"] = existing_data


func _extract_activity_extra_data(result: Dictionary) -> Dictionary:
	var extra_data := {}
	var reserved := {"success": true, "data": true, "message": true, "error": true, "hints": true, "activity": true}
	for key in result.keys():
		if reserved.has(str(key)):
			continue
		extra_data[str(key)] = result[key]
	return extra_data


func _is_protocol_activity_summary(value) -> bool:
	if not (value is Dictionary):
		return false
	return not str((value as Dictionary).get("call_id", "")).is_empty() and not str((value as Dictionary).get("state", "")).is_empty()


func _record_tool_call_metric(full_name: String, category: String, elapsed_ms: float) -> void:
	var metric: Dictionary = _tool_calls.get(full_name, {
		"tool_name": full_name,
		"category": category,
		"count": 0,
		"total_ms": 0.0,
		"avg_ms": 0.0,
		"last_ms": 0.0,
		"last_called_at_unix": 0
	})
	metric["count"] = int(metric.get("count", 0)) + 1
	metric["total_ms"] = float(metric.get("total_ms", 0.0)) + elapsed_ms
	metric["last_ms"] = elapsed_ms
	metric["last_called_at_unix"] = int(Time.get_unix_time_from_system())
	metric["avg_ms"] = metric["total_ms"] / float(metric["count"])
	_tool_calls[full_name] = metric


func _failure(error_type: String, category: String, tool_name: String, message: String, data: Dictionary = {}) -> Dictionary:
	var failure_data = data.duplicate(true)
	failure_data["error_type"] = error_type
	failure_data["domain"] = category
	failure_data["tool_name"] = category if tool_name.is_empty() else "%s_%s" % [category, tool_name]
	failure_data["timestamp_unix"] = int(Time.get_unix_time_from_system())
	return {
		"success": false,
		"error": message,
		"data": failure_data
	}


func _sort_tool_metric(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("tool_name", "")) < str(b.get("tool_name", ""))


func _sort_tool_usage_stats(a: Dictionary, b: Dictionary) -> bool:
	var left_count = int(a.get("call_count", 0))
	var right_count = int(b.get("call_count", 0))
	if left_count != right_count:
		return left_count > right_count
	var left_time = int(a.get("last_called_at_unix", 0))
	var right_time = int(b.get("last_called_at_unix", 0))
	if left_time != right_time:
		return left_time > right_time
	return str(a.get("tool_name", "")) < str(b.get("tool_name", ""))


func _elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0


func _as_bool(value) -> bool:
	if value is bool:
		return value
	if value is int:
		return value != 0
	if value is float:
		return !is_zero_approx(value)
	if value is String:
		var normalized = value.strip_edges().to_lower()
		return normalized == "true" or normalized == "1" or normalized == "yes" or normalized == "on"
	return value != null
