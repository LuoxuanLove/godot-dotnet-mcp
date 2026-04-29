extends RefCounted

const RuntimeCommandServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_command_service.gd")
const CUSTOM_CAPTURE_DIR := "user://contract_runtime_command_captures"


class FakeTexture extends RefCounted:
	var image: Image

	func _init(source_image: Image) -> void:
		image = source_image

	func get_image() -> Image:
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
		Callable(self, "_build_runtime_state")
	)

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

	return {
		"name": "runtime_command_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"user_path": user_path,
			"width": int(capture_data.get("width", 0)),
			"height": int(capture_data.get("height", 0))
		}
	}


func cleanup_case(_tree_arg: SceneTree) -> void:
	if _service != null and _service.has_method("dispose"):
		_service.dispose()
	_cleanup_capture_dir()
	_tree = null
	_viewport = null


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
