@tool
extends "res://addons/godot_dotnet_mcp/tools/navigation/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action := str(args.get("action", ""))
	match action:
		"list_regions":
			return _list_regions(str(args.get("mode", "")))
		"bake_mesh":
			return _bake_mesh(str(args.get("path", "")))
		"set_region_enabled":
			return _set_region_enabled(str(args.get("path", "")), bool(args.get("enabled", true)))
		_:
			return _error("Unknown action: %s" % action)


func _list_regions(mode: String) -> Dictionary:
	var root := _get_active_root()
	if root == null:
		return _error("No scene open")

	var regions: Array[Dictionary] = []
	_collect_navigation_regions(root, regions, mode)
	return _success({
		"count": regions.size(),
		"regions": regions
	})


func _bake_mesh(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)

	if node is NavigationRegion3D:
		if node.navigation_mesh == null:
			return _error("NavigationRegion3D has no NavigationMesh")
		node.bake_navigation_mesh()
		return _success({
			"path": path,
			"type": "NavigationRegion3D"
		}, "Navigation mesh baking started")
	elif node is NavigationRegion2D:
		if node.navigation_polygon == null:
			return _error("NavigationRegion2D has no NavigationPolygon")
		node.bake_navigation_polygon()
		return _success({
			"path": path,
			"type": "NavigationRegion2D"
		}, "Navigation polygon baking started")

	return _error("Node is not a NavigationRegion")


func _set_region_enabled(path: String, enabled: bool) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	if not (node is NavigationRegion3D or node is NavigationRegion2D):
		return _error("Node is not a NavigationRegion")

	node.enabled = enabled
	return _success({
		"path": path,
		"enabled": enabled
	}, "Region %s" % ("enabled" if enabled else "disabled"))
