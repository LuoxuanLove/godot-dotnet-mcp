@tool
extends RefCounted
class_name ClientInstallConfigEntryInspector

const ENTRY_PRESENT := "present"
const ENTRY_MISSING_FILE := "missing_file"
const ENTRY_EMPTY := "empty"
const ENTRY_MISSING_SERVER := "missing_server"
const ENTRY_INVALID_JSON := "invalid_json"
const ENTRY_INCOMPATIBLE_ROOT := "incompatible_root"
const ENTRY_INCOMPATIBLE_SERVERS := "incompatible_mcp_servers"
const MCP_SERVER_KEY := "godot-mcp"


func inspect_config_entry(file_path: String, config_type: String = "") -> Dictionary:
	if not _file_exists(file_path):
		return _build_result(file_path, config_type, ENTRY_MISSING_FILE, false)

	var read_result = _read_text_file(file_path)
	if read_result == null:
		return _build_result(file_path, config_type, ENTRY_MISSING_FILE, false)

	var text = str(read_result)
	if text.strip_edges().is_empty():
		return _build_result(file_path, config_type, ENTRY_EMPTY, false)

	var json = JSON.new()
	if json.parse(text) != OK:
		return _build_result(file_path, config_type, ENTRY_INVALID_JSON, false)

	var root = json.get_data()
	if not (root is Dictionary):
		return _build_result(file_path, config_type, ENTRY_INCOMPATIBLE_ROOT, false)

	var container_key = _get_server_container_key(config_type)
	if not root.has(container_key):
		return _build_result(file_path, config_type, ENTRY_MISSING_SERVER, false)

	var servers = root.get(container_key, {})
	if not (servers is Dictionary):
		return _build_result(file_path, config_type, ENTRY_INCOMPATIBLE_SERVERS, false)

	if servers.is_empty() or not servers.has(MCP_SERVER_KEY):
		return _build_result(file_path, config_type, ENTRY_MISSING_SERVER, false)

	return _build_result(file_path, config_type, ENTRY_PRESENT, true)


func can_prepare_file_path(file_path: String) -> bool:
	return _dir_exists(ProjectSettings.globalize_path(file_path).get_base_dir())


func normalize_path(path: String) -> String:
	return path.strip_edges().replace("\\", "/")


func _build_result(file_path: String, config_type: String, status: String, has_server_entry: bool) -> Dictionary:
	return {
		"success": true,
		"path": file_path,
		"config_type": config_type,
		"status": status,
		"has_server_entry": has_server_entry
	}


func _get_server_container_key(config_type: String) -> String:
	return "mcp" if config_type == "opencode" else "mcpServers"


func _file_exists(path: String) -> bool:
	return FileAccess.file_exists(ProjectSettings.globalize_path(normalize_path(path)))


func _read_text_file(file_path: String):
	var absolute_path := ProjectSettings.globalize_path(normalize_path(file_path))
	var file = FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return null
	var text = file.get_as_text()
	file.close()
	return text


func _dir_exists(path: String) -> bool:
	return DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(normalize_path(path)))
