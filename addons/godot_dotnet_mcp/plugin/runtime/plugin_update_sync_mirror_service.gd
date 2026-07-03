@tool
extends RefCounted
class_name PluginUpdateSyncMirrorService

const UPDATE_SYNC_ADDON_PREFIX := "addons/godot_dotnet_mcp/"
const UPDATE_SYNC_STALE_ADDON_FILES := [
	"tools/animation_tools.gd",
	"tools/animation_tools.gd.uid",
	"tools/audio_tools.gd",
	"tools/audio_tools.gd.uid",
	"tools/filesystem_tools.gd",
	"tools/filesystem_tools.gd.uid",
	"tools/geometry_tools.gd",
	"tools/geometry_tools.gd.uid",
	"tools/group_tools.gd",
	"tools/group_tools.gd.uid",
	"tools/lighting_tools.gd",
	"tools/lighting_tools.gd.uid",
	"tools/material_tools.gd",
	"tools/material_tools.gd.uid",
	"tools/navigation_tools.gd",
	"tools/navigation_tools.gd.uid",
	"tools/node_tools.gd",
	"tools/node_tools.gd.uid",
	"tools/particle_tools.gd",
	"tools/particle_tools.gd.uid",
	"tools/physics_tools.gd",
	"tools/physics_tools.gd.uid",
	"tools/project_tools.gd",
	"tools/project_tools.gd.uid",
	"tools/resource_tools.gd",
	"tools/resource_tools.gd.uid",
	"tools/scene_tools.gd",
	"tools/scene_tools.gd.uid",
	"tools/script_tools.gd",
	"tools/script_tools.gd.uid",
	"tools/shader_tools.gd",
	"tools/shader_tools.gd.uid",
	"tools/signal_tools.gd",
	"tools/signal_tools.gd.uid",
	"tools/tilemap_tools.gd",
	"tools/tilemap_tools.gd.uid",
	"tools/ui_tools.gd",
	"tools/ui_tools.gd.uid"
]


func sync_archive_to_addon(archive_path: String, addon_root_path: String) -> Dictionary:
	var reader := ZIPReader.new()
	var open_error := reader.open(archive_path)
	if open_error != OK:
		return {"success": false, "error": "Failed to open branch archive: %s" % open_error}
	var files := reader.get_files()
	var archive_prefix := find_archive_addon_prefix(files)
	if archive_prefix.is_empty():
		reader.close()
		return {"success": false, "error": "Branch archive does not contain addons/godot_dotnet_mcp."}
	var addon_root := addon_root_path.simplify_path()
	if is_link_path(addon_root):
		reader.close()
		return {"success": false, "error": "Update sync addon root must not be a symlink, junction, or reparse point: %s" % addon_root}
	var addon_root_prefix := "%s/" % addon_root
	var expected_files: Dictionary = {}
	for file_path in files:
		if file_path.ends_with("/") or not file_path.begins_with(archive_prefix):
			continue
		var relative_path := normalize_relative_path(file_path.substr(archive_prefix.length()))
		if should_skip_path(relative_path):
			continue
		var target_path := addon_root.path_join(relative_path).simplify_path()
		if target_path != addon_root and not target_path.begins_with(addon_root_prefix):
			reader.close()
			return {"success": false, "error": "Update archive entry escapes the plugin directory: %s" % relative_path}
		expected_files[relative_path] = true
	var completeness_error := validate_archive_files(expected_files)
	if not completeness_error.is_empty():
		reader.close()
		return {"success": false, "error": completeness_error}
	var entries: Array[Dictionary] = []
	for file_path in files:
		if file_path.ends_with("/") or not file_path.begins_with(archive_prefix):
			continue
		var relative_path := normalize_relative_path(file_path.substr(archive_prefix.length()))
		if should_skip_path(relative_path):
			continue
		var target_path := addon_root.path_join(relative_path).simplify_path()
		if not is_path_inside_root(addon_root, target_path):
			reader.close()
			return {"success": false, "error": "Update archive entry escapes the plugin directory: %s" % relative_path}
		if is_path_or_ancestor_link(addon_root, relative_path):
			reader.close()
			return {"success": false, "error": "Update archive target traverses a symlink, junction, or reparse point: %s" % relative_path}
		entries.append({
			"archive_path": str(file_path),
			"relative_path": relative_path,
			"target_path": target_path
		})
	if entries.is_empty():
		reader.close()
		return {"success": false, "error": "Branch archive contained no plugin files to sync."}
	var written := 0
	var rollback_state: Dictionary = {}
	for entry in entries:
		var relative_path := str(entry.get("relative_path", ""))
		var target_path := str(entry.get("target_path", ""))
		var target_dir := target_path.get_base_dir()
		var dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_dir))
		if dir_error != OK:
			reader.close()
			_rollback_written_files(rollback_state)
			return _dirty_sync_error("Failed to create directory %s: %s" % [target_dir, dir_error])
		if is_path_or_ancestor_link(addon_root, relative_path):
			reader.close()
			_rollback_written_files(rollback_state)
			return _dirty_sync_error("Update archive target traverses a symlink, junction, or reparse point: %s" % relative_path)
		var archive_entry_path := str(entry.get("archive_path", ""))
		var content := reader.read_file(archive_entry_path)
		var backup_result := _remember_rollback_state(rollback_state, target_path)
		if not bool(backup_result.get("success", false)):
			reader.close()
			_rollback_written_files(rollback_state)
			return _dirty_sync_error(str(backup_result.get("error", "Failed to prepare rollback state for %s." % target_path)))
		var output := FileAccess.open(target_path, FileAccess.WRITE)
		if output == null:
			reader.close()
			_rollback_written_files(rollback_state)
			return _dirty_sync_error("Failed to write %s: %s" % [target_path, FileAccess.get_open_error()])
		output.store_buffer(content)
		output.close()
		var verify = FileAccess.get_file_as_bytes(target_path)
		if verify != content:
			reader.close()
			_rollback_written_files(rollback_state)
			return _dirty_sync_error("Failed to verify written update file: %s" % target_path)
		written += 1
	reader.close()
	var mirror_result := delete_stale_paths(addon_root, expected_files)
	if not bool(mirror_result.get("success", false)):
		_rollback_written_files(rollback_state)
		return _dirty_sync_error(str(mirror_result.get("error", "Failed to remove stale update files.")), true, false)
	return {
		"success": true,
		"written": written,
		"deleted": int(mirror_result.get("deleted", 0)),
		"deleted_files": int(mirror_result.get("deleted_files", 0)),
		"deleted_dirs": int(mirror_result.get("deleted_dirs", 0)),
		"skipped_links": int(mirror_result.get("skipped_links", 0))
	}


func cleanup_stale_addon_files(addon_root_path: String) -> Dictionary:
	var addon_root := addon_root_path.simplify_path()
	if addon_root.is_empty() or not addon_root.begins_with("res://") or is_link_path(addon_root):
		return {"success": false, "deleted": 0, "error": "Update sync addon root is invalid for stale cleanup: %s" % addon_root}
	var deleted := 0
	var skipped_links := 0
	for relative_path in UPDATE_SYNC_STALE_ADDON_FILES:
		var normalized := normalize_relative_path(str(relative_path))
		if normalized.is_empty() or should_skip_path(normalized):
			continue
		var stale_path := addon_root.path_join(normalized).simplify_path()
		if not is_path_inside_root(addon_root, stale_path):
			return {"success": false, "deleted": deleted, "error": "Stale update cleanup path escapes the plugin directory: %s" % normalized}
		if is_path_or_ancestor_link(addon_root, normalized):
			skipped_links += 1
			continue
		if FileAccess.file_exists(stale_path):
			var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(stale_path))
			if remove_error != OK and remove_error != ERR_FILE_NOT_FOUND:
				return {"success": false, "deleted": deleted, "error": "Failed to remove stale update file %s: %s" % [normalized, remove_error]}
			if remove_error == OK:
				deleted += 1
	return {"success": true, "deleted": deleted, "skipped_links": skipped_links}


func find_archive_addon_prefix(files: PackedStringArray) -> String:
	for file_path in files:
		var normalized := str(file_path).replace("\\", "/")
		var prefix_index := normalized.find(UPDATE_SYNC_ADDON_PREFIX)
		if prefix_index >= 0:
			return normalized.substr(0, prefix_index + UPDATE_SYNC_ADDON_PREFIX.length())
	return ""


func normalize_relative_path(relative_path: String) -> String:
	var normalized := relative_path.strip_edges().replace("\\", "/")
	while normalized.find("//") != -1:
		normalized = normalized.replace("//", "/")
	return normalized


func validate_archive_files(expected_files: Dictionary) -> String:
	for required_path in [
		"plugin.cfg",
		"plugin.gd",
		"ui/mcp_dock.tscn"
	]:
		if not expected_files.has(required_path):
			return "Branch archive is incomplete and cannot be mirrored safely; missing %s." % required_path
	return ""


func should_skip_path(relative_path: String) -> bool:
	var normalized := normalize_relative_path(relative_path)
	if normalized.is_empty() or normalized.begins_with("/") or normalized.begins_with("../") or normalized.ends_with("/..") or normalized.find("/../") != -1 or normalized.find(":") != -1:
		return true
	if normalized == ".git" or normalized.begins_with(".git/"):
		return true
	if normalized == "custom_tools" or normalized.begins_with("custom_tools/"):
		return true
	if normalized == ".import" or normalized.begins_with(".import/"):
		return true
	if normalized == "dotnet_bridge/bin" or normalized.begins_with("dotnet_bridge/bin/"):
		return true
	if normalized == "dotnet_bridge/obj" or normalized.begins_with("dotnet_bridge/obj/"):
		return true
	if normalized.ends_with(".import"):
		return true
	return false


func delete_stale_paths(addon_root: String, expected_files: Dictionary) -> Dictionary:
	var normalized_root := addon_root.simplify_path()
	if normalized_root.is_empty() or not normalized_root.begins_with("res://"):
		return {"success": false, "error": "Update sync addon root is invalid: %s" % addon_root}
	var absolute_root := ProjectSettings.globalize_path(normalized_root)
	if not DirAccess.dir_exists_absolute(absolute_root):
		return {"success": true, "deleted": 0, "deleted_files": 0, "deleted_dirs": 0, "skipped_links": 0}
	return _delete_stale_paths_recursive(normalized_root, "", expected_files)


func is_directory_empty(path: String) -> bool:
	if is_link_path(path):
		return false
	var dir := DirAccess.open(path)
	if dir == null:
		return false
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			dir.list_dir_end()
			return false
		entry = dir.get_next()
	dir.list_dir_end()
	return true


func is_path_inside_root(addon_root: String, path: String) -> bool:
	var root := addon_root.simplify_path()
	if root.ends_with("/"):
		root = root.substr(0, root.length() - 1)
	var normalized := path.simplify_path()
	return normalized == root or normalized.begins_with("%s/" % root)


func is_path_or_ancestor_link(addon_root: String, relative_path: String) -> bool:
	var normalized_root := addon_root.simplify_path()
	if is_link_path(normalized_root):
		return true
	var normalized_relative := normalize_relative_path(relative_path)
	if normalized_relative.is_empty():
		return false
	var parts := normalized_relative.split("/", false)
	var current := normalized_root
	for part in parts:
		current = current.path_join(str(part)).simplify_path()
		if is_link_path(current):
			return true
	return false


func is_link_path(path: String) -> bool:
	var parent_path := path.get_base_dir()
	var name := path.get_file()
	if parent_path.is_empty() or name.is_empty():
		return false
	var parent := DirAccess.open(parent_path)
	if parent == null:
		return false
	return parent.is_link(name)


func _dirty_sync_error(message: String, dirty: bool = false, recovered: bool = true) -> Dictionary:
	return {
		"success": false,
		"error": message,
		"dirty": dirty,
		"recovered": recovered
	}


func _remember_rollback_state(rollback_state: Dictionary, target_path: String) -> Dictionary:
	if rollback_state.has(target_path):
		return {"success": true}
	var absolute_path := ProjectSettings.globalize_path(target_path)
	var was_directory := DirAccess.dir_exists_absolute(absolute_path)
	var existed := FileAccess.file_exists(target_path)
	var content := PackedByteArray()
	if existed:
		content = FileAccess.get_file_as_bytes(target_path)
		if content.is_empty() and FileAccess.get_open_error() != OK:
			return {"success": false, "error": "Failed to read rollback backup for %s: %s" % [target_path, FileAccess.get_open_error()]}
	rollback_state[target_path] = {
		"existed": existed,
		"was_directory": was_directory,
		"content": content
	}
	return {"success": true}


func _rollback_written_files(rollback_state: Dictionary) -> void:
	for target_path in rollback_state.keys():
		var state: Dictionary = rollback_state.get(target_path, {})
		var existed := bool(state.get("existed", false))
		var was_directory := bool(state.get("was_directory", false))
		var absolute_path := ProjectSettings.globalize_path(str(target_path))
		if existed:
			var target_dir := str(target_path).get_base_dir()
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_dir))
			var file := FileAccess.open(str(target_path), FileAccess.WRITE)
			if file != null:
				file.store_buffer(state.get("content", PackedByteArray()))
				file.close()
		elif not was_directory:
			DirAccess.remove_absolute(absolute_path)


func _delete_stale_paths_recursive(addon_root: String, relative_dir: String, expected_files: Dictionary) -> Dictionary:
	var current_path := addon_root.path_join(relative_dir).simplify_path() if not relative_dir.is_empty() else addon_root
	if not is_path_inside_root(addon_root, current_path):
		return {"success": false, "error": "Update sync delete path escapes the plugin directory: %s" % current_path}
	if is_link_path(current_path):
		return {"success": true, "deleted": 0, "deleted_files": 0, "deleted_dirs": 0, "skipped_links": 1}
	var dir := DirAccess.open(current_path)
	if dir == null:
		return {"success": true, "deleted": 0, "deleted_files": 0, "deleted_dirs": 0, "skipped_links": 0}
	var child_dirs: Array[String] = []
	var stale_files: Array[String] = []
	var skipped_links := 0
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var child_relative := normalize_relative_path(relative_dir.path_join(entry) if not relative_dir.is_empty() else entry)
		if should_skip_path(child_relative):
			entry = dir.get_next()
			continue
		if dir.is_link(entry):
			skipped_links += 1
			entry = dir.get_next()
			continue
		if dir.current_is_dir():
			child_dirs.append(child_relative)
		elif not expected_files.has(child_relative):
			stale_files.append(child_relative)
		entry = dir.get_next()
	dir.list_dir_end()

	var deleted_files := 0
	var deleted_dirs := 0
	for stale_file in stale_files:
		var stale_path := addon_root.path_join(stale_file).simplify_path()
		if not is_path_inside_root(addon_root, stale_path):
			return {"success": false, "error": "Update sync delete path escapes the plugin directory: %s" % stale_file}
		if is_link_path(stale_path):
			skipped_links += 1
			continue
		var remove_file_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(stale_path))
		if remove_file_error != OK and remove_file_error != ERR_FILE_NOT_FOUND:
			return {"success": false, "error": "Failed to remove stale update file %s: %s" % [stale_file, remove_file_error]}
		if remove_file_error == OK:
			deleted_files += 1
	for child_dir in child_dirs:
		var child_result: Dictionary = _delete_stale_paths_recursive(addon_root, child_dir, expected_files)
		if not bool(child_result.get("success", false)):
			return child_result
		deleted_files += int(child_result.get("deleted_files", 0))
		deleted_dirs += int(child_result.get("deleted_dirs", 0))
		skipped_links += int(child_result.get("skipped_links", 0))
		var child_path := addon_root.path_join(child_dir).simplify_path()
		if is_link_path(child_path):
			skipped_links += 1
			continue
		if is_directory_empty(child_path):
			var remove_dir_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(child_path))
			if remove_dir_error != OK and remove_dir_error != ERR_FILE_NOT_FOUND:
				return {"success": false, "error": "Failed to remove empty stale update directory %s: %s" % [child_dir, remove_dir_error]}
			if remove_dir_error == OK:
				deleted_dirs += 1
	return {
		"success": true,
		"deleted": deleted_files + deleted_dirs,
		"deleted_files": deleted_files,
		"deleted_dirs": deleted_dirs,
		"skipped_links": skipped_links
	}
