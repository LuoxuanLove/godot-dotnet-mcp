@tool
extends RefCounted
class_name ClientConfigSerializer

const ConfigPathsScript = preload("res://addons/godot_dotnet_mcp/plugin/config/config_paths.gd")


func get_claude_config_path() -> String:
	return ConfigPathsScript.get_claude_config_path()


func get_cursor_config_path() -> String:
	return ConfigPathsScript.get_cursor_config_path()


func get_trae_config_path() -> String:
	return ConfigPathsScript.get_trae_config_path()


func get_gemini_config_path() -> String:
	return ConfigPathsScript.get_gemini_config_path()


func get_codex_config_path() -> String:
	return ConfigPathsScript.get_codex_config_path()


func get_opencode_config_path() -> String:
	return ConfigPathsScript.get_opencode_config_path()


func get_url_config(host: String, port: int) -> String:
	return ConfigPathsScript.get_url_config(host, port)


func get_http_url_config(host: String, port: int) -> String:
	return ConfigPathsScript.get_http_url_config(host, port)


func get_command_config(command: String, args: Array) -> String:
	return ConfigPathsScript.get_command_config(command, args)


func get_opencode_local_config(command: String, args: Array) -> String:
	return ConfigPathsScript.get_opencode_local_config(command, args)


func get_opencode_remote_config(host: String, port: int) -> String:
	return ConfigPathsScript.get_opencode_remote_config(host, port)


func get_claude_code_command(scope: String, host: String, port: int) -> String:
	return ConfigPathsScript.get_claude_code_command(scope, host, port)


func get_codex_command(host: String, port: int) -> String:
	return ConfigPathsScript.get_codex_command(host, port)


func get_claude_code_stdio_command(scope: String, command: String, args: Array) -> String:
	return ConfigPathsScript.get_claude_code_stdio_command(scope, command, args)


func get_codex_stdio_command(command: String, args: Array) -> String:
	return ConfigPathsScript.get_codex_stdio_command(command, args)


func prepare_new_config(new_config: String, config_type: String = "") -> Dictionary:
	var json = JSON.new()
	if json.parse(new_config) != OK:
		return {"success": false, "error": "parse_error"}

	var new_config_data = json.get_data()
	if not (new_config_data is Dictionary):
		return {"success": false, "error": "parse_error"}

	var new_servers = new_config_data.get(get_server_container_key(config_type), {})
	if not (new_servers is Dictionary):
		return {"success": false, "error": "parse_error"}

	var server_names := PackedStringArray()
	for server_name in new_servers.keys():
		server_names.append(str(server_name))

	return {
		"success": true,
		"config_data": new_config_data,
		"new_servers": new_servers,
		"server_names": server_names
	}


func get_server_container_key(config_type: String) -> String:
	return "mcp" if config_type == "opencode" else "mcpServers"


func preflight_requires_confirmation(status: String) -> bool:
	return status == "invalid_json" \
		or status == "incompatible_root" \
		or status == "incompatible_mcp_servers" \
		or status == "incompatible_mcp"
