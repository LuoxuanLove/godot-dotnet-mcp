@tool
extends RefCounted
class_name CentralServerRuntimeFilesService

var _local_install_relative_dir := "GodotDotnetMcp/CentralServer/runtime"
var _download_cache_relative_dir := "GodotDotnetMcp/CentralServer/downloads"
var _log_relative_dir := "GodotDotnetMcp/CentralServer/logs"
var _install_metadata_name := "central_server_install.json"


func configure(layout: Dictionary = {}) -> void:
	_local_install_relative_dir = str(layout.get("local_install_relative_dir", _local_install_relative_dir))
	_download_cache_relative_dir = str(layout.get("download_cache_relative_dir", _download_cache_relative_dir))
	_log_relative_dir = str(layout.get("log_relative_dir", _log_relative_dir))
	_install_metadata_name = str(layout.get("install_metadata_name", _install_metadata_name))


func normalize_path(path_value: String) -> String:
	return path_value.strip_edges().replace("\\", "/").trim_suffix("/")


func get_local_install_dir() -> String:
	return _join_local_app_data_relative_path(_local_install_relative_dir)


func get_download_cache_dir() -> String:
	return _join_local_app_data_relative_path(_download_cache_relative_dir)


func get_log_dir() -> String:
	return _join_local_app_data_relative_path(_log_relative_dir)


func get_log_file_path() -> String:
	return "%s/central_server.log" % get_log_dir()


func get_install_metadata_path(install_dir: String) -> String:
	return "%s/%s" % [normalize_path(install_dir), _install_metadata_name]


func write_install_manifest(install_dir: String, manifest: Dictionary) -> int:
	var metadata_path = get_install_metadata_path(install_dir)
	var file = FileAccess.open(metadata_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(manifest, "\t"))
	return OK


func load_install_manifest(install_dir: String) -> Dictionary:
	var metadata_path = get_install_metadata_path(install_dir)
	if not FileAccess.file_exists(metadata_path):
		return {}
	var file = FileAccess.open(metadata_path, FileAccess.READ)
	if file == null:
		return {}
	var raw = file.get_as_text()
	var parsed = JSON.parse_string(raw)
	if parsed is Dictionary:
		return parsed
	return {}


func open_install_directory() -> Dictionary:
	var install_dir = get_local_install_dir()
	if not DirAccess.dir_exists_absolute(install_dir):
		return {
			"success": false,
			"message": "The local central server install directory does not exist yet."
		}
	return _shell_open_target(install_dir, "Opened the local central server install directory.")


func open_log_location() -> Dictionary:
	var log_file_path = get_log_file_path()
	if FileAccess.file_exists(log_file_path):
		return _shell_open_target(log_file_path, "Opened the local central server log file.")

	var log_dir = get_log_dir()
	var ensure_dir = DirAccess.make_dir_recursive_absolute(log_dir)
	if ensure_dir != OK:
		return {
			"success": false,
			"message": "Failed to prepare the local central server log directory."
		}
	return _shell_open_target(log_dir, "Opened the local central server log directory.")


func _join_local_app_data_relative_path(relative_path: String) -> String:
	var base_dir = OS.get_environment("LOCALAPPDATA").strip_edges()
	if base_dir.is_empty():
		base_dir = ProjectSettings.globalize_path("user://godot_dotnet_mcp/central_server")
	return normalize_path("%s/%s" % [base_dir.replace("\\", "/").trim_suffix("/"), relative_path])


func _shell_open_target(target_path: String, success_message: String) -> Dictionary:
	var normalized_path = str(target_path).strip_edges()
	if normalized_path.is_empty():
		return {
			"success": false,
			"message": "Failed to open the requested local central server path."
		}

	if OS.get_name() == "Windows":
		var absolute_path = ProjectSettings.globalize_path(normalized_path)
		var pid := 0
		if FileAccess.file_exists(absolute_path):
			pid = OS.create_process("explorer.exe", PackedStringArray(["/select,%s" % absolute_path]), false)
		elif DirAccess.dir_exists_absolute(absolute_path):
			pid = OS.create_process("explorer.exe", PackedStringArray([absolute_path]), false)
		if pid > 0:
			return {
				"success": true,
				"message": success_message,
				"path": absolute_path
			}
		if not absolute_path.is_empty():
			return {
				"success": false,
				"message": "Failed to open the requested local central server path."
			}

	var open_error = OS.shell_open(normalized_path)
	if open_error != OK:
		return {
			"success": false,
			"message": "Failed to open the requested local central server path."
		}
	return {
		"success": true,
		"message": success_message,
		"path": normalized_path
	}
