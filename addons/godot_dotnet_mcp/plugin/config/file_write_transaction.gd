@tool
extends RefCounted
class_name FileWriteTransaction


static func write_text_atomically(file_path: String, text: String) -> Dictionary:
	var dir_path := file_path.get_base_dir()
	if not dir_path.is_empty() and dir_path != ".":
		var dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
		if dir_error != OK:
			return {"success": false, "error_code": "make_dir_failed", "file_path": file_path}
	var temp_path := build_sidecar_path(file_path, "tmp")
	var backup_path := build_sidecar_path(file_path, "bak")
	var temp_file := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp_file == null:
		return {"success": false, "error_code": "write_open_failed", "file_path": file_path}
	temp_file.store_string(text)
	temp_file.close()
	if FileAccess.get_file_as_string(temp_path) != text:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		return {"success": false, "error_code": "write_verify_failed", "file_path": file_path}
	var absolute_path := ProjectSettings.globalize_path(file_path)
	var absolute_temp_path := ProjectSettings.globalize_path(temp_path)
	var absolute_backup_path := ProjectSettings.globalize_path(backup_path)
	var had_existing := FileAccess.file_exists(file_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup_path)
	if had_existing:
		var backup_error := DirAccess.rename_absolute(absolute_path, absolute_backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(absolute_temp_path)
			return {"success": false, "error_code": "backup_failed", "file_path": file_path}
	var replace_error := DirAccess.rename_absolute(absolute_temp_path, absolute_path)
	if replace_error != OK:
		if had_existing and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup_path, absolute_path)
		DirAccess.remove_absolute(absolute_temp_path)
		return {"success": false, "error_code": "replace_failed", "file_path": file_path}
	if had_existing and FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup_path)
	return {"success": true, "file_path": file_path}


static func build_sidecar_path(file_path: String, extension: String) -> String:
	var dir_path := file_path.get_base_dir()
	var file_name := file_path.get_file()
	var suffix := "%s-%s" % [str(Time.get_ticks_usec()), str(randi())]
	var sidecar_name := ".%s.%s.%s" % [file_name, suffix, extension]
	if dir_path.is_empty() or dir_path == ".":
		return sidecar_name
	return dir_path.path_join(sidecar_name)
