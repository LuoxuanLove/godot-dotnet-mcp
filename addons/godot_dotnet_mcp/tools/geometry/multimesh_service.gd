@tool
extends "res://addons/godot_dotnet_mcp/tools/geometry/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")

	match action:
		"create":
			return _create_multimesh(args)
		"get_info":
			return _get_multimesh_info(args.get("path", ""))
		"set_mesh":
			return _set_multimesh_mesh(args.get("path", ""), args.get("mesh", ""))
		"set_instance_count":
			return _set_instance_count(args.get("path", ""), args.get("count", 0), args.get("use_colors", false))
		"set_transform":
			return _set_instance_transform(args)
		"set_color":
			return _set_instance_color(args)
		"set_visible_count":
			return _set_visible_count(args.get("path", ""), args.get("count", -1))
		"populate_random":
			return _populate_random(args)
		"clear":
			return _clear_multimesh(args.get("path", ""))
		_:
			return _error("Unknown action: %s" % action)


func _create_multimesh(args: Dictionary) -> Dictionary:
	var parent_path = args.get("parent", "")
	var node_name = args.get("name", "MultiMeshInstance3D")
	if parent_path.is_empty():
		return _error("Parent path is required")

	var parent = _find_active_node(parent_path)
	if not parent:
		return _error("Parent not found: %s" % parent_path)

	var multi_instance = MultiMeshInstance3D.new()
	multi_instance.name = node_name

	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_instance.multimesh = multimesh

	parent.add_child(multi_instance)
	multi_instance.owner = _get_scene_owner()

	return _success({
		"path": _active_scene_path(multi_instance),
		"name": node_name
	}, "MultiMeshInstance3D created")


func _get_multimesh_info(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node or not node is MultiMeshInstance3D:
		return _error("MultiMeshInstance3D not found: %s" % path)
	if not node.multimesh:
		return _error("No MultiMesh assigned")

	var mm = node.multimesh
	return _success({
		"path": _active_scene_path(node),
		"instance_count": mm.instance_count,
		"visible_instance_count": mm.visible_instance_count,
		"has_mesh": mm.mesh != null,
		"use_colors": mm.use_colors,
		"use_custom_data": mm.use_custom_data,
		"transform_format": mm.transform_format
	})


func _set_multimesh_mesh(path: String, mesh_path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node or not node is MultiMeshInstance3D:
		return _error("MultiMeshInstance3D not found: %s" % path)

	if not node.multimesh:
		node.multimesh = MultiMesh.new()

	if mesh_path.is_empty():
		node.multimesh.mesh = null
	else:
		var mesh = load(mesh_path)
		if not mesh:
			return _error("Failed to load mesh: %s" % mesh_path)
		node.multimesh.mesh = mesh

	return _success({
		"path": _active_scene_path(node),
		"mesh": mesh_path
	}, "Mesh set")


func _set_instance_count(path: String, count: int, use_colors: bool) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node or not node is MultiMeshInstance3D:
		return _error("MultiMeshInstance3D not found: %s" % path)

	if not node.multimesh:
		node.multimesh = MultiMesh.new()

	node.multimesh.use_colors = use_colors
	node.multimesh.instance_count = count
	return _success({
		"path": _active_scene_path(node),
		"instance_count": count,
		"use_colors": use_colors
	}, "Instance count set")


func _set_instance_transform(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var index = args.get("index", 0)
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node or not node is MultiMeshInstance3D or not node.multimesh:
		return _error("MultiMeshInstance3D not found: %s" % path)

	var mm = node.multimesh
	if index < 0 or index >= mm.instance_count:
		return _error("Index out of range")

	var transform = Transform3D()
	if args.has("position"):
		var pos = args.get("position")
		transform.origin = Vector3(pos.get("x", 0), pos.get("y", 0), pos.get("z", 0))
	if args.has("rotation"):
		var rot = args.get("rotation")
		transform.basis = transform.basis.rotated(Vector3.RIGHT, deg_to_rad(rot.get("x", 0)))
		transform.basis = transform.basis.rotated(Vector3.UP, deg_to_rad(rot.get("y", 0)))
		transform.basis = transform.basis.rotated(Vector3.FORWARD, deg_to_rad(rot.get("z", 0)))
	if args.has("scale"):
		var scl = args.get("scale")
		transform.basis = transform.basis.scaled(Vector3(scl.get("x", 1), scl.get("y", 1), scl.get("z", 1)))

	mm.set_instance_transform(index, transform)
	return _success({
		"path": _active_scene_path(node),
		"index": index
	}, "Instance transform set")


func _set_instance_color(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var index = args.get("index", 0)
	var color_dict = args.get("color", {})
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node or not node is MultiMeshInstance3D or not node.multimesh:
		return _error("MultiMeshInstance3D not found: %s" % path)

	var mm = node.multimesh
	if not mm.use_colors:
		return _error("MultiMesh does not use colors. Set use_colors=true when setting instance count.")
	if index < 0 or index >= mm.instance_count:
		return _error("Index out of range")

	var color = Color(
		color_dict.get("r", 1),
		color_dict.get("g", 1),
		color_dict.get("b", 1),
		color_dict.get("a", 1)
	)
	mm.set_instance_color(index, color)

	return _success({
		"path": _active_scene_path(node),
		"index": index,
		"color": _serialize_value(color)
	}, "Instance color set")


func _set_visible_count(path: String, count: int) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node or not node is MultiMeshInstance3D or not node.multimesh:
		return _error("MultiMeshInstance3D not found: %s" % path)

	node.multimesh.visible_instance_count = count
	return _success({
		"path": _active_scene_path(node),
		"visible_instance_count": count
	}, "Visible count set")


func _populate_random(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var count = args.get("count", 10)
	var bounds = args.get("bounds", {})
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node or not node is MultiMeshInstance3D or not node.multimesh:
		return _error("MultiMeshInstance3D not found: %s" % path)

	var mm = node.multimesh
	mm.instance_count = count

	var min_bounds = bounds.get("min", {"x": -10, "y": 0, "z": -10})
	var max_bounds = bounds.get("max", {"x": 10, "y": 0, "z": 10})

	for i in count:
		var transform = Transform3D()
		transform.origin = Vector3(
			randf_range(min_bounds.get("x", -10), max_bounds.get("x", 10)),
			randf_range(min_bounds.get("y", 0), max_bounds.get("y", 0)),
			randf_range(min_bounds.get("z", -10), max_bounds.get("z", 10))
		)
		transform.basis = transform.basis.rotated(Vector3.UP, randf() * TAU)
		mm.set_instance_transform(i, transform)

	return _success({
		"path": _active_scene_path(node),
		"count": count,
		"bounds": bounds
	}, "Instances populated randomly")


func _clear_multimesh(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node or not node is MultiMeshInstance3D or not node.multimesh:
		return _error("MultiMeshInstance3D not found: %s" % path)

	node.multimesh.instance_count = 0
	return _success({"path": _active_scene_path(node)}, "MultiMesh cleared")
