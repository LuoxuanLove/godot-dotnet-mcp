@tool
extends RefCounted
class_name MCPJsonUtils

const TypeUtils = preload("res://addons/godot_dotnet_mcp/tools/mcp_type_utils.gd")

var _type_utils := TypeUtils.new()


func parse_json_like_value(value):
	if value is String:
		var trimmed = value.strip_edges()
		if trimmed.begins_with("{") or trimmed.begins_with("["):
			var json = JSON.new()
			if json.parse(trimmed) == OK:
				return json.get_data()
	return value


func normalize_input_value(value, reference = null):
	var normalized = parse_json_like_value(value)
	if reference != null:
		return _type_utils.deserialize_value(normalized, reference)
	return normalized


func get_nested_value(data, dotted_key: String) -> Dictionary:
	if dotted_key.is_empty():
		return _error("Key is required")

	var current = data
	for part in dotted_key.split("."):
		if current is Dictionary and current.has(part):
			current = current[part]
			continue
		if current is Array and part.is_valid_int():
			var index = int(part)
			if index >= 0 and index < current.size():
				current = current[index]
				continue
			return _error("Array index out of bounds: %s" % dotted_key)
		return _error("Key not found: %s" % dotted_key)

	return _success({"key": dotted_key, "value": current})


func set_nested_value(data, dotted_key: String, value):
	if dotted_key.is_empty():
		return _error("Key is required")
	if not data is Dictionary:
		return _error("Nested key writes require a Dictionary root")

	var keys = dotted_key.split(".")
	var current = data

	for i in range(keys.size() - 1):
		var key = keys[i]
		if not current.has(key) or not current[key] is Dictionary:
			current[key] = {}
		current = current[key]

	current[keys[-1]] = value
	return _success({"key": dotted_key, "value": value})


func _success(data = null, message: String = "") -> Dictionary:
	var result = {"success": true}
	if data != null:
		result["data"] = data
	if not message.is_empty():
		result["message"] = message
	return result


func _error(message: String, data = null, hints: Array = []) -> Dictionary:
	var result = {
		"success": false,
		"error": message
	}
	if data != null:
		result["data"] = data
	if not hints.is_empty():
		result["hints"] = hints
	return result
