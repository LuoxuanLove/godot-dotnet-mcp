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
		"call":
			return _call_method(node, args.get("method", ""), args.get("args", []))
		"call_deferred":
			return _call_method_deferred(node, args.get("method", ""), args.get("args", []))
		"propagate_call":
			return _propagate_call(node, args.get("method", ""), args.get("args", []), args.get("parent_first", false))
		"has_method":
			return _has_method(node, args.get("method", ""))
		"get_method_list":
			return _get_method_list(node, args.get("filter", ""))
		_:
			return _error("Unknown action: %s" % action)


func _call_method(node: Node, method: String, args: Array) -> Dictionary:
	if method.is_empty():
		return _error("Method name is required")
	if not node.has_method(method):
		return _error("Method not found: %s" % method)
	var result
	match args.size():
		0:
			result = node.call(method)
		1:
			result = node.call(method, args[0])
		2:
			result = node.call(method, args[0], args[1])
		3:
			result = node.call(method, args[0], args[1], args[2])
		4:
			result = node.call(method, args[0], args[1], args[2], args[3])
		5:
			result = node.call(method, args[0], args[1], args[2], args[3], args[4])
		_:
			return _error("Too many arguments (max 5)")
	return _success({"path": _active_scene_path(node), "method": method, "result": _serialize_value(result)}, "Method called")


func _call_method_deferred(node: Node, method: String, args: Array) -> Dictionary:
	if method.is_empty():
		return _error("Method name is required")
	if not node.has_method(method):
		return _error("Method not found: %s" % method)
	match args.size():
		0:
			node.call_deferred(method)
		1:
			node.call_deferred(method, args[0])
		2:
			node.call_deferred(method, args[0], args[1])
		3:
			node.call_deferred(method, args[0], args[1], args[2])
		4:
			node.call_deferred(method, args[0], args[1], args[2], args[3])
		_:
			return _error("Too many arguments (max 4)")
	return _success({"path": _active_scene_path(node), "method": method, "deferred": true}, "Method call deferred")


func _propagate_call(node: Node, method: String, args: Array, parent_first: bool) -> Dictionary:
	if method.is_empty():
		return _error("Method name is required")
	node.propagate_call(method, args, parent_first)
	return _success({"path": _active_scene_path(node), "method": method, "args_count": args.size(), "parent_first": parent_first}, "Call propagated")


func _has_method(node: Node, method: String) -> Dictionary:
	if method.is_empty():
		return _error("Method name is required")
	return _success({"path": _active_scene_path(node), "method": method, "exists": node.has_method(method)})


func _get_method_list(node: Node, filter: String) -> Dictionary:
	var methods: Array[Dictionary] = []
	for method_info in node.get_method_list():
		var method_name := str(method_info.get("name", ""))
		if not filter.is_empty() and not method_name.to_lower().contains(filter.to_lower()):
			continue
		methods.append({
			"name": method_name,
			"args": method_info.get("args", []),
			"default_args": method_info.get("default_args", []),
			"flags": method_info.get("flags", 0),
			"id": method_info.get("id", 0),
			"return": method_info.get("return", {})
		})
	return _success({"path": _active_scene_path(node), "count": methods.size(), "methods": methods})
