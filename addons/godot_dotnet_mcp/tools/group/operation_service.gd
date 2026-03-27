@tool
extends "res://addons/godot_dotnet_mcp/tools/group/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action := str(args.get("action", ""))
	match action:
		"call_group":
			return _call_group(str(args.get("group", "")), str(args.get("method", "")), args.get("args", []))
		"set_group":
			return _set_group(str(args.get("group", "")), str(args.get("property", "")), args.get("value"))
		_:
			return _error("Unknown action: %s" % action)


func _call_group(group_name: String, method_name: String, args: Array) -> Dictionary:
	if group_name.is_empty():
		return _error("Group name is required")
	if method_name.is_empty():
		return _error("Method name is required")

	var nodes := _get_group_nodes(group_name)
	if nodes.is_empty():
		return _error("No nodes in group: %s" % group_name)

	var called_count := 0
	for node in nodes:
		if not node.has_method(method_name):
			continue
		match args.size():
			0:
				node.call(method_name)
			1:
				node.call(method_name, args[0])
			2:
				node.call(method_name, args[0], args[1])
			3:
				node.call(method_name, args[0], args[1], args[2])
			_:
				node.callv(method_name, args)
		called_count += 1

	return _success({
		"group": group_name,
		"method": method_name,
		"args": args,
		"nodes_count": nodes.size(),
		"called_count": called_count
	}, "Method called on %d nodes" % called_count)


func _set_group(group_name: String, property_name: String, value) -> Dictionary:
	if group_name.is_empty():
		return _error("Group name is required")
	if property_name.is_empty():
		return _error("Property name is required")

	var nodes := _get_group_nodes(group_name)
	if nodes.is_empty():
		return _error("No nodes in group: %s" % group_name)

	var set_count := 0
	for node in nodes:
		if property_name in node:
			node.set(property_name, value)
			set_count += 1

	return _success({
		"group": group_name,
		"property": property_name,
		"value": value,
		"nodes_count": nodes.size(),
		"set_count": set_count
	}, "Property set on %d nodes" % set_count)
