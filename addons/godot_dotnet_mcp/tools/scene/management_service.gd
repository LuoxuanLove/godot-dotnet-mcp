@tool
extends "res://addons/godot_dotnet_mcp/tools/scene/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	match action:
		"get_current":
			return _get_current_scene()
		"open":
			return _open_scene(str(args.get("path", "")))
		"save":
			return _save_scene()
		"save_as":
			return _save_scene_as(str(args.get("path", "")))
		"create":
			return _create_scene(str(args.get("root_type", "Node")), str(args.get("name", "NewScene")))
		"close":
			return _close_scene()
		"reload":
			return _reload_scene()
		_:
			return _error("Unknown action: %s" % action)


func _get_current_scene() -> Dictionary:
	var root := _get_active_root()
	if root == null:
		return _success({
			"open": false,
			"message": "No scene currently open"
		})

	return _success({
		"open": true,
		"path": _get_active_scene_path(),
		"name": str(root.name),
		"root_type": str(root.get_class()),
		"node_count": _count_nodes(root)
	})


func _open_scene(path: String) -> Dictionary:
	var normalized := _normalize_res_path(path)
	if normalized.is_empty():
		return _error("Path is required")
	if not FileAccess.file_exists(normalized):
		return _error("Scene file not found: %s" % normalized)

	var editor_interface = _get_active_editor_interface()
	if editor_interface == null:
		return _error("Editor interface not available")

	editor_interface.open_scene_from_path(normalized)
	return _success({"path": normalized}, "Scene opened: %s" % normalized)


func _save_scene() -> Dictionary:
	var editor_interface = _get_active_editor_interface()
	if editor_interface == null:
		return _error("Editor interface not available")

	var root := _get_active_root()
	if root == null:
		return _error("No scene to save")

	var error = editor_interface.save_scene()
	if error != OK:
		return _error("Failed to save scene: %s" % error_string(error))

	return _success({"path": _get_active_scene_path()}, "Scene saved")


func _save_scene_as(path: String) -> Dictionary:
	var normalized := _normalize_res_path(path)
	if normalized.is_empty():
		return _error("Path is required")
	if not normalized.ends_with(".tscn"):
		normalized += ".tscn"

	var root := _get_active_root()
	if root == null:
		return _error("No scene to save")

	var previous_path := _get_active_scene_path()
	var packed_scene := PackedScene.new()
	packed_scene.pack(root)
	_ensure_res_directory(normalized.get_base_dir())
	var error = ResourceSaver.save(packed_scene, normalized)
	if error != OK:
		return _error("Failed to save scene: %s" % error_string(error))

	var editor_interface = _get_active_editor_interface()
	if editor_interface == null:
		return _error("Editor interface not available")

	editor_interface.open_scene_from_path(normalized)
	if _is_plugin_temp_scene_path(previous_path) and previous_path != normalized:
		_remove_resource_file(previous_path)

	return _success({"path": normalized}, "Scene saved as: %s" % normalized)


func _create_scene(root_type: String, scene_name: String) -> Dictionary:
	var editor_interface = _get_active_editor_interface()
	if editor_interface == null:
		return _error("Editor interface not available")

	var root: Node = null
	match root_type:
		"Node":
			root = Node.new()
		"Node2D":
			root = Node2D.new()
		"Node3D":
			root = Node3D.new()
		"Control":
			root = Control.new()
		"CanvasLayer":
			root = CanvasLayer.new()
		_:
			return _error("Unknown root type: %s" % root_type)

	root.name = scene_name
	var packed_scene := PackedScene.new()
	packed_scene.pack(root)

	var temp_path := _build_temp_scene_path(scene_name)
	_ensure_res_directory(TEMP_SCENE_DIR)
	var error = ResourceSaver.save(packed_scene, temp_path)
	if error != OK:
		root.free()
		return _error("Failed to create scene: %s" % error_string(error))

	root.free()
	editor_interface.open_scene_from_path(temp_path)

	return _success({
		"path": temp_path,
		"root_type": root_type,
		"name": scene_name
	}, "Scene created: %s" % temp_path)


func _close_scene() -> Dictionary:
	return _error("Close scene is not exposed by the editor API. Use File > Close Scene in the editor.")


func _reload_scene() -> Dictionary:
	var root := _get_active_root()
	if root == null:
		return _error("No scene to reload")

	var path := _get_active_scene_path()
	if path.is_empty():
		return _error("Scene has not been saved yet")

	var editor_interface = _get_active_editor_interface()
	if editor_interface == null:
		return _error("Editor interface not available")

	editor_interface.reload_scene_from_path(path)
	return _success({"path": path}, "Scene reloaded: %s" % path)


func _build_temp_scene_path(scene_name: String) -> String:
	var slug := scene_name.to_lower().replace(" ", "_")
	if slug.is_empty():
		slug = "new_scene"
	return "%s/%s_%d.tscn" % [TEMP_SCENE_DIR, slug, Time.get_unix_time_from_system()]


func _ensure_res_directory(path: String) -> void:
	if path.is_empty():
		return
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		DirAccess.make_dir_recursive_absolute(absolute_path)


func _is_plugin_temp_scene_path(path: String) -> bool:
	return not path.is_empty() and path.begins_with(TEMP_SCENE_DIR + "/")


func _remove_resource_file(path: String) -> void:
	if path.is_empty():
		return
	var normalized := _normalize_res_path(path)
	if normalized.is_empty():
		return
	var absolute_path := ProjectSettings.globalize_path(normalized)
	if FileAccess.file_exists(normalized):
		DirAccess.remove_absolute(absolute_path)
