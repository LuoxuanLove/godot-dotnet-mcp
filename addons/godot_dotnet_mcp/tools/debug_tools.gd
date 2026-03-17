@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

## Debug and console tools for Godot MCP
## Provides logging, debugging, and performance monitoring

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const MCPRuntimeDebugStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_debug_store.gd")

const DOTNET_DEFAULT_TIMEOUT_SEC := 30


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
- get_recent_filtered: Read recent events filtered by level (error/warning/info) with tail support
- get_errors_context: Read error events with enriched context (error_type, message, script, node, stacktrace)
- get_scene_snapshot: Read last captured scene state (node tree, properties, signals) from runtime bridge

EXAMPLES:
- Read runtime events: {"action": "get_recent", "limit": 20}
- Read runtime errors: {"action": "get_errors", "limit": 20}
- Read debugger sessions: {"action": "get_sessions"}
- Filtered by level: {"action": "get_recent_filtered", "level": "error", "tail": 10}
- Error context: {"action": "get_errors_context", "limit": 10}
- Scene snapshot: {"action": "get_scene_snapshot"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["get_recent", "get_errors", "get_sessions", "get_summary", "clear_buffer", "get_recent_filtered", "get_errors_context", "get_scene_snapshot"],
						"description": "Runtime bridge action"
					},
					"limit": {
						"type": "integer",
						"description": "Max number of events to return"
					},
					"level": {
						"type": "string",
						"enum": ["error", "warning", "info"],
						"description": "Log level filter for get_recent_filtered"
					},
					"tail": {
						"type": "integer",
						"description": "Return only the last N events (for get_recent_filtered)"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "dotnet",
			"description": """DOTNET DIAGNOSTICS: Run dotnet restore/build and return structured results.

ACTIONS:
- restore: Execute dotnet restore for a .csproj
- build: Execute dotnet build and parse warnings/errors

NOTES:
- build uses --no-restore and quiet MSBuild output
- timeout defaults to 30 seconds

EXAMPLES:
- Restore: {"action": "restore", "path": "res://Mechoes.csproj"}
- Build: {"action": "build", "path": "res://Mechoes.csproj"}
- Build with timeout: {"action": "build", "path": "res://Mechoes.csproj", "timeout_sec": 45}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["restore", "build"],
						"description": "dotnet action"
					},
					"path": {
						"type": "string",
						"description": "Optional .csproj path"
					},
					"timeout_sec": {
						"type": "integer",
						"description": "Execution timeout in seconds"
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
		"dotnet":
			return _execute_dotnet(args)
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
		"get_recent_filtered":
			return _execute_runtime_bridge_filtered(args)
		"get_errors_context":
			return _execute_runtime_bridge_errors_context(args)
		"get_scene_snapshot":
			return _execute_runtime_bridge_scene_snapshot(args)
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _execute_runtime_bridge_filtered(args: Dictionary) -> Dictionary:
	var level: String = str(args.get("level", ""))
	var tail: int = int(args.get("tail", 0))
	var limit: int = int(args.get("limit", 100))

	var all_events: Array[Dictionary] = MCPRuntimeDebugStore.get_recent(limit)
	var filtered: Array[Dictionary] = []

	for evt in all_events:
		var payload = evt.get("payload", {})
		if not (payload is Dictionary):
			payload = {}
		var evt_level: String = str(payload.get("level", "info"))
		if level.is_empty() or evt_level == level:
			filtered.append(evt)

	if tail > 0 and filtered.size() > tail:
		var tail_items: Array[Dictionary] = []
		for i in range(filtered.size() - tail, filtered.size()):
			tail_items.append(filtered[i])
		filtered = tail_items

	return _success({
		"bridge_status": MCPRuntimeDebugStore.get_bridge_status(),
		"filter_level": level if not level.is_empty() else "all",
		"count": filtered.size(),
		"events": filtered
	})


func _execute_runtime_bridge_errors_context(args: Dictionary) -> Dictionary:
	var limit: int = int(args.get("limit", 20))
	var raw_errors: Array[Dictionary] = MCPRuntimeDebugStore.get_errors(limit)

	var enriched: Array = []
	for evt in raw_errors:
		var payload = evt.get("payload", {})
		if not (payload is Dictionary):
			payload = {}

		var ctx: Dictionary = {
			"timestamp": str(evt.get("timestamp_text", "")),
			"session_id": evt.get("session_id", -1),
			"error_type": str(payload.get("error_type", payload.get("level", "error"))),
			"message": str(payload.get("message", "")),
			"script": str(payload.get("script", payload.get("source", ""))),
			"line": int(payload.get("line", payload.get("line_number", -1))),
			"node": str(payload.get("node", payload.get("node_path", ""))),
			"stacktrace": payload.get("stacktrace", payload.get("stack_trace", []))
		}
		enriched.append(ctx)

	return _success({
		"bridge_status": MCPRuntimeDebugStore.get_bridge_status(),
		"count": enriched.size(),
		"errors": enriched,
		"note": "Fields may be empty if not captured by the runtime bridge"
	})


func _execute_runtime_bridge_scene_snapshot(_args: Dictionary) -> Dictionary:
	var sessions: Dictionary = MCPRuntimeDebugStore.get_sessions()
	var recent_events: Array[Dictionary] = MCPRuntimeDebugStore.get_recent(50)

	# Look for scene-related events
	var scene_events: Array = []
	for evt in recent_events:
		var kind: String = str(evt.get("kind", ""))
		if kind in ["scene_changed", "scene_loaded", "scene_ready", "node_added", "node_removed",
				"script_error", "ready", "enter_tree", "close_requested", "exit_tree"]:
			scene_events.append(evt)

	# Get last known scene from events
	var last_scene: String = ""
	for evt in recent_events:
		var payload = evt.get("payload", {})
		if payload is Dictionary:
			var scene_path: String = str(payload.get("scene", payload.get("scene_path", "")))
			if not scene_path.is_empty():
				last_scene = scene_path
				break

	return _success({
		"bridge_status": MCPRuntimeDebugStore.get_bridge_status(),
		"session_count": sessions.size(),
		"last_known_scene": last_scene,
		"scene_event_count": scene_events.size(),
		"scene_events": scene_events,
		"note": "Snapshot reflects last captured runtime state. Run the project to capture live data."
	})


func _execute_dotnet(args: Dictionary) -> Dictionary:
	var action = str(args.get("action", "")).strip_edges()
	if action != "build" and action != "restore":
		return _error("Unknown action: %s" % action)

	var timeout_sec = int(args.get("timeout_sec", DOTNET_DEFAULT_TIMEOUT_SEC))
	if timeout_sec <= 0:
		timeout_sec = DOTNET_DEFAULT_TIMEOUT_SEC

	var project_path = _resolve_csproj_path(str(args.get("path", "")))
	if project_path.is_empty():
		return _error("No .csproj file found under res://")

	var command_result = _run_dotnet_command(action, project_path, timeout_sec)
	if not bool(command_result.get("success", false)):
		return command_result

	var data = command_result.get("data", {})
	if action == "build":
		if int(data.get("exit_code", 1)) != 0:
			return _error("dotnet build failed", data)
		return _success(data, "dotnet build completed")

	if int(data.get("exit_code", 1)) != 0:
		return _error("dotnet restore failed", data)
	return _success(data, "dotnet restore completed")


func _resolve_csproj_path(requested_path: String) -> String:
	var normalized_path = _normalize_res_path(requested_path)
	if not normalized_path.is_empty():
		if not normalized_path.ends_with(".csproj"):
			return ""
		if not FileAccess.file_exists(normalized_path):
			return ""
		return normalized_path

	var project_paths = _find_csproj_files("res://")
	if project_paths.is_empty():
		return ""
	return project_paths[0]


func _find_csproj_files(dir_path: String) -> Array[String]:
	var results: Array[String] = []
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return results

	dir.list_dir_begin()
	while true:
		var entry = dir.get_next()
		if entry.is_empty():
			break
		if entry.begins_with("."):
			continue
		var child_path = "%s%s" % [dir_path, entry] if dir_path == "res://" else "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			results.append_array(_find_csproj_files(child_path))
		elif entry.ends_with(".csproj"):
			results.append(_normalize_res_path(child_path))
	dir.list_dir_end()

	results.sort()
	return results


func _run_dotnet_command(action: String, project_path: String, timeout_sec: int) -> Dictionary:
	var global_project_path = ProjectSettings.globalize_path(project_path)
	var args: Array[String] = [action, global_project_path, "--nologo", "-v:q"]
	if action == "build":
		args.append("--no-restore")

	var command_result = _execute_process_with_pipe("dotnet", args, timeout_sec)
	if not bool(command_result.get("success", false)):
		return command_result

	var data = command_result.get("data", {})
	var output_text = str(data.get("output_text", ""))
	if bool(data.get("timed_out", false)):
		return _error("dotnet %s timed out" % action, _build_dotnet_result_data(action, project_path, args, data, output_text))

	if _is_dotnet_missing(output_text):
		return _error("dotnet SDK not available", _build_dotnet_result_data(action, project_path, args, data, output_text))

	return {
		"success": true,
		"data": _build_dotnet_result_data(action, project_path, args, data, output_text)
	}


func _build_dotnet_result_data(action: String, project_path: String, args: Array[String], command_data: Dictionary, output_text: String) -> Dictionary:
	var diagnostics = _parse_msbuild_diagnostics(output_text)
	return {
		"action": action,
		"project_path": project_path,
		"project_path_global": ProjectSettings.globalize_path(project_path),
		"command": args.duplicate(),
		"exit_code": int(command_data.get("exit_code", -1)),
		"timed_out": bool(command_data.get("timed_out", false)),
		"duration_ms": int(command_data.get("duration_ms", 0)),
		"warning_count": diagnostics.get("warnings", []).size(),
		"warnings": diagnostics.get("warnings", []),
		"error_count": diagnostics.get("errors", []).size(),
		"errors": diagnostics.get("errors", []),
		"output_line_count": output_text.split("\n").size(),
		"output_excerpt": _build_output_excerpt(output_text, 80)
	}


func _execute_process_with_pipe(executable_name: String, args: Array[String], timeout_sec: int) -> Dictionary:
	var process = OS.execute_with_pipe(executable_name, PackedStringArray(args), false)
	if process.is_empty():
		return _error("Failed to start dotnet process", {
			"command": args.duplicate()
		})

	var pid = int(process.get("pid", -1))
	if pid <= 0:
		return _error("Failed to start dotnet process", {
			"command": args.duplicate(),
			"pid": pid
		})

	var stdio = process.get("stdio")
	var stderr = process.get("stderr")
	var stdout_chunks: Array[String] = []
	var stderr_chunks: Array[String] = []
	var started_msec = Time.get_ticks_msec()
	var timed_out = false

	while OS.is_process_running(pid):
		_read_pipe_chunks(stdio, stdout_chunks)
		_read_pipe_chunks(stderr, stderr_chunks)
		if Time.get_ticks_msec() - started_msec > timeout_sec * 1000:
			timed_out = true
			OS.kill(pid)
			break
		OS.delay_msec(50)

	_read_pipe_chunks(stdio, stdout_chunks)
	_read_pipe_chunks(stderr, stderr_chunks)
	if stdio is FileAccess:
		(stdio as FileAccess).close()
	if stderr is FileAccess:
		(stderr as FileAccess).close()

	var exit_code = -1
	if not timed_out:
		exit_code = OS.get_process_exit_code(pid)

	var output_parts = stdout_chunks.duplicate()
	output_parts.append_array(stderr_chunks)
	return {
		"success": true,
		"data": {
			"exit_code": exit_code,
			"timed_out": timed_out,
			"duration_ms": int(Time.get_ticks_msec() - started_msec),
			"output_text": "\n".join(output_parts).strip_edges()
		}
	}


func _read_pipe_chunks(pipe: Variant, chunks: Array[String]) -> void:
	if not (pipe is FileAccess):
		return

	while true:
		var buffer = (pipe as FileAccess).get_buffer(4096)
		if buffer.is_empty():
			break
		chunks.append(buffer.get_string_from_utf8())
		if buffer.size() < 4096:
			break


func _is_dotnet_missing(output_text: String) -> bool:
	var lowered = output_text.to_lower()
	return lowered.contains("is not recognized as an internal or external command") \
		or lowered.contains("command not found") \
		or lowered.contains("could not execute because the specified command or file was not found")


func _parse_msbuild_diagnostics(output_text: String) -> Dictionary:
	var warnings: Array[Dictionary] = []
	var errors: Array[Dictionary] = []
	var seen_keys := {}
	var regex = RegEx.new()
	regex.compile("^(.*)\\((\\d+)(?:,(\\d+))?\\):\\s+(error|warning)\\s+([A-Za-z]+\\d+):\\s+(.*?)(?:\\s+\\[.*\\])?$")

	for raw_line in output_text.split("\n"):
		var line = raw_line.strip_edges()
		if line.is_empty():
			continue
		var match_result = regex.search(line)
		if match_result == null:
			continue

		var source_file = str(match_result.get_string(1)).replace("\\", "/")
		var source_line = int(match_result.get_string(2))
		var source_column = 0
		if not str(match_result.get_string(3)).is_empty():
			source_column = int(match_result.get_string(3))
		var severity = str(match_result.get_string(4))
		var code = str(match_result.get_string(5))
		var message = str(match_result.get_string(6)).strip_edges()
		var res_path = _absolute_path_to_res(source_file)
		var dedupe_key = "%s|%d|%d|%s|%s|%s" % [source_file, source_line, source_column, severity, code, message]
		if seen_keys.has(dedupe_key):
			continue
		seen_keys[dedupe_key] = true

		var diagnostic = {
			"severity": severity,
			"code": code,
			"message": message,
			"source_file": source_file,
			"source_path": res_path,
			"source_line": source_line,
			"source_column": source_column,
			"open_command": null if res_path.is_empty() else {
				"path": res_path,
				"line": source_line
			}
		}

		if severity == "warning":
			warnings.append(diagnostic)
		else:
			errors.append(diagnostic)

	return {
		"warnings": warnings,
		"errors": errors
	}


func _absolute_path_to_res(source_file: String) -> String:
	var project_root = ProjectSettings.globalize_path("res://").replace("\\", "/")
	var normalized_source = source_file.replace("\\", "/")
	if OS.get_name() == "Windows":
		project_root = project_root.to_lower()
		normalized_source = normalized_source.to_lower()

	if not normalized_source.begins_with(project_root):
		return ""

	var relative_path = source_file.replace("\\", "/").substr(ProjectSettings.globalize_path("res://").replace("\\", "/").length())
	relative_path = relative_path.trim_prefix("/")
	return "res://%s" % relative_path


func _build_output_excerpt(output_text: String, max_lines: int) -> String:
	var lines = output_text.split("\n")
	if lines.size() <= max_lines:
		return output_text.strip_edges()
	return "\n".join(lines.slice(lines.size() - max_lines)).strip_edges()


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
