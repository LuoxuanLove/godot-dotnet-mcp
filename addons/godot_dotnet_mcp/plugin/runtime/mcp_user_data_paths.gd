@tool
extends RefCounted
class_name MCPUserDataPaths

const ROOT := "user://godot_dotnet_mcp"
const CONFIG_EXCHANGE_ROOT := ROOT + "/config_exchange"
const CAPTURES_ROOT := ROOT + "/captures"
const EDITOR_CAPTURE_DIR := CAPTURES_ROOT + "/editor"
const EDITOR_CONTROL_CAPTURE_DIR := CAPTURES_ROOT + "/editor_controls"
const RUNTIME_ROOT := ROOT + "/runtime"
const RUNTIME_CAPTURE_ROOT := RUNTIME_ROOT + "/captures"
const RUNTIME_EVENTS_PATH := RUNTIME_ROOT + "/events.json"
const LOGS_ROOT := ROOT + "/logs"
const USER_TOOL_AUDIT_LOG_PATH := LOGS_ROOT + "/user_tool_audit.log"
const PROFILE_STORAGE_DIR := ROOT + "/profiles"

const LEGACY_EDITOR_CAPTURE_DIR := "user://godot_mcp_editor_captures"
const LEGACY_RUNTIME_CAPTURE_ROOT := "user://godot_mcp_runtime_captures"
const LEGACY_RUNTIME_EVENTS_PATH := "user://godot_mcp_runtime_bridge_events.json"
const LEGACY_USER_TOOL_AUDIT_LOG_PATH := "user://godot_dotnet_mcp_user_tool_audit.log"
const LEGACY_PROFILE_STORAGE_DIR := "user://godot_dotnet_mcp_tool_profiles"

const LEGACY_ROOT_CACHE_PREFIXES := [
	"activate_",
	"final_mcpdock_",
	"mcpdock_",
	"orbitdock_",
	"inspector_",
	"mcp_validation_",
	"editor_executor_"
]


static func initialize_layout(clean_legacy: bool = false) -> Dictionary:
	var result := {
		"created": [],
		"migrated": [],
		"removed": [],
		"candidates": [],
		"errors": []
	}
	for dir_path in [ROOT, CAPTURES_ROOT, EDITOR_CAPTURE_DIR, EDITOR_CONTROL_CAPTURE_DIR, RUNTIME_ROOT, RUNTIME_CAPTURE_ROOT, LOGS_ROOT, PROFILE_STORAGE_DIR, CONFIG_EXCHANGE_ROOT]:
		_ensure_dir(dir_path, result)
	if clean_legacy:
		var cleanup_result := cleanup_legacy_cache(false)
		for key in ["migrated", "removed", "candidates", "errors"]:
			(result[key] as Array).append_array(cleanup_result.get(key, []))
	return result


static func cleanup_legacy_cache(dry_run: bool = true) -> Dictionary:
	var result := {
		"dry_run": dry_run,
		"migrated": [],
		"removed": [],
		"candidates": [],
		"errors": []
	}
	_collect_legacy_candidates(result)
	if dry_run:
		return result
	initialize_layout(false)
	_migrate_file(LEGACY_RUNTIME_EVENTS_PATH, RUNTIME_EVENTS_PATH, result)
	_migrate_file(LEGACY_USER_TOOL_AUDIT_LOG_PATH, USER_TOOL_AUDIT_LOG_PATH, result)
	_migrate_directory(LEGACY_PROFILE_STORAGE_DIR, PROFILE_STORAGE_DIR, result)
	_cleanup_legacy_root_pngs(result)
	_remove_directory_recursive(LEGACY_EDITOR_CAPTURE_DIR, result)
	_remove_directory_recursive(LEGACY_RUNTIME_CAPTURE_ROOT, result)
	_remove_empty_dir(LEGACY_PROFILE_STORAGE_DIR, result)
	return result


static func editor_capture_path(filename: String) -> String:
	return "%s/%s" % [EDITOR_CAPTURE_DIR, sanitize_filename(filename)]


static func editor_control_capture_path(filename: String) -> String:
	return "%s/%s" % [EDITOR_CONTROL_CAPTURE_DIR, sanitize_filename(filename)]


static func normalize_editor_capture_output_path(requested_path: String, default_filename: String) -> String:
	return _normalize_managed_output_path(requested_path, EDITOR_CAPTURE_DIR, default_filename)


static func normalize_editor_control_capture_output_path(requested_path: String, default_filename: String) -> String:
	return _normalize_managed_output_path(requested_path, EDITOR_CONTROL_CAPTURE_DIR, default_filename)


static func sanitize_filename(raw_label: String) -> String:
	var sanitized := raw_label.strip_edges()
	if sanitized.is_empty():
		sanitized = "capture"
	for ch in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", " "]:
		sanitized = sanitized.replace(ch, "_")
	return sanitized


static func _normalize_managed_output_path(requested_path: String, default_dir: String, default_filename: String) -> String:
	var path := requested_path.strip_edges()
	if path.is_empty():
		return "%s/%s" % [default_dir, sanitize_filename(default_filename)]
	if path.begins_with("user://"):
		var relative := path.trim_prefix("user://").strip_edges()
		if not relative.contains("/") and not relative.contains("\\"):
			return "%s/%s" % [default_dir, sanitize_filename(relative)]
	return path


static func _ensure_dir(dir_path: String, result: Dictionary) -> void:
	var absolute := ProjectSettings.globalize_path(dir_path)
	if DirAccess.dir_exists_absolute(absolute):
		return
	var error := DirAccess.make_dir_recursive_absolute(absolute)
	if error == OK:
		(result["created"] as Array).append(dir_path)
	else:
		(result["errors"] as Array).append({"path": dir_path, "error": error_string(error)})


static func _migrate_file(from_path: String, to_path: String, result: Dictionary) -> void:
	if not FileAccess.file_exists(from_path):
		return
	_ensure_dir(to_path.get_base_dir(), result)
	if not FileAccess.file_exists(to_path):
		var copy_error := DirAccess.copy_absolute(ProjectSettings.globalize_path(from_path), ProjectSettings.globalize_path(to_path))
		if copy_error == OK:
			(result["migrated"] as Array).append({"from": from_path, "to": to_path})
		else:
			(result["errors"] as Array).append({"path": from_path, "error": error_string(copy_error)})
			return
	var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(from_path))
	if remove_error == OK:
		(result["removed"] as Array).append(from_path)


static func _migrate_directory(from_dir: String, to_dir: String, result: Dictionary) -> void:
	var absolute_from := ProjectSettings.globalize_path(from_dir)
	if not DirAccess.dir_exists_absolute(absolute_from):
		return
	_ensure_dir(to_dir, result)
	var dir := DirAccess.open(from_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir():
			_migrate_file("%s/%s" % [from_dir, entry], "%s/%s" % [to_dir, entry], result)
		entry = dir.get_next()
	dir.list_dir_end()


static func _cleanup_legacy_root_pngs(result: Dictionary) -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and entry.to_lower().ends_with(".png") and _is_legacy_root_cache_file(entry):
			var path := "user://%s" % entry
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			if error == OK:
				(result["removed"] as Array).append(path)
		entry = dir.get_next()
	dir.list_dir_end()


static func _collect_legacy_candidates(result: Dictionary) -> void:
	_add_file_candidate(LEGACY_RUNTIME_EVENTS_PATH, RUNTIME_EVENTS_PATH, result)
	_add_file_candidate(LEGACY_USER_TOOL_AUDIT_LOG_PATH, USER_TOOL_AUDIT_LOG_PATH, result)
	_collect_profile_candidates(result)
	_collect_root_png_candidates(result)
	_add_directory_candidate(LEGACY_EDITOR_CAPTURE_DIR, result)
	_add_directory_candidate(LEGACY_RUNTIME_CAPTURE_ROOT, result)
	_add_directory_candidate(LEGACY_PROFILE_STORAGE_DIR, result)


static func _add_file_candidate(from_path: String, to_path: String, result: Dictionary) -> void:
	if FileAccess.file_exists(from_path):
		(result["candidates"] as Array).append({"type": "file", "from": from_path, "to": to_path, "action": "migrate"})


static func _add_directory_candidate(dir_path: String, result: Dictionary) -> void:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		var action := "remove_recursive" if dir_path in [LEGACY_EDITOR_CAPTURE_DIR, LEGACY_RUNTIME_CAPTURE_ROOT] else "remove_if_empty"
		(result["candidates"] as Array).append({"type": "directory", "path": dir_path, "action": action})


static func _collect_profile_candidates(result: Dictionary) -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(LEGACY_PROFILE_STORAGE_DIR)):
		return
	var dir := DirAccess.open(LEGACY_PROFILE_STORAGE_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir():
			(result["candidates"] as Array).append({
				"type": "file",
				"from": "%s/%s" % [LEGACY_PROFILE_STORAGE_DIR, entry],
				"to": "%s/%s" % [PROFILE_STORAGE_DIR, entry],
				"action": "migrate"
			})
		entry = dir.get_next()
	dir.list_dir_end()


static func _collect_root_png_candidates(result: Dictionary) -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and entry.to_lower().ends_with(".png") and _is_legacy_root_cache_file(entry):
			(result["candidates"] as Array).append({"type": "file", "path": "user://%s" % entry, "action": "remove"})
		entry = dir.get_next()
	dir.list_dir_end()


static func _is_legacy_root_cache_file(filename: String) -> bool:
	for prefix in LEGACY_ROOT_CACHE_PREFIXES:
		if filename.begins_with(str(prefix)):
			return true
	return false


static func _remove_empty_dir(dir_path: String, result: Dictionary) -> void:
	var absolute := ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		dir.list_dir_end()
		return
	dir.list_dir_end()
	var error := DirAccess.remove_absolute(absolute)
	if error == OK:
		(result["removed"] as Array).append(dir_path)


static func _remove_directory_recursive(dir_path: String, result: Dictionary) -> void:
	var absolute := ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	_remove_directory_contents(dir_path, result)
	var error := DirAccess.remove_absolute(absolute)
	if error == OK:
		(result["removed"] as Array).append(dir_path)
	else:
		(result["errors"] as Array).append({"path": dir_path, "error": error_string(error)})


static func _remove_directory_contents(dir_path: String, result: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var child_path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			_remove_directory_recursive(child_path, result)
		else:
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(child_path))
			if error == OK:
				(result["removed"] as Array).append(child_path)
			else:
				(result["errors"] as Array).append({"path": child_path, "error": error_string(error)})
		entry = dir.get_next()
	dir.list_dir_end()
