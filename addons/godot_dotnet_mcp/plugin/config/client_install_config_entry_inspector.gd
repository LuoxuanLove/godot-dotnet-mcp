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


func inspect_config_entry(config_path: String, config_type: String = "") -> Dictionary:
	if config_path.is_empty() or not _file_exists(config_path):
		return {
			"status": ENTRY_MISSING_FILE,
			"has_server_entry": false
		}

	var text = _read_text_file(config_path)
	if text == null:
		return {
			"status": ENTRY_MISSING_FILE,
			"has_server_entry": false
		}
	if text.strip_edges().is_empty():
		return {
			"status": ENTRY_EMPTY,
			"has_server_entry": false
		}

	var json = JSON.new()
	if json.parse(text) != OK:
		return {
			"status": ENTRY_INVALID_JSON,
			"has_server_entry": false
		}

	var root = json.get_data()
	if not (root is Dictionary):
		return {
			"status": ENTRY_INCOMPATIBLE_ROOT,
			"has_server_entry": false
		}

	var server_key = "mcp" if config_type == "opencode" else "mcpServers"
	var mcp_servers = root.get(server_key, {})
	if not (mcp_servers is Dictionary):
		return {
			"status": ENTRY_INCOMPATIBLE_SERVERS,
			"has_server_entry": false
		}

	if not mcp_servers.has("godot-mcp"):
		return {
			"status": ENTRY_MISSING_SERVER,
			"has_server_entry": false
		}

	return {
		"status": ENTRY_PRESENT,
		"has_server_entry": true
	}


func can_prepare_file_path(file_path: String) -> bool:
	var dir_path = normalize_path(file_path.get_base_dir())
	if dir_path.is_empty():
		return false
	return _has_existing_ancestor(dir_path)


func normalize_path(path: String) -> String:
	return path.replace("\\", "/").strip_edges().trim_suffix("/")


func _has_existing_ancestor(path: String) -> bool:
	var current = normalize_path(path)
	while not current.is_empty():
		if _dir_exists(current):
			return true
		var parent = current.get_base_dir()
		if parent == current:
			break
		current = normalize_path(parent)
	return false


func _read_text_file(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return null
	var text = file.get_as_text()
	file.close()
	return text


func _file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func _dir_exists(path: String) -> bool:
	return DirAccess.dir_exists_absolute(path)
