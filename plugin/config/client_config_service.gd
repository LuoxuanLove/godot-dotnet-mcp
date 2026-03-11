@tool
extends RefCounted
class_name ClientConfigService

const ConfigPathsScript = preload("res://addons/godot_dotnet_mcp/plugin/config/config_paths.gd")


func get_claude_config_path() -> String:
	return ConfigPathsScript.get_claude_config_path()


func get_cursor_config_path() -> String:
	return ConfigPathsScript.get_cursor_config_path()


func get_gemini_config_path() -> String:
	return ConfigPathsScript.get_gemini_config_path()


func get_url_config(host: String, port: int) -> String:
	return ConfigPathsScript.get_url_config(host, port)


func get_http_url_config(host: String, port: int) -> String:
	return ConfigPathsScript.get_http_url_config(host, port)


func get_claude_code_command(scope: String, host: String, port: int) -> String:
	return ConfigPathsScript.get_claude_code_command(scope, host, port)


func get_codex_command(host: String, port: int) -> String:
	return ConfigPathsScript.get_codex_command(host, port)


func write_config_file(config_type: String, filepath: String, new_config: String) -> Dictionary:
	var json = JSON.new()
	if json.parse(new_config) != OK:
		return {"success": false, "error": "parse_error"}

	var new_config_data = json.get_data()
	var final_config: Dictionary = {}

	if FileAccess.file_exists(filepath):
		var file = FileAccess.open(filepath, FileAccess.READ)
		if file:
			var existing_text = file.get_as_text()
			file.close()
			if not existing_text.strip_edges().is_empty():
				if json.parse(existing_text) == OK and json.get_data() is Dictionary:
					final_config = json.get_data()

	if final_config.is_empty():
		final_config = {}

	var merged_servers = final_config.get("mcpServers", {})
	if not (merged_servers is Dictionary):
		merged_servers = {}

	var new_servers = new_config_data.get("mcpServers", {})
	if not (new_servers is Dictionary):
		return {"success": false, "error": "parse_error"}

	for server_name in new_servers.keys():
		merged_servers[server_name] = new_servers[server_name]

	final_config["mcpServers"] = merged_servers

	var dir_path = filepath.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var err = DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			return {"success": false, "error": "dir_error", "path": dir_path}

	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		return {"success": false, "error": "write_error"}

	file.store_string(JSON.stringify(final_config, "  "))
	file.close()

	return {
		"success": true,
		"config_type": config_type,
		"path": filepath
	}
