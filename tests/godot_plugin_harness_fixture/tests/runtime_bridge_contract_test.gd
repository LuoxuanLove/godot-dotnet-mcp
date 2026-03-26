extends RefCounted

const RuntimeBridgeScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_bridge.gd")
const FALLBACK_FILE_PATH := "user://godot_mcp_runtime_bridge_events.json"
const REQUEST_ID := "runtime-unknown-action"


func run_case(tree: SceneTree) -> Dictionary:
	_cleanup_fallback_file()

	var bridge = RuntimeBridgeScript.new()
	tree.root.add_child(bridge)
	await tree.process_frame

	var accepted := bridge._capture_runtime_command("call", [{
		"request_id": REQUEST_ID,
		"action": "unknown",
		"session_id": 17,
		"payload": {}
	}])
	await tree.process_frame
	await tree.process_frame
	bridge._flush_to_disk()
	var events = bridge._read_fallback_events()

	tree.root.remove_child(bridge)
	bridge.queue_free()
	await tree.process_frame

	if not accepted:
		return _failure("Runtime bridge rejected the synthetic command capture.")

	var reply := _find_reply_event(events)
	if reply.is_empty():
		return _failure("Runtime bridge did not persist a runtime_reply fallback event.")

	var payload = reply.get("payload", {})
	if not (payload is Dictionary):
		return _failure("Runtime bridge reply payload is not a dictionary.")

	if str(payload.get("error", "")) != "invalid_argument":
		return _failure("Runtime bridge returned an unexpected error code: %s" % str(payload.get("error", "")))

	var data = payload.get("data", {})
	if not (data is Dictionary):
		return _failure("Runtime bridge reply data is not a dictionary.")

	var runtime_context = (data as Dictionary).get("runtime_context", {})
	if not (runtime_context is Dictionary):
		return _failure("Runtime bridge reply is missing runtime_context.")

	if str((runtime_context as Dictionary).get("action", "")) != "unknown":
		return _failure("Runtime bridge runtime_context.action did not preserve the failing action.")

	if str((data as Dictionary).get("hint", "")).is_empty():
		return _failure("Runtime bridge reply is missing a human-readable hint.")

	if not (data as Dictionary).has("runtime_state"):
		return _failure("Runtime bridge reply is missing runtime_state.")

	return {
		"name": "runtime_bridge_invalid_action_fallback",
		"success": true,
		"error": "",
		"details": {
			"event_count": events.size(),
			"reply_error": str(payload.get("error", "")),
			"hint": str((data as Dictionary).get("hint", ""))
		}
	}


func _find_reply_event(events: Array) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var item = events[index]
		if item is Dictionary and str((item as Dictionary).get("kind", "")) == "runtime_reply":
			var payload = (item as Dictionary).get("payload", {})
			if payload is Dictionary and str((payload as Dictionary).get("request_id", "")) == REQUEST_ID:
				return (item as Dictionary).duplicate(true)
	return {}


func _cleanup_fallback_file() -> void:
	var absolute_path := ProjectSettings.globalize_path(FALLBACK_FILE_PATH)
	if FileAccess.file_exists(FALLBACK_FILE_PATH):
		DirAccess.remove_absolute(absolute_path)


func _failure(message: String) -> Dictionary:
	return {
		"name": "runtime_bridge_invalid_action_fallback",
		"success": false,
		"error": message
	}
