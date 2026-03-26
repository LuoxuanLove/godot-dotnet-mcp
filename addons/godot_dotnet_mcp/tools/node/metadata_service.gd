@tool
extends "res://addons/godot_dotnet_mcp/tools/node/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	var path = args.get("path", "")
	if path.is_empty():
		return _error("Path is required")
	var node = _find_active_node(path)
	if not node:
		return _error("Node not found: %s" % path)
	match action:
		"get":
			return _get_metadata(node, args.get("key", ""))
		"set":
			return _set_metadata(node, args.get("key", ""), args.get("value"))
		"has":
			return _has_metadata(node, args.get("key", ""))
		"remove":
			return _remove_metadata(node, args.get("key", ""))
		"list":
			return _list_metadata(node)
		_:
			return _error("Unknown action: %s" % action)


func _get_metadata(node: Node, key: String) -> Dictionary:
	if key.is_empty():
		return _error("Key is required")
	if not node.has_meta(key):
		return _error("Metadata not found: %s" % key)
	return _success({"path": _active_scene_path(node), "key": key, "value": _serialize_value(node.get_meta(key))})


func _set_metadata(node: Node, key: String, value) -> Dictionary:
	if key.is_empty():
		return _error("Key is required")
	node.set_meta(key, value)
	return _success({"path": _active_scene_path(node), "key": key, "value": _serialize_value(value)}, "Metadata set")


func _has_metadata(node: Node, key: String) -> Dictionary:
	if key.is_empty():
		return _error("Key is required")
	return _success({"path": _active_scene_path(node), "key": key, "exists": node.has_meta(key)})


func _remove_metadata(node: Node, key: String) -> Dictionary:
	if key.is_empty():
		return _error("Key is required")
	if not node.has_meta(key):
		return _error("Metadata not found: %s" % key)
	node.remove_meta(key)
	return _success({"path": _active_scene_path(node), "key": key}, "Metadata removed")


func _list_metadata(node: Node) -> Dictionary:
	var keys: Array[String] = []
	for key in node.get_meta_list():
		keys.append(str(key))
	return _success({"path": _active_scene_path(node), "count": keys.size(), "keys": keys})
