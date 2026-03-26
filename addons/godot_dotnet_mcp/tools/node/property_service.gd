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
			return _get_property(node, args.get("property", ""))
		"set":
			return _set_property(node, args.get("property", ""), args.get("value"))
		"list":
			return _list_properties(node, args.get("filter", ""))
		"reset":
			return _reset_property(node, args.get("property", ""))
		"revert":
			return _check_revert(node, args.get("property", ""))
		_:
			return _error("Unknown action: %s" % action)


func _get_property(node: Node, property: String) -> Dictionary:
	if property.is_empty():
		return _error("Property name is required")
	if not property in node:
		return _error("Property not found: %s" % property)
	var value = node.get(property)
	return _success({
		"property": property,
		"value": _serialize_value(value),
		"type": typeof(value),
		"type_name": _type_to_string(typeof(value))
	})


func _set_property(node: Node, property: String, value) -> Dictionary:
	if property.is_empty():
		return _error("Property name is required")
	if not property in node:
		var available: Array = []
		for prop in node.get_property_list():
			var prop_name = str(prop.name)
			if prop.usage & PROPERTY_USAGE_EDITOR and not prop_name.begins_with("_"):
				if property.to_lower() in prop_name.to_lower():
					available.append(prop_name)
		var hints = []
		if not available.is_empty():
			hints.append("Similar properties: %s" % ", ".join(available.slice(0, 5)))
		return _error("Property not found: %s" % property, {"node_type": str(node.get_class())}, hints)
	var prop_info = _get_property_info(node, property)
	var current_value = node.get(property)
	if prop_info.has("valid_values") and value is String:
		var enum_values = prop_info["valid_values"]
		var found_idx = -1
		for i in range(enum_values.size()):
			var enum_val = enum_values[i].strip_edges()
			var enum_name = enum_val.split(":")[0] if ":" in enum_val else enum_val
			if enum_name.to_lower() == value.to_lower():
				found_idx = i
				break
		if found_idx >= 0:
			value = found_idx
		else:
			return _error("Invalid enum value: '%s'" % value, {}, ["Valid values: %s" % ", ".join(enum_values)])
	var converted_value = _deserialize_value(value, current_value)
	var old_value = _serialize_value(current_value)
	node.set(property, converted_value)
	var new_value = _serialize_value(node.get(property))
	return _success({
		"property": property,
		"old_value": old_value,
		"new_value": new_value,
		"node_path": _active_scene_path(node),
		"node_type": str(node.get_class())
	}, "Property set: %s" % property)


func _list_properties(node: Node, filter: String) -> Dictionary:
	var properties: Array[Dictionary] = []
	for prop in node.get_property_list():
		var prop_name = str(prop.name)
		if prop_name.begins_with("_") or prop.usage & PROPERTY_USAGE_INTERNAL:
			continue
		if not (prop.usage & PROPERTY_USAGE_EDITOR):
			continue
		if not filter.is_empty() and not filter.to_lower() in prop_name.to_lower():
			continue
		var prop_data = {
			"name": prop_name,
			"type": prop.type,
			"type_name": _type_to_string(prop.type),
			"hint": prop.hint,
			"hint_string": str(prop.hint_string)
		}
		if prop.type in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_COLOR]:
			prop_data["current_value"] = _serialize_value(node.get(prop_name))
		if prop.hint == PROPERTY_HINT_ENUM and not prop.hint_string.is_empty():
			prop_data["valid_values"] = prop.hint_string.split(",")
		if prop.hint == PROPERTY_HINT_RANGE and not prop.hint_string.is_empty():
			var parts = prop.hint_string.split(",")
			if parts.size() >= 2:
				prop_data["range"] = {"min": float(parts[0]), "max": float(parts[1])}
		properties.append(prop_data)
	return _success({
		"path": _active_scene_path(node),
		"type": str(node.get_class()),
		"count": properties.size(),
		"properties": properties
	})


func _reset_property(node: Node, property: String) -> Dictionary:
	if property.is_empty():
		return _error("Property name is required")
	var default_instance = ClassDB.instantiate(node.get_class())
	if default_instance:
		var default_value = default_instance.get(property)
		node.set(property, default_value)
		if default_instance is Node:
			default_instance.queue_free()
		return _success({"property": property, "value": _serialize_value(node.get(property))}, "Property reset: %s" % property)
	return _error("Could not determine default value")


func _check_revert(node: Node, property: String) -> Dictionary:
	if property.is_empty():
		return _error("Property name is required")
	var can_revert = node.property_can_revert(property)
	var result = {"property": property, "can_revert": can_revert}
	if can_revert:
		result["revert_value"] = _serialize_value(node.property_get_revert(property))
	return _success(result)
