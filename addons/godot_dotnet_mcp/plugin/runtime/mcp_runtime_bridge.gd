extends Node

const EVENT_CHANNEL := "godot_mcp/runtime_event"
const LOG_CHANNEL := "godot_mcp/runtime_log"
const FALLBACK_FILE_PATH := "user://godot_mcp_runtime_bridge_events.json"
const MAX_STORED_EVENTS := 300
const FALLBACK_FLUSH_INTERVAL_SECONDS := 2.0

var _pending_events: Array[Dictionary] = []
var _fallback_cache: Array[Dictionary] = []
var _fallback_cache_loaded := false
var _flush_timer: Timer
var _tool_loader = null
var _gdscript_lsp_diagnostics_service = null


func _enter_tree() -> void:
	_ensure_flush_timer()
	_emit_event("enter_tree")


func _ready() -> void:
	_emit_event("ready", {
		"current_scene": _get_current_scene_path(),
		"tree_root": str(get_tree().root.name)
	})


func _exit_tree() -> void:
	_emit_event("exit_tree")
	_flush_to_disk()


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


func set_tool_loader(tool_loader) -> void:
	_tool_loader = tool_loader


func get_tool_loader():
	return _tool_loader


func set_gdscript_lsp_diagnostics_service(service) -> void:
	_gdscript_lsp_diagnostics_service = service


func get_gdscript_lsp_diagnostics_service():
	return _gdscript_lsp_diagnostics_service


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
	_pending_events.append(event)
	_trim_cached_events()
	if _flush_timer != null and _flush_timer.is_stopped():
		_flush_timer.start()


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


func _ensure_flush_timer() -> void:
	if _flush_timer != null and is_instance_valid(_flush_timer):
		return
	_flush_timer = Timer.new()
	_flush_timer.name = "MCPRuntimeBridgeFlushTimer"
	_flush_timer.one_shot = false
	_flush_timer.wait_time = FALLBACK_FLUSH_INTERVAL_SECONDS
	_flush_timer.timeout.connect(_on_flush_timer_timeout)
	add_child(_flush_timer)


func _on_flush_timer_timeout() -> void:
	_flush_to_disk()


func _flush_to_disk() -> void:
	if _pending_events.is_empty():
		if _flush_timer != null:
			_flush_timer.stop()
		return
	if not _fallback_cache_loaded:
		_fallback_cache = _read_fallback_events()
		_fallback_cache_loaded = true
	_fallback_cache.append_array(_pending_events)
	if _fallback_cache.size() > MAX_STORED_EVENTS:
		_fallback_cache = _fallback_cache.slice(_fallback_cache.size() - MAX_STORED_EVENTS)
	_write_fallback_events(_fallback_cache)
	_pending_events.clear()
	if _flush_timer != null:
		_flush_timer.stop()


func _trim_cached_events() -> void:
	var projected_size := _pending_events.size()
	if _fallback_cache_loaded:
		projected_size += _fallback_cache.size()
	if projected_size <= MAX_STORED_EVENTS:
		return
	var overflow := projected_size - MAX_STORED_EVENTS
	while overflow > 0 and not _pending_events.is_empty():
		_pending_events.remove_at(0)
		overflow -= 1
