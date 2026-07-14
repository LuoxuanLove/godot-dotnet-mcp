extends RefCounted

const ClientInstallDetectionServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_install_detection_service.gd")
const ConfigPathsScript = preload("res://addons/godot_dotnet_mcp/plugin/config/config_paths.gd")


class FakeDetectionService extends ClientInstallDetectionServiceScript:
	var resolved_paths: Dictionary = {}
	var cli_results: Dictionary = {}
	var config_entries: Dictionary = {}
	var supported_paths: Dictionary = {}
	var cli_query_count := 0

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
		cli_query_count += 1
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


class SlowGuardDetectionService extends ClientInstallDetectionServiceScript:
	var running_process_probe_count := 0
	var where_probe_count := 0
	var appx_probe_count := 0

	func _collect_running_process_names() -> PackedStringArray:
		if _allow_slow_checks:
			running_process_probe_count += 1
		return PackedStringArray()

	func _collect_appx_package_candidates(_package_name: String, _relative_paths: Array[String]) -> Array[String]:
		if _allow_slow_checks:
			appx_probe_count += 1
		return []

	func _collect_where_paths(_command_name: String) -> Array[String]:
		if _allow_slow_checks:
			where_probe_count += 1
		return []

	func _collect_existing_candidates(_candidates: Array[String]) -> Array[String]:
		return []

	func _inspect_config_entry(_config_path: String, _config_type: String = "") -> Dictionary:
		return {
			"status": ENTRY_MISSING_FILE,
			"has_server_entry": false
		}

	func _can_prepare_file_path(_file_path: String) -> bool:
		return true


func run_case(_tree: SceneTree) -> Dictionary:
	var service = FakeDetectionService.new()
	var gemini_config_path = ConfigPathsScript.get_gemini_project_config_path("E:/Project/Test")
	var antigravity_config_path = ConfigPathsScript.get_antigravity_mcp_config_path()
	service.supported_paths[gemini_config_path] = true
	service.supported_paths[antigravity_config_path] = true
	service.config_entries["|%s" % gemini_config_path] = {
		"status": service.ENTRY_PRESENT,
		"has_server_entry": true
	}
	service.config_entries["|%s" % antigravity_config_path] = {
		"status": service.ENTRY_MISSING_SERVER,
		"has_server_entry": false
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
		},
		"antigravity": {
			"path": "C:/Programs/Antigravity/Antigravity.exe",
			"detected_via": "common_path",
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
	var passive_statuses = service.detect_all()
	if service.cli_query_count != 0:
		return _failure("Passive client install detection should not execute CLI queries while rendering the config tab.")
	if not passive_statuses.has("gemini"):
		return _failure("Passive client install detection should still include Gemini in the detected client set.")
	if str(passive_statuses.get("claude_code", {}).get("config_entry_status", {}).get("status", "")) != service.ENTRY_DEFERRED:
		return _failure("Passive CLI detection should mark CLI entry status as deferred, not missing.")
	if str(passive_statuses.get("claude_desktop", {}).get("runtime_status", {}).get("status", "")) != service.RUNTIME_UNKNOWN:
		return _failure("Passive process detection should mark runtime status as unknown, not not_running.")
	if bool(service._allow_slow_checks):
		return _failure("Passive client detection should restore the slow-check guard after detection.")
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
	if not bool(statuses.get("antigravity", {}).get("write_supported", false)):
		return _failure("Antigravity detection should expose one-click writes for its known MCP config file.")
	if str(statuses.get("antigravity", {}).get("config_path", "")) != antigravity_config_path:
		return _failure("Antigravity detection should expose its Gemini-backed MCP config file path.")
	if str(statuses.get("antigravity", {}).get("guidance_path", "")) != ConfigPathsScript.get_antigravity_config_hint_path():
		return _failure("Antigravity detection should retain the user-data path as supplemental guidance.")
	if not bool(statuses.get("antigravity", {}).get("launch_supported", false)):
		return _failure("Antigravity detection should expose app launch support when an executable path is known.")
	var antigravity_actions: Array = statuses.get("antigravity", {}).get("capability", {}).get("actions", [])
	if not antigravity_actions.has("write_config") or not antigravity_actions.has("open_config_file"):
		return _failure("Antigravity detection should expose config-file write and open actions.")
	if str(statuses.get("gemini", {}).get("config_entry_status", {}).get("status", "")) != service.ENTRY_PRESENT:
		return _failure("Gemini detection should reuse config entry inspection so the config page can show install status.")
	var expected_support_levels := {
		"claude_desktop": "full_write",
		"claude_code": "auto_add",
		"cursor": "full_write",
		"trae": "full_write",
		"antigravity": "full_write",
		"codex_desktop": "launch_path",
		"codex": "auto_add",
		"gemini": "auto_add",
		"opencode_desktop": "manual_guidance",
		"opencode": "full_write",
		"windsurf": "full_write",
		"cline": "full_write",
		"roo_code": "full_write",
		"qwen": "auto_add",
		"cherry_studio": "manual_guidance"
	}
	for client_id in expected_support_levels.keys():
		var capability: Dictionary = statuses.get(client_id, {}).get("capability", {})
		if capability.is_empty():
			return _failure("Client install detection service should attach the shared capability matrix for %s." % client_id)
		var support_level := str(capability.get("support_level", ""))
		if support_level != str(expected_support_levels.get(client_id, "")):
			return _failure("Client install detection service should expose the shared support level for %s." % client_id)
		var actions: Variant = capability.get("actions", [])
		if not (actions is Array) or not actions.has("copy_config"):
			return _failure("Client install detection service should expose capability actions for %s." % client_id)
	if not statuses.get("claude_code", {}).get("capability", {}).get("actions", []).has("auto_add"):
		return _failure("Client install detection service should expose Claude Code auto-add capability on the production detection path.")
	if not statuses.get("opencode", {}).get("capability", {}).get("actions", []).has("write_config"):
		return _failure("Client install detection service should expose OpenCode config-write capability on the production detection path.")
	if service.cli_query_count != 2:
		return _failure("Forced client install detection should execute the expected deep CLI queries exactly once each.")
	if bool(service._allow_slow_checks):
		return _failure("Forced client detection should restore the slow-check guard after detection.")

	var missing_antigravity_service = FakeDetectionService.new()
	missing_antigravity_service.supported_paths[antigravity_config_path] = true
	missing_antigravity_service.configure({
		"client_manual_paths": {},
		"current_cli_scope": "project"
	})
	var missing_antigravity_statuses = missing_antigravity_service.detect_all(true)
	if str(missing_antigravity_statuses.get("antigravity", {}).get("status", "")) != service.STATUS_CONFIG_ONLY:
		return _failure("Antigravity should be config_only when no executable path is detected but the MCP config path is writable.")

	var slow_guard = SlowGuardDetectionService.new()
	slow_guard.configure({
		"client_manual_paths": {},
		"current_cli_scope": "project"
	})
	slow_guard.detect_all()
	if slow_guard.running_process_probe_count != 0 or slow_guard.where_probe_count != 0 or slow_guard.appx_probe_count != 0:
		return _failure("Passive client install detection should not enter tasklist, where, or AppX slow probes.")
	if bool(slow_guard._allow_slow_checks):
		return _failure("Passive slow-probe guard should be restored after detection.")
	slow_guard.detect_all(false, true)
	if slow_guard.running_process_probe_count == 0:
		return _failure("Explicit deep client detection should run the process-list probe even when passive cache exists.")
	if slow_guard.where_probe_count == 0:
		return _failure("Explicit deep client detection should run where.exe probes even when passive cache exists.")
	if slow_guard.appx_probe_count == 0:
		return _failure("Explicit deep client detection should run AppX probes even when passive cache exists.")
	if bool(slow_guard._allow_slow_checks):
		return _failure("Explicit deep client detection should restore the slow-check guard after detection.")

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
