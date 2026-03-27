@tool
extends "res://addons/godot_dotnet_mcp/tools/debug/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
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
			return _execute_runtime_bridge_scene_snapshot()
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _execute_runtime_bridge_filtered(args: Dictionary) -> Dictionary:
	var level := str(args.get("level", ""))
	var tail := int(args.get("tail", 0))
	var limit := int(args.get("limit", 100))
	var all_events: Array[Dictionary] = MCPRuntimeDebugStore.get_recent(limit)
	var filtered: Array[Dictionary] = []

	for evt in all_events:
		var payload = evt.get("payload", {})
		if not (payload is Dictionary):
			payload = {}
		var evt_level := str(payload.get("level", "info"))
		if level.is_empty() or evt_level == level:
			filtered.append(evt)

	if tail > 0 and filtered.size() > tail:
		filtered = filtered.slice(filtered.size() - tail)

	return _success({
		"bridge_status": MCPRuntimeDebugStore.get_bridge_status(),
		"filter_level": level if not level.is_empty() else "all",
		"count": filtered.size(),
		"events": filtered
	})


func _execute_runtime_bridge_errors_context(args: Dictionary) -> Dictionary:
	var limit := int(args.get("limit", 20))
	var raw_errors: Array[Dictionary] = MCPRuntimeDebugStore.get_errors(limit)
	var enriched: Array = []

	for evt in raw_errors:
		var payload = evt.get("payload", {})
		if not (payload is Dictionary):
			payload = {}
		enriched.append({
			"timestamp": str(evt.get("timestamp_text", "")),
			"session_id": evt.get("session_id", -1),
			"error_type": str(payload.get("error_type", payload.get("level", "error"))),
			"message": str(payload.get("message", "")),
			"script": str(payload.get("script", payload.get("source", ""))),
			"line": int(payload.get("line", payload.get("line_number", -1))),
			"node": str(payload.get("node", payload.get("node_path", ""))),
			"stacktrace": payload.get("stacktrace", payload.get("stack_trace", []))
		})

	return _success({
		"bridge_status": MCPRuntimeDebugStore.get_bridge_status(),
		"count": enriched.size(),
		"errors": enriched,
		"note": "Fields may be empty if not captured by the runtime bridge"
	})


func _execute_runtime_bridge_scene_snapshot() -> Dictionary:
	var sessions: Dictionary = MCPRuntimeDebugStore.get_sessions()
	var recent_events: Array[Dictionary] = MCPRuntimeDebugStore.get_recent(50)
	var scene_events: Array = []

	for evt in recent_events:
		var kind := str(evt.get("kind", ""))
		if kind in ["scene_changed", "scene_loaded", "scene_ready", "node_added", "node_removed", "script_error", "ready", "enter_tree", "close_requested", "exit_tree"]:
			scene_events.append(evt)

	var last_scene := ""
	for evt in recent_events:
		var payload = evt.get("payload", {})
		if payload is Dictionary:
			var scene_path := str(payload.get("scene", payload.get("scene_path", "")))
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
