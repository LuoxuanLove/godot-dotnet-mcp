@tool
extends "res://addons/godot_dotnet_mcp/tools/material/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	match str(args.get("action", "")):
		"set_property":
			return _set_material_property(str(args.get("path", "")), str(args.get("property", "")), args.get("value"))
		"get_property":
			return _get_material_property(str(args.get("path", "")), str(args.get("property", "")))
		"list_properties":
			return _list_material_properties(str(args.get("path", "")))
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _set_material_property(path: String, property: String, value) -> Dictionary:
	if property.is_empty():
		return _error("Property name is required")

	var material = _load_material(path)
	if not material:
		return _error("Material not found: %s" % path)

	if value is Dictionary and value.has("r"):
		value = Color(value.get("r", 1), value.get("g", 1), value.get("b", 1), value.get("a", 1))

	if property.ends_with("_texture") and value is String:
		if value.is_empty():
			value = null
		else:
			var texture_path := str(value)
			if not texture_path.begins_with("res://"):
				texture_path = "res://" + texture_path
			value = load(texture_path)

	if material is ShaderMaterial and not property.begins_with("shader_parameter/") and property != "shader":
		property = "shader_parameter/" + property

	if not property in material:
		return _error("Property not found: %s" % property)

	material.set(property, value)
	return _success({
		"property": property,
		"value": _serialize_value(material.get(property))
	}, "Property set")


func _get_material_property(path: String, property: String) -> Dictionary:
	if property.is_empty():
		return _error("Property name is required")

	var material = _load_material(path)
	if not material:
		return _error("Material not found: %s" % path)

	if material is ShaderMaterial and not property.begins_with("shader_parameter/") and property != "shader":
		property = "shader_parameter/" + property

	if not property in material:
		return _error("Property not found: %s" % property)

	return _success({
		"property": property,
		"value": _serialize_value(material.get(property))
	})


func _list_material_properties(path: String) -> Dictionary:
	var material = _load_material(path)
	if not material:
		return _error("Material not found: %s" % path)

	var properties: Array[Dictionary] = []
	for prop in material.get_property_list():
		var prop_name := str(prop.name)
		if prop_name.begins_with("_") or prop_name in ["resource_path", "resource_name", "resource_local_to_scene"]:
			continue
		if prop.usage & PROPERTY_USAGE_EDITOR:
			properties.append({
				"name": prop_name,
				"type": _type_to_string(prop.type),
				"value": _serialize_value(material.get(prop_name))
			})

	return _success({
		"type": str(material.get_class()),
		"count": properties.size(),
		"properties": properties
	})
