@tool
extends RefCounted
class_name MCPFileUtils


func normalize_res_path(path: String) -> String:
	if path.is_empty():
		return ""
	return path if path.begins_with("res://") else "res://" + path


func read_text_file(path: String) -> Dictionary:
	var normalized = normalize_res_path(path)
	if normalized.is_empty():
		return _error("Path is required")
	if not FileAccess.file_exists(normalized):
		return _error("File not found: %s" % normalized)

	var file = FileAccess.open(normalized, FileAccess.READ)
	if not file:
		return _error("Failed to open file: %s" % normalized)

	var content = file.get_as_text()
	file.close()
	return _success({
		"path": normalized,
		"content": content,
		"line_count": content.split("\n").size()
	})


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
