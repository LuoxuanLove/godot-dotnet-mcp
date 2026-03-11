@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

## Debug and console tools for Godot MCP
## Provides logging, debugging, and performance monitoring

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const MCPRuntimeDebugStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_debug_store.gd")


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "log",
			"description": "COMPATIBILITY ALIAS: Legacy debug_log tool entry kept for existing MCP wrappers.",
			"compatibility_alias": true,
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string"},
					"message": {"type": "string"},
					"limit": {"type": "integer"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "log_write",
			"description": """LOG WRITE: Write messages to Godot's console/output.

ACTIONS:
- print: Print a message
- warning: Print a warning message
- error: Print an error message
- rich: Print rich text (supports BBCode)

EXAMPLES:
- Print message: {"action": "print", "message": "Hello from MCP"}
- Warning: {"action": "warning", "message": "Something might be wrong"}
- Error: {"action": "error", "message": "Something went wrong!"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["print", "warning", "error", "rich"],
						"description": "Log action"
					},
					"message": {
						"type": "string",
						"description": "Message to log"
					},
					"limit": {
						"type": "integer",
						"description": "Max number of events to return"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "log_buffer",
			"description": """LOG BUFFER: Read or clear buffered MCP debug events.

ACTIONS:
- get_recent: Read recent buffered debug events
- get_errors: Read buffered warning/error events
- clear_buffer: Clear buffered debug events

EXAMPLES:
- Read recent events: {"action": "get_recent", "limit": 20}
- Read errors only: {"action": "get_errors", "limit": 20}
- Clear buffer: {"action": "clear_buffer"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["get_recent", "get_errors", "clear_buffer"],
						"description": "Buffer action"
					},
					"limit": {
						"type": "integer",
						"description": "Max number of events to return"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "runtime_bridge",
			"description": """RUNTIME BRIDGE: Read structured runtime bridge events from the running project.

ACTIONS:
- get_recent: Read recent runtime bridge events
- get_errors: Read runtime bridge warning/error events
- get_sessions: Read editor debugger session states
- get_summary: Read a combined runtime bridge summary
- clear_buffer: Clear captured runtime bridge events and session state

EXAMPLES:
- Read runtime events: {"action": "get_recent", "limit": 20}
- Read runtime errors: {"action": "get_errors", "limit": 20}
- Read debugger sessions: {"action": "get_sessions"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["get_recent", "get_errors", "get_sessions", "get_summary", "clear_buffer"],
						"description": "Runtime bridge action"
					},
					"limit": {
						"type": "integer",
						"description": "Max number of events to return"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "performance",
			"description": """PERFORMANCE: Get performance metrics and monitor resource usage.

ACTIONS:
- get_fps: Get current FPS
- get_memory: Get memory usage statistics
- get_monitors: Get all performance monitors
- get_render_info: Get rendering statistics

EXAMPLES:
- Get FPS: {"action": "get_fps"}
- Get memory: {"action": "get_memory"}
- Get all monitors: {"action": "get_monitors"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["get_fps", "get_memory", "get_monitors", "get_render_info"],
						"description": "Performance action"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "profiler",
			"description": """PROFILER: Control the built-in profiler.

ACTIONS:
- start: Start profiling
- stop: Stop profiling
- is_active: Check if profiler is running
- get_summary: Return profiler/debugger summary available to the plugin

NOTE: Full profiling data is only available in the running game, not in editor.

EXAMPLES:
- Start profiling: {"action": "start"}
- Stop profiling: {"action": "stop"}
- Check status: {"action": "is_active"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["start", "stop", "is_active", "get_summary"],
						"description": "Profiler action"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "class_db",
			"description": """CLASS DATABASE: Query information about Godot classes.

ACTIONS:
- get_class_list: Get all available classes
- get_class_info: Get detailed info about a class
- get_class_methods: Get methods of a class
- get_class_properties: Get properties of a class
- get_class_signals: Get signals of a class
- get_inheriters: Get classes that inherit from a class
- class_exists: Check if a class exists

EXAMPLES:
- Get all classes: {"action": "get_class_list"}
- Get Node2D info: {"action": "get_class_info", "class_name": "Node2D"}
- Get methods: {"action": "get_class_methods", "class_name": "CharacterBody2D"}
- Get inheriters: {"action": "get_inheriters", "class_name": "Node"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["get_class_list", "get_class_info", "get_class_methods", "get_class_properties", "get_class_signals", "get_inheriters", "class_exists"],
						"description": "ClassDB action"
					},
					"class_name": {
						"type": "string",
						"description": "Class name to query"
					},
					"include_inherited": {
						"type": "boolean",
						"description": "Include inherited members"
					}
				},
				"required": ["action"]
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"log":
			return _execute_log_compat(args)
		"log_write":
			return _execute_log_write(args)
		"log_buffer":
			return _execute_log_buffer(args)
		"runtime_bridge":
			return _execute_runtime_bridge(args)
		"performance":
			return _execute_performance(args)
		"profiler":
			return _execute_profiler(args)
		"class_db":
			return _execute_class_db(args)
		_:
			return _error("Unknown tool: %s" % tool_name)


# ==================== LOG ====================

func _execute_log_write(args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	var message = args.get("message", "")

	match action:
		"print":
			if message.is_empty():
				return _error("Message is required")
			print("[MCP] %s" % message)
			MCPDebugBuffer.record("info", "debug_log", message)
		"warning":
			if message.is_empty():
				return _error("Message is required")
			push_warning("[MCP] %s" % message)
			MCPDebugBuffer.record("warning", "debug_log", message)
		"error":
			if message.is_empty():
				return _error("Message is required")
			push_error("[MCP] %s" % message)
			MCPDebugBuffer.record("error", "debug_log", message)
		"rich":
			if message.is_empty():
				return _error("Message is required")
			print_rich(message)
			MCPDebugBuffer.record("info", "debug_log", message)
		_:
			return _error("Unknown action: %s" % action)

	return _success({
		"action": action,
		"message": message
	}, "Message logged")


func _execute_log_buffer(args: Dictionary) -> Dictionary:
	match args.get("action", ""):
		"get_recent":
			return _success({
				"count": MCPDebugBuffer.size(),
				"events": MCPDebugBuffer.get_recent(int(args.get("limit", 50)))
			})
		"get_errors":
			var events := MCPDebugBuffer.get_by_levels(["warning", "error"], int(args.get("limit", 50)))
			return _success({
				"count": events.size(),
				"events": events
			})
		"clear_buffer":
			MCPDebugBuffer.clear()
			return _success({"count": 0}, "Debug buffer cleared")
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _execute_log_compat(args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	if action in ["print", "warning", "error", "rich"]:
		return _execute_log_write(args)
	return _execute_log_buffer(args)


func _execute_runtime_bridge(args: Dictionary) -> Dictionary:
	match str(args.get("action", "")):
		"get_recent":
			var recent_events := MCPRuntimeDebugStore.get_recent(int(args.get("limit", 50)))
			return _success({
				"bridge_status": MCPRuntimeDebugStore.get_bridge_status(),
				"count": recent_events.size(),
				"events": recent_events
			})
		"get_errors":
			var events := MCPRuntimeDebugStore.get_errors(int(args.get("limit", 50)))
			return _success({
				"bridge_status": MCPRuntimeDebugStore.get_bridge_status(),
				"count": events.size(),
				"events": events
			})
		"get_sessions":
			var sessions := MCPRuntimeDebugStore.get_sessions()
			return _success({
				"bridge_status": MCPRuntimeDebugStore.get_bridge_status(),
				"count": sessions.size(),
				"sessions": sessions
			})
		"get_summary":
			return _success(MCPRuntimeDebugStore.get_summary())
		"clear_buffer":
			MCPRuntimeDebugStore.clear()
			return _success({"count": 0}, "Runtime bridge buffer cleared")
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


# ==================== PERFORMANCE ====================

func _execute_performance(args: Dictionary) -> Dictionary:
	var action = args.get("action", "")

	match action:
		"get_fps":
			return _get_fps()
		"get_memory":
			return _get_memory()
		"get_monitors":
			return _get_monitors()
		"get_render_info":
			return _get_render_info()
		_:
			return _error("Unknown action: %s" % action)


func _get_fps() -> Dictionary:
	return _success({
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process_time": Performance.get_monitor(Performance.TIME_PROCESS),
		"physics_time": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	})


func _get_memory() -> Dictionary:
	return _success({
		"static_memory": Performance.get_monitor(Performance.MEMORY_STATIC),
		"static_memory_max": Performance.get_monitor(Performance.MEMORY_STATIC_MAX),
		"message_buffer_max": Performance.get_monitor(Performance.MEMORY_MESSAGE_BUFFER_MAX)
	})


func _get_monitors() -> Dictionary:
	var monitors = {}

	# Time monitors
	monitors["time"] = {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process": Performance.get_monitor(Performance.TIME_PROCESS),
		"physics_process": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
		"navigation_process": Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS)
	}

	# Memory monitors
	monitors["memory"] = {
		"static": Performance.get_monitor(Performance.MEMORY_STATIC),
		"static_max": Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	}

	# Object monitors
	monitors["objects"] = {
		"count": Performance.get_monitor(Performance.OBJECT_COUNT),
		"resource_count": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphan_node_count": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	}

	# Render monitors
	monitors["render"] = {
		"total_objects_in_frame": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"total_primitives_in_frame": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"total_draw_calls_in_frame": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	}

	# Physics monitors
	monitors["physics_2d"] = {
		"active_objects": Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS),
		"collision_pairs": Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS),
		"island_count": Performance.get_monitor(Performance.PHYSICS_2D_ISLAND_COUNT)
	}

	monitors["physics_3d"] = {
		"active_objects": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		"collision_pairs": Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
		"island_count": Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT)
	}

	return _success(monitors)


func _get_render_info() -> Dictionary:
	return _success({
		"total_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"total_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"total_draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"video_memory_used": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	})


# ==================== PROFILER ====================

func _execute_profiler(args: Dictionary) -> Dictionary:
	var action = args.get("action", "")

	match action:
		"start":
			return _start_profiler()
		"stop":
			return _stop_profiler()
		"is_active":
			return _is_profiler_active()
		"get_summary":
			return _get_profiler_summary()
		_:
			return _error("Unknown action: %s" % action)


func _start_profiler() -> Dictionary:
	# Note: The profiler is controlled differently in Godot 4
	# This is a simplified interface
	return _success({
		"note": "Use the Debugger panel in editor to access full profiling"
	}, "Profiler control is available in the Debugger panel")


func _stop_profiler() -> Dictionary:
	return _success({
		"note": "Use the Debugger panel in editor to control profiling"
	}, "Profiler control is available in the Debugger panel")


func _is_profiler_active() -> Dictionary:
	return _success({
		"note": "Profiler status is shown in the Debugger panel"
	})


func _get_profiler_summary() -> Dictionary:
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


# ==================== CLASS DB ====================

func _execute_class_db(args: Dictionary) -> Dictionary:
	var action = args.get("action", "")

	match action:
		"get_class_list":
			return _get_class_list()
		"get_class_info":
			return _get_class_info(args.get("class_name", ""))
		"get_class_methods":
			return _get_class_methods(args.get("class_name", ""), args.get("include_inherited", false))
		"get_class_properties":
			return _get_class_properties(args.get("class_name", ""), args.get("include_inherited", false))
		"get_class_signals":
			return _get_class_signals(args.get("class_name", ""), args.get("include_inherited", false))
		"get_inheriters":
			return _get_inheriters(args.get("class_name", ""))
		"class_exists":
			return _class_exists(args.get("class_name", ""))
		_:
			return _error("Unknown action: %s" % action)


func _get_class_list() -> Dictionary:
	var classes = ClassDB.get_class_list()
	var class_array: Array[String] = []

	for c in classes:
		class_array.append(str(c))

	class_array.sort()

	return _success({
		"count": class_array.size(),
		"classes": class_array
	})


func _get_class_info(cls_name: String) -> Dictionary:
	if cls_name.is_empty():
		return _error("Class name is required")

	if not ClassDB.class_exists(cls_name):
		return _error("Class not found: %s" % cls_name)

	return _success({
		"name": cls_name,
		"parent": str(ClassDB.get_parent_class(cls_name)),
		"can_instantiate": ClassDB.can_instantiate(cls_name),
		"is_class": ClassDB.is_parent_class(cls_name, "Object"),
		"method_count": ClassDB.class_get_method_list(cls_name, true).size(),
		"property_count": ClassDB.class_get_property_list(cls_name, true).size(),
		"signal_count": ClassDB.class_get_signal_list(cls_name, true).size()
	})


func _get_class_methods(cls_name: String, include_inherited: bool) -> Dictionary:
	if cls_name.is_empty():
		return _error("Class name is required")

	if not ClassDB.class_exists(cls_name):
		return _error("Class not found: %s" % cls_name)

	var methods_list = ClassDB.class_get_method_list(cls_name, not include_inherited)
	var methods: Array[Dictionary] = []

	for method in methods_list:
		methods.append({
			"name": str(method.name),
			"args": method.args.size(),
			"return_type": method.get("return", {}).get("type", 0),
			"flags": method.flags
		})

	return _success({
		"class": cls_name,
		"include_inherited": include_inherited,
		"count": methods.size(),
		"methods": methods
	})


func _get_class_properties(cls_name: String, include_inherited: bool) -> Dictionary:
	if cls_name.is_empty():
		return _error("Class name is required")

	if not ClassDB.class_exists(cls_name):
		return _error("Class not found: %s" % cls_name)

	var props_list = ClassDB.class_get_property_list(cls_name, not include_inherited)
	var properties: Array[Dictionary] = []

	for prop in props_list:
		properties.append({
			"name": str(prop.name),
			"type": prop.type,
			"hint": prop.hint,
			"usage": prop.usage
		})

	return _success({
		"class": cls_name,
		"include_inherited": include_inherited,
		"count": properties.size(),
		"properties": properties
	})


func _get_class_signals(cls_name: String, include_inherited: bool) -> Dictionary:
	if cls_name.is_empty():
		return _error("Class name is required")

	if not ClassDB.class_exists(cls_name):
		return _error("Class not found: %s" % cls_name)

	var signals_list = ClassDB.class_get_signal_list(cls_name, not include_inherited)
	var signals_arr: Array[Dictionary] = []

	for sig in signals_list:
		signals_arr.append({
			"name": str(sig.name),
			"args": sig.args.size()
		})

	return _success({
		"class": cls_name,
		"include_inherited": include_inherited,
		"count": signals_arr.size(),
		"signals": signals_arr
	})


func _get_inheriters(cls_name: String) -> Dictionary:
	if cls_name.is_empty():
		return _error("Class name is required")

	if not ClassDB.class_exists(cls_name):
		return _error("Class not found: %s" % cls_name)

	var inheriters = ClassDB.get_inheriters_from_class(cls_name)
	var inheriter_array: Array[String] = []

	for c in inheriters:
		inheriter_array.append(str(c))

	inheriter_array.sort()

	return _success({
		"class": cls_name,
		"count": inheriter_array.size(),
		"inheriters": inheriter_array
	})


func _class_exists(cls_name: String) -> Dictionary:
	if cls_name.is_empty():
		return _error("Class name is required")

	return _success({
		"class": cls_name,
		"exists": ClassDB.class_exists(cls_name)
	})
