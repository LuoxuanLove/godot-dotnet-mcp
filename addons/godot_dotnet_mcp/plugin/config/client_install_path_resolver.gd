@tool
extends RefCounted
class_name ClientInstallPathResolver

var _manual_paths: Dictionary = {}


func configure(settings: Dictionary) -> bool:
	var candidate_paths = settings.get("client_manual_paths", {})
	var normalized_paths := {}
	if candidate_paths is Dictionary:
		for key in candidate_paths.keys():
			var normalized = normalize_path(str(candidate_paths[key]))
			if not normalized.is_empty():
				normalized_paths[str(key)] = normalized
	if _manual_paths == normalized_paths:
		return false
	_manual_paths = normalized_paths
	return true


func resolve_executable_path(
	client_id: String,
	candidates: Array[String],
	where_aliases: Array[String],
	extra_candidates: Array[String] = []
) -> Dictionary:
	var manual_path = normalize_path(str(_manual_paths.get(client_id, "")))
	var has_manual_path = not manual_path.is_empty()
	if has_manual_path and _file_exists(manual_path):
		return {
			"path": manual_path,
			"detected_via": "manual",
			"using_manual_path": true,
			"has_manual_path": true,
			"manual_path_invalid": false,
			"manual_path": manual_path
		}

	var existing_candidates = _collect_existing_candidates(candidates)
	if not existing_candidates.is_empty():
		return {
			"path": existing_candidates[0],
			"detected_via": "common_path",
			"using_manual_path": false,
			"has_manual_path": has_manual_path,
			"manual_path_invalid": has_manual_path,
			"manual_path": manual_path
		}

	var existing_extra_candidates = _collect_existing_candidates(extra_candidates)
	if not existing_extra_candidates.is_empty():
		return {
			"path": existing_extra_candidates[0],
			"detected_via": "windows_store",
			"using_manual_path": false,
			"has_manual_path": has_manual_path,
			"manual_path_invalid": has_manual_path,
			"manual_path": manual_path
		}

	for alias in where_aliases:
		var where_paths = _collect_where_paths(alias)
		if where_paths.is_empty():
			continue
		return {
			"path": where_paths[0],
			"detected_via": "where",
			"using_manual_path": false,
			"has_manual_path": has_manual_path,
			"manual_path_invalid": has_manual_path,
			"manual_path": manual_path
		}

	return {
		"path": "",
		"detected_via": "",
		"using_manual_path": false,
		"has_manual_path": has_manual_path,
		"manual_path_invalid": has_manual_path,
		"manual_path": manual_path
	}


func collect_appx_package_candidates(package_name: String, relative_paths: Array[String]) -> Array[String]:
	var command = "Get-AppxPackage -Name '%s' | Sort-Object Version -Descending | Select-Object -ExpandProperty InstallLocation" % [
		package_name.replace("'", "''")
	]
	var command_result = _run_process(
		"powershell.exe",
		PackedStringArray(["-NoProfile", "-Command", command])
	)
	if int(command_result.get("exit_code", -1)) != 0:
		return []

	var candidates: Array[String] = []
	for chunk in command_result.get("output", []):
		var text = str(chunk).replace("\r", "\n")
		for line in text.split("\n", false):
			var package_dir = normalize_path(line.trim_suffix("\\"))
			if package_dir.is_empty():
				continue
			for relative_path in relative_paths:
				var normalized_relative = str(relative_path).replace("\\", "/").trim_prefix("/")
				var candidate = normalize_path("%s/%s" % [package_dir, normalized_relative])
				if not candidate.is_empty():
					candidates.append(candidate)
	return candidates


func normalize_path(path: String) -> String:
	return path.replace("\\", "/").strip_edges().trim_suffix("/")


func _collect_where_paths(command_name: String) -> Array[String]:
	var command_result = _run_process("where.exe", PackedStringArray([command_name]))
	if int(command_result.get("exit_code", -1)) != 0:
		return []

	var lines: Array[String] = []
	for chunk in command_result.get("output", []):
		var text = str(chunk).replace("\r", "\n")
		for line in text.split("\n", false):
			var normalized = normalize_path(line)
			if not normalized.is_empty() and _file_exists(normalized):
				lines.append(normalized)
	return lines


func _collect_existing_candidates(candidates: Array[String]) -> Array[String]:
	var results: Array[String] = []
	for candidate in candidates:
		var normalized = normalize_path(candidate)
		if normalized.is_empty():
			continue
		if _file_exists(normalized):
			results.append(normalized)
	return results


func _run_process(executable: String, arguments: PackedStringArray) -> Dictionary:
	var output: Array = []
	var exit_code = OS.execute(executable, arguments, output, true, false)
	return {
		"exit_code": exit_code,
		"output": output
	}


func _file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func get_home_root() -> String:
	return normalize_path(OS.get_environment("USERPROFILE"))


func get_app_data_root() -> String:
	return normalize_path(OS.get_environment("APPDATA"))


func get_local_app_data_root() -> String:
	return normalize_path(OS.get_environment("LOCALAPPDATA"))


func get_program_files_root() -> String:
	var value = normalize_path(OS.get_environment("ProgramFiles"))
	return "C:/Program Files" if value.is_empty() else value


func get_secondary_program_files_root() -> String:
	var primary = get_program_files_root()
	if primary == "E:/Program Files":
		return "C:/Program Files"
	if primary == "C:/Program Files":
		return "E:/Program Files"
	return "E:/Program Files"
