@tool
extends "res://addons/godot_dotnet_mcp/tools/navigation/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action := str(args.get("action", ""))
	match action:
		"get_map_info":
			return _get_map_info(str(args.get("mode", "3d")))
		"get_path":
			return _get_navigation_path(args)
		_:
			return _error("Unknown action: %s" % action)


func _get_map_info(mode: String) -> Dictionary:
	var info := {}

	if mode == "3d" or mode.is_empty():
		var maps_3d = NavigationServer3D.get_maps()
		info["3d"] = {
			"map_count": maps_3d.size(),
			"maps": []
		}
		for map_rid in maps_3d:
			info["3d"]["maps"].append({
				"active": NavigationServer3D.map_is_active(map_rid),
				"cell_size": NavigationServer3D.map_get_cell_size(map_rid),
				"cell_height": NavigationServer3D.map_get_cell_height(map_rid),
				"edge_connection_margin": NavigationServer3D.map_get_edge_connection_margin(map_rid),
				"link_connection_radius": NavigationServer3D.map_get_link_connection_radius(map_rid)
			})

	if mode == "2d" or mode.is_empty():
		var maps_2d = NavigationServer2D.get_maps()
		info["2d"] = {
			"map_count": maps_2d.size(),
			"maps": []
		}
		for map_rid in maps_2d:
			info["2d"]["maps"].append({
				"active": NavigationServer2D.map_is_active(map_rid),
				"cell_size": NavigationServer2D.map_get_cell_size(map_rid),
				"edge_connection_margin": NavigationServer2D.map_get_edge_connection_margin(map_rid),
				"link_connection_radius": NavigationServer2D.map_get_link_connection_radius(map_rid)
			})

	return _success(info)


func _get_navigation_path(args: Dictionary) -> Dictionary:
	var mode := str(args.get("mode", "3d"))
	var from_dict: Dictionary = args.get("from", {})
	var to_dict: Dictionary = args.get("to", {})
	if from_dict.is_empty() or to_dict.is_empty():
		return _error("Both 'from' and 'to' positions are required")

	if mode == "3d":
		var from := Vector3(from_dict.get("x", 0), from_dict.get("y", 0), from_dict.get("z", 0))
		var to := Vector3(to_dict.get("x", 0), to_dict.get("y", 0), to_dict.get("z", 0))
		var maps_3d = NavigationServer3D.get_maps()
		if maps_3d.is_empty():
			return _error("No 3D navigation maps available")
		var path_points: Array[Dictionary] = []
		for point in NavigationServer3D.map_get_path(maps_3d[0], from, to, true):
			path_points.append(_serialize_value(point))
		return _success({
			"mode": "3d",
			"from": _serialize_value(from),
			"to": _serialize_value(to),
			"point_count": path_points.size(),
			"path": path_points,
			"valid": path_points.size() > 0
		})

	var from_2d := Vector2(from_dict.get("x", 0), from_dict.get("y", 0))
	var to_2d := Vector2(to_dict.get("x", 0), to_dict.get("y", 0))
	var maps_2d = NavigationServer2D.get_maps()
	if maps_2d.is_empty():
		return _error("No 2D navigation maps available")
	var path_points_2d: Array[Dictionary] = []
	for point in NavigationServer2D.map_get_path(maps_2d[0], from_2d, to_2d, true):
		path_points_2d.append(_serialize_value(point))
	return _success({
		"mode": "2d",
		"from": _serialize_value(from_2d),
		"to": _serialize_value(to_2d),
		"point_count": path_points_2d.size(),
		"path": path_points_2d,
		"valid": path_points_2d.size() > 0
	})
