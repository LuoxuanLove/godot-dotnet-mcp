extends RefCounted

# {"name": "plugin_performance_monitor_contracts"}

const PluginPerformanceMonitorScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_performance_monitor.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var source_guard := _assert_plugin_performance_monitor_source()
	if not source_guard.is_empty():
		return _failure(source_guard)

	var monitor = PluginPerformanceMonitorScript.new()
	monitor.record_process_elapsed_ms(2.0, 0.1)
	var first_status: Dictionary = monitor.get_status()
	if int(first_status.get("frame_count", 0)) != 1:
		return _failure("Performance monitor should count process frames.")
	if not is_equal_approx(float(first_status.get("last_ms", 0.0)), 2.0):
		return _failure("Performance monitor should preserve the last process elapsed time.")
	if not is_equal_approx(float(first_status.get("average_ms", 0.0)), 2.0):
		return _failure("Performance monitor should compute average elapsed time.")
	if int(first_status.get("slow_frame_count", 0)) != 0:
		return _failure("Performance monitor should not flag frames below the slow-frame threshold.")
	if int(first_status.get("sample_count", 0)) != 1:
		return _failure("Performance monitor should take an initial Godot performance sample.")
	if not (first_status.get("godot_monitors", {}) is Dictionary) or (first_status.get("godot_monitors", {}) as Dictionary).is_empty():
		return _failure("Performance monitor should expose cached Godot monitor samples.")

	monitor.record_process_elapsed_ms(12.0, 0.2)
	var second_status: Dictionary = monitor.get_status()
	if int(second_status.get("frame_count", 0)) != 2:
		return _failure("Performance monitor should keep cumulative frame count.")
	if int(second_status.get("slow_frame_count", 0)) != 1:
		return _failure("Performance monitor should count frames above the slow-frame threshold.")
	if not is_equal_approx(float(second_status.get("last_slow_frame_ms", 0.0)), 12.0):
		return _failure("Performance monitor should preserve the last slow-frame elapsed time.")
	if int(second_status.get("sample_count", 0)) != 1:
		return _failure("Performance monitor should not resample Godot monitors before the one-second interval.")

	monitor.record_process_elapsed_ms(3.0, 0.9)
	var third_status: Dictionary = monitor.get_status()
	if int(third_status.get("sample_count", 0)) != 2:
		return _failure("Performance monitor should resample Godot monitors after the one-second interval.")
	if not is_equal_approx(float(third_status.get("average_ms", 0.0)), 17.0 / 3.0):
		return _failure("Performance monitor should keep average elapsed time across sampled frames.")
	if int(third_status.get("window_frame_count", 0)) != 3:
		return _failure("Performance monitor should expose the rolling window frame count.")

	monitor.record_process_elapsed_ms(100.0, 0.0)
	for _index in range(int(third_status.get("window_size", 240))):
		monitor.record_process_elapsed_ms(1.0, 0.0)
	var rolled_status: Dictionary = monitor.get_status()
	if int(rolled_status.get("frame_count", 0)) <= int(rolled_status.get("window_frame_count", 0)):
		return _failure("Performance monitor should retain total frame count separately from rolling window count.")
	if float(rolled_status.get("max_ms", 0.0)) > 1.01:
		return _failure("Performance monitor max_ms should roll out old slow startup samples.")
	if not is_equal_approx(float(rolled_status.get("average_ms", 0.0)), 1.0):
		return _failure("Performance monitor average_ms should use the recent rolling window.")

	var custom_ids: Array = third_status.get("custom_monitors", [])
	for expected_id in [
		"Godot .NET MCP/Process Last",
		"Godot .NET MCP/Process Average",
		"Godot .NET MCP/Process Max",
		"Godot .NET MCP/Slow Frames",
		"Godot .NET MCP/Sample Count"
	]:
		if not custom_ids.has(expected_id):
			return _failure("Performance monitor should expose the custom monitor id: %s" % expected_id)

	if not is_equal_approx(monitor._get_custom_monitor_value("process_last_seconds"), 0.001):
		return _failure("Custom process-last monitor should return seconds for Godot time monitors.")
	if not is_equal_approx(monitor._get_custom_monitor_value("slow_frame_count"), 2.0):
		return _failure("Custom slow-frame monitor should report the cumulative slow-frame count.")
	if not is_equal_approx(monitor._get_custom_monitor_value("sample_count"), 2.0):
		return _failure("Custom sample-count monitor should report cached sample count.")

	monitor.install_custom_monitors()
	if not Performance.has_custom_monitor(StringName("Godot .NET MCP/Process Last")):
		monitor.remove_custom_monitors()
		return _failure("Performance monitor should register custom Godot debugger monitors.")
	monitor.remove_custom_monitors()
	if Performance.has_custom_monitor(StringName("Godot .NET MCP/Process Last")):
		return _failure("Performance monitor should remove custom Godot debugger monitors during teardown.")

	return {
		"name": "plugin_performance_monitor_contracts",
		"success": true,
		"error": "",
		"details": {
			"frames": int(third_status.get("frame_count", 0)),
			"samples": int(third_status.get("sample_count", 0)),
			"custom_monitors": custom_ids.size()
		}
	}


func _assert_plugin_performance_monitor_source() -> String:
	var source_path := "res://addons/godot_dotnet_mcp/plugin/runtime/plugin_performance_monitor.gd"
	if not FileAccess.file_exists(source_path):
		return "Plugin performance monitor source should exist."
	var source := FileAccess.get_file_as_string(source_path)
	for required in [
		"const SAMPLE_INTERVAL_SECONDS := 1.0",
		"const PROCESS_SLOW_FRAME_THRESHOLD_MS := 8.0",
		"const PROCESS_WINDOW_SIZE := 240",
		"Performance.add_custom_monitor(",
		"Performance.remove_custom_monitor(",
		"Performance.get_monitor(Performance.TIME_FPS)",
		"Performance.get_monitor(Performance.TIME_PROCESS)",
		"func record_process_elapsed_ms(elapsed_ms: float, delta: float)",
		"func get_status() -> Dictionary",
		"func _record_process_window_sample",
		"func _resolve_process_window_max"
	]:
		if source.find(required) == -1:
			return "Plugin performance monitor should retain the monitoring contract: %s" % required
	return ""


func _failure(message: String, details: Dictionary = {}) -> Dictionary:
	return {
		"name": "plugin_performance_monitor_contracts",
		"success": false,
		"error": message,
		"details": details
	}
