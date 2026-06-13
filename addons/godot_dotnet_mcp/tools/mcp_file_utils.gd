@tool
extends RefCounted
class_name MCPFileUtils

const PROJECT_PATH_ERROR_CODE := "project_path_outside_project"
const TEXT_FILE_ERROR_CODE := "project_text_file_required"
const _TEXT_SAMPLE_BYTES := 8192
const _BINARY_TEXT_WRITE_EXTENSIONS := {
	".aseprite": true,
	".bin": true,
	".bmp": true,
	".dll": true,
	".exe": true,
	".gif": true,
	".ico": true,
	".import": true,
	".jpeg": true,
	".jpg": true,
	".mp3": true,
	".ogg": true,
	".otf": true,
	".pck": true,
	".png": true,
	".res": true,
	".scn": true,
	".ttf": true,
	".uid": true,
	".wav": true,
	".webp": true,
	".zip": true
}


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


func validate_text_file_path(path: String, allow_create: bool = false, context: String = "file") -> Dictionary:
	var validation := validate_project_path(path, false)
	if not bool(validation.get("success", false)):
		return validation
	var normalized := str(validation.get("path", ""))
	var ext_error := _validate_text_extension(normalized, context)
	if not ext_error.is_empty():
		return ext_error
	if FileAccess.file_exists(normalized) and not _looks_like_text_file(normalized):
		return _text_file_error("%s must be a text file; binary files are not safe for text operations." % context.capitalize(), normalized)
	if not allow_create and not FileAccess.file_exists(normalized):
		return _error("File not found: %s" % normalized)
	return validation


func read_text_file(path: String) -> Dictionary:
	var validation := validate_text_file_path(path, false, "file")
	if not bool(validation.get("success", false)):
		return validation
	var normalized := str(validation.get("path", ""))

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


func _text_file_error(message: String, path: String) -> Dictionary:
	return {
		"success": false,
		"error": message,
		"error_code": TEXT_FILE_ERROR_CODE,
		"data": {
			"code": TEXT_FILE_ERROR_CODE,
			"path": path,
			"extension": path.get_extension()
		},
		"hints": [
			"Use text resources such as .gd, .cs, .tscn, .tres, .json, .cfg, .md, .txt, .shader, .yml, or .xml.",
			"Use Godot import/resource APIs for binary scenes, binary resources, images, audio, fonts, and .import/.uid metadata."
		]
	}


func _validate_text_extension(path: String, context: String) -> Dictionary:
	var ext := ".%s" % path.get_extension().to_lower()
	if ext == ".":
		return {}
	if _BINARY_TEXT_WRITE_EXTENSIONS.has(ext):
		return _text_file_error("%s targets a binary or generated file extension that is not safe for text operations: %s" % [context.capitalize(), ext], path)
	return {}


func _looks_like_text_file(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var length := int(file.get_length())
	var sample_size := min(length, _TEXT_SAMPLE_BYTES)
	var sample := file.get_buffer(sample_size)
	file.close()
	for byte_value in sample:
		if int(byte_value) == 0:
			return false
	return true


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
