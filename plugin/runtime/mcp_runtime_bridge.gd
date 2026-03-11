extends Node

const EVENT_CHANNEL := "godot_mcp/runtime_event"
const LOG_CHANNEL := "godot_mcp/runtime_log"
const FALLBACK_FILE_PATH := "user://godot_mcp_runtime_bridge_events.json"
const MAX_STORED_EVENTS := 300


func _enter_tree() -> void:
	_emit_event("enter_tree")


func _ready() -> void:
	_emit_event("ready", {
		"current_scene": _get_current_scene_path(),
		"tree_root": str(get_tree().root.name)
	})


func _exit_tree() -> void:
	_emit_event("exit_tree")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_emit_event("application_paused")
		NOTIFICATION_APPLICATION_RESUMED:
			_emit_event("application_resumed")
		NOTIFICATION_WM_CLOSE_REQUEST:
			_emit_event("close_requested")


func emit_log(level: String, message: String, metadata: Dictionary = {}) -> void:
	if message.is_empty():
		return
	_send(LOG_CHANNEL, {
		"level": str(level).to_lower(),
		"message": message,
		"scene": _get_current_scene_path(),
		"stack": get_stack(),
		"metadata": metadata.duplicate(true)
	})


func emit_info(message: String, metadata: Dictionary = {}) -> void:
	emit_log("info", message, metadata)


func emit_warning(message: String, metadata: Dictionary = {}) -> void:
	emit_log("warning", message, metadata)


func emit_error(message: String, metadata: Dictionary = {}) -> void:
	emit_log("error", message, metadata)


func emit_event(event_name: String, metadata: Dictionary = {}) -> void:
	_emit_event(event_name, metadata)


func _emit_event(event_name: String, metadata: Dictionary = {}) -> void:
	_send(EVENT_CHANNEL, {
		"event": event_name,
		"scene": _get_current_scene_path(),
		"metadata": metadata.duplicate(true)
	})


func _send(channel: String, payload: Dictionary) -> void:
	_append_fallback_event(channel, payload)
	if not EngineDebugger.is_active():
		return
	EngineDebugger.send_message(channel, [payload])


func _get_current_scene_path() -> String:
	var tree := get_tree()
	if tree == null:
		return ""
	var current_scene := tree.current_scene
	if current_scene == null:
		return ""
	return str(current_scene.scene_file_path)


func _append_fallback_event(channel: String, payload: Dictionary) -> void:
	var event := {
		"timestamp_unix": int(Time.get_unix_time_from_system()),
		"timestamp_text": Time.get_datetime_string_from_system(true, true),
		"kind": "runtime_event" if channel == EVENT_CHANNEL else "runtime_log",
		"session_id": -1,
		"payload": payload.duplicate(true)
	}
	var events := _read_fallback_events()
	events.append(event)
	if events.size() > MAX_STORED_EVENTS:
		events = events.slice(events.size() - MAX_STORED_EVENTS)
	_write_fallback_events(events)


func _read_fallback_events() -> Array[Dictionary]:
	if not FileAccess.file_exists(FALLBACK_FILE_PATH):
		return []
	var file := FileAccess.open(FALLBACK_FILE_PATH, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		var events: Array[Dictionary] = []
		for item in parsed:
			if item is Dictionary:
				events.append((item as Dictionary).duplicate(true))
		return events
	if parsed is Dictionary:
		var data = parsed.get("events", [])
		if data is Array:
			var wrapped_events: Array[Dictionary] = []
			for item in data:
				if item is Dictionary:
					wrapped_events.append((item as Dictionary).duplicate(true))
			return wrapped_events
	return []


func _write_fallback_events(events: Array[Dictionary]) -> void:
	var file := FileAccess.open(FALLBACK_FILE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(events))
	file.close()
