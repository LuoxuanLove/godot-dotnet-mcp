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

var _pending_events: Array[Dictionary] = []
var _fallback_cache: Array[Dictionary] = []
var _fallback_cache_loaded := false
var _flush_timer: Timer
var _tool_loader = null
var _gdscript_lsp_diagnostics_service = null
var _command_capture_registered := false
var _capture_files_by_session: Dictionary = {}
var _last_runtime_event_at := ""


func _enter_tree() -> void:
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
	_flush_to_disk()
	_cleanup_capture_root()
	_unregister_command_capture()


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
	_last_runtime_event_at = Time.get_datetime_string_from_system(true, true)
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
	if action.is_empty():
		_reply_error(request_id, session_id, "invalid_argument", "Runtime command is missing an action.")
		return
	if not (args is Dictionary):
		args = {}

	match action:
		"capture_frame":
			var frame_result: Dictionary = await _capture_frame_async(session_id, args)
			_reply_result(request_id, session_id, frame_result)
		"capture_sequence":
			var sequence_result: Dictionary = await _capture_sequence_async(session_id, args)
			_reply_result(request_id, session_id, sequence_result)
		"input":
			var input_result: Dictionary = await _apply_inputs_async(session_id, args)
			_reply_result(request_id, session_id, input_result)
		"step":
			var step_result: Dictionary = await _run_step_async(session_id, args)
			_reply_result(request_id, session_id, step_result)
		_:
			_reply_error(request_id, session_id, "invalid_argument", "Unknown runtime action: %s" % action)


func _capture_frame_async(session_id: int, args: Dictionary) -> Dictionary:
	var include_runtime_state := bool(args.get("include_runtime_state", true))
	var capture_label := str(args.get("capture_label", ""))
	await _await_capture_ready()
	var viewport := get_viewport()
	if viewport == null:
		return _failure("runtime_capture_failed", "Viewport is unavailable.")
	var texture := viewport.get_texture()
	if texture == null:
		return _failure("runtime_capture_failed", "Viewport texture is unavailable.")
	var image := texture.get_image()
	if image == null or image.is_empty():
		return _failure("runtime_capture_failed", "Viewport image is unavailable.")

	var session_key := _session_key(session_id)
	var capture_dir := "%s/%s" % [CAPTURE_ROOT_DIR, session_key]
	var absolute_capture_dir := ProjectSettings.globalize_path(capture_dir)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_capture_dir)
	if mkdir_error != OK:
		return _failure("runtime_capture_failed", "Failed to create capture directory.", {
			"error_code": mkdir_error,
			"capture_dir": absolute_capture_dir
		})

	var timestamp := Time.get_datetime_string_from_system(true, true).replace(":", "-")
	var filename := "frame_%s_%d.png" % [timestamp, Time.get_ticks_msec()]
	if not capture_label.is_empty():
		filename = "%s_%s" % [_sanitize_capture_label(capture_label), filename]
	var user_path := "%s/%s" % [capture_dir, filename]
	var absolute_path := ProjectSettings.globalize_path(user_path)
	var save_error := image.save_png(absolute_path)
	if save_error != OK:
		return _failure("runtime_capture_failed", "Failed to save runtime capture.", {
			"error_code": save_error,
			"file_path": absolute_path
		})

	_track_capture_file(session_key, absolute_path)
	var runtime_state := _build_runtime_state(session_id) if include_runtime_state else {}
	return _success({
		"file_path": absolute_path,
		"user_path": user_path,
		"width": image.get_width(),
		"height": image.get_height(),
		"scene": _get_current_scene_path(),
		"session_id": session_id,
		"captured_at": Time.get_datetime_string_from_system(true, true),
		"runtime_state": runtime_state
	}, "Runtime frame captured")


func _capture_sequence_async(session_id: int, args: Dictionary) -> Dictionary:
	var frame_count := maxi(int(args.get("frame_count", 1)), 1)
	var interval_frames := maxi(int(args.get("interval_frames", 1)), 0)
	var frames: Array[Dictionary] = []
	for index in range(frame_count):
		if index > 0 and interval_frames > 0:
			await _await_process_frames(interval_frames)
		var frame_result: Dictionary = await _capture_frame_async(session_id, args)
		if not bool(frame_result.get("success", false)):
			return frame_result
		var frame_data = frame_result.get("data", {})
		if frame_data is Dictionary:
			var frame_dict: Dictionary = (frame_data as Dictionary).duplicate(true)
			frame_dict["index"] = index
			frames.append(frame_dict)
	return _success({
		"frame_count": frames.size(),
		"frames": frames,
		"runtime_state": frames[-1].get("runtime_state", {}) if not frames.is_empty() else _build_runtime_state(session_id)
	}, "Runtime capture sequence completed")


func _apply_inputs_async(session_id: int, args: Dictionary) -> Dictionary:
	var inputs = args.get("inputs", [])
	if not (inputs is Array) or (inputs as Array).is_empty():
		return _failure("invalid_argument", "Runtime input requires a non-empty inputs array.")
	var executed: Array[Dictionary] = []
	for raw_input in inputs:
		if not (raw_input is Dictionary):
			return _failure("invalid_argument", "Each runtime input entry must be a dictionary.")
		var input_entry: Dictionary = (raw_input as Dictionary).duplicate(true)
		var result := await _apply_single_input_async(input_entry)
		if not bool(result.get("success", false)):
			return result
		var executed_entry = result.get("data", {})
		if executed_entry is Dictionary:
			executed.append((executed_entry as Dictionary).duplicate(true))
	return _success({
		"inputs": executed,
		"runtime_state": _build_runtime_state(session_id)
	}, "Runtime inputs applied")


func _apply_single_input_async(input_entry: Dictionary) -> Dictionary:
	var kind := str(input_entry.get("kind", "")).to_lower()
	var target := str(input_entry.get("target", ""))
	var op := str(input_entry.get("op", "")).to_lower()
	var duration_ms := maxi(int(input_entry.get("duration_ms", 60)), 1)
	if kind.is_empty() or target.is_empty() or op.is_empty():
		return _failure("invalid_argument", "Runtime input entries require kind, target, and op.")

	match kind:
		"action":
			if not InputMap.has_action(target):
				return _failure("invalid_argument", "Unknown input action: %s" % target)
			return await _apply_action_input_async(target, op, duration_ms)
		"key":
			return await _apply_key_input_async(target, op, duration_ms)
		_:
			return _failure("invalid_argument", "Unsupported runtime input kind: %s" % kind)


func _apply_action_input_async(action_name: String, op: String, duration_ms: int) -> Dictionary:
	match op:
		"press":
			_dispatch_action_event(action_name, true)
		"release":
			_dispatch_action_event(action_name, false)
		"tap", "hold":
			_dispatch_action_event(action_name, true)
			await _await_duration_ms(duration_ms)
			_dispatch_action_event(action_name, false)
		_:
			return _failure("invalid_argument", "Unsupported action input op: %s" % op)
	return _success({
		"kind": "action",
		"target": action_name,
		"op": op,
		"duration_ms": duration_ms if op in ["tap", "hold"] else 0
	}, "Runtime action input applied")


func _apply_key_input_async(key_name: String, op: String, duration_ms: int) -> Dictionary:
	var keycode := int(OS.find_keycode_from_string(key_name))
	if keycode == 0:
		return _failure("invalid_argument", "Unsupported key name: %s" % key_name)
	match op:
		"press":
			_dispatch_key_event(keycode, true)
		"release":
			_dispatch_key_event(keycode, false)
		"tap", "hold":
			_dispatch_key_event(keycode, true)
			await _await_duration_ms(duration_ms)
			_dispatch_key_event(keycode, false)
		_:
			return _failure("invalid_argument", "Unsupported key input op: %s" % op)
	return _success({
		"kind": "key",
		"target": key_name,
		"keycode": keycode,
		"op": op,
		"duration_ms": duration_ms if op in ["tap", "hold"] else 0
	}, "Runtime key input applied")


func _run_step_async(session_id: int, args: Dictionary) -> Dictionary:
	var inputs = args.get("inputs", [])
	if inputs != null and not (inputs is Array):
		return _failure("invalid_argument", "Runtime step inputs must be an array when provided.")
	var applied_inputs: Array[Dictionary] = []
	if inputs is Array and not (inputs as Array).is_empty():
		var input_result: Dictionary = await _apply_inputs_async(session_id, {"inputs": inputs})
		if not bool(input_result.get("success", false)):
			return input_result
		var input_data = input_result.get("data", {})
		if input_data is Dictionary:
			applied_inputs = (input_data as Dictionary).get("inputs", []).duplicate(true)

	var wait_frames := maxi(int(args.get("wait_frames", 1)), 0)
	if wait_frames > 0:
		await _await_process_frames(wait_frames)

	var capture := bool(args.get("capture", true))
	var frame := {}
	if capture:
		var capture_result: Dictionary = await _capture_frame_async(session_id, args)
		if not bool(capture_result.get("success", false)):
			return capture_result
		frame = capture_result.get("data", {})
	var step_data := {
		"inputs": applied_inputs,
		"wait_frames": wait_frames,
		"capture": capture,
		"frame": frame,
		"runtime_state": frame.get("runtime_state", _build_runtime_state(session_id)) if frame is Dictionary else _build_runtime_state(session_id)
	}
	if frame is Dictionary:
		for key in ["file_path", "user_path", "width", "height", "scene", "session_id", "captured_at"]:
			if (frame as Dictionary).has(key):
				step_data[key] = (frame as Dictionary).get(key)
	return _success(step_data, "Runtime step completed")


func _await_capture_ready() -> void:
	await _await_process_frames(1)
	await RenderingServer.frame_post_draw


func _await_process_frames(frame_count: int) -> void:
	var tree := get_tree()
	if tree == null:
		return
	for _index in range(maxi(frame_count, 0)):
		await tree.process_frame


func _await_duration_ms(duration_ms: int) -> void:
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(float(duration_ms) / 1000.0).timeout


func _dispatch_action_event(action_name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


func _dispatch_key_event(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	event.echo = false
	Input.parse_input_event(event)


func _reply_result(request_id: String, session_id: int, result: Dictionary) -> void:
	if bool(result.get("success", false)):
		_send(REPLY_CHANNEL, {
			"request_id": request_id,
			"ok": true,
			"message": str(result.get("message", "Runtime command completed")),
			"data": result.get("data", {}),
			"session_id": session_id
		})
		return
	_reply_error(
		request_id,
		session_id,
		str(result.get("error", "runtime_command_failed")),
		str(result.get("message", result.get("error", "Runtime command failed"))),
		result.get("data", {})
	)


func _reply_error(request_id: String, session_id: int, error_type: String, message: String, data = {}) -> void:
	_send(REPLY_CHANNEL, {
		"request_id": request_id,
		"ok": false,
		"error": error_type,
		"message": message,
		"data": data if data is Dictionary else {"details": data},
		"session_id": session_id
	})


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


func _track_capture_file(session_key: String, absolute_path: String) -> void:
	var files: Array = _capture_files_by_session.get(session_key, [])
	files.append(absolute_path)
	while files.size() > MAX_CAPTURE_FILES_PER_SESSION:
		var stale_path := str(files[0])
		files.remove_at(0)
		if FileAccess.file_exists(stale_path):
			DirAccess.remove_absolute(stale_path)
	_capture_files_by_session[session_key] = files


func _cleanup_capture_root() -> void:
	var absolute_root := ProjectSettings.globalize_path(CAPTURE_ROOT_DIR)
	if not DirAccess.dir_exists_absolute(absolute_root):
		return
	_delete_directory_recursive(absolute_root)
	_capture_files_by_session.clear()


func _delete_directory_recursive(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return
	directory.list_dir_begin()
	while true:
		var entry := directory.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."]:
			continue
		var child_path := "%s/%s" % [path.replace("\\", "/"), entry]
		if directory.current_is_dir():
			_delete_directory_recursive(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	directory.list_dir_end()
	DirAccess.remove_absolute(path)


func _session_key(session_id: int) -> String:
	return str(session_id) if session_id >= 0 else "unknown"


func _sanitize_capture_label(label: String) -> String:
	var sanitized := label.strip_edges().replace(" ", "_")
	for invalid_char in ["\\", "/", ":", "*", "?", "\"", "<", ">", "|"]:
		sanitized = sanitized.replace(invalid_char, "_")
	return sanitized.substr(0, mini(sanitized.length(), 32))


func _extract_payload(data) -> Dictionary:
	if data is Array and data.size() > 0 and data[0] is Dictionary:
		return (data[0] as Dictionary).duplicate(true)
	if data is Dictionary:
		return (data as Dictionary).duplicate(true)
	return {}


func _success(data, message: String) -> Dictionary:
	return {
		"success": true,
		"data": data,
		"message": message
	}


func _failure(error_type: String, message: String, data = {}) -> Dictionary:
	var result := {
		"success": false,
		"error": error_type,
		"message": message
	}
	if data is Dictionary and not (data as Dictionary).is_empty():
		result["data"] = data
	return result
