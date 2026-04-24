@tool
extends RefCounted
class_name ConfigPaths


static func _get_home_dir() -> String:
	var home = OS.get_environment("HOME")
	if home.is_empty():
		home = OS.get_environment("USERPROFILE")
	return _normalize_path(home)


static func _normalize_path(path: String) -> String:
	return path.replace("\\", "/").strip_edges().trim_suffix("/")


static func get_claude_config_path() -> String:
	var home = _get_home_dir()
	match OS.get_name():
		"macOS":
			return _normalize_path(home + "/Library/Application Support/Claude/claude_desktop_config.json")
		"Windows":
			return _normalize_path(OS.get_environment("APPDATA") + "/Claude/claude_desktop_config.json")
		_:
			return _normalize_path(home + "/.config/Claude/claude_desktop_config.json")


static func get_cursor_config_path() -> String:
	return _normalize_path(_get_home_dir() + "/.cursor/mcp.json")


static func get_trae_config_path() -> String:
	var app_data = _normalize_path(OS.get_environment("APPDATA"))
	var candidates := [
		_normalize_path(app_data + "/Trae CN/User/mcp.json"),
		_normalize_path(app_data + "/Trae/User/mcp.json")
	]
	for candidate in candidates:
		if FileAccess.file_exists(candidate):
			return candidate
	return candidates[0]


static func get_gemini_config_path() -> String:
	return _normalize_path(_get_home_dir() + "/.gemini/settings.json")


static func get_gemini_project_config_path(project_root: String) -> String:
	return _normalize_path(project_root + "/.gemini/settings.json")


static func get_codex_config_path() -> String:
	return _normalize_path(_get_home_dir() + "/.codex/config.toml")


static func get_opencode_config_path() -> String:
	return _normalize_path(_get_home_dir() + "/.config/opencode/opencode.json")


static func get_windsurf_config_path() -> String:
	return _normalize_path(_get_home_dir() + "/.codeium/windsurf/mcp_config.json")


static func get_cline_config_path() -> String:
	return _normalize_path(OS.get_environment("APPDATA") + "/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json")


static func get_roo_config_path() -> String:
	return _normalize_path(OS.get_environment("APPDATA") + "/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json")


static func get_qwen_config_path() -> String:
	return _normalize_path(_get_home_dir() + "/.qwen/settings.json")


static func get_qwen_project_config_path(project_root: String) -> String:
	return _normalize_path(project_root + "/.qwen/settings.json")


static func get_cherry_studio_config_hint_path() -> String:
	return _normalize_path(OS.get_environment("APPDATA") + "/CherryStudio")


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


static func get_opencode_remote_config(host: String, port: int) -> String:
	return JSON.stringify({
		"$schema": "https://opencode.ai/config.json",
		"mcp": {
			"godot-mcp": {
				"type": "remote",
				"url": "http://%s:%d/mcp" % [host, port],
				"enabled": true
			}
		}
	}, "  ")


static func get_claude_code_command(scope: String, host: String, port: int) -> String:
	return "claude mcp add --transport http --scope %s godot-mcp http://%s:%d/mcp" % [scope, host, port]


static func get_codex_command(host: String, port: int) -> String:
	return "codex mcp add godot-mcp --url http://%s:%d/mcp" % [host, port]


static func get_gemini_command(scope: String, host: String, port: int) -> String:
	return "gemini mcp add --transport http --scope %s godot-mcp http://%s:%d/mcp" % [scope, host, port]


static func get_qwen_command(scope: String, host: String, port: int) -> String:
	return "qwen mcp add --transport http --scope %s godot-mcp http://%s:%d/mcp" % [scope, host, port]
