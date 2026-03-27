@tool
extends "res://addons/godot_dotnet_mcp/tools/debug/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	match action:
		"get_fps":
			return _success({
				"fps": Performance.get_monitor(Performance.TIME_FPS),
				"process_time": Performance.get_monitor(Performance.TIME_PROCESS),
				"physics_time": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
			})
		"get_memory":
			return _success({
				"static_memory": Performance.get_monitor(Performance.MEMORY_STATIC),
				"static_memory_max": Performance.get_monitor(Performance.MEMORY_STATIC_MAX),
				"message_buffer_max": Performance.get_monitor(Performance.MEMORY_MESSAGE_BUFFER_MAX)
			})
		"get_monitors":
			return _success({
				"time": {
					"fps": Performance.get_monitor(Performance.TIME_FPS),
					"process": Performance.get_monitor(Performance.TIME_PROCESS),
					"physics_process": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
					"navigation_process": Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS)
				},
				"memory": {
					"static": Performance.get_monitor(Performance.MEMORY_STATIC),
					"static_max": Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
				},
				"objects": {
					"count": Performance.get_monitor(Performance.OBJECT_COUNT),
					"resource_count": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
					"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
					"orphan_node_count": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
				},
				"render": {
					"total_objects_in_frame": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
					"total_primitives_in_frame": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
					"total_draw_calls_in_frame": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
				},
				"physics_2d": {
					"active_objects": Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS),
					"collision_pairs": Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS),
					"island_count": Performance.get_monitor(Performance.PHYSICS_2D_ISLAND_COUNT)
				},
				"physics_3d": {
					"active_objects": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
					"collision_pairs": Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
					"island_count": Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT)
				}
			})
		"get_render_info":
			return _success({
				"total_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				"total_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				"total_draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				"video_memory_used": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
			})
		_:
			return _error("Unknown action: %s" % action)
