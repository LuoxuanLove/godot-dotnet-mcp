@tool
extends RefCounted
class_name ConfigPaths


static func _get_home_dir() -> String:
	var home = OS.get_environment("HOME")
	if home.is_empty():
		home = OS.get_environment("USERPROFILE")
	return home


static func get_claude_config_path() -> String:
	var home = _get_home_dir()
	match OS.get_name():
		"macOS":
			return home + "/Library/Application Support/Claude/claude_desktop_config.json"
		"Windows":
			return OS.get_environment("APPDATA") + "/Claude/claude_desktop_config.json"
		_:
			return home + "/.config/Claude/claude_desktop_config.json"


static func get_cursor_config_path() -> String:
	return _get_home_dir() + "/.cursor/mcp.json"


static func get_gemini_config_path() -> String:
	return _get_home_dir() + "/.gemini/settings.json"


static func get_url_config(host: String, port: int) -> String:
	return JSON.stringify({
		"mcpServers": {
			"godot-mcp": {
				"url": "http://%s:%d/mcp" % [host, port]
			}
		}
	}, "  ")


static func get_http_url_config(host: String, port: int) -> String:
	return JSON.stringify({
		"mcpServers": {
			"godot-mcp": {
				"httpUrl": "http://%s:%d/mcp" % [host, port]
			}
		}
	}, "  ")


static func get_claude_code_command(scope: String, host: String, port: int) -> String:
	return "claude mcp add --transport http --scope %s godot-mcp http://%s:%d/mcp" % [scope, host, port]


static func get_codex_command(host: String, port: int) -> String:
	return "codex mcp add godot-mcp --url http://%s:%d/mcp" % [host, port]
