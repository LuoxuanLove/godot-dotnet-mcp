@tool
extends RefCounted
class_name MCPTypeUtils


func get_property_info(node: Node, property_name: String) -> Dictionary:
	for prop in node.get_property_list():
		if str(prop.name) == property_name:
			var info = {
				"name": str(prop.name),
				"type": prop.type,
				"type_name": type_to_string(prop.type),
				"hint": prop.hint,
				"hint_string": str(prop.hint_string),
				"usage": prop.usage
			}
			var hint_string = str(prop.hint_string)

			match prop.hint:
				PROPERTY_HINT_ENUM, PROPERTY_HINT_ENUM_SUGGESTION:
					if not hint_string.is_empty():
						info["valid_values"] = hint_string.split(",")
				PROPERTY_HINT_RANGE:
					if not hint_string.is_empty():
						info["range"] = parse_range_hint(hint_string, prop.type == TYPE_INT)
				PROPERTY_HINT_FLAGS:
					if not hint_string.is_empty():
						info["flags"] = hint_string.split(",")
				PROPERTY_HINT_EXP_EASING:
					info["easing"] = true
					if "attenuation" in hint_string:
						info["easing_attenuation"] = true
					if "positive_only" in hint_string:
						info["easing_positive_only"] = true
				PROPERTY_HINT_LAYERS_2D_RENDER, PROPERTY_HINT_LAYERS_2D_PHYSICS, \
				PROPERTY_HINT_LAYERS_2D_NAVIGATION, PROPERTY_HINT_LAYERS_3D_RENDER, \
				PROPERTY_HINT_LAYERS_3D_PHYSICS, PROPERTY_HINT_LAYERS_3D_NAVIGATION, \
				PROPERTY_HINT_LAYERS_AVOIDANCE:
					info["layer_hint"] = true
					info["range"] = {"min": 1, "max": 32, "step": 1}
				PROPERTY_HINT_FILE, PROPERTY_HINT_GLOBAL_FILE, PROPERTY_HINT_SAVE_FILE, PROPERTY_HINT_GLOBAL_SAVE_FILE:
					if not hint_string.is_empty():
						info["file_filter"] = hint_string.split(",")
				PROPERTY_HINT_DIR, PROPERTY_HINT_GLOBAL_DIR:
					info["is_directory"] = true
				PROPERTY_HINT_RESOURCE_TYPE:
					if not hint_string.is_empty():
						info["resource_types"] = hint_string.split(",")
				PROPERTY_HINT_COLOR_NO_ALPHA:
					info["color_no_alpha"] = true
				PROPERTY_HINT_NODE_TYPE:
					if not hint_string.is_empty():
						info["node_types"] = hint_string.split(",")

			if prop.usage & PROPERTY_USAGE_READ_ONLY:
				info["read_only"] = true
			if prop.usage & PROPERTY_USAGE_CLASS_IS_ENUM:
				info["is_enum_class"] = true

			return info

	return {}


func parse_range_hint(hint_string: String, is_int: bool = false) -> Dictionary:
	var result = {
		"min": 0.0,
		"max": 100.0,
		"step": 1.0 if is_int else 0.001,
		"or_greater": false,
		"or_less": false,
		"exp": false,
		"suffix": ""
	}

	var slices = hint_string.split(",")
	if slices.size() < 2:
		return result

	result["min"] = float(slices[0])
	result["max"] = float(slices[1])

	if slices.size() >= 3:
		var third = slices[2].strip_edges()
		if third.is_valid_float():
			result["step"] = float(third)

	for i in range(2, slices.size()):
		var slice = slices[i].strip_edges()
		match slice:
			"or_greater":
				result["or_greater"] = true
			"or_less":
				result["or_less"] = true
			"exp":
				result["exp"] = true
			"radians_as_degrees", "degrees":
				result["suffix"] = "deg"
			_:
				if slice.begins_with("suffix:"):
					result["suffix"] = slice.substr(7).strip_edges()

	return result


func type_to_string(type: int) -> String:
	match type:
		TYPE_NIL: return "null"
		TYPE_BOOL: return "bool (true/false)"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2 {\"x\": float, \"y\": float}"
		TYPE_VECTOR2I: return "Vector2i {\"x\": int, \"y\": int}"
		TYPE_RECT2: return "Rect2 {\"position\": {x,y}, \"size\": {x,y}}"
		TYPE_RECT2I: return "Rect2i {\"position\": {x,y}, \"size\": {x,y}}"
		TYPE_VECTOR3: return "Vector3 {\"x\": float, \"y\": float, \"z\": float}"
		TYPE_VECTOR3I: return "Vector3i {\"x\": int, \"y\": int, \"z\": int}"
		TYPE_TRANSFORM2D: return "Transform2D"
		TYPE_VECTOR4: return "Vector4 {\"x\": float, \"y\": float, \"z\": float, \"w\": float}"
		TYPE_VECTOR4I: return "Vector4i {\"x\": int, \"y\": int, \"z\": int, \"w\": int}"
		TYPE_PLANE: return "Plane {\"normal\": {x,y,z}, \"d\": float}"
		TYPE_QUATERNION: return "Quaternion {\"x\": float, \"y\": float, \"z\": float, \"w\": float}"
		TYPE_AABB: return "AABB {\"position\": {x,y,z}, \"size\": {x,y,z}}"
		TYPE_BASIS: return "Basis"
		TYPE_TRANSFORM3D: return "Transform3D {\"basis\": Basis, \"origin\": {x,y,z}}"
		TYPE_PROJECTION: return "Projection"
		TYPE_COLOR: return "Color {\"r\": 0-1, \"g\": 0-1, \"b\": 0-1, \"a\": 0-1} or \"#RRGGBB\""
		TYPE_STRING_NAME: return "StringName (String)"
		TYPE_NODE_PATH: return "NodePath (String path)"
		TYPE_RID: return "RID (resource ID)"
		TYPE_OBJECT: return "Object/Resource (res:// path)"
		TYPE_CALLABLE: return "Callable"
		TYPE_SIGNAL: return "Signal"
		TYPE_DICTIONARY: return "Dictionary {}"
		TYPE_ARRAY: return "Array []"
		TYPE_PACKED_BYTE_ARRAY: return "PackedByteArray"
		TYPE_PACKED_INT32_ARRAY: return "PackedInt32Array"
		TYPE_PACKED_INT64_ARRAY: return "PackedInt64Array"
		TYPE_PACKED_FLOAT32_ARRAY: return "PackedFloat32Array"
		TYPE_PACKED_FLOAT64_ARRAY: return "PackedFloat64Array"
		TYPE_PACKED_STRING_ARRAY: return "PackedStringArray"
		TYPE_PACKED_VECTOR2_ARRAY: return "PackedVector2Array"
		TYPE_PACKED_VECTOR3_ARRAY: return "PackedVector3Array"
		TYPE_PACKED_COLOR_ARRAY: return "PackedColorArray"
		TYPE_PACKED_VECTOR4_ARRAY: return "PackedVector4Array"
		_: return "Unknown (type %d)" % type


func validate_value_type(value, expected_type: int, prop_info: Dictionary = {}) -> Dictionary:
	var value_type = typeof(value)
	var compatible = false
	var hints: Array = []

	if prop_info.get("read_only", false):
		hints.append("This property is read-only")
		return {"valid": false, "hints": hints}

	match expected_type:
		TYPE_BOOL:
			compatible = value_type == TYPE_BOOL or (value_type == TYPE_INT and (value == 0 or value == 1))
			if not compatible:
				hints.append("Expected: true or false")
		TYPE_INT:
			compatible = value_type == TYPE_INT or value_type == TYPE_FLOAT
			if compatible and prop_info.has("range"):
				var r = prop_info["range"]
				var min_val = r.get("min", 0)
				var max_val = r.get("max", 100)
				var or_greater = r.get("or_greater", false)
				var or_less = r.get("or_less", false)
				if value < min_val and not or_less:
					hints.append("Value %s is below minimum %s" % [value, min_val])
					compatible = false
				elif value > max_val and not or_greater:
					hints.append("Value %s is above maximum %s" % [value, max_val])
					compatible = false

				var range_desc = "Range: %s to %s" % [min_val, max_val]
				if or_greater:
					range_desc += " (or greater)"
				if or_less:
					range_desc += " (or less)"
				if r.get("suffix", "") != "":
					range_desc += " %s" % r["suffix"]
				hints.append(range_desc)

			if prop_info.has("valid_values"):
				hints.append("Valid values: %s" % ", ".join(prop_info["valid_values"]))
		TYPE_FLOAT:
			compatible = value_type == TYPE_FLOAT or value_type == TYPE_INT
			if compatible and prop_info.has("range"):
				var rf = prop_info["range"]
				var min_float = rf.get("min", 0.0)
				var max_float = rf.get("max", 1.0)
				var allow_greater = rf.get("or_greater", false)
				var allow_less = rf.get("or_less", false)
				if value < min_float and not allow_less:
					hints.append("Value %s is below minimum %s" % [value, min_float])
					compatible = false
				elif value > max_float and not allow_greater:
					hints.append("Value %s is above maximum %s" % [value, max_float])
					compatible = false

				var float_range_desc = "Range: %s to %s" % [min_float, max_float]
				if allow_greater:
					float_range_desc += " (or greater)"
				if allow_less:
					float_range_desc += " (or less)"
				if rf.get("suffix", "") != "":
					float_range_desc += " %s" % rf["suffix"]
				hints.append(float_range_desc)
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			compatible = value_type == TYPE_STRING or value_type == TYPE_STRING_NAME or value_type == TYPE_NODE_PATH
			if prop_info.has("file_filter"):
				hints.append("File types: %s" % ", ".join(prop_info["file_filter"]))
			if prop_info.get("is_directory", false):
				hints.append("Must be a directory path")
		TYPE_VECTOR2:
			compatible = value_type == TYPE_VECTOR2 or (value_type == TYPE_DICTIONARY and value.has("x") and value.has("y"))
			if not compatible:
				hints.append("Expected: {\"x\": float, \"y\": float}")
		TYPE_VECTOR2I:
			compatible = value_type == TYPE_VECTOR2I or (value_type == TYPE_DICTIONARY and value.has("x") and value.has("y"))
			if not compatible:
				hints.append("Expected: {\"x\": int, \"y\": int}")
		TYPE_VECTOR3:
			compatible = value_type == TYPE_VECTOR3 or (value_type == TYPE_DICTIONARY and value.has("x") and value.has("y") and value.has("z"))
			if not compatible:
				hints.append("Expected: {\"x\": float, \"y\": float, \"z\": float}")
		TYPE_VECTOR3I:
			compatible = value_type == TYPE_VECTOR3I or (value_type == TYPE_DICTIONARY and value.has("x") and value.has("y") and value.has("z"))
			if not compatible:
				hints.append("Expected: {\"x\": int, \"y\": int, \"z\": int}")
		TYPE_VECTOR4, TYPE_VECTOR4I:
			compatible = value_type == TYPE_VECTOR4 or value_type == TYPE_VECTOR4I or (value_type == TYPE_DICTIONARY and value.has("x") and value.has("y") and value.has("z") and value.has("w"))
			if not compatible:
				hints.append("Expected: {\"x\": num, \"y\": num, \"z\": num, \"w\": num}")
		TYPE_RECT2, TYPE_RECT2I:
			compatible = value_type == TYPE_DICTIONARY and value.has("position") and value.has("size")
			if not compatible:
				hints.append("Expected: {\"position\": {\"x\": n, \"y\": n}, \"size\": {\"x\": n, \"y\": n}}")
		TYPE_COLOR:
			if value_type == TYPE_DICTIONARY:
				compatible = value.has("r") and value.has("g") and value.has("b")
				if compatible and prop_info.get("color_no_alpha", false) and value.has("a"):
					hints.append("Note: Alpha channel will be ignored for this property")
			elif value_type == TYPE_COLOR:
				compatible = true
			elif value_type == TYPE_STRING:
				compatible = true
			if not compatible:
				hints.append("Expected: {\"r\": 0-1, \"g\": 0-1, \"b\": 0-1, \"a\": 0-1} or \"#RRGGBB\"")
		TYPE_QUATERNION:
			compatible = value_type == TYPE_DICTIONARY and value.has("x") and value.has("y") and value.has("z") and value.has("w")
			if not compatible:
				hints.append("Expected: {\"x\": float, \"y\": float, \"z\": float, \"w\": float}")
		TYPE_AABB:
			compatible = value_type == TYPE_DICTIONARY and value.has("position") and value.has("size")
			if not compatible:
				hints.append("Expected: {\"position\": {x,y,z}, \"size\": {x,y,z}}")
		TYPE_OBJECT:
			compatible = value == null or value_type == TYPE_STRING or value_type == TYPE_OBJECT
			if value_type == TYPE_STRING and not value.is_empty() and not value.begins_with("res://"):
				hints.append("Resource paths should start with 'res://'")
			if prop_info.has("resource_types"):
				hints.append("Expected resource types: %s" % ", ".join(prop_info["resource_types"]))
			if prop_info.has("node_types"):
				hints.append("Expected node types: %s" % ", ".join(prop_info["node_types"]))
		TYPE_ARRAY:
			compatible = value_type == TYPE_ARRAY
			if not compatible:
				hints.append("Expected: Array []")
		TYPE_DICTIONARY:
			compatible = value_type == TYPE_DICTIONARY
			if not compatible:
				hints.append("Expected: Dictionary {}")
		_:
			compatible = true

	return {"valid": compatible, "hints": hints}


func serialize_value(value) -> Variant:
	match typeof(value):
		TYPE_VECTOR2:
			return {"x": float(value.x), "y": float(value.y)}
		TYPE_VECTOR2I:
			return {"x": int(value.x), "y": int(value.y)}
		TYPE_VECTOR3:
			return {"x": float(value.x), "y": float(value.y), "z": float(value.z)}
		TYPE_VECTOR3I:
			return {"x": int(value.x), "y": int(value.y), "z": int(value.z)}
		TYPE_VECTOR4:
			return {"x": float(value.x), "y": float(value.y), "z": float(value.z), "w": float(value.w)}
		TYPE_VECTOR4I:
			return {"x": int(value.x), "y": int(value.y), "z": int(value.z), "w": int(value.w)}
		TYPE_COLOR:
			return {"r": float(value.r), "g": float(value.g), "b": float(value.b), "a": float(value.a)}
		TYPE_RECT2:
			return {"position": {"x": float(value.position.x), "y": float(value.position.y)}, "size": {"x": float(value.size.x), "y": float(value.size.y)}}
		TYPE_RECT2I:
			return {"position": {"x": int(value.position.x), "y": int(value.position.y)}, "size": {"x": int(value.size.x), "y": int(value.size.y)}}
		TYPE_PLANE:
			return {"normal": {"x": float(value.normal.x), "y": float(value.normal.y), "z": float(value.normal.z)}, "d": float(value.d)}
		TYPE_QUATERNION:
			return {"x": float(value.x), "y": float(value.y), "z": float(value.z), "w": float(value.w)}
		TYPE_AABB:
			return {"position": {"x": float(value.position.x), "y": float(value.position.y), "z": float(value.position.z)}, "size": {"x": float(value.size.x), "y": float(value.size.y), "z": float(value.size.z)}}
		TYPE_TRANSFORM2D:
			return {
				"x": {"x": float(value.x.x), "y": float(value.x.y)},
				"y": {"x": float(value.y.x), "y": float(value.y.y)},
				"origin": {"x": float(value.origin.x), "y": float(value.origin.y)}
			}
		TYPE_TRANSFORM3D:
			return {
				"basis": {
					"x": {"x": float(value.basis.x.x), "y": float(value.basis.x.y), "z": float(value.basis.x.z)},
					"y": {"x": float(value.basis.y.x), "y": float(value.basis.y.y), "z": float(value.basis.y.z)},
					"z": {"x": float(value.basis.z.x), "y": float(value.basis.z.y), "z": float(value.basis.z.z)}
				},
				"origin": {"x": float(value.origin.x), "y": float(value.origin.y), "z": float(value.origin.z)}
			}
		TYPE_BASIS:
			return {
				"x": {"x": float(value.x.x), "y": float(value.x.y), "z": float(value.x.z)},
				"y": {"x": float(value.y.x), "y": float(value.y.y), "z": float(value.y.z)},
				"z": {"x": float(value.z.x), "y": float(value.z.y), "z": float(value.z.z)}
			}
		TYPE_OBJECT:
			if value == null:
				return null
			if value is Resource and value.resource_path:
				return str(value.resource_path)
			return str(value)
		TYPE_STRING_NAME:
			return str(value)
		TYPE_NODE_PATH:
			return str(value)
		TYPE_FLOAT:
			if is_nan(value) or is_inf(value):
				return 0.0
			return float(value)
		_:
			return value


func deserialize_value(value, reference):
	if value is String:
		var trimmed = value.strip_edges()
		if trimmed.begins_with("{") or trimmed.begins_with("["):
			var json = JSON.new()
			if json.parse(trimmed) == OK:
				value = json.get_data()

	match typeof(reference):
		TYPE_VECTOR2:
			if value is Dictionary:
				return Vector2(value.get("x", 0), value.get("y", 0))
		TYPE_VECTOR2I:
			if value is Dictionary:
				return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
		TYPE_VECTOR3:
			if value is Dictionary:
				return Vector3(value.get("x", 0), value.get("y", 0), value.get("z", 0))
		TYPE_VECTOR3I:
			if value is Dictionary:
				return Vector3i(int(value.get("x", 0)), int(value.get("y", 0)), int(value.get("z", 0)))
		TYPE_VECTOR4:
			if value is Dictionary:
				return Vector4(value.get("x", 0), value.get("y", 0), value.get("z", 0), value.get("w", 0))
		TYPE_VECTOR4I:
			if value is Dictionary:
				return Vector4i(int(value.get("x", 0)), int(value.get("y", 0)), int(value.get("z", 0)), int(value.get("w", 0)))
		TYPE_COLOR:
			if value is Dictionary:
				return Color(value.get("r", 1), value.get("g", 1), value.get("b", 1), value.get("a", 1))
			elif value is String:
				if value.begins_with("#") or not "{" in value:
					return Color.html(value) if Color.html_is_valid(value) else Color.WHITE
		TYPE_RECT2:
			if value is Dictionary:
				var pos = value.get("position", {"x": 0, "y": 0})
				var sz = value.get("size", {"x": 0, "y": 0})
				return Rect2(pos.get("x", 0), pos.get("y", 0), sz.get("x", 0), sz.get("y", 0))
		TYPE_RECT2I:
			if value is Dictionary:
				var pos_i = value.get("position", {"x": 0, "y": 0})
				var sz_i = value.get("size", {"x": 0, "y": 0})
				return Rect2i(int(pos_i.get("x", 0)), int(pos_i.get("y", 0)), int(sz_i.get("x", 0)), int(sz_i.get("y", 0)))
		TYPE_PLANE:
			if value is Dictionary:
				var normal = value.get("normal", {"x": 0, "y": 1, "z": 0})
				return Plane(Vector3(normal.get("x", 0), normal.get("y", 1), normal.get("z", 0)), value.get("d", 0))
		TYPE_QUATERNION:
			if value is Dictionary:
				return Quaternion(value.get("x", 0), value.get("y", 0), value.get("z", 0), value.get("w", 1))
		TYPE_AABB:
			if value is Dictionary:
				var pos3 = value.get("position", {"x": 0, "y": 0, "z": 0})
				var sz3 = value.get("size", {"x": 1, "y": 1, "z": 1})
				return AABB(
					Vector3(pos3.get("x", 0), pos3.get("y", 0), pos3.get("z", 0)),
					Vector3(sz3.get("x", 1), sz3.get("y", 1), sz3.get("z", 1))
				)
		TYPE_TRANSFORM2D:
			if value is Dictionary:
				var x_axis = value.get("x", {"x": 1, "y": 0})
				var y_axis = value.get("y", {"x": 0, "y": 1})
				var origin = value.get("origin", {"x": 0, "y": 0})
				return Transform2D(
					Vector2(x_axis.get("x", 1), x_axis.get("y", 0)),
					Vector2(y_axis.get("x", 0), y_axis.get("y", 1)),
					Vector2(origin.get("x", 0), origin.get("y", 0))
				)
		TYPE_BASIS:
			if value is Dictionary:
				var bx = value.get("x", {"x": 1, "y": 0, "z": 0})
				var by = value.get("y", {"x": 0, "y": 1, "z": 0})
				var bz = value.get("z", {"x": 0, "y": 0, "z": 1})
				return Basis(
					Vector3(bx.get("x", 1), bx.get("y", 0), bx.get("z", 0)),
					Vector3(by.get("x", 0), by.get("y", 1), by.get("z", 0)),
					Vector3(bz.get("x", 0), bz.get("y", 0), bz.get("z", 1))
				)
		TYPE_TRANSFORM3D:
			if value is Dictionary:
				var basis_data = value.get("basis", {})
				var origin_data = value.get("origin", {"x": 0, "y": 0, "z": 0})
				var basis = Basis.IDENTITY
				if not basis_data.is_empty():
					var tx = basis_data.get("x", {"x": 1, "y": 0, "z": 0})
					var ty = basis_data.get("y", {"x": 0, "y": 1, "z": 0})
					var tz = basis_data.get("z", {"x": 0, "y": 0, "z": 1})
					basis = Basis(
						Vector3(tx.get("x", 1), tx.get("y", 0), tx.get("z", 0)),
						Vector3(ty.get("x", 0), ty.get("y", 1), ty.get("z", 0)),
						Vector3(tz.get("x", 0), tz.get("y", 0), tz.get("z", 1))
					)
				var origin3 = Vector3(origin_data.get("x", 0), origin_data.get("y", 0), origin_data.get("z", 0))
				return Transform3D(basis, origin3)
		TYPE_OBJECT:
			if value is String and value.begins_with("res://"):
				var res = load(value)
				if res:
					return res

	return value
