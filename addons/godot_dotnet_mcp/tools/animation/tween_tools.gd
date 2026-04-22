@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

## Tween tools for Godot MCP


func execute(ei, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")

	match action:
		"info":
			return _get_tween_info()
		"property":
			return _tween_property(args)
		"create", "method", "callback":
			return _success({
				"note": "Tweens are best created via scripts. Use 'property' action for simple tweens, or add tween code to your scripts."
			}, "See info action for tween documentation")
		_:
			return _error("Unknown action: %s" % action)


func _get_tween_info() -> Dictionary:
	return _success({
		"description": "Tweens provide procedural animations for properties",
		"example_code": """
# Create tween in GDScript:
var tween = create_tween()
tween.tween_property($Sprite2D, "position", Vector2(100, 200), 1.0)
tween.tween_property($Sprite2D, "modulate", Color.RED, 0.5)

# With easing:
tween.tween_property($Sprite2D, "position", Vector2(100, 200), 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

# Parallel tweens:
tween.set_parallel(true)
tween.tween_property($Sprite2D, "position", Vector2(100, 200), 1.0)
tween.tween_property($Sprite2D, "rotation", PI, 1.0)
""",
		"ease_types": ["EASE_IN", "EASE_OUT", "EASE_IN_OUT", "EASE_OUT_IN"],
		"trans_types": ["TRANS_LINEAR", "TRANS_SINE", "TRANS_QUAD", "TRANS_CUBIC", "TRANS_QUART", "TRANS_QUINT", "TRANS_EXPO", "TRANS_CIRC", "TRANS_ELASTIC", "TRANS_BACK", "TRANS_BOUNCE"]
	})


func _tween_property(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var property = args.get("property", "")
	var final_value = args.get("final_value")
	var duration = args.get("duration", 1.0)

	if path.is_empty():
		return _error("Path is required")
	if property.is_empty():
		return _error("Property is required")
	if final_value == null:
		return _error("Final value is required", null, [
			"Provide 'final_value' - the target value for the tween",
			"For Vector2: {\"x\": number, \"y\": number}",
			"For Color: {\"r\": 0-1, \"g\": 0-1, \"b\": 0-1, \"a\": 0-1}",
			"For numbers: just the number"
		])

	var node = _find_node_by_path(path)
	if not node:
		return _error("Node not found: %s" % path)

	if not property in node:
		var available: Array = []
		for prop in node.get_property_list():
			var prop_name = str(prop.name)
			if prop.usage & PROPERTY_USAGE_EDITOR and not prop_name.begins_with("_"):
				if property.to_lower() in prop_name.to_lower():
					available.append(prop_name)
		return _error("Property not found: %s" % property, {"node_type": node.get_class()},
			["Similar properties: %s" % ", ".join(available.slice(0, 5))] if not available.is_empty() else [])

	if duration <= 0:
		return _error("Duration must be positive", {"provided_duration": duration})

	var current_value = node.get(property)
	var expected_type = typeof(current_value)
	var converted_value = _normalize_input_value(final_value, current_value)

	var validation = _validate_value_type(converted_value, expected_type)
	if not validation["valid"]:
		var hints = validation["hints"]
		hints.append("Property '%s' expects type: %s" % [property, _type_to_string(expected_type)])
		return _error("Invalid value type for tween", {
			"property": property,
			"expected_type": _type_to_string(expected_type),
			"provided_value": final_value,
			"converted_value": _serialize_value(converted_value)
		}, hints)

	var tween = node.create_tween()
	var tweener = tween.tween_property(node, property, converted_value, duration)

	var ease_type = args.get("ease", "")
	var trans_type = args.get("trans", "")

	if not ease_type.is_empty():
		var ease_enum = _get_ease_enum(ease_type)
		if ease_enum < 0:
			return _error("Invalid ease type: %s" % ease_type, null, ["Valid ease types: IN, OUT, IN_OUT, OUT_IN"])
		tweener.set_ease(ease_enum)

	if not trans_type.is_empty():
		var trans_enum = _get_trans_enum(trans_type)
		if trans_enum < 0:
			return _error("Invalid transition type: %s" % trans_type, null, ["Valid transition types: LINEAR, SINE, QUAD, CUBIC, QUART, QUINT, EXPO, CIRC, ELASTIC, BACK, BOUNCE"])
		tweener.set_trans(trans_enum)

	return _success({
		"path": path,
		"property": property,
		"start_value": _serialize_value(current_value) if current_value != null else null,
		"final_value": _serialize_value(converted_value),
		"duration": duration,
		"ease": ease_type if not ease_type.is_empty() else "default",
		"trans": trans_type if not trans_type.is_empty() else "default"
	}, "Tween started")


func _get_ease_enum(ease_name: String) -> int:
	match ease_name.to_upper():
		"IN": return Tween.EASE_IN
		"OUT": return Tween.EASE_OUT
		"IN_OUT": return Tween.EASE_IN_OUT
		"OUT_IN": return Tween.EASE_OUT_IN
	return -1


func _get_trans_enum(trans_name: String) -> int:
	match trans_name.to_upper():
		"LINEAR": return Tween.TRANS_LINEAR
		"SINE": return Tween.TRANS_SINE
		"QUAD": return Tween.TRANS_QUAD
		"CUBIC": return Tween.TRANS_CUBIC
		"QUART": return Tween.TRANS_QUART
		"QUINT": return Tween.TRANS_QUINT
		"EXPO": return Tween.TRANS_EXPO
		"CIRC": return Tween.TRANS_CIRC
		"ELASTIC": return Tween.TRANS_ELASTIC
		"BACK": return Tween.TRANS_BACK
		"BOUNCE": return Tween.TRANS_BOUNCE
	return -1
