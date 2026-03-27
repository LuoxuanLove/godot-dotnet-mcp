extends RefCounted

const GeometryExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/geometry/executor.gd")

var _scene_root: Node3D = null


func run_case(tree: SceneTree) -> Dictionary:
	var executor = GeometryExecutorScript.new()
	_scene_root = _build_scene_fixture(tree)
	executor.configure_context({"scene_root": _scene_root})

	if ResourceLoader.exists("res://addons/godot_dotnet_mcp/tools/geometry_tools.gd"):
		return _failure("geometry_tools.gd should be removed once the split executor becomes the only stable entry.")

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 3:
		return _failure("Geometry executor should expose 3 tool definitions after the split.")

	var expected_names := ["csg", "gridmap", "multimesh"]
	var actual_names: Array[String] = []
	for tool_def in tool_defs:
		actual_names.append(str(tool_def.get("name", "")))
	for expected_name in expected_names:
		if not actual_names.has(expected_name):
			return _failure("Geometry executor is missing tool definition '%s'." % expected_name)

	var create_csg_result: Dictionary = executor.execute("csg", {
		"action": "create",
		"type": "csg_box_3d",
		"parent": ".",
		"name": "Brush"
	})
	if not bool(create_csg_result.get("success", false)):
		return _failure("CSG create failed through the split csg service.")

	var csg_path := str(create_csg_result.get("data", {}).get("path", ""))
	var set_size_result: Dictionary = executor.execute("csg", {
		"action": "set_size",
		"path": csg_path,
		"size": {"x": 2.0, "y": 1.5, "z": 3.0}
	})
	if not bool(set_size_result.get("success", false)):
		return _failure("CSG set_size failed through the split csg service.")

	var create_gridmap_result: Dictionary = executor.execute("gridmap", {
		"action": "create",
		"parent": ".",
		"name": "Grid"
	})
	if not bool(create_gridmap_result.get("success", false)):
		return _failure("GridMap create failed through the split gridmap service.")

	var gridmap_path := str(create_gridmap_result.get("data", {}).get("path", ""))
	var set_cell_result: Dictionary = executor.execute("gridmap", {
		"action": "set_cell",
		"path": gridmap_path,
		"x": 0,
		"y": 0,
		"z": 0,
		"item": 1
	})
	if not bool(set_cell_result.get("success", false)):
		return _failure("GridMap set_cell failed through the split gridmap service.")

	var get_cell_result: Dictionary = executor.execute("gridmap", {
		"action": "get_cell",
		"path": gridmap_path,
		"x": 0,
		"y": 0,
		"z": 0
	})
	if not bool(get_cell_result.get("success", false)):
		return _failure("GridMap get_cell failed through the split gridmap service.")

	var create_multimesh_result: Dictionary = executor.execute("multimesh", {
		"action": "create",
		"parent": ".",
		"name": "Foliage"
	})
	if not bool(create_multimesh_result.get("success", false)):
		return _failure("MultiMesh create failed through the split multimesh service.")

	var multimesh_path := str(create_multimesh_result.get("data", {}).get("path", ""))
	var set_count_result: Dictionary = executor.execute("multimesh", {
		"action": "set_instance_count",
		"path": multimesh_path,
		"count": 2,
		"use_colors": false
	})
	if not bool(set_count_result.get("success", false)):
		return _failure("MultiMesh set_instance_count failed through the split multimesh service.")

	var get_info_result: Dictionary = executor.execute("multimesh", {
		"action": "get_info",
		"path": multimesh_path
	})
	if not bool(get_info_result.get("success", false)):
		return _failure("MultiMesh get_info failed through the split multimesh service.")

	return {
		"name": "geometry_tool_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"csg_path": csg_path,
			"gridmap_path": gridmap_path,
			"multimesh_path": multimesh_path,
			"instance_count": int(get_info_result.get("data", {}).get("instance_count", 0))
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	if _scene_root != null:
		if _scene_root.get_parent() != null:
			_scene_root.get_parent().remove_child(_scene_root)
		_scene_root.queue_free()
		_scene_root = null
		await tree.process_frame


func _build_scene_fixture(tree: SceneTree) -> Node3D:
	var root := Node3D.new()
	root.name = "GeometryToolExecutorContracts"
	tree.root.add_child(root)
	return root


func _failure(message: String) -> Dictionary:
	return {
		"name": "geometry_tool_executor_contracts",
		"success": false,
		"error": message
	}
