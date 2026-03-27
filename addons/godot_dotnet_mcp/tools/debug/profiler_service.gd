@tool
extends "res://addons/godot_dotnet_mcp/tools/debug/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	match action:
		"start":
			return _success({
				"note": "Use the Debugger panel in editor to access full profiling"
			}, "Profiler control is available in the Debugger panel")
		"stop":
			return _success({
				"note": "Use the Debugger panel in editor to control profiling"
			}, "Profiler control is available in the Debugger panel")
		"is_active":
			return _success({
				"note": "Profiler status is shown in the Debugger panel"
			})
		"get_summary":
			return _success({
				"fps": Performance.get_monitor(Performance.TIME_FPS),
				"process_time": Performance.get_monitor(Performance.TIME_PROCESS),
				"physics_time": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
				"static_memory": Performance.get_monitor(Performance.MEMORY_STATIC),
				"object_count": Performance.get_monitor(Performance.OBJECT_COUNT),
				"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				"recent_debug_events": MCPDebugBuffer.get_recent(10),
				"note": "Summary is limited to metrics available from the editor-side plugin."
			})
		_:
			return _error("Unknown action: %s" % action)
