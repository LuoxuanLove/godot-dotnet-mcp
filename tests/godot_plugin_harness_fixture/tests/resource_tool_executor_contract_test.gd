extends RefCounted

const ResourceExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/resource/executor.gd")

const TEMP_ROOT := "res://Tmp/godot_dotnet_mcp_resource_contracts"
const MATERIAL_PATH := "res://Tmp/godot_dotnet_mcp_resource_contracts/materials/contract_material.tres"
const MATERIAL_COPY_PATH := "res://Tmp/godot_dotnet_mcp_resource_contracts/materials/contract_material_copy.tres"
const MATERIAL_MOVED_PATH := "res://Tmp/godot_dotnet_mcp_resource_contracts/materials/contract_material_moved.tres"
const TEXTURE_PATH := "res://Tmp/godot_dotnet_mcp_resource_contracts/textures/contract_texture.png"

var _scene_root: Node2D = null


func run_case(tree: SceneTree) -> Dictionary:
	var executor = ResourceExecutorScript.new()
	_scene_root = _build_scene_fixture(tree)
	executor.configure_context({"scene_root": _scene_root})

	if ResourceLoader.exists("res://addons/godot_dotnet_mcp/tools/resource_tools.gd"):
		return _failure("resource_tools.gd should be removed once the split executor becomes the only stable entry.")

	_remove_tree(TEMP_ROOT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 4:
		return _failure("Resource executor should expose 4 tool definitions after the split.")

	var expected_names := ["query", "create", "file_ops", "texture"]
	var actual_names: Array[String] = []
	for tool_def in tool_defs:
		actual_names.append(str(tool_def.get("name", "")))
	for expected_name in expected_names:
		if not actual_names.has(expected_name):
			return _failure("Resource executor is missing tool definition '%s'." % expected_name)

	var create_result: Dictionary = executor.execute("create", {
		"type": "StandardMaterial3D",
		"path": MATERIAL_PATH
	})
	if not bool(create_result.get("success", false)):
		return _failure("Resource create failed through the split create service.")

	var info_result: Dictionary = executor.execute("query", {
		"action": "get_info",
		"path": MATERIAL_PATH
	})
	if not bool(info_result.get("success", false)):
		return _failure("Resource query get_info failed through the split query service.")

	var list_result: Dictionary = executor.execute("query", {
		"action": "list",
		"path": TEMP_ROOT,
		"recursive": true
	})
	if not bool(list_result.get("success", false)):
		return _failure("Resource query list failed through the split query service.")

	var search_result: Dictionary = executor.execute("query", {
		"action": "search",
		"pattern": "*contract_material*",
		"recursive": true
	})
	if not bool(search_result.get("success", false)):
		return _failure("Resource query search failed through the split query service.")

	var dependency_result: Dictionary = executor.execute("query", {
		"action": "get_dependencies",
		"path": MATERIAL_PATH
	})
	if not bool(dependency_result.get("success", false)):
		return _failure("Resource query get_dependencies failed through the split query service.")

	var copy_result: Dictionary = executor.execute("file_ops", {
		"action": "copy",
		"source": MATERIAL_PATH,
		"dest": MATERIAL_COPY_PATH
	})
	if not bool(copy_result.get("success", false)):
		return _failure("Resource copy failed through the split file ops service.")

	var move_result: Dictionary = executor.execute("file_ops", {
		"action": "move",
		"source": MATERIAL_COPY_PATH,
		"dest": MATERIAL_MOVED_PATH
	})
	if not bool(move_result.get("success", false)):
		return _failure("Resource move failed through the split file ops service.")

	var reload_result: Dictionary = executor.execute("file_ops", {
		"action": "reload",
		"path": MATERIAL_MOVED_PATH
	})
	if not bool(reload_result.get("success", false)):
		return _failure("Resource reload failed through the split file ops service.")

	var delete_result: Dictionary = executor.execute("file_ops", {
		"action": "delete",
		"path": MATERIAL_MOVED_PATH
	})
	if not bool(delete_result.get("success", false)):
		return _failure("Resource delete failed through the split file ops service.")

	if not _create_test_texture(TEXTURE_PATH):
		return _failure("Failed to create a texture fixture for the split texture service.")

	var texture_info_result: Dictionary = executor.execute("texture", {
		"action": "get_info",
		"path": TEXTURE_PATH
	})
	if not bool(texture_info_result.get("success", false)):
		return _failure("Texture get_info failed through the split texture service.")

	var texture_list_result: Dictionary = executor.execute("texture", {
		"action": "list_all"
	})
	if not bool(texture_list_result.get("success", false)):
		return _failure("Texture list_all failed through the split texture service.")

	var assign_result: Dictionary = executor.execute("texture", {
		"action": "assign_to_node",
		"texture_path": TEXTURE_PATH,
		"node_path": "SpriteNode",
		"property": "texture"
	})
	if not bool(assign_result.get("success", false)):
		return _failure("Texture assign_to_node failed through the split texture service.")

	var invalid_assign_result: Dictionary = executor.execute("texture", {
		"action": "assign_to_node",
		"texture_path": TEXTURE_PATH,
		"node_path": "SpriteNode",
		"property": "missing_property"
	})
	if bool(invalid_assign_result.get("success", false)):
		return _failure("Texture assign_to_node should fail for an invalid property.")

	return {
		"name": "resource_tool_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"list_count": int(list_result.get("data", {}).get("count", 0)),
			"search_count": int(search_result.get("data", {}).get("count", 0)),
			"texture_width": int(texture_info_result.get("data", {}).get("width", 0)),
			"texture_list_count": int(texture_list_result.get("data", {}).get("count", 0))
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	_remove_tree(TEMP_ROOT)
	if _scene_root != null:
		if _scene_root.get_parent() != null:
			_scene_root.get_parent().remove_child(_scene_root)
		_scene_root.queue_free()
		_scene_root = null
		await tree.process_frame


func _build_scene_fixture(tree: SceneTree) -> Node2D:
	var root := Node2D.new()
	root.name = "ResourceToolExecutorContracts"
	var sprite := Sprite2D.new()
	sprite.name = "SpriteNode"
	root.add_child(sprite)
	tree.root.add_child(root)
	return root


func _create_test_texture(path: String) -> bool:
	var absolute_dir := ProjectSettings.globalize_path(path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.3, 0.6, 0.9, 1.0))
	return image.save_png(ProjectSettings.globalize_path(path)) == OK


func _remove_tree(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	_remove_tree_absolute(absolute_path)


func _remove_tree_absolute(absolute_path: String) -> void:
	var dir = DirAccess.open(absolute_path)
	if dir == null:
		DirAccess.remove_absolute(absolute_path)
		return

	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child_path := absolute_path.path_join(entry)
			if dir.current_is_dir():
				_remove_tree_absolute(child_path)
			else:
				DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _failure(message: String) -> Dictionary:
	return {
		"name": "resource_tool_executor_contracts",
		"success": false,
		"error": message
	}
