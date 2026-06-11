extends RefCounted

const RuntimeCommandServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_command_service.gd")
const CUSTOM_CAPTURE_DIR := "user://contract_runtime_command_captures"


class FakeTexture extends RefCounted:
	var image: Image
	var get_image_call_count := 0

	func _init(source_image: Image) -> void:
		image = source_image

	func get_image() -> Image:
		get_image_call_count += 1
		return image


class FakeViewport extends RefCounted:
	var texture: FakeTexture

	func _init(source_texture: FakeTexture) -> void:
		texture = source_texture

	func get_texture() -> FakeTexture:
		return texture


var _service = RuntimeCommandServiceScript.new()
var _tree: SceneTree
var _viewport: FakeViewport
var _input_events: Array[InputEvent] = []


func run_case(tree: SceneTree) -> Dictionary:
	_tree = tree
	_cleanup_capture_dir()
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.4, 0.6, 1.0))
	_viewport = FakeViewport.new(FakeTexture.new(image))
	_service.configure(
		Callable(self, "_get_tree"),
		Callable(self, "_get_viewport"),
		Callable(self, "_get_current_scene_path"),
		Callable(self, "_build_runtime_state"),
		CUSTOM_CAPTURE_DIR,
		24,
		Callable(self, "_record_input_event")
	)
	_service._get_capture_availability = Callable(self, "_capture_available")

	var capture_result: Dictionary = await _service.execute_action_async(5, "capture", {
		"capture_dir": CUSTOM_CAPTURE_DIR,
		"capture_label": "custom-dir",
		"include_runtime_state": true
	})
	if not bool(capture_result.get("success", false)):
		return _failure("Runtime command service custom capture_dir request failed: %s" % str(capture_result))
	var data = capture_result.get("data", {})
	if not (data is Dictionary):
		return _failure("Runtime command service capture did not return a dictionary payload.")
	var capture_data: Dictionary = data
	var user_path := str(capture_data.get("user_path", ""))
	if not user_path.begins_with(CUSTOM_CAPTURE_DIR + "/"):
		return _failure("Runtime command service did not save into the requested capture_dir: %s" % user_path)
	var file_path := str(capture_data.get("file_path", ""))
	if file_path.is_empty() or not FileAccess.file_exists(file_path):
		return _failure("Runtime command service did not write a capture file at the reported file_path.")
	if str(capture_data.get("runtime_state", {}).get("session_id", "")) != "5":
		return _failure("Runtime command service did not preserve runtime_state for custom capture_dir captures.")
	if int(_viewport.texture.get_image_call_count) != 1:
		return _failure("Runtime command service should read the viewport image when capture is available.")

	_viewport = FakeViewport.new(FakeTexture.new(image))
	_service.configure(
		Callable(self, "_get_tree"),
		Callable(self, "_get_viewport"),
		Callable(self, "_get_current_scene_path"),
		Callable(self, "_build_runtime_state"),
		CUSTOM_CAPTURE_DIR,
		24,
		Callable(self, "_record_input_event")
	)
	_service._get_capture_availability = Callable(self, "_capture_headless_unavailable")
	var skipped_result: Dictionary = await _service.execute_action_async(5, "capture", {
		"include_runtime_state": true
	})
	if not bool(skipped_result.get("success", false)):
		return _failure("Runtime command service should return success for structured headless capture skips.")
	var skipped_data = skipped_result.get("data", {})
	if not (skipped_data is Dictionary) or not bool((skipped_data as Dictionary).get("skipped", false)):
		return _failure("Runtime command service headless capture skip should return skipped=true.")
	if str((skipped_data as Dictionary).get("skip_reason", "")) != "skipped_headless":
		return _failure("Runtime command service headless capture skip should expose skipped_headless.")
	if bool((skipped_data as Dictionary).get("capture_available", true)):
		return _failure("Runtime command service headless capture skip should expose capture_available=false.")
	if not ((skipped_data as Dictionary).get("capture_context", {}) is Dictionary):
		return _failure("Runtime command service headless capture skip should include capture_context.")
	if int(_viewport.texture.get_image_call_count) != 0:
		return _failure("Runtime command service should skip before reading viewport images when capture is unavailable.")

	_input_events.clear()
	var mouse_input_result: Dictionary = await _service.execute_action_async(5, "input", {
		"inputs": [
			{"kind": "mouse", "op": "move", "position": {"x": 24, "y": 36}},
			{"kind": "mouse", "button": "left", "op": "click", "x": 24, "y": 36, "duration_ms": 1}
		]
	})
	if not bool(mouse_input_result.get("success", false)):
		return _failure("Runtime command service mouse input request failed: %s" % str(mouse_input_result))
	if _input_events.size() != 3:
		return _failure("Runtime mouse input should dispatch one motion event and two button events.")
	if not (_input_events[0] is InputEventMouseMotion) or Vector2((_input_events[0] as InputEventMouseMotion).position) != Vector2(24, 36):
		return _failure("Runtime mouse move should dispatch a motion event at the requested position.")
	if not (_input_events[1] is InputEventMouseButton) or not bool((_input_events[1] as InputEventMouseButton).pressed):
		return _failure("Runtime mouse click should dispatch a pressed mouse button event.")
	if not (_input_events[2] is InputEventMouseButton) or bool((_input_events[2] as InputEventMouseButton).pressed):
		return _failure("Runtime mouse click should dispatch a released mouse button event.")
	if int((_input_events[1] as InputEventMouseButton).button_index) != MOUSE_BUTTON_LEFT:
		return _failure("Runtime mouse click should preserve the requested mouse button.")
	if Vector2((_input_events[1] as InputEventMouseButton).position) != Vector2(24, 36):
		return _failure("Runtime mouse click should preserve the requested position.")
	var mouse_input_data = mouse_input_result.get("data", {})
	if not (mouse_input_data is Dictionary) or int(((mouse_input_data as Dictionary).get("inputs", []) as Array).size()) != 2:
		return _failure("Runtime mouse input should report both executed entries.")

	var missing_position_result: Dictionary = await _service.execute_action_async(5, "input", {
		"inputs": [{"kind": "mouse", "target": "left", "op": "click"}]
	})
	if str(missing_position_result.get("error", "")) != "invalid_argument":
		return _failure("Runtime mouse input should reject missing positions.")
	var invalid_button_result: Dictionary = await _service.execute_action_async(5, "input", {
		"inputs": [{"kind": "mouse", "button": "unknown", "op": "click", "x": 1, "y": 2}]
	})
	if str(invalid_button_result.get("error", "")) != "invalid_argument":
		return _failure("Runtime mouse input should reject unknown mouse buttons.")

	return {
		"name": "runtime_command_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"user_path": user_path,
			"width": int(capture_data.get("width", 0)),
			"height": int(capture_data.get("height", 0)),
			"mouse_events": _input_events.size(),
			"skip_reason": str((skipped_data as Dictionary).get("skip_reason", ""))
		}
	}


func cleanup_case(_tree_arg: SceneTree) -> void:
	if _service != null and _service.has_method("dispose"):
		_service.dispose()
	_cleanup_capture_dir()
	_tree = null
	_viewport = null
	_input_events.clear()


func _get_tree() -> SceneTree:
	return _tree


func _get_viewport():
	return _viewport


func _get_current_scene_path() -> String:
	return "res://ContractScene.tscn"


func _build_runtime_state(session_id: int) -> Dictionary:
	return {
		"running": true,
		"session_id": session_id,
		"scene": _get_current_scene_path()
	}


func _record_input_event(event: InputEvent) -> void:
	_input_events.append(event)


func _capture_available() -> Dictionary:
	return {
		"available": true,
		"headless": false,
		"display_server": "contract-visible"
	}


func _capture_headless_unavailable() -> Dictionary:
	return {
		"available": false,
		"skip_reason": "skipped_headless",
		"headless": true,
		"display_server": "headless",
		"hint": "Runtime screenshots require a visible rendering backend."
	}


func _cleanup_capture_dir() -> void:
	var absolute_dir := ProjectSettings.globalize_path(CUSTOM_CAPTURE_DIR)
	if not DirAccess.dir_exists_absolute(absolute_dir):
		return
	var directory := DirAccess.open(absolute_dir)
	if directory != null:
		directory.list_dir_begin()
		while true:
			var entry := directory.get_next()
			if entry.is_empty():
				break
			if entry in [".", ".."]:
				continue
			DirAccess.remove_absolute("%s/%s" % [absolute_dir, entry])
		directory.list_dir_end()
	DirAccess.remove_absolute(absolute_dir)


func _failure(message: String) -> Dictionary:
	return {
		"name": "runtime_command_service_contracts",
		"success": false,
		"error": message
	}
