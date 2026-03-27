extends RefCounted

const MaterialExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/material/executor.gd")

const TEMP_ROOT := "res://Tmp/godot_dotnet_mcp_material_contracts"
const MATERIAL_PATH := "res://Tmp/godot_dotnet_mcp_material_contracts/contract_material.tres"
const DUPLICATE_PATH := "res://Tmp/godot_dotnet_mcp_material_contracts/contract_material_copy.tres"

var _scene_root: Node3D = null


func run_case(tree: SceneTree) -> Dictionary:
	var executor = MaterialExecutorScript.new()
	_scene_root = _build_scene_fixture(tree)
	executor.configure_context({"scene_root": _scene_root})

	if ResourceLoader.exists("res://addons/godot_dotnet_mcp/tools/material_tools.gd"):
		return _failure("material_tools.gd should be removed once the split executor becomes the only stable entry.")

	_remove_tree(TEMP_ROOT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 2:
		return _failure("Material executor should expose 2 tool definitions after the split.")

	var expected_names := ["material", "mesh"]
	var actual_names: Array[String] = []
	for tool_def in tool_defs:
		actual_names.append(str(tool_def.get("name", "")))
	for expected_name in expected_names:
		if not actual_names.has(expected_name):
			return _failure("Material executor is missing tool definition '%s'." % expected_name)

	var create_result: Dictionary = executor.execute("material", {
		"action": "create",
		"type": "StandardMaterial3D",
		"name": "ContractMaterial",
		"save_path": MATERIAL_PATH
	})
	if not bool(create_result.get("success", false)):
		return _failure("Material create failed through the split material service.")

	var set_result: Dictionary = executor.execute("material", {
		"action": "set_property",
		"path": MATERIAL_PATH,
		"property": "metallic",
		"value": 0.9
	})
	if not bool(set_result.get("success", false)):
		return _failure("Material set_property failed through the split parameter service.")

	var save_result: Dictionary = executor.execute("material", {
		"action": "save",
		"path": MATERIAL_PATH
	})
	if not bool(save_result.get("success", false)):
		return _failure("Material save failed through the split material service.")

	var get_result: Dictionary = executor.execute("material", {
		"action": "get_property",
		"path": MATERIAL_PATH,
		"property": "metallic"
	})
	if not bool(get_result.get("success", false)):
		return _failure("Material get_property failed through the split parameter service.")
	if str(get_result.get("data", {}).get("property", "")) != "metallic":
		return _failure("Material get_property returned an unexpected property payload.")

	var list_result: Dictionary = executor.execute("material", {
		"action": "list_properties",
		"path": MATERIAL_PATH
	})
	if not bool(list_result.get("success", false)):
		return _failure("Material list_properties failed through the split parameter service.")
	var list_properties: Array = list_result.get("data", {}).get("properties", [])
	var has_metallic := false
	for property_info in list_properties:
		if str(property_info.get("name", "")) == "metallic":
			has_metallic = true
			break
	if not has_metallic:
		return _failure("Material list_properties did not surface the metallic property after split.")

	var primitive_result: Dictionary = executor.execute("mesh", {
		"action": "create_primitive",
		"type": "box",
		"size": {"x": 1.0, "y": 2.0, "z": 3.0},
		"node_path": "MeshNode"
	})
	if not bool(primitive_result.get("success", false)):
		return _failure("Mesh create_primitive failed through the split mesh service.")

	var assign_result: Dictionary = executor.execute("material", {
		"action": "assign_to_node",
		"material_path": MATERIAL_PATH,
		"node_path": "MeshNode",
		"surface": 0
	})
	if not bool(assign_result.get("success", false)):
		return _failure("Material assign_to_node failed through the split material service.")

	var surface_result: Dictionary = executor.execute("mesh", {
		"action": "get_surface_material",
		"path": "MeshNode",
		"surface": 0
	})
	if not bool(surface_result.get("success", false)):
		return _failure("Mesh get_surface_material failed through the split mesh service.")
	if str(surface_result.get("data", {}).get("material", {}).get("type", "")) != "StandardMaterial3D":
		return _failure("Mesh get_surface_material returned unexpected material type.")

	var mesh_info_result: Dictionary = executor.execute("mesh", {
		"action": "get_info",
		"path": "MeshNode"
	})
	if not bool(mesh_info_result.get("success", false)):
		return _failure("Mesh get_info failed through the split mesh service.")

	var aabb_result: Dictionary = executor.execute("mesh", {
		"action": "get_aabb",
		"path": "MeshNode"
	})
	if not bool(aabb_result.get("success", false)):
		return _failure("Mesh get_aabb failed through the split mesh service.")

	var duplicate_result: Dictionary = executor.execute("material", {
		"action": "duplicate",
		"path": MATERIAL_PATH,
		"save_path": DUPLICATE_PATH
	})
	if not bool(duplicate_result.get("success", false)):
		return _failure("Material duplicate failed through the split material service.")

	return {
		"name": "material_tool_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"material_path": MATERIAL_PATH,
			"duplicate_path": DUPLICATE_PATH,
			"surface_material_type": str(surface_result.get("data", {}).get("material", {}).get("type", "")),
			"property_count": int(list_result.get("data", {}).get("count", 0))
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


func _build_scene_fixture(tree: SceneTree) -> Node3D:
	var root := Node3D.new()
	root.name = "MaterialToolExecutorContracts"
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "MeshNode"
	root.add_child(mesh_node)
	tree.root.add_child(root)
	return root


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
		"name": "material_tool_executor_contracts",
		"success": false,
		"error": message
	}
