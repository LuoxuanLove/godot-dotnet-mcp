extends RefCounted

const ClientConfigPresenterScript = preload("res://addons/godot_dotnet_mcp/plugin/presenters/client_config_presenter.gd")


class FakeLocalization extends RefCounted:
	func get_text(key: String) -> String:
		var texts := {
			"config_client_claude_code": "Claude Code CLI",
			"config_client_claude_desktop": "Claude Desktop",
			"config_client_cursor": "Cursor",
			"config_client_gemini": "Gemini CLI",
			"config_client_qwen": "Qwen Code CLI",
			"config_client_windsurf": "Windsurf",
			"config_client_cline": "Cline",
			"config_client_roo_code": "Roo Code",
			"config_client_cherry_studio": "Cherry Studio",
			"config_client_codex": "Codex CLI",
			"config_client_codex_desktop": "Codex Desktop",
			"config_client_opencode_desktop": "OpenCode Desktop",
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
			"config_client_action_open_project": "Open Project",
			"config_client_action_open_app": "Open App",
			"config_client_capability_summary_label": "Capability",
			"config_client_capability_full_write": "Full one-click config write and remove are available for this client.",
			"config_client_capability_auto_add": "One-click CLI add or remove is available through the detected executable.",
			"config_client_capability_manual_guidance": "Manual setup guidance is available; this client is not a full one-click integration here.",
			"config_client_capability_launch_path": "Launch and path management are available; MCP setup should use the recommended manual or CLI flow.",
			"config_client_capability_copy_guidance": "Copyable setup guidance is available, but automatic client changes are not supported.",
			"tool_action_remove_name": "Remove",
			"scope_user": "User (Global)",
			"scope_project": "Project (Current Only)",
			"config_client_cursor_desc": "Cursor description",
			"config_client_claude_code_desc": "Claude Code description",
			"config_client_codex_desc": "Codex description",
			"config_client_qwen_desc": "Qwen description",
			"config_client_windsurf_desc": "Windsurf description",
			"config_client_cline_desc": "Cline description",
			"config_client_roo_code_desc": "Roo Code description",
			"config_client_cherry_studio_desc": "Cherry Studio description",
			"config_client_cursor_ready_msg": "Cursor ready",
			"config_client_claude_code_ready_msg": "Claude ready",
			"config_client_codex_ready_msg": "Codex ready",
			"config_client_qwen_ready_msg": "Qwen ready",
			"config_client_windsurf_ready_msg": "Windsurf ready"
		}
		return str(texts.get(key, key))


class FakeConfigService extends RefCounted:
	func get_claude_config_path() -> String:
		return "C:/Users/Test/AppData/Roaming/Claude/claude_desktop_config.json"

	func get_cursor_config_path() -> String:
		return "C:/Users/Test/.cursor/mcp.json"

	func get_trae_config_path() -> String:
		return "C:/Users/Test/AppData/Roaming/Trae/User/mcp.json"

	func get_windsurf_config_path() -> String:
		return "C:/Users/Test/.codeium/windsurf/mcp_config.json"

	func get_cline_config_path() -> String:
		return "C:/Users/Test/AppData/Roaming/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"

	func get_roo_config_path() -> String:
		return "C:/Users/Test/AppData/Roaming/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json"

	func get_cherry_studio_config_hint_path() -> String:
		return "C:/Users/Test/AppData/Roaming/CherryStudio"

	func get_gemini_config_path(scope: String = "user") -> String:
		if scope == "project":
			return "E:/Project/Test/.gemini/settings.json"
		return "C:/Users/Test/.gemini/settings.json"

	func get_qwen_config_path(scope: String = "user") -> String:
		if scope == "project":
			return "E:/Project/Test/.qwen/settings.json"
		return "C:/Users/Test/.qwen/settings.json"

	func get_claude_code_command(_scope: String, host: String, port: int) -> String:
		return "claude mcp add --transport http godot-mcp http://%s:%d/mcp" % [host, port]

	func get_codex_command(host: String, port: int) -> String:
		return "codex mcp add godot-mcp --url http://%s:%d/mcp" % [host, port]

	func get_gemini_command(scope: String, host: String, port: int) -> String:
		return "gemini mcp add --transport http --scope %s godot-mcp http://%s:%d/mcp" % [scope, host, port]

	func get_qwen_command(scope: String, host: String, port: int) -> String:
		return "qwen mcp add --transport http --scope %s godot-mcp http://%s:%d/mcp" % [scope, host, port]

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
				"runtime_status": {"status": "not_running"},
				"capability": {
					"support_level": "manual_guidance",
					"actions": ["copy_config"],
					"notes": ["config_client_capability_manual_guidance"]
				}
			},
			"codex_desktop": {
				"status": "ready",
				"write_supported": false,
				"auto_add_supported": false,
				"launch_supported": true,
				"path_pick_supported": true,
				"path_clear_supported": false,
				"runtime_status": {"status": "unknown"},
				"executable_path": "C:/Apps/Codex/Codex.exe",
				"capability": "invalid"
			},
			"cherry_studio": {
				"status": "config_only",
				"config_path": "C:/Users/Test/AppData/Roaming/CherryStudio",
				"config_entry_status": {"status": "deferred"},
				"write_supported": false,
				"auto_add_supported": false,
				"launch_supported": false,
				"path_pick_supported": true,
				"path_clear_supported": false,
				"runtime_status": {"status": "unknown"},
				"capability": {
					"kind": "manual_guidance"
				}
			}
		},
		localization,
		config_service
	)
	var cursor_model: Dictionary = desktop_models[1]
	if desktop_models.size() != 9:
		return _failure("Presenter should expose all supported desktop clients in the config page model.")
	if str(cursor_model.get("install_status_text", "")).find("C:/Users/Test/.cursor/mcp.json") == -1:
		return _failure("Desktop client status should surface the concrete config path once godot-mcp is installed.")
	if str(cursor_model.get("capability", {}).get("kind", "")) != "manual_guidance":
		return _failure("Presenter should prefer the detection capability matrix over legacy boolean inference.")
	if str(cursor_model.get("capability", {}).get("support_level", "")) != "manual_guidance":
		return _failure("Presenter should expose detection capability support_level in the card model.")
	if cursor_model.get("capability", {}).get("actions", []).has("write_config"):
		return _failure("Presenter should not expose write_config when detection capability support_level is manual guidance.")
	if not cursor_model.get("capability", {}).get("actions", []).has("open_config_file"):
		return _failure("Presenter should merge realtime config-path actions when detection capability is present.")
	if str(cursor_model.get("guidance_text", "")).find("Manual setup guidance") == -1:
		return _failure("Presenter should use detection capability support_level for the visible capability summary.")
	var codex_desktop_model: Dictionary = desktop_models[3]
	if str(codex_desktop_model.get("capability", {}).get("kind", "")) != "launch_path":
		return _failure("Presenter should fall back to legacy inference when detection capability is not a dictionary.")
	if str(codex_desktop_model.get("capability", {}).get("support_level", "")) != "launch_path":
		return _failure("A launch-only desktop client should expose launch_path as its capability support level.")
	if str(codex_desktop_model.get("guidance_text", "")).find("Launch and path management") == -1:
		return _failure("Launch-only desktop client guidance should summarize launch/path-only support.")
	var cherry_model: Dictionary = desktop_models[8]
	if str(cherry_model.get("capability", {}).get("kind", "")) != "manual_guidance":
		return _failure("A config/manual guidance client should be labelled separately from full one-click clients.")
	if str(cherry_model.get("capability", {}).get("support_level", "")) != "manual_guidance":
		return _failure("Presenter should preserve legacy capability.kind as support_level when support_level is absent.")
	if str(cherry_model.get("guidance_text", "")).find("Manual setup guidance") == -1:
		return _failure("Manual guidance client summary should explain that it is not full one-click support.")
	var windsurf_model: Dictionary = desktop_models[5]
	if str(windsurf_model.get("name_key", "")) != "config_client_windsurf":
		return _failure("Presenter should include Windsurf in the desktop client list.")

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
				"write_supported": true,
				"auto_add_supported": true,
				"launch_supported": true,
				"path_pick_supported": true,
				"path_clear_supported": false,
				"runtime_status": {"status": "unknown"},
				"executable_path": "C:/Tools/gemini.cmd"
			},
			"qwen": {
				"status": "ready",
				"config_path": "E:/Project/Test/.qwen/settings.json",
				"config_entry_status": {"status": "present"},
				"auto_add_supported": true,
				"launch_supported": true,
				"path_pick_supported": true,
				"path_clear_supported": false,
				"runtime_status": {"status": "unknown"},
				"executable_path": "C:/Tools/qwen.cmd"
			}
		},
		localization,
		config_service
	)
	var claude_model: Dictionary = cli_models[0]
	if cli_models.size() != 5:
		return _failure("Presenter should expose all supported CLI clients in the config page model.")
	if str(claude_model.get("install_status_text", "")).find("Project (Current Only)") == -1:
		return _failure("Claude Code status should surface the active install scope when godot-mcp is already installed.")
	if str(claude_model.get("primary_action_label_key", "")) != "tool_action_remove_name":
		return _failure("Claude Code should switch the primary action to Remove when godot-mcp is already installed.")
	var codex_model: Dictionary = cli_models[1]
	if str(codex_model.get("install_status_text", "")).find("C:/Users/Test/.codex/config.toml") == -1:
		return _failure("Codex status should surface the concrete config file path once godot-mcp is already installed.")
	if str(codex_model.get("primary_action_label_key", "")) != "tool_action_remove_name":
		return _failure("Codex should switch the primary action to Remove when godot-mcp is already installed.")
	if str(codex_model.get("capability", {}).get("kind", "")) != "auto_add":
		return _failure("A CLI auto-add client should be labelled as one-click CLI add/remove support.")
	if str(codex_model.get("capability", {}).get("support_level", "")) != "auto_add":
		return _failure("A CLI auto-add client should expose auto_add as its capability support level.")
	if not codex_model.get("capability", {}).get("actions", []).has("auto_add"):
		return _failure("A CLI auto-add client should expose auto_add as a supported capability action.")
	if str(codex_model.get("guidance_text", "")).find("One-click CLI add or remove") == -1:
		return _failure("CLI auto-add client guidance should summarize one-click CLI capabilities.")
	var gemini_model: Dictionary = cli_models[2]
	if str(gemini_model.get("install_status_text", "")).find("E:/Project/Test/.gemini/settings.json") == -1:
		return _failure("Gemini CLI status should surface the active config file path once godot-mcp is already installed.")
	if str(gemini_model.get("launch_action_label_key", "")) != "config_client_action_open_terminal":
		return _failure("Gemini CLI should launch through the terminal flow, not the desktop-app flow.")
	if str(gemini_model.get("primary_action_label_key", "")) != "tool_action_remove_name":
		return _failure("Gemini CLI should switch the primary action to Remove when godot-mcp is already installed.")
	if str(gemini_model.get("capability", {}).get("kind", "")) != "auto_add":
		return _failure("A CLI client with write_supported and auto_add_supported should prefer the auto-add capability summary.")
	var qwen_model: Dictionary = cli_models[4]
	if str(qwen_model.get("install_status_text", "")).find("E:/Project/Test/.qwen/settings.json") == -1:
		return _failure("Qwen Code CLI status should surface the active config file path once godot-mcp is already installed.")
	if str(qwen_model.get("primary_action_label_key", "")) != "tool_action_remove_name":
		return _failure("Qwen Code CLI should switch the primary action to Remove when godot-mcp is already installed.")

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
