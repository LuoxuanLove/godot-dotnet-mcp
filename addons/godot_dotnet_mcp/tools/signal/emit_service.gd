@tool
extends "res://addons/godot_dotnet_mcp/tools/signal/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action := str(args.get("action", ""))
	if action != "emit":
		return _error("Unknown action: %s" % action)
	return _emit_signal(str(args.get("path", "")), str(args.get("signal", "")), args.get("args", []))


func _emit_signal(path: String, signal_name: String, args: Array) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")
	if signal_name.is_empty():
		return _error("Signal name is required")

	var node = _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	if not node.has_signal(signal_name):
		return _error("Signal not found: %s" % signal_name)

	match args.size():
		0:
			node.emit_signal(signal_name)
		1:
			node.emit_signal(signal_name, args[0])
		2:
			node.emit_signal(signal_name, args[0], args[1])
		3:
			node.emit_signal(signal_name, args[0], args[1], args[2])
		4:
			node.emit_signal(signal_name, args[0], args[1], args[2], args[3])
		_:
			return _error("Too many arguments (max 4)")

	return _success({
		"path": path,
		"signal": signal_name,
		"args": args
	}, "Signal emitted")
