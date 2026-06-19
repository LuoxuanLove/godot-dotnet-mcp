@tool
extends RefCounted
class_name PluginPerformanceMonitor

const SAMPLE_INTERVAL_SECONDS := 1.0
const PROCESS_SLOW_FRAME_THRESHOLD_MS := 8.0
const PROCESS_WINDOW_SIZE := 240

const CUSTOM_MONITOR_PROCESS_LAST := "Godot .NET MCP/Process Last"
const CUSTOM_MONITOR_PROCESS_AVERAGE := "Godot .NET MCP/Process Average"
const CUSTOM_MONITOR_PROCESS_MAX := "Godot .NET MCP/Process Max"
const CUSTOM_MONITOR_SLOW_FRAMES := "Godot .NET MCP/Slow Frames"
const CUSTOM_MONITOR_SAMPLE_COUNT := "Godot .NET MCP/Sample Count"

const _CUSTOM_MONITOR_ENTRIES := [
	{
		"id": CUSTOM_MONITOR_PROCESS_LAST,
		"metric": "process_last_seconds",
		"type": Performance.MONITOR_TYPE_TIME
	},
	{
		"id": CUSTOM_MONITOR_PROCESS_AVERAGE,
		"metric": "process_average_seconds",
		"type": Performance.MONITOR_TYPE_TIME
	},
	{
		"id": CUSTOM_MONITOR_PROCESS_MAX,
		"metric": "process_max_seconds",
		"type": Performance.MONITOR_TYPE_TIME
	},
	{
		"id": CUSTOM_MONITOR_SLOW_FRAMES,
		"metric": "slow_frame_count",
		"type": Performance.MONITOR_TYPE_QUANTITY
	},
	{
		"id": CUSTOM_MONITOR_SAMPLE_COUNT,
		"metric": "sample_count",
		"type": Performance.MONITOR_TYPE_QUANTITY
	}
]

var _process_perf := {
	"frame_count": 0,
	"window_total_ms": 0.0,
	"window_max_ms": 0.0,
	"last_ms": 0.0,
	"slow_frame_count": 0,
	"last_slow_frame_ms": 0.0
}
var _process_window_ms: Array[float] = []
var _sample_elapsed_seconds := 0.0
var _sample_count := 0
var _last_godot_monitor_sample := {}
var _installed_custom_monitors: Array[StringName] = []


func install_custom_monitors() -> void:
	remove_custom_monitors()
	for entry in _CUSTOM_MONITOR_ENTRIES:
		var monitor_id := StringName(str(entry.get("id", "")))
		if monitor_id == StringName():
			continue
		if Performance.has_custom_monitor(monitor_id):
			Performance.remove_custom_monitor(monitor_id)
		Performance.add_custom_monitor(
			monitor_id,
			Callable(self, "_get_custom_monitor_value").bind(str(entry.get("metric", ""))),
			[],
			int(entry.get("type", Performance.MONITOR_TYPE_QUANTITY))
		)
		_installed_custom_monitors.append(monitor_id)


func remove_custom_monitors() -> void:
	for monitor_id in _installed_custom_monitors:
		if Performance.has_custom_monitor(monitor_id):
			Performance.remove_custom_monitor(monitor_id)
	_installed_custom_monitors.clear()


func record_process_frame(started_usec: int, delta: float) -> void:
	var elapsed_ms := maxf(float(Time.get_ticks_usec() - started_usec) / 1000.0, 0.0)
	record_process_elapsed_ms(elapsed_ms, delta)


func record_process_elapsed_ms(elapsed_ms: float, delta: float) -> void:
	var safe_elapsed_ms := maxf(elapsed_ms, 0.0)
	_process_perf["frame_count"] = int(_process_perf.get("frame_count", 0)) + 1
	_process_perf["last_ms"] = safe_elapsed_ms
	_record_process_window_sample(safe_elapsed_ms)
	if safe_elapsed_ms > PROCESS_SLOW_FRAME_THRESHOLD_MS:
		_process_perf["slow_frame_count"] = int(_process_perf.get("slow_frame_count", 0)) + 1
		_process_perf["last_slow_frame_ms"] = safe_elapsed_ms
	_maybe_sample_godot_monitors(delta)


func get_status() -> Dictionary:
	var frame_count := int(_process_perf.get("frame_count", 0))
	var window_count := _process_window_ms.size()
	var window_total_ms := float(_process_perf.get("window_total_ms", 0.0))
	return {
		"frame_count": frame_count,
		"window_frame_count": window_count,
		"window_size": PROCESS_WINDOW_SIZE,
		"last_ms": float(_process_perf.get("last_ms", 0.0)),
		"max_ms": float(_process_perf.get("window_max_ms", 0.0)),
		"average_ms": window_total_ms / float(window_count) if window_count > 0 else 0.0,
		"slow_frame_count": int(_process_perf.get("slow_frame_count", 0)),
		"last_slow_frame_ms": float(_process_perf.get("last_slow_frame_ms", 0.0)),
		"slow_frame_threshold_ms": PROCESS_SLOW_FRAME_THRESHOLD_MS,
		"sample_interval_seconds": SAMPLE_INTERVAL_SECONDS,
		"sample_count": _sample_count,
		"godot_monitors": _last_godot_monitor_sample.duplicate(true),
		"custom_monitors": _get_custom_monitor_ids()
	}


func _maybe_sample_godot_monitors(delta: float) -> void:
	_sample_elapsed_seconds += maxf(delta, 0.0)
	if _sample_count > 0 and _sample_elapsed_seconds < SAMPLE_INTERVAL_SECONDS:
		return
	_sample_elapsed_seconds = 0.0
	_sample_count += 1
	_last_godot_monitor_sample = {
		"time": {
			"fps": Performance.get_monitor(Performance.TIME_FPS),
			"process_seconds": Performance.get_monitor(Performance.TIME_PROCESS),
			"physics_process_seconds": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
			"navigation_process_seconds": Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS)
		},
		"memory": {
			"static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
			"static_max_bytes": Performance.get_monitor(Performance.MEMORY_STATIC_MAX),
			"message_buffer_max_bytes": Performance.get_monitor(Performance.MEMORY_MESSAGE_BUFFER_MAX)
		},
		"objects": {
			"count": Performance.get_monitor(Performance.OBJECT_COUNT),
			"resource_count": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
			"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			"orphan_node_count": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
		}
	}


func _get_custom_monitor_value(metric: String) -> float:
	match metric:
		"process_last_seconds":
			return float(_process_perf.get("last_ms", 0.0)) / 1000.0
		"process_average_seconds":
			var window_count := _process_window_ms.size()
			if window_count <= 0:
				return 0.0
			return (float(_process_perf.get("window_total_ms", 0.0)) / float(window_count)) / 1000.0
		"process_max_seconds":
			return float(_process_perf.get("window_max_ms", 0.0)) / 1000.0
		"slow_frame_count":
			return float(_process_perf.get("slow_frame_count", 0))
		"sample_count":
			return float(_sample_count)
	return 0.0


func _record_process_window_sample(elapsed_ms: float) -> void:
	_process_window_ms.append(elapsed_ms)
	_process_perf["window_total_ms"] = float(_process_perf.get("window_total_ms", 0.0)) + elapsed_ms
	if elapsed_ms >= float(_process_perf.get("window_max_ms", 0.0)):
		_process_perf["window_max_ms"] = elapsed_ms
	while _process_window_ms.size() > PROCESS_WINDOW_SIZE:
		var removed := _process_window_ms.pop_front()
		_process_perf["window_total_ms"] = maxf(float(_process_perf.get("window_total_ms", 0.0)) - removed, 0.0)
		if is_equal_approx(removed, float(_process_perf.get("window_max_ms", 0.0))) or removed > float(_process_perf.get("window_max_ms", 0.0)):
			_process_perf["window_max_ms"] = _resolve_process_window_max()


func _resolve_process_window_max() -> float:
	var max_ms := 0.0
	for sample in _process_window_ms:
		max_ms = maxf(max_ms, sample)
	return max_ms


func _get_custom_monitor_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in _CUSTOM_MONITOR_ENTRIES:
		ids.append(str(entry.get("id", "")))
	return ids
