@tool
extends "res://addons/godot_dotnet_mcp/tools/signal/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action := str(args.get("action", ""))
	match action:
		"list":
			return _list_signals(str(args.get("path", "")))
		"get_info":
			return _get_signal_info(str(args.get("path", "")), str(args.get("signal", "")))
		"list_connections":
			return _list_connections(str(args.get("path", "")), str(args.get("signal", "")))
		"is_connected":
			return _is_connected(args)
		"list_all_connections":
			return _list_all_connections()
		_:
			return _error("Unknown action: %s" % action)


func _list_signals(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)

	var signals: Array[Dictionary] = []
	for sig in node.get_signal_list():
		var signal_name := str(sig.get("name", ""))
		var signal_info: Dictionary = {
			"name": signal_name,
			"args": []
		}
		for arg in sig.get("args", []):
			signal_info["args"].append({
				"name": arg["name"],
				"type": type_string(arg["type"])
			})
		signal_info["connection_count"] = node.get_signal_connection_list(signal_name).size()
		signals.append(signal_info)

	return _success({
		"path": path,
		"count": signals.size(),
		"signals": signals
	})


func _get_signal_info(path: String, signal_name: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")
	if signal_name.is_empty():
		return _error("Signal name is required")

	var node = _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	if not node.has_signal(signal_name):
		return _error("Signal not found: %s" % signal_name)

	var signal_info: Dictionary = {}
	for sig in node.get_signal_list():
		if str(sig.get("name", "")) == signal_name:
			signal_info = sig
			break

	var args: Array[Dictionary] = []
	for arg in signal_info.get("args", []):
		args.append({
			"name": arg["name"],
			"type": type_string(arg["type"]),
			"class_name": arg.get("class_name", "")
		})

	var connections = node.get_signal_connection_list(signal_name)
	var connection_list: Array[Dictionary] = []
	for conn in connections:
		var target_obj = conn["callable"].get_object()
		connection_list.append({
			"target": _get_scene_path(target_obj) if target_obj != null and target_obj is Node else "",
			"method": conn["callable"].get_method(),
			"flags": conn["flags"]
		})

	return _success({
		"path": path,
		"signal": signal_name,
		"args": args,
		"connection_count": connections.size(),
		"connections": connection_list
	})


func _list_connections(path: String, signal_name: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")
	if signal_name.is_empty():
		return _error("Signal name is required")

	var node = _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	if not node.has_signal(signal_name):
		return _error("Signal not found: %s" % signal_name)

	var connection_list: Array[Dictionary] = []
	for conn in node.get_signal_connection_list(signal_name):
		var target_obj = conn["callable"].get_object()
		connection_list.append({
			"target_path": _get_scene_path(target_obj) if target_obj != null and target_obj is Node else "",
			"target_object": str(target_obj) if target_obj != null else "",
			"method": conn["callable"].get_method(),
			"flags": conn["flags"]
		})

	return _success({
		"path": path,
		"signal": signal_name,
		"count": connection_list.size(),
		"connections": connection_list
	})


func _is_connected(args: Dictionary) -> Dictionary:
	var source_path := str(args.get("source", args.get("path", "")))
	var signal_name := str(args.get("signal", ""))
	var target_path := str(args.get("target", ""))
	var method_name := str(args.get("method", ""))
	if source_path.is_empty() or signal_name.is_empty() or target_path.is_empty() or method_name.is_empty():
		return _error("source, signal, target, and method are required")

	var source = _find_active_node(source_path)
	if source == null:
		return _error("Source not found: %s" % source_path)
	var target = _find_active_node(target_path)
	if target == null:
		return _error("Target not found: %s" % target_path)

	return _success({
		"source": source_path,
		"signal": signal_name,
		"target": target_path,
		"method": method_name,
		"connected": source.is_connected(signal_name, Callable(target, method_name))
	})


func _list_all_connections() -> Dictionary:
	var root := _get_active_root()
	if root == null:
		return _error("No scene open")

	var all_connections: Array[Dictionary] = []
	_collect_connections(root, all_connections)
	return _success({
		"count": all_connections.size(),
		"connections": all_connections
	})
