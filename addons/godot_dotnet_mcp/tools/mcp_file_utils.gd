@tool
extends RefCounted
class_name MCPFileUtils

const PROJECT_PATH_ERROR_CODE := "project_path_outside_project"


func normalize_res_path(path: String) -> String:
	var validation := validate_project_path(path)
	if not bool(validation.get("success", false)):
		return ""
	return str(validation.get("path", ""))


func validate_project_path(path: String, allow_root: bool = true) -> Dictionary:
	var raw_path := str(path)
	var normalized := raw_path.strip_edges().replace("\\", "/")
	if normalized.is_empty():
		return _project_path_error("Project path is required.", raw_path, normalized)

	if normalized.begins_with("user://"):
		return _project_path_error("Project paths must use res:// and stay inside the project tree.", raw_path, normalized)
	if _has_non_res_scheme(normalized):
		return _project_path_error("Project paths must not use external URI schemes.", raw_path, normalized)
	if normalized.begins_with("//") or normalized.begins_with("/") or _is_windows_absolute_path(normalized):
		return _project_path_error("Project paths must be res:// paths or relative project paths.", raw_path, normalized)

	if normalized.begins_with("res://"):
		normalized = "res://" + normalized.substr("res://".length()).trim_prefix("/")
	else:
		normalized = "res://" + normalized

	var relative := normalized.substr("res://".length())
	if relative.is_empty() and not allow_root:
		return _project_path_error("Project path must target a file or directory below res://.", raw_path, normalized)

	for segment in relative.split("/", false):
		if segment == "." or segment == "..":
			return _project_path_error("Project paths must not contain traversal segments.", raw_path, normalized)

	var project_root := _normalize_absolute(ProjectSettings.globalize_path("res://"))
	var target_path := _normalize_absolute(ProjectSettings.globalize_path(normalized))
	var compare_root := project_root
	var compare_target := target_path
	if OS.get_name() == "Windows":
		compare_root = compare_root.to_lower()
		compare_target = compare_target.to_lower()
	if compare_target != compare_root and not compare_target.begins_with(compare_root + "/"):
		return _project_path_error("Project path resolves outside the project tree.", raw_path, normalized)
	if _path_uses_link_segment(project_root, relative):
		return _project_path_error("Project paths must not traverse symlink, junction, or reparse-point segments.", raw_path, normalized)

	return {
		"success": true,
		"path": normalized,
		"absolute_path": target_path
	}


func read_text_file(path: String) -> Dictionary:
	var validation := validate_project_path(path, false)
	if not bool(validation.get("success", false)):
		return validation
	var normalized := str(validation.get("path", ""))
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


func _project_path_error(message: String, raw_path: String, normalized_path: String) -> Dictionary:
	return {
		"success": false,
		"error": message,
		"error_code": PROJECT_PATH_ERROR_CODE,
		"data": {
			"code": PROJECT_PATH_ERROR_CODE,
			"path": raw_path,
			"normalized_path": normalized_path,
			"allowed_root": "res://"
		},
		"hints": [
			"Use a res:// path inside the current Godot project.",
			"Do not use user://, absolute paths, URI schemes, or . / .. path segments."
		]
	}


func _has_non_res_scheme(path: String) -> bool:
	var marker := path.find(":")
	if marker <= 0:
		return false
	for index in range(marker):
		var code := path.unicode_at(index)
		var is_alpha := (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		var is_digit := code >= 48 and code <= 57
		var is_scheme_char := is_alpha or is_digit or code == 43 or code == 45 or code == 46
		if index == 0 and not is_alpha:
			return false
		if not is_scheme_char:
			return false
	return not path.begins_with("res://")


func _is_windows_absolute_path(path: String) -> bool:
	if path.length() < 3:
		return false
	var drive := path.substr(0, 1)
	var code := drive.unicode_at(0)
	return path.substr(1, 2) == ":/" and ((code >= 65 and code <= 90) or (code >= 97 and code <= 122))


func _normalize_absolute(path: String) -> String:
	var normalized := path.replace("\\", "/")
	while normalized.ends_with("/") and normalized.length() > 1:
		normalized = normalized.substr(0, normalized.length() - 1)
	return normalized


func _path_uses_link_segment(project_root: String, relative_path: String) -> bool:
	var current_path := project_root
	for segment in relative_path.split("/", false):
		var parent_dir := DirAccess.open(current_path)
		current_path = current_path.path_join(segment)
		if not DirAccess.dir_exists_absolute(current_path) and not FileAccess.file_exists(current_path):
			return false
		if parent_dir != null and parent_dir.is_link(segment):
			return true
	return false


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
