@tool
extends RefCounted
class_name MCPRuntimeCommandService

var _get_tree := Callable()
var _get_viewport := Callable()
var _get_current_scene_path := Callable()
var _build_runtime_state := Callable()
var _capture_root_dir := "user://godot_mcp_runtime_captures"
var _max_capture_files_per_session := 24
var _capture_files_by_session: Dictionary = {}


func configure(callbacks: Dictionary = {}, options: Dictionary = {}) -> void:
	_get_tree = callbacks.get("get_tree", Callable())
	_get_viewport = callbacks.get("get_viewport", Callable())
	_get_current_scene_path = callbacks.get("get_current_scene_path", Callable())
	_build_runtime_state = callbacks.get("build_runtime_state", Callable())
	_capture_root_dir = str(options.get("capture_root_dir", _capture_root_dir))
	_max_capture_files_per_session = maxi(int(options.get("max_capture_files_per_session", _max_capture_files_per_session)), 1)


func execute_action_async(session_id: int, action: String, args: Dictionary) -> Dictionary:
	match action:
		"status":
			return _success({
				"runtime_state": _build_runtime_state_safe(session_id)
			}, "Runtime bridge ready")
		"capture":
			return await _capture_async(session_id, args)
		"input":
			return await _apply_inputs_async(session_id, args)
		"step":
			return await _run_step_async(session_id, args)
		_:
			return _failure("invalid_argument", "Unknown runtime action: %s" % action)


func dispose() -> void:
	_cleanup_tracked_capture_files()
	_capture_files_by_session.clear()
	_get_tree = Callable()
	_get_viewport = Callable()
	_get_current_scene_path = Callable()
	_build_runtime_state = Callable()


func _capture_async(session_id: int, args: Dictionary) -> Dictionary:
	var frame_count := int(args.get("frame_count", 1))
	var interval_frames := int(args.get("interval_frames", 1))
	if frame_count <= 0:
		return _failure("invalid_argument", "frame_count must be greater than 0.")
	if interval_frames < 0:
		return _failure("invalid_argument", "interval_frames must be 0 or greater.")
	if frame_count <= 1:
		return await _capture_single_frame_async(session_id, args)

	var frames: Array[Dictionary] = []
	for index in range(frame_count):
		if index > 0 and interval_frames > 0:
			await _await_process_frames(interval_frames)
		var frame_result: Dictionary = await _capture_single_frame_async(session_id, args)
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
		"runtime_state": frames[-1].get("runtime_state", {}) if not frames.is_empty() else _build_runtime_state_safe(session_id)
	}, "Runtime capture sequence completed")


func _capture_single_frame_async(session_id: int, args: Dictionary) -> Dictionary:
	var include_runtime_state := bool(args.get("include_runtime_state", true))
	var capture_label := str(args.get("capture_label", ""))
	await _await_capture_ready()
	var viewport = _get_viewport_safe()
	if viewport == null:
		return _failure("runtime_capture_failed", "Viewport is unavailable.")
	var texture = viewport.get_texture()
	if texture == null:
		return _failure("runtime_capture_failed", "Viewport texture is unavailable.")
	var image = texture.get_image()
	if image == null or image.is_empty():
		return _failure("runtime_capture_failed", "Viewport image is unavailable.")

	var session_key := _session_key(session_id)
	var capture_dir := "%s/%s" % [_capture_root_dir, session_key]
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
	var save_error = image.save_png(absolute_path)
	if save_error != OK:
		return _failure("runtime_capture_failed", "Failed to save runtime capture.", {
			"error_code": save_error,
			"file_path": absolute_path
		})

	_track_capture_file(session_key, absolute_path)
	var runtime_state := _build_runtime_state_safe(session_id) if include_runtime_state else {}
	return _success({
		"file_path": absolute_path,
		"user_path": user_path,
		"width": image.get_width(),
		"height": image.get_height(),
		"scene": _get_current_scene_path_safe(),
		"session_id": session_id,
		"captured_at": Time.get_datetime_string_from_system(true, true),
		"runtime_state": runtime_state
	}, "Runtime frame captured")


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
		"runtime_state": _build_runtime_state_safe(session_id)
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
		var capture_result: Dictionary = await _capture_single_frame_async(session_id, args)
		if not bool(capture_result.get("success", false)):
			return capture_result
		frame = capture_result.get("data", {})
	var step_data := {
		"inputs": applied_inputs,
		"wait_frames": wait_frames,
		"capture": capture,
		"frame": frame,
		"runtime_state": frame.get("runtime_state", _build_runtime_state_safe(session_id)) if frame is Dictionary else _build_runtime_state_safe(session_id)
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
	var tree = _get_tree_safe()
	if tree == null:
		return
	for _index in range(maxi(frame_count, 0)):
		await tree.process_frame


func _await_duration_ms(duration_ms: int) -> void:
	var tree = _get_tree_safe()
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


func _track_capture_file(session_key: String, absolute_path: String) -> void:
	var files: Array = _capture_files_by_session.get(session_key, [])
	files.append(absolute_path)
	while files.size() > _max_capture_files_per_session:
		var stale_path := str(files[0])
		files.remove_at(0)
		if FileAccess.file_exists(stale_path):
			DirAccess.remove_absolute(stale_path)
	_capture_files_by_session[session_key] = files


func _cleanup_tracked_capture_files() -> void:
	var directories: Dictionary = {}
	for session_key in _capture_files_by_session.keys():
		var files = _capture_files_by_session.get(session_key, [])
		if not (files is Array):
			continue
		for raw_path in files:
			var absolute_path := str(raw_path)
			if absolute_path.is_empty():
				continue
			directories[absolute_path.get_base_dir()] = true
			if FileAccess.file_exists(absolute_path):
				DirAccess.remove_absolute(absolute_path)
	for directory_path in directories.keys():
		_remove_directory_if_empty(str(directory_path))
	_remove_directory_if_empty(ProjectSettings.globalize_path(_capture_root_dir))


func _remove_directory_if_empty(path: String) -> void:
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	while true:
		var entry := directory.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."]:
			continue
		directory.list_dir_end()
		return
	directory.list_dir_end()
	DirAccess.remove_absolute(path)

func _get_tree_safe():
	if _get_tree.is_valid():
		return _get_tree.call()
	return null


func _get_viewport_safe():
	if _get_viewport.is_valid():
		return _get_viewport.call()
	return null


func _get_current_scene_path_safe() -> String:
	if _get_current_scene_path.is_valid():
		return str(_get_current_scene_path.call())
	return ""


func _build_runtime_state_safe(session_id: int) -> Dictionary:
	if _build_runtime_state.is_valid():
		var state = _build_runtime_state.call(session_id)
		if state is Dictionary:
			return (state as Dictionary).duplicate(true)
	return {
		"running": true,
		"scene": _get_current_scene_path_safe(),
		"session_id": session_id
	}


func _session_key(session_id: int) -> String:
	return str(session_id) if session_id >= 0 else "unknown"


func _sanitize_capture_label(label: String) -> String:
	var sanitized := label.strip_edges().replace(" ", "_")
	for invalid_char in ["\\", "/", ":", "*", "?", "\"", "<", ">", "|"]:
		sanitized = sanitized.replace(invalid_char, "_")
	return sanitized.substr(0, mini(sanitized.length(), 32))


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
