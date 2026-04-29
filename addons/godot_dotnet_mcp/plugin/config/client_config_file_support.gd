@tool
extends RefCounted
class_name ClientConfigFileSupport


func can_prepare_file_path(file_path: String) -> bool:
	var absolute_path := ProjectSettings.globalize_path(file_path)
	return _dir_exists(absolute_path.get_base_dir())


func _dir_exists(path: String) -> bool:
	return DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path))
