extends RefCounted

const ClientConfigPresenterScript = preload("res://addons/godot_dotnet_mcp/plugin/presenters/client_config_presenter.gd")


class FakeLocalization extends RefCounted:
	func get_text(key: String) -> String:
		var texts := {
			"config_client_claude_code": "Claude Code CLI",
			"config_client_claude_desktop": "Claude Desktop",
			"config_client_cursor": "Cursor",
			"config_client_gemini": "Gemini CLI",
			"config_client_codex": "Codex CLI",
			"config_transport_http_fallback": "HTTP",
			"config_client_write_path_label": "Config Write Location",
			"config_client_cli_entry_label": "Detected CLI Entry",
			"config_client_program_entry_label": "Detected Program Entry",
			"config_client_entry_present": "Installed to",
			"config_client_action_open_terminal": "Open In Terminal",
			"config_client_cli_missing_explainer": "CLI missing",
			"config_client_cli_detected_explainer": "CLI detected",
			"config_client_desktop_path_explainer": "Desktop path",
			"config_client_status_ready": "Detected",
			"config_client_status_config_only": "Config Available",
			"config_client_status_missing": "Missing",
			"config_client_status_error": "Error",
			"config_client_runtime_running": "Running",
			"config_client_runtime_not_running": "Not Running",
			"config_client_runtime_unknown": "Unknown",
			"config_client_entry_missing_file": "Config File Missing",
			"config_client_entry_empty": "Config File Empty",
			"config_client_entry_missing_server": "No godot-mcp Entry Found",
			"config_client_entry_invalid_json": "Invalid JSON",
			"config_client_entry_incompatible": "Incompatible",
			"config_client_path_source_auto": "Auto",
			"config_client_path_source_manual": "Manual",
			"config_client_path_source_store": "Store",
			"config_client_path_source_missing": "Missing",
			"config_client_action_add": "One-Click Add",
			"tool_action_remove_name": "Remove",
			"scope_user": "User (Global)",
			"scope_project": "Project (Current Only)",
			"config_client_cursor_desc": "Cursor description",
			"config_client_claude_code_desc": "Claude Code description",
			"config_client_codex_desc": "Codex description",
			"config_client_cursor_ready_msg": "Cursor ready",
			"config_client_claude_code_ready_msg": "Claude ready",
			"config_client_codex_ready_msg": "Codex ready"
		}
		return str(texts.get(key, key))


class FakeConfigService extends RefCounted:
	func get_claude_config_path() -> String:
		return "C:/Users/Test/AppData/Roaming/Claude/claude_desktop_config.json"

	func get_cursor_config_path() -> String:
		return "C:/Users/Test/.cursor/mcp.json"

	func get_trae_config_path() -> String:
		return "C:/Users/Test/AppData/Roaming/Trae/User/mcp.json"

	func get_gemini_config_path(scope: String = "user") -> String:
		if scope == "project":
			return "E:/Project/Test/.gemini/settings.json"
		return "C:/Users/Test/.gemini/settings.json"

	func get_claude_code_command(_scope: String, host: String, port: int) -> String:
		return "claude mcp add --transport http godot-mcp http://%s:%d/mcp" % [host, port]

	func get_codex_command(host: String, port: int) -> String:
		return "codex mcp add godot-mcp --url http://%s:%d/mcp" % [host, port]

	func get_gemini_command(scope: String, host: String, port: int) -> String:
		return "gemini mcp add --transport http --scope %s godot-mcp http://%s:%d/mcp" % [scope, host, port]

	func get_opencode_config_path() -> String:
		return "C:/Users/Test/.config/opencode/opencode.json"

	func get_opencode_remote_config(host: String, port: int) -> String:
		return "http://%s:%d/mcp" % [host, port]

	func get_url_config(host: String, port: int) -> String:
		return "http://%s:%d/mcp" % [host, port]

	func get_http_url_config(host: String, port: int) -> String:
		return "http://%s:%d/mcp" % [host, port]

	func get_command_config(command: String, args: Array) -> String:
		return "%s %s" % [command, " ".join(args)]


func run_case(_tree: SceneTree) -> Dictionary:
	var presenter = ClientConfigPresenterScript.new()
	var localization = FakeLocalization.new()
	var config_service = FakeConfigService.new()

	var desktop_models = presenter.build_desktop_client_models(
		{"host": "127.0.0.1", "port": 3000},
		"user",
		{},
		{
			"claude_desktop": {
				"status": "ready",
				"config_entry_status": {"status": "missing_server"},
				"launch_supported": true,
				"path_pick_supported": true,
				"path_clear_supported": false,
				"runtime_status": {"status": "not_running"},
				"executable_path": "C:/Apps/Claude/Claude.exe"
			},
			"cursor": {
				"status": "ready",
				"config_path": "C:/Users/Test/.cursor/mcp.json",
				"config_entry_status": {"status": "present"},
				"write_supported": true,
				"launch_supported": true,
				"path_pick_supported": true,
				"path_clear_supported": false,
				"runtime_status": {"status": "not_running"}
			}
		},
		localization,
		config_service
	)
	var cursor_model: Dictionary = desktop_models[1]
	if str(cursor_model.get("install_status_text", "")).find("C:/Users/Test/.cursor/mcp.json") == -1:
		return _failure("Desktop client status should surface the concrete config path once godot-mcp is installed.")

	var cli_models = presenter.build_cli_client_models(
		{"host": "127.0.0.1", "port": 3000},
		"project",
		{},
		{
			"claude_code": {
				"status": "ready",
				"config_entry_status": {"status": "present"},
				"auto_add_supported": true,
				"launch_supported": true,
				"path_pick_supported": true,
				"path_clear_supported": false,
				"runtime_status": {"status": "not_running"},
				"executable_path": "C:/Tools/claude.exe"
			},
			"codex": {
				"status": "ready",
				"config_path": "C:/Users/Test/.codex/config.toml",
				"config_entry_status": {"status": "present"},
				"auto_add_supported": true,
				"launch_supported": true,
				"path_pick_supported": true,
				"path_clear_supported": false,
				"runtime_status": {"status": "not_running"},
				"executable_path": "C:/Tools/codex.exe"
			},
			"gemini": {
				"status": "ready",
				"config_path": "E:/Project/Test/.gemini/settings.json",
				"config_entry_status": {"status": "present"},
				"auto_add_supported": true,
				"launch_supported": true,
				"path_pick_supported": true,
				"path_clear_supported": false,
				"runtime_status": {"status": "unknown"},
				"executable_path": "C:/Tools/gemini.cmd"
			}
		},
		localization,
		config_service
	)
	var claude_model: Dictionary = cli_models[0]
	if str(claude_model.get("install_status_text", "")).find("Project (Current Only)") == -1:
		return _failure("Claude Code status should surface the active install scope when godot-mcp is already installed.")
	if str(claude_model.get("primary_action_label_key", "")) != "tool_action_remove_name":
		return _failure("Claude Code should switch the primary action to Remove when godot-mcp is already installed.")
	var codex_model: Dictionary = cli_models[1]
	if str(codex_model.get("install_status_text", "")).find("C:/Users/Test/.codex/config.toml") == -1:
		return _failure("Codex status should surface the concrete config file path once godot-mcp is already installed.")
	if str(codex_model.get("primary_action_label_key", "")) != "tool_action_remove_name":
		return _failure("Codex should switch the primary action to Remove when godot-mcp is already installed.")
	var gemini_model: Dictionary = cli_models[2]
	if str(gemini_model.get("install_status_text", "")).find("E:/Project/Test/.gemini/settings.json") == -1:
		return _failure("Gemini CLI status should surface the active config file path once godot-mcp is already installed.")
	if str(gemini_model.get("launch_action_label_key", "")) != "config_client_action_open_terminal":
		return _failure("Gemini CLI should launch through the terminal flow, not the desktop-app flow.")
	if str(gemini_model.get("primary_action_label_key", "")) != "tool_action_remove_name":
		return _failure("Gemini CLI should switch the primary action to Remove when godot-mcp is already installed.")

	return {
		"name": "client_config_presenter_contracts",
		"success": true,
		"error": "",
		"details": {
			"cursor_status": str(cursor_model.get("install_status_text", "")),
			"claude_status": str(claude_model.get("install_status_text", "")),
			"codex_status": str(codex_model.get("install_status_text", ""))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "client_config_presenter_contracts",
		"success": false,
		"error": message
	}
