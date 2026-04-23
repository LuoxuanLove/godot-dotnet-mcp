extends RefCounted

const ClientInstallDetectionServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_install_detection_service.gd")
const ConfigPathsScript = preload("res://addons/godot_dotnet_mcp/plugin/config/config_paths.gd")


class FakeDetectionService extends ClientInstallDetectionServiceScript:
	var resolved_paths: Dictionary = {}
	var cli_results: Dictionary = {}
	var config_entries: Dictionary = {}
	var supported_paths: Dictionary = {}

	func _resolve_executable_path(client_id: String, _candidates: Array[String], _where_aliases: Array[String], _extra_candidates: Array[String] = []) -> Dictionary:
		return resolved_paths.get(client_id, {
			"path": "",
			"detected_via": "",
			"using_manual_path": false,
			"has_manual_path": false,
			"manual_path_invalid": false,
			"manual_path": ""
		})

	func _collect_running_process_names() -> PackedStringArray:
		return PackedStringArray()

	func _inspect_config_entry(config_path: String, config_type: String = "") -> Dictionary:
		return config_entries.get("%s|%s" % [config_type, config_path], {
			"status": ENTRY_MISSING_SERVER,
			"has_server_entry": false
		})

	func _can_prepare_file_path(file_path: String) -> bool:
		return bool(supported_paths.get(file_path, true))

	func _execute_cli_query(executable_path: String, arguments: PackedStringArray) -> Dictionary:
		return cli_results.get(_cli_key(executable_path, arguments), {
			"success": false,
			"exit_code": 1,
			"output": [],
			"message": "missing"
		})

	func _cli_key(executable_path: String, arguments: PackedStringArray) -> String:
		return "%s|%s" % [executable_path, "|".join(Array(arguments))]

	func _get_gemini_config_path_for_scope() -> String:
		return ConfigPathsScript.get_gemini_project_config_path("E:/Project/Test")


func run_case(_tree: SceneTree) -> Dictionary:
	var service = FakeDetectionService.new()
	var gemini_config_path = ConfigPathsScript.get_gemini_project_config_path("E:/Project/Test")
	service.supported_paths[gemini_config_path] = true
	service.config_entries["|%s" % gemini_config_path] = {
		"status": service.ENTRY_PRESENT,
		"has_server_entry": true
	}
	service.resolved_paths = {
		"claude_desktop": {
			"path": "C:/Apps/Claude/Claude.exe",
			"detected_via": "common_path",
			"using_manual_path": false,
			"has_manual_path": false,
			"manual_path_invalid": false,
			"manual_path": ""
		},
		"claude_code": {
			"path": "C:/Tools/claude.exe",
			"detected_via": "where",
			"using_manual_path": false,
			"has_manual_path": false,
			"manual_path_invalid": false,
			"manual_path": ""
		},
		"codex": {
			"path": "C:/Tools/codex.exe",
			"detected_via": "where",
			"using_manual_path": false,
			"has_manual_path": false,
			"manual_path_invalid": false,
			"manual_path": ""
		},
		"gemini": {
			"path": "C:/Users/Test/AppData/Roaming/npm/gemini.cmd",
			"detected_via": "where",
			"using_manual_path": false,
			"has_manual_path": false,
			"manual_path_invalid": false,
			"manual_path": ""
		}
	}
	service.cli_results[service._cli_key("C:/Tools/claude.exe", PackedStringArray(["mcp", "get", "godot-mcp"]))] = {
		"success": true,
		"exit_code": 0,
		"output": ["godot-mcp"],
		"message": "ok"
	}
	service.cli_results[service._cli_key("C:/Tools/codex.exe", PackedStringArray(["mcp", "get", "godot-mcp", "--json"]))] = {
		"success": true,
		"exit_code": 0,
		"output": ["{}"],
		"message": "ok"
	}

	service.configure({
		"client_manual_paths": {},
		"current_cli_scope": "project"
	})
	var statuses = service.detect_all(true)

	if not statuses.has("gemini"):
		return _failure("Client install detection service should include Gemini in the detected client set.")
	if str(statuses.get("claude_code", {}).get("config_entry_status", {}).get("status", "")) != service.ENTRY_PRESENT:
		return _failure("Claude Code detection should mark the MCP entry as present when `claude mcp get godot-mcp` succeeds.")
	if str(statuses.get("codex", {}).get("config_entry_status", {}).get("status", "")) != service.ENTRY_PRESENT:
		return _failure("Codex detection should mark the MCP entry as present when `codex mcp get godot-mcp --json` succeeds.")
	if not bool(statuses.get("claude_desktop", {}).get("launch_supported", false)):
		return _failure("Claude Desktop detection should expose desktop launch support when an executable path is known.")
	if not bool(statuses.get("gemini", {}).get("launch_supported", false)):
		return _failure("Gemini CLI detection should expose launch support when a CLI entry is known.")
	if str(statuses.get("gemini", {}).get("config_entry_status", {}).get("status", "")) != service.ENTRY_PRESENT:
		return _failure("Gemini detection should reuse config entry inspection so the config page can show install status.")

	return {
		"name": "client_install_detection_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"clients": statuses.keys(),
			"claude_code_status": str(statuses.get("claude_code", {}).get("config_entry_status", {}).get("status", "")),
			"codex_status": str(statuses.get("codex", {}).get("config_entry_status", {}).get("status", "")),
			"gemini_status": str(statuses.get("gemini", {}).get("config_entry_status", {}).get("status", ""))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "client_install_detection_service_contracts",
		"success": false,
		"error": message
	}
