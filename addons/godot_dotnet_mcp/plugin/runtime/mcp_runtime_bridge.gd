extends Node

const EVENT_CHANNEL := "godot_mcp/runtime_event"
const LOG_CHANNEL := "godot_mcp/runtime_log"
const COMMAND_CAPTURE_PREFIX := "godot_mcp/runtime_command"
const REPLY_CHANNEL := "godot_mcp/runtime_reply"
const FALLBACK_FILE_PATH := "user://godot_mcp_runtime_bridge_events.json"
const MAX_STORED_EVENTS := 300
const FALLBACK_FLUSH_INTERVAL_SECONDS := 2.0
const CAPTURE_ROOT_DIR := "user://godot_mcp_runtime_captures"
const MAX_CAPTURE_FILES_PER_SESSION := 24
const MCPRuntimeFallbackStoreScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_fallback_store.gd")
const MCPRuntimeCommandServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_command_service.gd")
const MCPRuntimeReplyServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_reply_service.gd")

var _flush_timer: Timer
var _tool_loader = null
var _gdscript_lsp_diagnostics_service = null
var _command_capture_registered := false
var _last_runtime_event_at := ""
var _fallback_store = MCPRuntimeFallbackStoreScript.new()
var _command_service = MCPRuntimeCommandServiceScript.new()
var _reply_service = MCPRuntimeReplyServiceScript.new()


func _enter_tree() -> void:
	_configure_services()
	_ensure_flush_timer()
	_ensure_command_capture()
	_emit_event("enter_tree")


func _ready() -> void:
	_emit_event("ready", {
		"current_scene": _get_current_scene_path(),
		"tree_root": str(get_tree().root.name)
	})


func _exit_tree() -> void:
	_emit_event("exit_tree")
	dispose()


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


func handle_runtime_command_capture(message: String, data: Array) -> bool:
	return _capture_runtime_command(message, data)


func flush_fallback_events() -> void:
	_flush_to_disk()


func read_fallback_events() -> Array[Dictionary]:
	if _fallback_store == null:
		return []
	return _fallback_store.read_events()


func dispose() -> void:
	_flush_to_disk()
	if _command_service != null and _command_service.has_method("dispose"):
		_command_service.dispose()
	if _reply_service != null and _reply_service.has_method("dispose"):
		_reply_service.dispose()
	if _fallback_store != null and _fallback_store.has_method("dispose"):
		_fallback_store.dispose()
	_unregister_command_capture()
	if _flush_timer != null and is_instance_valid(_flush_timer):
		_flush_timer.stop()
		_flush_timer.queue_free()
	_flush_timer = null
	_tool_loader = null
	_gdscript_lsp_diagnostics_service = null
	_command_service = null
	_reply_service = null
	_fallback_store = null


func set_tool_loader(tool_loader) -> void:
	_tool_loader = tool_loader


func get_tool_loader():
	return _tool_loader


func set_gdscript_lsp_diagnostics_service(service) -> void:
	_gdscript_lsp_diagnostics_service = service


func get_gdscript_lsp_diagnostics_service():
	return _gdscript_lsp_diagnostics_service


func _configure_services() -> void:
	if _fallback_store == null:
		_fallback_store = MCPRuntimeFallbackStoreScript.new()
	_fallback_store.configure({
		"fallback_file_path": FALLBACK_FILE_PATH,
		"max_stored_events": MAX_STORED_EVENTS
	})
	if _command_service == null:
		_command_service = MCPRuntimeCommandServiceScript.new()
	_command_service.configure({
		"get_tree": Callable(self, "get_tree"),
		"get_viewport": Callable(self, "get_viewport"),
		"get_current_scene_path": Callable(self, "_get_current_scene_path"),
		"build_runtime_state": Callable(self, "_build_runtime_state")
	}, {
		"capture_root_dir": CAPTURE_ROOT_DIR,
		"max_capture_files_per_session": MAX_CAPTURE_FILES_PER_SESSION
	})
	if _reply_service == null:
		_reply_service = MCPRuntimeReplyServiceScript.new()
	_reply_service.configure({
		"send_reply": Callable(self, "_send_reply_payload"),
		"get_current_scene_path": Callable(self, "_get_current_scene_path"),
		"build_runtime_state": Callable(self, "_build_runtime_state")
	})


func _emit_event(event_name: String, metadata: Dictionary = {}) -> void:
	_send(EVENT_CHANNEL, {
		"event": event_name,
		"scene": _get_current_scene_path(),
		"metadata": metadata.duplicate(true)
	})


func _send(channel: String, payload: Dictionary) -> void:
	_append_fallback_event(channel, payload)
	_last_runtime_event_at = Time.get_datetime_string_from_system(true, true)
	if channel == REPLY_CHANNEL:
		_flush_to_disk()
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
	var event_kind := "runtime_log"
	if channel == EVENT_CHANNEL:
		event_kind = "runtime_event"
	elif channel == REPLY_CHANNEL:
		event_kind = "runtime_reply"
	_configure_services()
	_fallback_store.append_event(event_kind, payload, int(payload.get("session_id", -1)))
	if _flush_timer != null and _flush_timer.is_inside_tree() and _flush_timer.is_stopped():
		_flush_timer.start()


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
	if _fallback_store == null or not _fallback_store.has_pending_events():
		if _flush_timer != null:
			_flush_timer.stop()
		return
	_fallback_store.flush()
	if _flush_timer != null:
		_flush_timer.stop()


func _ensure_command_capture() -> void:
	if _command_capture_registered:
		return
	if EngineDebugger.has_capture(COMMAND_CAPTURE_PREFIX):
		EngineDebugger.unregister_message_capture(COMMAND_CAPTURE_PREFIX)
	EngineDebugger.register_message_capture(COMMAND_CAPTURE_PREFIX, Callable(self, "_capture_runtime_command"))
	_command_capture_registered = true


func _unregister_command_capture() -> void:
	if not _command_capture_registered:
		return
	if EngineDebugger.has_capture(COMMAND_CAPTURE_PREFIX):
		EngineDebugger.unregister_message_capture(COMMAND_CAPTURE_PREFIX)
	_command_capture_registered = false


func _capture_runtime_command(message: String, data: Array) -> bool:
	if message != "call":
		return false
	var payload := _extract_payload(data)
	call_deferred("_execute_runtime_command_async", payload)
	return true


func _execute_runtime_command_async(payload: Dictionary) -> void:
	var request_id := str(payload.get("request_id", ""))
	var action := str(payload.get("action", ""))
	var session_id := int(payload.get("session_id", -1))
	var args = payload.get("payload", {})
	if request_id.is_empty():
		return
	_configure_services()
	if action.is_empty():
		_reply_service.send_error(request_id, session_id, "invalid_argument", "Runtime command is missing an action.", {}, action)
		return
	if not (args is Dictionary):
		args = {}
	var result: Dictionary = await _command_service.execute_action_async(session_id, action, args)
	_reply_service.send_result(request_id, session_id, result, action)


func _send_reply_payload(payload: Dictionary) -> void:
	_send(REPLY_CHANNEL, payload)


func _build_runtime_state(session_id: int) -> Dictionary:
	var tree := get_tree()
	return {
		"running": true,
		"scene": _get_current_scene_path(),
		"paused": tree != null and tree.paused,
		"session_id": session_id,
		"process_frame": Engine.get_process_frames(),
		"physics_frame": Engine.get_physics_frames(),
		"last_runtime_event_at": _last_runtime_event_at
	}


func _extract_payload(data) -> Dictionary:
	if data is Array and data.size() > 0 and data[0] is Dictionary:
		return (data[0] as Dictionary).duplicate(true)
	if data is Dictionary:
		return (data as Dictionary).duplicate(true)
	return {}
