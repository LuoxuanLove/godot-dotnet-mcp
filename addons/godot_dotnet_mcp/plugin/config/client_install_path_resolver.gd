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
	var changed := _manual_paths != normalized_paths
	_manual_paths = normalized_paths
	return changed


func resolve_executable_path(client_id: String, candidates: Array, where_aliases: Array, extra_candidates: Array = []) -> Dictionary:
	var manual_path = str(_manual_paths.get(client_id, ""))
	var has_manual_path := not manual_path.is_empty()
	var manual_path_invalid := has_manual_path and not _file_exists(manual_path)

	if has_manual_path and not manual_path_invalid:
		return _build_result(manual_path, "manual_path", true, true, false, manual_path)

	for candidate in candidates:
		var normalized_candidate = normalize_path(str(candidate))
		if not normalized_candidate.is_empty() and _file_exists(normalized_candidate):
			return _build_result(normalized_candidate, "common_path", false, has_manual_path, manual_path_invalid, manual_path)

	for candidate in extra_candidates:
		var normalized_extra = normalize_path(str(candidate))
		if not normalized_extra.is_empty() and _file_exists(normalized_extra):
			return _build_result(normalized_extra, "common_path", false, has_manual_path, manual_path_invalid, manual_path)

	for alias in where_aliases:
		for where_path in _collect_where_paths(alias):
			var normalized_where = normalize_path(str(where_path))
			if not normalized_where.is_empty():
				return _build_result(normalized_where, "where", false, has_manual_path, manual_path_invalid, manual_path)

	return _build_result("", "", false, has_manual_path, manual_path_invalid, manual_path)


func normalize_path(path: String) -> String:
	return path.strip_edges().replace("\\", "/")


func _build_result(path: String, detected_via: String, using_manual_path: bool, has_manual_path: bool, manual_path_invalid: bool, manual_path: String) -> Dictionary:
	return {
		"path": path,
		"detected_via": detected_via,
		"using_manual_path": using_manual_path,
		"has_manual_path": has_manual_path,
		"manual_path_invalid": manual_path_invalid,
		"manual_path": manual_path
	}


func _file_exists(path: String) -> bool:
	return FileAccess.file_exists(ProjectSettings.globalize_path(normalize_path(path)))


func _collect_where_paths(_command_name: String) -> Array[String]:
	return []
