@tool
extends "res://addons/godot_dotnet_mcp/tools/physics/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")

	match action:
		"raycast":
			return _do_raycast(args)
		"point_check":
			return _do_point_check(args)
		"list_bodies_in_area":
			return _list_bodies_in_area(args.get("path", ""))
		_:
			return _error("Unknown action: %s" % action)


func _do_raycast(args: Dictionary) -> Dictionary:
	var mode = args.get("mode", "3d")
	var from_dict = args.get("from", {})
	var to_dict = args.get("to", {})
	var collision_mask = args.get("collision_mask", 0xFFFFFFFF)

	if from_dict.is_empty() or to_dict.is_empty():
		return _error("Both 'from' and 'to' positions are required")

	var root = _get_active_root()
	if not root:
		return _error("No scene open")

	if mode == "3d":
		var from_3d := Vector3(from_dict.get("x", 0), from_dict.get("y", 0), from_dict.get("z", 0))
		var to_3d := Vector3(to_dict.get("x", 0), to_dict.get("y", 0), to_dict.get("z", 0))
		var space_state_3d = root.get_world_3d().direct_space_state
		var query_3d = PhysicsRayQueryParameters3D.create(from_3d, to_3d, collision_mask)
		query_3d.collide_with_bodies = args.get("collide_with_bodies", true)
		query_3d.collide_with_areas = args.get("collide_with_areas", false)

		var result_3d = space_state_3d.intersect_ray(query_3d)
		if result_3d.is_empty():
			return _success({
				"hit": false,
				"from": _serialize_value(from_3d),
				"to": _serialize_value(to_3d)
			})

		return _success({
			"hit": true,
			"from": _serialize_value(from_3d),
			"to": _serialize_value(to_3d),
			"position": _serialize_value(result_3d.position),
			"normal": _serialize_value(result_3d.normal),
			"collider": _active_scene_path(result_3d.collider) if result_3d.collider else "",
			"collider_id": result_3d.collider_id
		})

	var from_2d := Vector2(from_dict.get("x", 0), from_dict.get("y", 0))
	var to_2d := Vector2(to_dict.get("x", 0), to_dict.get("y", 0))
	var space_state_2d = root.get_world_2d().direct_space_state
	var query_2d = PhysicsRayQueryParameters2D.create(from_2d, to_2d, collision_mask)
	query_2d.collide_with_bodies = args.get("collide_with_bodies", true)
	query_2d.collide_with_areas = args.get("collide_with_areas", false)

	var result_2d = space_state_2d.intersect_ray(query_2d)
	if result_2d.is_empty():
		return _success({
			"hit": false,
			"from": _serialize_value(from_2d),
			"to": _serialize_value(to_2d)
		})

	return _success({
		"hit": true,
		"from": _serialize_value(from_2d),
		"to": _serialize_value(to_2d),
		"position": _serialize_value(result_2d.position),
		"normal": _serialize_value(result_2d.normal),
		"collider": _active_scene_path(result_2d.collider) if result_2d.collider else "",
		"collider_id": result_2d.collider_id
	})


func _do_point_check(args: Dictionary) -> Dictionary:
	var mode = args.get("mode", "2d")
	var point_dict = args.get("point", {})
	var collision_mask = args.get("collision_mask", 0xFFFFFFFF)

	if point_dict.is_empty():
		return _error("Point is required")
	if mode != "2d":
		return _error("Point check is only available for 2D. Use raycast for 3D.")

	var root = _get_active_root()
	if not root:
		return _error("No scene open")

	var point := Vector2(point_dict.get("x", 0), point_dict.get("y", 0))
	var space_state = root.get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = collision_mask
	query.collide_with_bodies = args.get("collide_with_bodies", true)
	query.collide_with_areas = args.get("collide_with_areas", false)

	var results = space_state.intersect_point(query, 32)
	var hits: Array[Dictionary] = []
	for result_value in results:
		hits.append({
			"collider": _active_scene_path(result_value.collider) if result_value.collider else "",
			"collider_id": result_value.collider_id,
			"shape": result_value.shape
		})

	return _success({
		"point": _serialize_value(point),
		"hit_count": hits.size(),
		"hits": hits
	})


func _list_bodies_in_area(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)
	if not (node is Area2D or node is Area3D):
		return _error("Node is not an Area")

	var bodies: Array[Dictionary] = []
	for body in node.get_overlapping_bodies():
		bodies.append({
			"path": _active_scene_path(body),
			"type": body.get_class()
		})

	return _success({
		"path": _active_scene_path(node),
		"body_count": bodies.size(),
		"bodies": bodies
	})
