@tool
extends RefCounted
class_name ClientInstallDetectionService

const ConfigPathsScript = preload("res://addons/godot_dotnet_mcp/plugin/config/config_paths.gd")

const STATUS_READY := "ready"
const STATUS_CONFIG_ONLY := "config_only"
const STATUS_MISSING := "missing"
const STATUS_ERROR := "error"
const ENTRY_PRESENT := "present"
const ENTRY_MISSING_FILE := "missing_file"
const ENTRY_EMPTY := "empty"
const ENTRY_MISSING_SERVER := "missing_server"
const ENTRY_INVALID_JSON := "invalid_json"
const ENTRY_INCOMPATIBLE_ROOT := "incompatible_root"
const ENTRY_INCOMPATIBLE_SERVERS := "incompatible_mcp_servers"
const ENTRY_DEFERRED := "deferred"
const RUNTIME_RUNNING := "running"
const RUNTIME_NOT_RUNNING := "not_running"
const RUNTIME_UNKNOWN := "unknown"
const CACHE_TTL_MS := 5000

var _cached_all: Dictionary = {}
var _cache_deadline_msec := 0
var _cached_all_includes_slow_checks := false
var _manual_paths: Dictionary = {}
var _current_cli_scope := "user"
var _allow_slow_checks := false


func configure(settings: Dictionary) -> void:
	var candidate_paths = settings.get("client_manual_paths", {})
	var normalized_paths := {}
	if candidate_paths is Dictionary:
		for key in candidate_paths.keys():
			var normalized = _normalize_path(str(candidate_paths[key]))
			if not normalized.is_empty():
				normalized_paths[str(key)] = normalized
	var next_cli_scope = str(settings.get("current_cli_scope", "user")).strip_edges()
	if next_cli_scope.is_empty():
		next_cli_scope = "user"
	if _manual_paths == normalized_paths and _current_cli_scope == next_cli_scope:
		return
	_manual_paths = normalized_paths
	_current_cli_scope = next_cli_scope
	invalidate_cache()


func detect_all(force_refresh: bool = false, include_slow_checks: bool = false) -> Dictionary:
	var now = Time.get_ticks_msec()
	var requested_slow_checks := include_slow_checks or force_refresh
	if not force_refresh and not _cached_all.is_empty() and now < _cache_deadline_msec:
		if not requested_slow_checks or _cached_all_includes_slow_checks:
			return _cached_all.duplicate(true)

	_allow_slow_checks = requested_slow_checks
	var running_processes = _collect_running_process_names()
	_cached_all = {
		"claude_desktop": _detect_claude_desktop(running_processes),
		"claude_code": _detect_claude_code(running_processes),
		"cursor": _detect_cursor(running_processes),
		"trae": _detect_trae(running_processes),
		"gemini": _detect_gemini(running_processes),
		"codex_desktop": _detect_codex_desktop(running_processes),
		"codex": _detect_codex(running_processes),
		"opencode_desktop": _detect_opencode_desktop(running_processes),
		"opencode": _detect_opencode(running_processes),
		"windsurf": _detect_windsurf(running_processes),
		"cline": _detect_config_file_client("cline", ConfigPathsScript.get_cline_config_path()),
		"roo_code": _detect_config_file_client("roo_code", ConfigPathsScript.get_roo_config_path()),
		"qwen": _detect_qwen(running_processes),
		"cherry_studio": _detect_cherry_studio(running_processes)
	}
	_cached_all_includes_slow_checks = requested_slow_checks
	_allow_slow_checks = false
	_cache_deadline_msec = now + CACHE_TTL_MS
	return _cached_all.duplicate(true)


func detect_client(client_id: String) -> Dictionary:
	return detect_all().get(client_id, {
		"id": client_id,
		"status": STATUS_ERROR,
		"message": "Unsupported client."
	})


func invalidate_cache() -> void:
	_cached_all.clear()
	_cache_deadline_msec = 0
	_cached_all_includes_slow_checks = false


func _detect_claude_desktop(running_processes: PackedStringArray = PackedStringArray()) -> Dictionary:
	var config_path = ConfigPathsScript.get_claude_config_path()
	var resolved = _resolve_executable_path(
		"claude_desktop",
		[
			"%s/Programs/Claude/Claude.exe" % _get_local_app_data_root(),
			"%s/Programs/Claude/claude.exe" % _get_local_app_data_root(),
			"%s/Claude/Claude.exe" % _get_program_files_root(),
			"%s/Claude/claude.exe" % _get_program_files_root(),
			"%s/Claude/Claude.exe" % _get_secondary_program_files_root(),
			"%s/Claude/claude.exe" % _get_secondary_program_files_root()
		],
		["claude"]
	)
	var entry_state = _inspect_config_entry(config_path)
	var runtime_state = _build_runtime_state(str(resolved.get("path", "")), ["claude.exe"], running_processes)
	var config_supported = _can_prepare_file_path(config_path)

	var result = _build_common_result("claude_desktop", resolved, runtime_state, entry_state)
	result["config_path"] = config_path
	result["write_supported"] = config_supported
	result["auto_add_supported"] = false
	result["launch_supported"] = not str(resolved.get("path", "")).is_empty()
	result["path_pick_supported"] = true
	result["path_clear_supported"] = bool(resolved.get("has_manual_path", false))
	if not str(resolved.get("path", "")).is_empty() and config_supported:
		result["status"] = STATUS_READY
	elif config_supported:
		result["status"] = STATUS_CONFIG_ONLY
	else:
		result["status"] = STATUS_MISSING
	return result


func _detect_cursor(running_processes: PackedStringArray = PackedStringArray()) -> Dictionary:
	var config_path = ConfigPathsScript.get_cursor_config_path()
	var resolved = _resolve_executable_path(
		"cursor",
		[
			"%s/Cursor/Cursor.exe" % _get_local_app_data_root(),
			"%s/Programs/Cursor/Cursor.exe" % _get_local_app_data_root(),
			"%s/cursor/Cursor.exe" % _get_program_files_root(),
			"%s/cursor/resources/app/bin/cursor.cmd" % _get_program_files_root(),
			"%s/cursor/resources/app/bin/cursor" % _get_program_files_root(),
			"%s/cursor/Cursor.exe" % _get_secondary_program_files_root(),
			"%s/cursor/resources/app/bin/cursor.cmd" % _get_secondary_program_files_root(),
			"%s/cursor/resources/app/bin/cursor" % _get_secondary_program_files_root()
		],
		["cursor"]
	)
	var entry_state = _inspect_config_entry(config_path)
	var runtime_state = _build_runtime_state(str(resolved.get("path", "")), ["cursor.exe"], running_processes)
	var config_supported = _can_prepare_file_path(config_path)

	var result = _build_common_result("cursor", resolved, runtime_state, entry_state)
	result["config_path"] = config_path
	result["write_supported"] = config_supported
	result["auto_add_supported"] = false
	result["launch_supported"] = not str(resolved.get("path", "")).is_empty()
	result["path_pick_supported"] = true
	result["path_clear_supported"] = bool(resolved.get("has_manual_path", false))
	if not str(resolved.get("path", "")).is_empty() and config_supported:
		result["status"] = STATUS_READY
	elif config_supported:
		result["status"] = STATUS_CONFIG_ONLY
	else:
		result["status"] = STATUS_MISSING
	return result


func _detect_trae(running_processes: PackedStringArray = PackedStringArray()) -> Dictionary:
	var config_path = ConfigPathsScript.get_trae_config_path()
	var resolved = _resolve_executable_path(
		"trae",
		[
			"%s/Trae CN/Trae CN.exe" % _get_program_files_root(),
			"%s/Trae/Trae.exe" % _get_program_files_root(),
			"%s/Programs/Trae CN/Trae CN.exe" % _get_local_app_data_root(),
			"%s/Programs/Trae/Trae.exe" % _get_local_app_data_root(),
			"%s/Trae CN/Trae CN.exe" % _get_secondary_program_files_root(),
			"%s/Trae/Trae.exe" % _get_secondary_program_files_root()
		],
		["trae-cn", "trae"]
	)
	var entry_state = _inspect_config_entry(config_path)
	var runtime_state = _build_runtime_state(
		str(resolved.get("path", "")),
		["trae cn.exe", "trae.exe"],
		running_processes
	)
	var config_supported = _can_prepare_file_path(config_path)

	var result = _build_common_result("trae", resolved, runtime_state, entry_state)
	result["config_path"] = config_path
	result["write_supported"] = config_supported
	result["auto_add_supported"] = false
	result["launch_supported"] = not str(resolved.get("path", "")).is_empty()
	result["path_pick_supported"] = true
	result["path_clear_supported"] = bool(resolved.get("has_manual_path", false))
	if not str(resolved.get("path", "")).is_empty() and config_supported:
		result["status"] = STATUS_READY
	elif config_supported:
		result["status"] = STATUS_CONFIG_ONLY
	else:
		result["status"] = STATUS_MISSING
	return result


func _detect_gemini(running_processes: PackedStringArray = PackedStringArray()) -> Dictionary:
	var config_path = _get_gemini_config_path_for_scope()
	var resolved = _resolve_executable_path(
		"gemini",
		[
			"%s/npm/gemini.cmd" % _get_app_data_root(),
			"%s/npm/gemini" % _get_app_data_root(),
			"%s/.local/bin/gemini" % _get_home_root()
		],
		["gemini"]
	)
	var entry_state = _inspect_config_entry(config_path)
	var runtime_state = _build_runtime_state(str(resolved.get("path", "")), [], running_processes)
	var config_supported = _can_prepare_file_path(config_path)

	var result = _build_common_result("gemini", resolved, runtime_state, entry_state)
	result["config_path"] = config_path
	result["write_supported"] = config_supported
	result["auto_add_supported"] = not str(resolved.get("path", "")).is_empty()
	result["launch_supported"] = not str(resolved.get("path", "")).is_empty()
	result["path_pick_supported"] = true
	result["path_clear_supported"] = bool(resolved.get("has_manual_path", false))
	if not str(resolved.get("path", "")).is_empty() and config_supported:
		result["status"] = STATUS_READY
	elif config_supported:
		result["status"] = STATUS_CONFIG_ONLY
	else:
		result["status"] = STATUS_MISSING
	return result


func _get_gemini_config_path_for_scope() -> String:
	if _current_cli_scope == "project":
		var project_root = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
		return ConfigPathsScript.get_gemini_project_config_path(project_root)
	return ConfigPathsScript.get_gemini_config_path()


func _detect_claude_code(running_processes: PackedStringArray = PackedStringArray()) -> Dictionary:
	var resolved = _resolve_executable_path(
		"claude_code",
		[
			"%s/npm/claude.cmd" % _get_app_data_root(),
			"%s/npm/claude" % _get_app_data_root(),
			"%s/.local/bin/claude.exe" % _get_home_root()
		],
		["claude"]
	)
	var result = _build_common_result(
		"claude_code",
		resolved,
		_build_runtime_state(str(resolved.get("path", "")), ["claude.exe"], running_processes),
		_inspect_cli_server_entry(
			str(resolved.get("path", "")),
			PackedStringArray(["mcp", "get", "godot-mcp"])
		)
	)
	result["config_path"] = ""
	result["write_supported"] = false
	result["auto_add_supported"] = not str(resolved.get("path", "")).is_empty()
	result["launch_supported"] = not str(resolved.get("path", "")).is_empty()
	result["path_pick_supported"] = true
	result["path_clear_supported"] = bool(resolved.get("has_manual_path", false))
	result["status"] = STATUS_READY if not str(resolved.get("path", "")).is_empty() else STATUS_MISSING
	return result


func _detect_codex_desktop(running_processes: PackedStringArray = PackedStringArray()) -> Dictionary:
	var windows_store_candidates := _collect_appx_package_candidates(
		"OpenAI.Codex",
		["app/Codex.exe"]
	)
	var resolved = _resolve_executable_path(
		"codex_desktop",
		[
			"%s/Codex Desktop/Codex Desktop.exe" % _get_program_files_root(),
			"%s/Codex Desktop/Codex.exe" % _get_program_files_root(),
			"%s/Codex Desktop/resources/app/bin/codex.cmd" % _get_program_files_root(),
			"%s/Codex Desktop/resources/app/bin/codex" % _get_program_files_root(),
			"%s/Codex/Codex.exe" % _get_program_files_root(),
			"%s/Codex/codex.exe" % _get_program_files_root(),
			"%s/Codex/resources/app/bin/codex.cmd" % _get_program_files_root(),
			"%s/Codex/resources/app/bin/codex" % _get_program_files_root(),
			"%s/OpenAI Codex/Codex.exe" % _get_program_files_root(),
			"%s/OpenAI Codex/codex.exe" % _get_program_files_root(),
			"%s/OpenAI/Codex Desktop/Codex Desktop.exe" % _get_program_files_root(),
			"%s/OpenAI/Codex Desktop/Codex.exe" % _get_program_files_root(),
			"%s/OpenAI/Codex/Codex.exe" % _get_program_files_root(),
			"%s/OpenAI/Codex/codex.exe" % _get_program_files_root(),
			"%s/OpenAI/Codex.exe" % _get_program_files_root(),
			"%s/Codex Desktop/Codex Desktop.exe" % _get_secondary_program_files_root(),
			"%s/Codex Desktop/Codex.exe" % _get_secondary_program_files_root(),
			"%s/Codex Desktop/resources/app/bin/codex.cmd" % _get_secondary_program_files_root(),
			"%s/Codex Desktop/resources/app/bin/codex" % _get_secondary_program_files_root(),
			"%s/Codex/Codex.exe" % _get_secondary_program_files_root(),
			"%s/Codex/codex.exe" % _get_secondary_program_files_root(),
			"%s/Codex/resources/app/bin/codex.cmd" % _get_secondary_program_files_root(),
			"%s/Codex/resources/app/bin/codex" % _get_secondary_program_files_root(),
			"%s/OpenAI Codex/Codex.exe" % _get_secondary_program_files_root(),
			"%s/OpenAI Codex/codex.exe" % _get_secondary_program_files_root(),
			"%s/OpenAI/Codex Desktop/Codex Desktop.exe" % _get_secondary_program_files_root(),
			"%s/OpenAI/Codex Desktop/Codex.exe" % _get_secondary_program_files_root(),
			"%s/OpenAI/Codex/Codex.exe" % _get_secondary_program_files_root(),
			"%s/OpenAI/Codex/codex.exe" % _get_secondary_program_files_root(),
			"%s/OpenAI/Codex.exe" % _get_secondary_program_files_root(),
			"%s/Programs/Codex Desktop/Codex Desktop.exe" % _get_local_app_data_root(),
			"%s/Programs/Codex Desktop/resources/app/bin/codex.cmd" % _get_local_app_data_root(),
			"%s/Programs/Codex/Codex.exe" % _get_local_app_data_root(),
			"%s/Programs/Codex/codex.exe" % _get_local_app_data_root(),
			"%s/Programs/Codex/resources/app/bin/codex.cmd" % _get_local_app_data_root(),
			"%s/Programs/OpenAI Codex/Codex.exe" % _get_local_app_data_root(),
			"%s/Programs/OpenAI Codex/codex.exe" % _get_local_app_data_root(),
			"%s/Programs/OpenAI/Codex Desktop/Codex Desktop.exe" % _get_local_app_data_root(),
			"%s/Programs/OpenAI/Codex/Codex.exe" % _get_local_app_data_root()
		],
		["codex-desktop", "codexdesktop", "openai-codex"],
		windows_store_candidates
	)
	var result = _build_common_result(
		"codex_desktop",
		resolved,
		_build_runtime_state(str(resolved.get("path", "")), ["codex.exe", "codex desktop.exe"], running_processes),
		{}
	)
	result["config_path"] = ""
	result["write_supported"] = false
	result["auto_add_supported"] = false
	result["launch_supported"] = not str(resolved.get("path", "")).is_empty()
	result["path_pick_supported"] = true
	result["path_clear_supported"] = bool(resolved.get("has_manual_path", false))
	result["status"] = STATUS_READY if not str(resolved.get("path", "")).is_empty() else STATUS_MISSING
	return result


func _detect_codex(running_processes: PackedStringArray = PackedStringArray()) -> Dictionary:
	var resolved = _resolve_executable_path(
		"codex",
		[
			"%s/npm/codex.cmd" % _get_app_data_root(),
			"%s/npm/codex" % _get_app_data_root(),
			"%s/.vscode/extensions/openai.chatgpt-26.318.11754-win32-x64/bin/windows-x86_64/codex.exe" % _get_home_root()
		],
		["codex"]
	)
	var result = _build_common_result(
		"codex",
		resolved,
		_build_runtime_state(str(resolved.get("path", "")), ["codex.exe"], running_processes),
		_inspect_cli_server_entry(
			str(resolved.get("path", "")),
			PackedStringArray(["mcp", "get", "godot-mcp", "--json"])
		)
	)
	result["config_path"] = ConfigPathsScript.get_codex_config_path()
	result["write_supported"] = false
	result["auto_add_supported"] = not str(resolved.get("path", "")).is_empty()
	result["launch_supported"] = not str(resolved.get("path", "")).is_empty()
	result["path_pick_supported"] = true
	result["path_clear_supported"] = bool(resolved.get("has_manual_path", false))
	result["status"] = STATUS_READY if not str(resolved.get("path", "")).is_empty() else STATUS_MISSING
	return result


func _detect_opencode_desktop(running_processes: PackedStringArray = PackedStringArray()) -> Dictionary:
	var resolved = _resolve_executable_path(
		"opencode_desktop",
		[
			"%s/OpenCode/OpenCode.exe" % _get_program_files_root(),
			"%s/OpenCode/OpenCode.exe" % _get_secondary_program_files_root(),
			"%s/Programs/OpenCode/OpenCode.exe" % _get_local_app_data_root()
		],
		["opencode-desktop"]
	)
	var result = _build_common_result(
		"opencode_desktop",
		resolved,
		_build_runtime_state(str(resolved.get("path", "")), ["opencode.exe", "opencode-desktop.exe", "opencode desktop.exe"], running_processes),
		_inspect_config_entry(ConfigPathsScript.get_opencode_config_path(), "opencode")
	)
	result["config_path"] = ConfigPathsScript.get_opencode_config_path()
	result["write_supported"] = false
	result["auto_add_supported"] = false
	result["launch_supported"] = not str(resolved.get("path", "")).is_empty()
	result["path_pick_supported"] = true
	result["path_clear_supported"] = bool(resolved.get("has_manual_path", false))
	result["status"] = STATUS_READY if not str(resolved.get("path", "")).is_empty() else STATUS_MISSING
	return result


func _detect_opencode(running_processes: PackedStringArray = PackedStringArray()) -> Dictionary:
	var resolved = _resolve_executable_path(
		"opencode",
		[
			"%s/OpenCode/opencode-cli.exe" % _get_program_files_root(),
			"%s/OpenCode/opencode-cli.exe" % _get_secondary_program_files_root(),
			"%s/npm/opencode.cmd" % _get_app_data_root(),
			"%s/npm/opencode" % _get_app_data_root()
		],
		["opencode"]
	)
	var result = _build_common_result(
		"opencode",
		resolved,
		_build_runtime_state(str(resolved.get("path", "")), ["opencode-cli.exe", "opencode.exe"], running_processes),
		_inspect_config_entry(ConfigPathsScript.get_opencode_config_path(), "opencode")
	)
	var config_path = ConfigPathsScript.get_opencode_config_path()
	var config_supported = _can_prepare_file_path(config_path)
	result["config_path"] = config_path
	result["write_supported"] = config_supported
	result["auto_add_supported"] = false
	result["launch_supported"] = not str(resolved.get("path", "")).is_empty()
	result["path_pick_supported"] = true
	result["path_clear_supported"] = bool(resolved.get("has_manual_path", false))
	if not str(resolved.get("path", "")).is_empty() and config_supported:
		result["status"] = STATUS_READY
	elif config_supported:
		result["status"] = STATUS_CONFIG_ONLY
	else:
		result["status"] = STATUS_MISSING
	return result


func _detect_windsurf(running_processes: PackedStringArray = PackedStringArray()) -> Dictionary:
	var config_path = ConfigPathsScript.get_windsurf_config_path()
	var resolved = _resolve_executable_path(
		"windsurf",
		[
			"%s/Windsurf/Windsurf.exe" % _get_local_app_data_root(),
			"%s/Programs/Windsurf/Windsurf.exe" % _get_local_app_data_root(),
			"%s/Windsurf/Windsurf.exe" % _get_program_files_root(),
			"%s/Windsurf/Windsurf.exe" % _get_secondary_program_files_root()
		],
		["windsurf"]
	)
	var result = _build_common_result(
		"windsurf",
		resolved,
		_build_runtime_state(str(resolved.get("path", "")), ["windsurf.exe"], running_processes),
		_inspect_config_entry(config_path)
	)
	return _finish_config_file_result(result, config_path, not str(resolved.get("path", "")).is_empty())


func _detect_qwen(running_processes: PackedStringArray = PackedStringArray()) -> Dictionary:
	var config_path = _get_qwen_config_path_for_scope()
	var resolved = _resolve_executable_path(
		"qwen",
		[
			"%s/npm/qwen.cmd" % _get_app_data_root(),
			"%s/npm/qwen" % _get_app_data_root(),
			"%s/.local/bin/qwen" % _get_home_root()
		],
		["qwen"]
	)
	var result = _build_common_result(
		"qwen",
		resolved,
		_build_runtime_state(str(resolved.get("path", "")), [], running_processes),
		_inspect_config_entry(config_path)
	)
	result["config_path"] = config_path
	result["write_supported"] = _can_prepare_file_path(config_path)
	result["auto_add_supported"] = not str(resolved.get("path", "")).is_empty()
	result["launch_supported"] = not str(resolved.get("path", "")).is_empty()
	result["path_pick_supported"] = true
	result["path_clear_supported"] = bool(resolved.get("has_manual_path", false))
	result["status"] = STATUS_READY if not str(resolved.get("path", "")).is_empty() else (STATUS_CONFIG_ONLY if bool(result.get("write_supported", false)) else STATUS_MISSING)
	return result


func _get_qwen_config_path_for_scope() -> String:
	if _current_cli_scope == "project":
		var project_root = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
		return ConfigPathsScript.get_qwen_project_config_path(project_root)
	return ConfigPathsScript.get_qwen_config_path()


func _detect_cherry_studio(running_processes: PackedStringArray = PackedStringArray()) -> Dictionary:
	var config_path = ConfigPathsScript.get_cherry_studio_config_hint_path()
	var resolved = _resolve_executable_path(
		"cherry_studio",
		[
			"%s/Cherry Studio/Cherry Studio.exe" % _get_local_app_data_root(),
			"%s/Programs/Cherry Studio/Cherry Studio.exe" % _get_local_app_data_root(),
			"%s/Cherry Studio/Cherry Studio.exe" % _get_program_files_root(),
			"%s/Cherry Studio/Cherry Studio.exe" % _get_secondary_program_files_root()
		],
		["cherry-studio", "cherrystudio"]
	)
	var result = _build_common_result(
		"cherry_studio",
		resolved,
		_build_runtime_state(str(resolved.get("path", "")), ["cherry studio.exe", "cherry-studio.exe"], running_processes),
		{"status": ENTRY_DEFERRED, "has_server_entry": false, "deferred": true}
	)
	result["config_path"] = config_path
	result["write_supported"] = false
	result["auto_add_supported"] = false
	result["launch_supported"] = not str(resolved.get("path", "")).is_empty()
	result["path_pick_supported"] = true
	result["path_clear_supported"] = bool(resolved.get("has_manual_path", false))
	result["status"] = STATUS_READY if not str(resolved.get("path", "")).is_empty() else STATUS_CONFIG_ONLY
	return result


func _detect_config_file_client(client_id: String, config_path: String) -> Dictionary:
	var result = _build_common_result(
		client_id,
		{},
		{"status": RUNTIME_UNKNOWN, "is_running": false},
		_inspect_config_entry(config_path)
	)
	return _finish_config_file_result(result, config_path, false)


func _finish_config_file_result(result: Dictionary, config_path: String, has_executable: bool) -> Dictionary:
	var config_supported = _can_prepare_file_path(config_path)
	result["config_path"] = config_path
	result["write_supported"] = config_supported
	result["auto_add_supported"] = false
	result["launch_supported"] = has_executable
	result["path_pick_supported"] = has_executable
	result["path_clear_supported"] = bool(result.get("has_manual_path", false))
	if has_executable and config_supported:
		result["status"] = STATUS_READY
	elif config_supported:
		result["status"] = STATUS_CONFIG_ONLY
	else:
		result["status"] = STATUS_MISSING
	return result


func _build_common_result(client_id: String, resolved: Dictionary, runtime_state: Dictionary, entry_state: Dictionary) -> Dictionary:
	return {
		"id": client_id,
		"status": STATUS_MISSING,
		"config_path": "",
		"executable_path": str(resolved.get("path", "")),
		"detected_via": str(resolved.get("detected_via", "")),
		"using_manual_path": bool(resolved.get("using_manual_path", false)),
		"has_manual_path": bool(resolved.get("has_manual_path", false)),
		"manual_path_invalid": bool(resolved.get("manual_path_invalid", false)),
		"manual_path": str(resolved.get("manual_path", "")),
		"write_supported": false,
		"auto_add_supported": false,
		"launch_supported": false,
		"path_pick_supported": false,
		"path_clear_supported": false,
		"config_entry_status": entry_state,
		"runtime_status": runtime_state
	}


func _inspect_cli_server_entry(executable_path: String, arguments: PackedStringArray) -> Dictionary:
	if not _allow_slow_checks:
		return {
			"status": ENTRY_DEFERRED,
			"has_server_entry": false,
			"deferred": true
		}
	if executable_path.is_empty():
		return {
			"status": ENTRY_MISSING_SERVER,
			"has_server_entry": false
		}
	var result = _execute_cli_query(executable_path, arguments)
	if bool(result.get("success", false)):
		return {
			"status": ENTRY_PRESENT,
			"has_server_entry": true
		}
	return {
		"status": ENTRY_MISSING_SERVER,
		"has_server_entry": false
	}


func _execute_cli_query(executable_path: String, arguments: PackedStringArray) -> Dictionary:
	if not _allow_slow_checks:
		return {
			"success": false,
			"exit_code": -1,
			"output": PackedStringArray(),
			"message": "Skipped passive CLI query during config page render."
		}
	if executable_path.is_empty():
		return {
			"success": false,
			"exit_code": -1,
			"output": PackedStringArray(),
			"message": "CLI executable path is empty."
		}
	var invocation = _build_cli_invocation(executable_path, arguments)
	var output: Array = []
	var exit_code = OS.execute(
		str(invocation.get("command", "")),
		invocation.get("arguments", PackedStringArray()),
		output,
		true,
		false
	)
	return {
		"success": exit_code == 0,
		"exit_code": exit_code,
		"output": output,
		"message": "\n".join(output)
	}


func _build_cli_invocation(executable_path: String, arguments: PackedStringArray) -> Dictionary:
	var lower_path = executable_path.to_lower()
	if lower_path.ends_with(".cmd") or lower_path.ends_with(".bat"):
		var wrapped_args := PackedStringArray(["/c", executable_path])
		wrapped_args.append_array(arguments)
		return {
			"command": "cmd.exe",
			"arguments": wrapped_args
		}
	return {
		"command": executable_path,
		"arguments": arguments
	}


func _resolve_executable_path(client_id: String, candidates: Array[String], where_aliases: Array[String], extra_candidates: Array[String] = []) -> Dictionary:
	var manual_path = _normalize_path(str(_manual_paths.get(client_id, "")))
	var has_manual_path = not manual_path.is_empty()
	if has_manual_path and FileAccess.file_exists(manual_path):
		return {
			"path": manual_path,
			"detected_via": "manual",
			"using_manual_path": true,
			"has_manual_path": true,
			"manual_path_invalid": false,
			"manual_path": manual_path
		}

	var existing_candidates = _collect_existing_candidates(candidates)
	if not existing_candidates.is_empty():
		return {
			"path": existing_candidates[0],
			"detected_via": "common_path",
			"using_manual_path": false,
			"has_manual_path": has_manual_path,
			"manual_path_invalid": has_manual_path,
			"manual_path": manual_path
		}

	var existing_extra_candidates = _collect_existing_candidates(extra_candidates)
	if not existing_extra_candidates.is_empty():
		return {
			"path": existing_extra_candidates[0],
			"detected_via": "windows_store",
			"using_manual_path": false,
			"has_manual_path": has_manual_path,
			"manual_path_invalid": has_manual_path,
			"manual_path": manual_path
		}

	for alias in where_aliases:
		var where_paths = _collect_where_paths(alias)
		if where_paths.is_empty():
			continue
		return {
			"path": where_paths[0],
			"detected_via": "where",
			"using_manual_path": false,
			"has_manual_path": has_manual_path,
			"manual_path_invalid": has_manual_path,
			"manual_path": manual_path
		}

	return {
		"path": "",
		"detected_via": "",
		"using_manual_path": false,
		"has_manual_path": has_manual_path,
		"manual_path_invalid": has_manual_path,
		"manual_path": manual_path
	}


func _collect_appx_package_candidates(package_name: String, relative_paths: Array[String]) -> Array[String]:
	if not _allow_slow_checks:
		return []
	var output: Array = []
	var command = "Get-AppxPackage -Name '%s' | Sort-Object Version -Descending | Select-Object -ExpandProperty InstallLocation" % [
		package_name.replace("'", "''")
	]
	var exit_code = OS.execute(
		"powershell.exe",
		PackedStringArray(["-NoProfile", "-Command", command]),
		output,
		true,
		false
	)
	if exit_code != 0:
		return []

	var candidates: Array[String] = []
	for chunk in output:
		var text = str(chunk).replace("\r", "\n")
		for line in text.split("\n", false):
			var package_dir = _normalize_path(line.trim_suffix("\\"))
			if package_dir.is_empty():
				continue
			for relative_path in relative_paths:
				var normalized_relative = str(relative_path).replace("\\", "/").trim_prefix("/")
				var candidate = _normalize_path("%s/%s" % [package_dir, normalized_relative])
				if not candidate.is_empty():
					candidates.append(candidate)
	return candidates


func _collect_where_paths(command_name: String) -> Array[String]:
	if not _allow_slow_checks:
		return []
	var output: Array = []
	var exit_code = OS.execute("where.exe", PackedStringArray([command_name]), output, true, false)
	if exit_code != 0:
		return []

	var lines: Array[String] = []
	for chunk in output:
		var text = str(chunk).replace("\r", "\n")
		for line in text.split("\n", false):
			var normalized = _normalize_path(line)
			if not normalized.is_empty() and FileAccess.file_exists(normalized):
				lines.append(normalized)
	return lines


func _collect_existing_candidates(candidates: Array[String]) -> Array[String]:
	var results: Array[String] = []
	for candidate in candidates:
		var normalized = _normalize_path(candidate)
		if normalized.is_empty():
			continue
		if FileAccess.file_exists(normalized):
			results.append(normalized)
	return results


func _collect_running_process_names() -> PackedStringArray:
	if not _allow_slow_checks:
		return PackedStringArray()
	var output: Array = []
	var exit_code = OS.execute("tasklist.exe", PackedStringArray(["/FO", "CSV", "/NH"]), output, true, false)
	if exit_code != 0:
		return PackedStringArray()

	var process_names := PackedStringArray()
	for chunk in output:
		var text = str(chunk).replace("\r", "\n")
		for line in text.split("\n", false):
			var trimmed = line.strip_edges()
			if trimmed.is_empty():
				continue
			if trimmed.begins_with("\""):
				var closing = trimmed.find("\",")
				if closing > 1:
					process_names.append(trimmed.substr(1, closing - 1).to_lower())
	return process_names


func _build_runtime_state(executable_path: String, image_names: Array[String], running_processes: PackedStringArray) -> Dictionary:
	if not _allow_slow_checks:
		return {
			"status": RUNTIME_UNKNOWN,
			"is_running": false,
			"deferred": true
		}
	if image_names.is_empty():
		return {
			"status": RUNTIME_UNKNOWN,
			"is_running": false
		}

	var candidates: Array[String] = []
	for image_name in image_names:
		var normalized = str(image_name).to_lower().strip_edges()
		if not normalized.is_empty() and not candidates.has(normalized):
			candidates.append(normalized)

	var executable_file = executable_path.get_file().to_lower()
	if not executable_file.is_empty() and executable_file.ends_with(".exe") and not candidates.has(executable_file):
		candidates.append(executable_file)

	for process_name in running_processes:
		if candidates.has(str(process_name).to_lower()):
			return {
				"status": RUNTIME_RUNNING,
				"is_running": true,
				"matched_image": str(process_name)
			}

	return {
		"status": RUNTIME_NOT_RUNNING,
		"is_running": false
	}


func _inspect_config_entry(config_path: String, config_type: String = "") -> Dictionary:
	if config_path.is_empty() or not FileAccess.file_exists(config_path):
		return {
			"status": ENTRY_MISSING_FILE,
			"has_server_entry": false
		}

	var file = FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return {
			"status": ENTRY_MISSING_FILE,
			"has_server_entry": false
		}
	var text = file.get_as_text()
	file.close()
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


func _can_prepare_file_path(file_path: String) -> bool:
	var dir_path = _normalize_path(file_path.get_base_dir())
	if dir_path.is_empty():
		return false
	return _has_existing_ancestor(dir_path)


func _has_existing_ancestor(path: String) -> bool:
	var current = _normalize_path(path)
	while not current.is_empty():
		if DirAccess.dir_exists_absolute(current):
			return true
		var parent = current.get_base_dir()
		if parent == current:
			break
		current = _normalize_path(parent)
	return false


func _get_home_root() -> String:
	return _normalize_path(OS.get_environment("USERPROFILE"))


func _get_app_data_root() -> String:
	return _normalize_path(OS.get_environment("APPDATA"))


func _get_local_app_data_root() -> String:
	return _normalize_path(OS.get_environment("LOCALAPPDATA"))


func _get_program_files_root() -> String:
	var value = _normalize_path(OS.get_environment("ProgramFiles"))
	return "C:/Program Files" if value.is_empty() else value


func _get_secondary_program_files_root() -> String:
	var primary = _get_program_files_root()
	if primary == "E:/Program Files":
		return "C:/Program Files"
	if primary == "C:/Program Files":
		return "E:/Program Files"
	return "E:/Program Files"


func _normalize_path(path: String) -> String:
	return path.replace("\\", "/").strip_edges().trim_suffix("/")
