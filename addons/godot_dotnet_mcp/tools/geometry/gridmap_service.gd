@tool
extends "res://addons/godot_dotnet_mcp/tools/geometry/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")

	match action:
		"create":
			return _create_gridmap(args)
		"get_info":
			return _get_gridmap_info(args.get("path", ""))
		"set_mesh_library":
			return _set_mesh_library(args.get("path", ""), args.get("library", ""))
		"get_cell":
			return _get_gridmap_cell(args.get("path", ""), args.get("x", 0), args.get("y", 0), args.get("z", 0))
		"set_cell":
			return _set_gridmap_cell(args)
		"erase_cell":
			return _erase_gridmap_cell(args.get("path", ""), args.get("x", 0), args.get("y", 0), args.get("z", 0))
		"clear":
			return _clear_gridmap(args.get("path", ""))
		"get_used_cells":
			return _get_used_cells(args.get("path", ""))
		"get_used_cells_by_item":
			return _get_used_cells_by_item(args.get("path", ""), args.get("item", 0))
		"set_cell_size":
			return _set_cell_size(args.get("path", ""), args.get("cell_size", {}))
		_:
			return _error("Unknown action: %s" % action)


func _create_gridmap(args: Dictionary) -> Dictionary:
	var parent_path = args.get("parent", "")
	var node_name = args.get("name", "GridMap")
	if parent_path.is_empty():
		return _error("Parent path is required")

	var parent = _find_active_node(parent_path)
	if not parent:
		return _error("Parent not found: %s" % parent_path)

	var gridmap = GridMap.new()
	gridmap.name = node_name
	parent.add_child(gridmap)
	gridmap.owner = _get_scene_owner()

	return _success({
		"path": _active_scene_path(gridmap),
		"name": node_name
	}, "GridMap created")


func _get_gridmap_info(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node or not node is GridMap:
		return _error("GridMap not found: %s" % path)

	return _success({
		"path": _active_scene_path(node),
		"cell_size": _serialize_value(node.cell_size),
		"cell_octant_size": node.cell_octant_size,
		"has_mesh_library": node.mesh_library != null,
		"used_cells_count": node.get_used_cells().size()
	})


func _set_mesh_library(path: String, library_path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node or not node is GridMap:
		return _error("GridMap not found: %s" % path)

	if library_path.is_empty():
		node.mesh_library = null
	else:
		var library = load(library_path)
		if not library or not library is MeshLibrary:
			return _error("Failed to load MeshLibrary: %s" % library_path)
		node.mesh_library = library

	return _success({
		"path": _active_scene_path(node),
		"library": library_path
	}, "MeshLibrary set")


func _get_gridmap_cell(path: String, x: int, y: int, z: int) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node or not node is GridMap:
		return _error("GridMap not found: %s" % path)

	var item = node.get_cell_item(Vector3i(x, y, z))
	var orientation = node.get_cell_item_orientation(Vector3i(x, y, z))
	return _success({
		"path": _active_scene_path(node),
		"position": {"x": x, "y": y, "z": z},
		"item": item,
		"orientation": orientation,
		"empty": item == GridMap.INVALID_CELL_ITEM
	})


func _set_gridmap_cell(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var x = args.get("x", 0)
	var y = args.get("y", 0)
	var z = args.get("z", 0)
	var item = args.get("item", 0)
	var orientation = args.get("orientation", 0)
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node or not node is GridMap:
		return _error("GridMap not found: %s" % path)

	node.set_cell_item(Vector3i(x, y, z), item, orientation)
	return _success({
		"path": _active_scene_path(node),
		"position": {"x": x, "y": y, "z": z},
		"item": item,
		"orientation": orientation
	}, "Cell set")


func _erase_gridmap_cell(path: String, x: int, y: int, z: int) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node or not node is GridMap:
		return _error("GridMap not found: %s" % path)

	node.set_cell_item(Vector3i(x, y, z), GridMap.INVALID_CELL_ITEM)
	return _success({
		"path": _active_scene_path(node),
		"position": {"x": x, "y": y, "z": z}
	}, "Cell erased")


func _clear_gridmap(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node or not node is GridMap:
		return _error("GridMap not found: %s" % path)

	node.clear()
	return _success({"path": _active_scene_path(node)}, "GridMap cleared")


func _get_used_cells(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node or not node is GridMap:
		return _error("GridMap not found: %s" % path)

	var cell_list: Array[Dictionary] = []
	for cell in node.get_used_cells():
		cell_list.append({
			"x": cell.x,
			"y": cell.y,
			"z": cell.z,
			"item": node.get_cell_item(cell)
		})

	return _success({
		"path": _active_scene_path(node),
		"count": cell_list.size(),
		"cells": cell_list
	})


func _get_used_cells_by_item(path: String, item: int) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node or not node is GridMap:
		return _error("GridMap not found: %s" % path)

	var cell_list: Array[Dictionary] = []
	for cell in node.get_used_cells_by_item(item):
		cell_list.append({"x": cell.x, "y": cell.y, "z": cell.z})

	return _success({
		"path": _active_scene_path(node),
		"item": item,
		"count": cell_list.size(),
		"cells": cell_list
	})


func _set_cell_size(path: String, cell_size: Dictionary) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node or not node is GridMap:
		return _error("GridMap not found: %s" % path)

	node.cell_size = Vector3(
		cell_size.get("x", node.cell_size.x),
		cell_size.get("y", node.cell_size.y),
		cell_size.get("z", node.cell_size.z)
	)

	return _success({
		"path": _active_scene_path(node),
		"cell_size": _serialize_value(node.cell_size)
	}, "Cell size set")
