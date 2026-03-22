@tool
extends RefCounted
class_name MCPToolMetricsService

var _performance: Dictionary = {}


func _init() -> void:
	reset()


func reset() -> void:
	_performance = {
		"startup_ms": 0.0,
		"definition_scan_ms": 0.0,
		"preload_ms": 0.0,
		"reload_total_ms": 0.0,
		"reload_count": 0,
		"tool_calls": {}
	}


func set_definition_scan_ms(value: float) -> void:
	_performance["definition_scan_ms"] = value


func set_preload_ms(value: float) -> void:
	_performance["preload_ms"] = value


func set_startup_ms(value: float) -> void:
	_performance["startup_ms"] = value


func apply_reload_metrics(status: Dictionary) -> void:
	_performance["reload_total_ms"] = float(_performance.get("reload_total_ms", 0.0)) + float(status.get("reload_total_ms_delta", 0.0))
	_performance["reload_count"] = int(_performance.get("reload_count", 0)) + int(status.get("reload_count_delta", 0))


func record_tool_call(full_name: String, category: String, elapsed_ms: float) -> void:
	var per_tool: Dictionary = _performance.get("tool_calls", {})
	var metric: Dictionary = per_tool.get(full_name, {
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
	per_tool[full_name] = metric
	_performance["tool_calls"] = per_tool


func build_performance_summary() -> Dictionary:
	var per_tool: Array[Dictionary] = []
	for tool_name in _performance.get("tool_calls", {}).keys():
		per_tool.append(_performance["tool_calls"][tool_name].duplicate(true))
	per_tool.sort_custom(_sort_tool_metric)
	return {
		"startup_ms": _performance.get("startup_ms", 0.0),
		"definition_scan_ms": _performance.get("definition_scan_ms", 0.0),
		"preload_ms": _performance.get("preload_ms", 0.0),
		"reload_total_ms": _performance.get("reload_total_ms", 0.0),
		"reload_count": _performance.get("reload_count", 0),
		"tool_calls": per_tool
	}


func build_tool_usage_stats() -> Array[Dictionary]:
	var stats: Array[Dictionary] = []
	for tool_name in _performance.get("tool_calls", {}).keys():
		var metric: Dictionary = _performance["tool_calls"][tool_name]
		stats.append({
			"tool_name": str(metric.get("tool_name", tool_name)),
			"category": str(metric.get("category", "")),
			"call_count": int(metric.get("count", 0)),
			"last_called_at_unix": int(metric.get("last_called_at_unix", 0)),
			"total_ms": float(metric.get("total_ms", 0.0)),
			"avg_ms": float(metric.get("avg_ms", 0.0)),
			"last_ms": float(metric.get("last_ms", 0.0))
		})
	stats.sort_custom(_sort_tool_usage_stats)
	return stats


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
