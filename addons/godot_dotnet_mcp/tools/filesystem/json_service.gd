@tool
extends "res://addons/godot_dotnet_mcp/tools/filesystem/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	var path = str(args.get("path", ""))

	if path.is_empty():
		return _error("Path is required")

	path = _normalize_tool_path(path)

	match action:
		"read":
			return _read_json(path)
		"write":
			return _write_json(path, args.get("data"))
		"get_value":
			return _get_json_value(path, str(args.get("key", "")))
		"set_value":
			return _set_json_value(path, str(args.get("key", "")), args.get("value"))
		_:
			return _error("Unknown action: %s" % action)


func _read_json(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return _error("Cannot read file: %s" % path)

	var content = file.get_as_text()
	file.close()

	var json := JSON.new()
	var error = json.parse(content)
	if error != OK:
		return _error("Invalid JSON: %s at line %d" % [json.get_error_message(), json.get_error_line()])

	return _success({
		"path": path,
		"data": json.get_data()
	})


func _write_json(path: String, data) -> Dictionary:
	if data == null:
		return _error("Data is required")

	var normalized_data = _parse_json_like_value(data)
	var content = JSON.stringify(normalized_data, "\t")
	return _write_file(path, content)


func _write_file(path: String, content: String) -> Dictionary:
	var protected_error = _guard_protected_plugin_write(path)
	if not protected_error.is_empty():
		return protected_error

	_ensure_parent_directory(path)

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return _error("Cannot write file: %s" % path)

	file.store_string(content)
	file.close()

	_refresh_filesystem()
	return _success({
		"path": path,
		"size": content.length()
	}, "File written")


func _get_json_value(path: String, key: String) -> Dictionary:
	if key.is_empty():
		return _error("Key is required")

	var read_result = _read_json(path)
	if not bool(read_result.get("success", false)):
		return read_result

	var payload = read_result.get("data", {})
	var value_result = _get_nested_value(payload.get("data"), key)
	if not bool(value_result.get("success", false)):
		return value_result

	return _success({
		"path": path,
		"key": key,
		"value": value_result.get("data", {}).get("value")
	})


func _set_json_value(path: String, key: String, value) -> Dictionary:
	if key.is_empty():
		return _error("Key is required")

	var data = {}
	if FileAccess.file_exists(path):
		var read_result = _read_json(path)
		if bool(read_result.get("success", false)):
			var current_data = read_result.get("data", {}).get("data")
			if current_data is Dictionary:
				data = current_data

	var normalized_value = _parse_json_like_value(value)
	var set_result = _set_nested_value(data, key, normalized_value)
	if not bool(set_result.get("success", false)):
		return set_result

	return _write_json(path, data)
