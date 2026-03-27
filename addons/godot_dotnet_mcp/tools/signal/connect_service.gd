@tool
extends "res://addons/godot_dotnet_mcp/tools/signal/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action := str(args.get("action", ""))
	match action:
		"connect":
			return _connect_signal(args)
		"disconnect":
			return _disconnect_signal(args)
		"disconnect_all":
			return _disconnect_all(str(args.get("path", "")), str(args.get("signal", "")))
		_:
			return _error("Unknown action: %s" % action)


func _connect_signal(args: Dictionary) -> Dictionary:
	var source_path := str(args.get("source", args.get("path", "")))
	var signal_name := str(args.get("signal", ""))
	var target_path := str(args.get("target", ""))
	var method_name := str(args.get("method", ""))
	var flags := int(args.get("flags", 0))

	if source_path.is_empty():
		return _error("Source path is required")
	if signal_name.is_empty():
		return _error("Signal name is required")
	if target_path.is_empty():
		return _error("Target path is required")
	if method_name.is_empty():
		return _error("Method name is required")

	var source = _find_active_node(source_path)
	if source == null:
		return _error("Source not found: %s" % source_path)
	var target = _find_active_node(target_path)
	if target == null:
		return _error("Target not found: %s" % target_path)
	if not source.has_signal(signal_name):
		return _error("Signal not found: %s" % signal_name)

	var callable := Callable(target, method_name)
	if source.is_connected(signal_name, callable):
		return _error("Signal already connected")

	var error = source.connect(signal_name, callable, flags)
	if error != OK:
		return _error("Failed to connect: %s" % error_string(error))

	return _success({
		"source": source_path,
		"signal": signal_name,
		"target": target_path,
		"method": method_name
	}, "Signal connected")


func _disconnect_signal(args: Dictionary) -> Dictionary:
	var source_path := str(args.get("source", args.get("path", "")))
	var signal_name := str(args.get("signal", ""))
	var target_path := str(args.get("target", ""))
	var method_name := str(args.get("method", ""))

	if source_path.is_empty():
		return _error("Source path is required")
	if signal_name.is_empty():
		return _error("Signal name is required")
	if target_path.is_empty():
		return _error("Target path is required")
	if method_name.is_empty():
		return _error("Method name is required")

	var source = _find_active_node(source_path)
	if source == null:
		return _error("Source not found: %s" % source_path)
	var target = _find_active_node(target_path)
	if target == null:
		return _error("Target not found: %s" % target_path)

	var callable := Callable(target, method_name)
	if not source.is_connected(signal_name, callable):
		return _error("Signal not connected")

	source.disconnect(signal_name, callable)
	return _success({
		"source": source_path,
		"signal": signal_name,
		"target": target_path,
		"method": method_name
	}, "Signal disconnected")


func _disconnect_all(path: String, signal_name: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")
	if signal_name.is_empty():
		return _error("Signal name is required")

	var node = _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	if not node.has_signal(signal_name):
		return _error("Signal not found: %s" % signal_name)

	var connections = node.get_signal_connection_list(signal_name)
	var count := connections.size()
	for conn in connections:
		node.disconnect(signal_name, conn["callable"])

	return _success({
		"path": path,
		"signal": signal_name,
		"disconnected_count": count
	}, "All connections disconnected")
