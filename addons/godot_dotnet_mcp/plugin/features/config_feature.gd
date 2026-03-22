extends RefCounted

var _settings: Dictionary = {}
var _localization
var _config_service
var _dock_presenter
var _central_server_process_service
var _show_message := Callable()
var _show_confirmation := Callable()
var _refresh_dock := Callable()
var _save_settings := Callable()
var _invalidate_client_install_status_cache := Callable()
var _configure_client_install_detection_service := Callable()
var _get_client_install_statuses := Callable()
var _ensure_client_executable_dialog := Callable()
var _get_client_executable_dialog := Callable()
var _pending_client_path_request := {}


func configure(
	settings: Dictionary,
	localization,
	config_service,
	dock_presenter,
	central_server_process_service,
	callbacks: Dictionary
) -> void:
	_settings = settings
	_localization = localization
	_config_service = config_service
	_dock_presenter = dock_presenter
	_central_server_process_service = central_server_process_service
	_show_message = callbacks.get("show_message", Callable())
	_show_confirmation = callbacks.get("show_confirmation", Callable())
	_refresh_dock = callbacks.get("refresh_dock", Callable())
	_save_settings = callbacks.get("save_settings", Callable())
	_invalidate_client_install_status_cache = callbacks.get("invalidate_client_install_status_cache", Callable())
	_configure_client_install_detection_service = callbacks.get("configure_client_install_detection_service", Callable())
	_get_client_install_statuses = callbacks.get("get_client_install_statuses", Callable())
	_ensure_client_executable_dialog = callbacks.get("ensure_client_executable_dialog", Callable())
	_get_client_executable_dialog = callbacks.get("get_client_executable_dialog", Callable())


func get_client_display_name(client_id: String) -> String:
	match client_id:
		"claude_desktop":
			return _get_localized_text("config_client_claude_desktop")
		"claude_code":
			return _get_localized_text("config_client_claude_code")
		"cursor":
			return _get_localized_text("config_client_cursor")
		"trae":
			return _get_localized_text("config_client_trae")
		"codex_desktop":
			return _get_localized_text("config_client_codex_desktop")
		"codex":
			return _get_localized_text("config_client_codex")
		"opencode_desktop":
			return _get_localized_text("config_client_opencode_desktop")
		"opencode":
			return _get_localized_text("config_client_opencode")
		"gemini":
			return _get_localized_text("config_client_gemini")
		_:
			return client_id


func handle_validate_requested() -> void:
	if _central_server_process_service == null:
		return
	var result = _central_server_process_service.validate_client_transport(
		str(_settings.get("host", "127.0.0.1")),
		int(_settings.get("port", 3000))
	)
	if not bool(result.get("success", false)):
		_call_show_message("%s\n\n%s" % [
			_get_localized_text("config_validate_failed"),
			str(result.get("message", ""))
		])
		return
	var mode = str(result.get("mode", "http"))
	var success_key = "config_validate_success_stdio" if mode == "stdio" else "config_validate_success_http"
	_call_show_message("%s\n\n%s" % [
		_get_localized_text(success_key),
		str(result.get("message", ""))
	])


func handle_client_action_requested(client_id: String) -> void:
	var client_statuses = _get_statuses()
	match client_id:
		"codex":
			_apply_codex_mcp_config(client_statuses.get("codex", {}))


func handle_client_launch_requested(client_id: String) -> void:
	var client_statuses = _get_statuses()
	match client_id:
		"cursor":
			_launch_cursor_for_current_project(client_statuses.get("cursor", {}))
		"trae":
			_launch_desktop_agent_for_current_project(
				_get_localized_text("config_client_trae"),
				client_statuses.get("trae", {})
			)
		"claude_code":
			_launch_cli_agent_for_current_project(client_id, _get_localized_text("config_client_claude_code"), client_statuses.get("claude_code", {}))
		"codex":
			_launch_cli_agent_for_current_project(client_id, _get_localized_text("config_client_codex"), client_statuses.get("codex", {}))
		"opencode":
			_launch_cli_agent_for_current_project(client_id, _get_localized_text("config_client_opencode"), client_statuses.get("opencode", {}))
		_:
			_call_show_message(_get_localized_text("msg_client_launch_unsupported"))


func handle_client_path_pick_requested(client_id: String) -> void:
	_call_ensure_client_executable_dialog()
	var dialog = _get_client_executable_dialog_safe()
	if dialog == null or not is_instance_valid(dialog):
		_call_show_message(_get_localized_text("msg_client_path_dialog_unavailable"))
		return

	var client_statuses = _get_statuses()
	var detection: Dictionary = client_statuses.get(client_id, {})
	var client_name = get_client_display_name(client_id)
	var current_path = str(detection.get("executable_path", detection.get("manual_path", ""))).strip_edges()
	_pending_client_path_request = {
		"client_id": client_id
	}
	dialog.title = _get_localized_text("msg_client_path_dialog_title") % client_name
	if not current_path.is_empty():
		dialog.current_path = current_path
		dialog.current_dir = current_path.get_base_dir()
	else:
		dialog.current_dir = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	dialog.popup_centered_ratio(0.75)


func handle_client_executable_file_selected(path: String) -> void:
	var client_id = str(_pending_client_path_request.get("client_id", "")).strip_edges()
	_pending_client_path_request = {}
	if client_id.is_empty():
		return

	var normalized_path = path.replace("\\", "/").strip_edges()
	if normalized_path.is_empty() or not FileAccess.file_exists(normalized_path):
		_call_show_message(_get_localized_text("msg_client_path_invalid"))
		return

	var manual_paths = _get_client_manual_paths()
	manual_paths[client_id] = normalized_path
	_settings["client_manual_paths"] = manual_paths
	_call_save_settings()
	_call_configure_detection_service()
	_call_invalidate_client_install_status_cache()
	_call_refresh_dock()
	var client_name = get_client_display_name(client_id)
	_call_show_message("%s\n\n%s" % [
		_get_localized_text("msg_client_path_saved") % client_name,
		normalized_path
	])


func reset_client_path_request() -> void:
	_pending_client_path_request = {}


func handle_client_path_clear_requested(client_id: String) -> void:
	var manual_paths = _get_client_manual_paths()
	if not manual_paths.has(client_id):
		_call_show_message(_get_localized_text("msg_client_manual_path_missing"))
		return
	manual_paths.erase(client_id)
	_settings["client_manual_paths"] = manual_paths
	_call_save_settings()
	_call_configure_detection_service()
	_call_invalidate_client_install_status_cache()
	_call_refresh_dock()
	_call_show_message(_get_localized_text("msg_client_path_cleared") % get_client_display_name(client_id))


func handle_client_open_config_dir_requested(client_id: String) -> void:
	var client_statuses = _get_statuses()
	var detection: Dictionary = client_statuses.get(client_id, {})
	var config_path = str(detection.get("config_path", "")).strip_edges()
	if config_path.is_empty():
		_call_show_message(_get_localized_text("msg_client_open_config_dir_failed") % get_client_display_name(client_id))
		return
	var dir_path = config_path.get_base_dir()
	if dir_path.is_empty():
		_call_show_message(_get_localized_text("msg_client_open_config_dir_failed") % get_client_display_name(client_id))
		return
	if not DirAccess.dir_exists_absolute(dir_path):
		var dir_error = DirAccess.make_dir_recursive_absolute(dir_path)
		if dir_error != OK:
			_call_show_message(_get_localized_text("msg_client_open_config_dir_failed") % get_client_display_name(client_id))
			return
	var result = _config_service.open_target_path(dir_path)
	if not bool(result.get("success", false)):
		_call_show_message(_get_localized_text("msg_client_open_config_dir_failed") % get_client_display_name(client_id))
		return
	_call_show_message(_get_localized_text("msg_client_open_config_dir_success") % get_client_display_name(client_id))


func handle_client_open_config_file_requested(client_id: String) -> void:
	var client_statuses = _get_statuses()
	var detection: Dictionary = client_statuses.get(client_id, {})
	var config_path = str(detection.get("config_path", "")).strip_edges()
	if config_path.is_empty() or not FileAccess.file_exists(config_path):
		_call_show_message(_get_localized_text("msg_client_open_config_file_missing") % get_client_display_name(client_id))
		return
	var result = _config_service.open_text_file(config_path)
	if not bool(result.get("success", false)):
		_call_show_message(_get_localized_text("msg_client_open_config_file_failed") % get_client_display_name(client_id))
		return
	_call_show_message(_get_localized_text("msg_client_open_config_file_success") % get_client_display_name(client_id))


func handle_write_requested(config_type: String, filepath: String, config: String, client_name: String) -> void:
	var preflight = _config_service.preflight_write_config(config_type, filepath, config)
	if not bool(preflight.get("success", false)):
		_call_show_message(_build_config_write_failure_message(preflight, filepath))
		return

	if bool(preflight.get("requires_confirmation", false)):
		_call_show_confirmation(
			_build_config_write_confirmation_message(client_name, preflight),
			func() -> void:
				_perform_config_write(config_type, filepath, config, client_name, preflight, true)
		)
		return

	_perform_config_write(config_type, filepath, config, client_name, preflight, false)


func handle_remove_requested(config_type: String, filepath: String, client_name: String) -> void:
	var inspection = _config_service.inspect_config_entry(config_type, filepath)
	if not bool(inspection.get("success", false)):
		_call_show_message(_build_config_remove_failure_message(inspection, filepath))
		return

	var status = str(inspection.get("status", "missing_file"))
	if status != "present":
		_call_show_message(_build_config_remove_noop_message(inspection, client_name))
		return

	_call_show_confirmation(
		_build_config_remove_confirmation_message(client_name, inspection),
		func() -> void:
			_perform_config_remove(config_type, filepath, client_name, inspection)
	)


func _perform_config_write(
	config_type: String,
	filepath: String,
	config: String,
	client_name: String,
	preflight: Dictionary,
	allow_incompatible_overwrite: bool
) -> void:
	var result = _config_service.write_config_file(
		config_type,
		filepath,
		config,
		{
			"preflight": preflight,
			"allow_incompatible_overwrite": allow_incompatible_overwrite
		}
	)
	if not bool(result.get("success", false)):
		_call_show_message(_build_config_write_failure_message(result, filepath))
		return

	_call_invalidate_client_install_status_cache()
	_call_refresh_dock()

	var success_lines: PackedStringArray = PackedStringArray([
		_get_localized_text("msg_config_success") % client_name,
		_get_localized_text("msg_config_verified") % str(result.get("path", filepath))
	])
	var backup_path = str(result.get("backup_path", "")).strip_edges()
	if not backup_path.is_empty():
		success_lines.append(_get_localized_text("msg_config_backup_created") % backup_path)
	success_lines.append(_get_localized_text("msg_config_effect_hint"))
	success_lines.append(_build_client_runtime_followup_message(config_type))
	_call_show_message("\n\n".join(success_lines))


func _perform_config_remove(config_type: String, filepath: String, client_name: String, inspection: Dictionary) -> void:
	var result = _config_service.remove_config_entry(config_type, filepath, {"inspection": inspection})
	if not bool(result.get("success", false)):
		_call_show_message(_build_config_remove_failure_message(result, filepath))
		return

	if not bool(result.get("removed", false)):
		_call_show_message(_build_config_remove_noop_message(result, client_name))
		return

	_call_invalidate_client_install_status_cache()
	_call_refresh_dock()

	var success_lines: PackedStringArray = PackedStringArray([
		_get_localized_text("msg_config_remove_success") % client_name
	])
	var backup_path = str(result.get("backup_path", "")).strip_edges()
	if not backup_path.is_empty():
		success_lines.append(_get_localized_text("msg_config_backup_created") % backup_path)
	success_lines.append(_build_client_runtime_followup_message(config_type))
	_call_show_message("\n\n".join(success_lines))


func _build_config_write_confirmation_message(client_name: String, preflight: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray([
		_get_localized_text("msg_config_overwrite_confirm") % client_name
	])
	var filepath = str(preflight.get("path", ""))
	match str(preflight.get("status", "")):
		"invalid_json":
			lines.append(_get_localized_text("msg_config_precheck_invalid_json") % filepath)
		"incompatible_root":
			lines.append(_get_localized_text("msg_config_precheck_incompatible_root") % filepath)
		"incompatible_mcp_servers":
			lines.append(_get_localized_text("msg_config_precheck_incompatible_servers") % filepath)
		"incompatible_mcp":
			lines.append(_get_localized_text("msg_config_precheck_incompatible_mcp") % filepath)
		_:
			lines.append(_get_localized_text("msg_write_error"))

	var backup_path = str(preflight.get("backup_path", "")).strip_edges()
	if not backup_path.is_empty():
		lines.append(_get_localized_text("msg_config_backup_notice") % backup_path)
	return "\n\n".join(lines)


func _build_config_remove_confirmation_message(client_name: String, inspection: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray([
		_get_localized_text("msg_config_remove_confirm") % client_name,
		_get_localized_text("msg_config_remove_safe_scope")
	])
	var backup_path = str(inspection.get("backup_path", "")).strip_edges()
	if not backup_path.is_empty():
		lines.append(_get_localized_text("msg_config_backup_notice") % backup_path)
	return "\n\n".join(lines)


func _build_config_write_failure_message(result: Dictionary, filepath: String) -> String:
	var message := ""
	match str(result.get("error", "")):
		"parse_error":
			message = _get_localized_text("msg_parse_error")
		"dir_error":
			message = _get_localized_text("msg_dir_error") + str(result.get("path", ""))
		"precheck_read_error":
			message = _get_localized_text("msg_config_precheck_read_error") % str(result.get("path", filepath))
		"precheck_confirmation_required":
			message = _build_config_write_confirmation_message("MCP", result)
		"backup_error":
			message = _get_localized_text("msg_config_backup_failed") % str(result.get("backup_path", filepath + ".bak"))
		"readback_missing_file":
			message = "%s\n\n%s" % [
				_get_localized_text("msg_config_readback_failed"),
				_get_localized_text("msg_config_readback_missing_file") % str(result.get("path", filepath))
			]
		"readback_open_error":
			message = "%s\n\n%s" % [
				_get_localized_text("msg_config_readback_failed"),
				_get_localized_text("msg_config_readback_open_error") % str(result.get("path", filepath))
			]
		"readback_parse_error", "readback_missing_servers":
			message = "%s\n\n%s" % [
				_get_localized_text("msg_config_readback_failed"),
				_get_localized_text("msg_config_readback_parse_error") % str(result.get("path", filepath))
			]
		"readback_missing_server":
			message = "%s\n\n%s" % [
				_get_localized_text("msg_config_readback_failed"),
				_get_localized_text("msg_config_readback_missing_server") % [
					str(result.get("server_name", "godot-mcp")),
					str(result.get("path", filepath))
				]
			]
		"readback_mismatch":
			message = "%s\n\n%s" % [
				_get_localized_text("msg_config_readback_failed"),
				_get_localized_text("msg_config_readback_mismatch") % [
					str(result.get("server_name", "godot-mcp")),
					str(result.get("path", filepath))
				]
			]
		_:
			message = _get_localized_text("msg_write_error")

	if bool(result.get("rollback_restored", false)):
		message = "%s\n\n%s" % [message, _get_localized_text("msg_config_restored_backup")]
	elif str(result.get("rollback_error", "")) == "restore_failed":
		message = "%s\n\n%s" % [
			message,
			_get_localized_text("msg_config_restore_failed") % str(result.get("backup_path", filepath + ".bak"))
		]
	return message


func _build_config_remove_failure_message(result: Dictionary, filepath: String) -> String:
	var message := ""
	match str(result.get("error", "")):
		"precheck_read_error":
			message = _get_localized_text("msg_config_precheck_read_error") % str(result.get("path", filepath))
		"backup_error":
			message = _get_localized_text("msg_config_backup_failed") % str(result.get("backup_path", filepath + ".bak"))
		"remove_blocked_invalid_json":
			message = _get_localized_text("msg_config_remove_blocked_invalid_json") % str(result.get("path", filepath))
		"remove_blocked_incompatible_root", "remove_blocked_incompatible_mcp_servers", "remove_blocked_incompatible_mcp":
			message = _get_localized_text("msg_config_remove_blocked_incompatible") % str(result.get("path", filepath))
		"readback_missing_file":
			message = _get_localized_text("msg_config_remove_readback_failed") % str(result.get("path", filepath))
		"readback_open_error", "readback_parse_error", "readback_missing_servers":
			message = _get_localized_text("msg_config_remove_readback_failed") % str(result.get("path", filepath))
		"readback_remove_mismatch":
			message = _get_localized_text("msg_config_remove_readback_mismatch") % [
				str(result.get("server_name", "godot-mcp")),
				str(result.get("path", filepath))
			]
		_:
			message = _get_localized_text("msg_config_remove_failed")

	if bool(result.get("rollback_restored", false)):
		message = "%s\n\n%s" % [message, _get_localized_text("msg_config_restored_backup")]
	elif str(result.get("rollback_error", "")) == "restore_failed":
		message = "%s\n\n%s" % [
			message,
			_get_localized_text("msg_config_restore_failed") % str(result.get("backup_path", filepath + ".bak"))
		]
	return message


func _build_config_remove_noop_message(result: Dictionary, client_name: String) -> String:
	match str(result.get("status", result.get("noop_reason", ""))):
		"missing_file":
			return _get_localized_text("msg_config_remove_noop_missing_file") % client_name
		"empty", "missing_server":
			return _get_localized_text("msg_config_remove_noop_missing_entry") % client_name
		_:
			return _get_localized_text("msg_config_remove_failed")


func _build_client_runtime_followup_message(client_id: String) -> String:
	var detection = _get_statuses().get(client_id, {})
	var runtime_status = str(detection.get("runtime_status", {}).get("status", "unknown"))
	if runtime_status == "running":
		match client_id:
			"claude_desktop":
				return _get_localized_text("msg_config_restart_claude")
			"cursor":
				return _get_localized_text("msg_config_restart_cursor")
			"trae":
				return _get_localized_text("msg_config_restart_trae")
			"opencode", "opencode_desktop":
				return _get_localized_text("msg_config_restart_opencode")
			_:
				return _get_localized_text("msg_config_effect_hint")
	if runtime_status == "not_running":
		return _get_localized_text("msg_config_client_not_running")
	return _get_localized_text("msg_config_effect_hint")


func _apply_codex_mcp_config(detection: Dictionary) -> void:
	if detection.is_empty() or str(detection.get("status", "")) != "ready":
		_call_show_message(_get_client_install_message_text("codex", str(detection.get("status", "missing"))))
		return

	var executable_path = str(detection.get("executable_path", "")).strip_edges()
	if executable_path.is_empty():
		_call_show_message(_get_localized_text("msg_client_action_missing_executable") % _get_localized_text("config_client_codex"))
		return

	var transport = _build_client_transport_model()
	var remove_result = _config_service.execute_cli_command(executable_path, PackedStringArray(["mcp", "remove", "godot-mcp"]))
	if not bool(remove_result.get("success", false)):
		var remove_message = str(remove_result.get("message", ""))
		if remove_message.find("No MCP server named 'godot-mcp' found.") == -1:
			_call_show_message("%s\n\n%s" % [
				_get_localized_text("msg_client_action_failed") % _get_localized_text("config_client_codex"),
				remove_message
			])
			return

	var add_result = _config_service.execute_cli_command(executable_path, _build_codex_add_arguments(transport))
	if not bool(add_result.get("success", false)):
		_call_show_message("%s\n\n%s" % [
			_get_localized_text("msg_client_action_failed") % _get_localized_text("config_client_codex"),
			str(add_result.get("message", ""))
		])
		return

	_call_invalidate_client_install_status_cache()
	_call_refresh_dock()
	_call_show_message(_get_localized_text("msg_client_action_success") % _get_localized_text("config_client_codex"))


func _launch_cursor_for_current_project(detection: Dictionary) -> void:
	_launch_desktop_agent_for_current_project(_get_localized_text("config_client_cursor"), detection)


func _launch_desktop_agent_for_current_project(client_name: String, detection: Dictionary) -> void:
	var executable_path = str(detection.get("executable_path", "")).strip_edges()
	if executable_path.is_empty():
		_call_show_message(_get_localized_text("msg_client_action_missing_executable") % client_name)
		return

	var project_root = _get_current_project_root()
	var result = _config_service.launch_desktop_client(
		executable_path,
		PackedStringArray([project_root]),
		project_root
	)
	if not bool(result.get("success", false)):
		_call_show_message("%s\n\n%s" % [
			_get_localized_text("msg_client_launch_failed") % client_name,
			str(result.get("message", ""))
		])
		return

	_call_invalidate_client_install_status_cache()
	_call_refresh_dock()
	_call_show_message("%s\n\n%s" % [
		_get_localized_text("msg_client_launch_success") % client_name,
		_get_localized_text("msg_client_launch_workdir") % project_root
	])


func _launch_cli_agent_for_current_project(client_id: String, client_name: String, detection: Dictionary) -> void:
	var executable_path = str(detection.get("executable_path", "")).strip_edges()
	if executable_path.is_empty():
		_call_show_message(_get_localized_text("msg_client_action_missing_executable") % client_name)
		return

	var project_root = _get_current_project_root()
	var arguments := PackedStringArray()
	match client_id:
		"claude_code", "codex":
			arguments = PackedStringArray()
		"opencode":
			arguments = PackedStringArray([project_root])
		_:
			_call_show_message(_get_localized_text("msg_client_launch_unsupported"))
			return

	var result = _config_service.launch_cli_client_in_terminal(executable_path, arguments, project_root)
	if not bool(result.get("success", false)):
		_call_show_message("%s\n\n%s" % [
			_get_localized_text("msg_client_launch_failed") % client_name,
			str(result.get("message", ""))
		])
		return

	_call_invalidate_client_install_status_cache()
	_call_refresh_dock()
	_call_show_message("%s\n\n%s" % [
		_get_localized_text("msg_client_launch_success") % client_name,
		"%s\n%s" % [
			_get_localized_text("msg_client_launch_workdir") % project_root,
			_get_localized_text("msg_client_launch_terminal_hint")
		]
	])


func _build_codex_add_arguments(transport: Dictionary) -> PackedStringArray:
	if str(transport.get("mode", "")) == "stdio":
		var args := PackedStringArray(["mcp", "add", "godot-mcp", "--", str(transport.get("command", ""))])
		for value in transport.get("args", []):
			args.append(str(value))
		return args

	return PackedStringArray([
		"mcp",
		"add",
		"godot-mcp",
		"--url",
		"http://%s:%d/mcp" % [str(transport.get("host", "127.0.0.1")), int(transport.get("port", 3000))]
	])


func _build_client_transport_model() -> Dictionary:
	var process_status = {}
	if _central_server_process_service != null:
		process_status = _central_server_process_service.get_status()
	if _dock_presenter != null:
		return _dock_presenter.build_client_transport_model(_settings, process_status)
	return {
		"mode": "http",
		"host": str(_settings.get("host", "127.0.0.1")),
		"port": int(_settings.get("port", 3000))
	}


func _get_client_install_message_text(client_id: String, status: String) -> String:
	if _dock_presenter != null:
		return _dock_presenter.get_client_install_message_text(client_id, status, _localization)
	return ""


func _get_current_project_root() -> String:
	return ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")


func _get_client_manual_paths() -> Dictionary:
	var manual_paths = _settings.get("client_manual_paths", {})
	if manual_paths is Dictionary:
		return manual_paths.duplicate(true)
	return {}


func _get_statuses() -> Dictionary:
	if _get_client_install_statuses.is_valid():
		var result = _get_client_install_statuses.call()
		if result is Dictionary:
			return result
	return {}


func _get_client_executable_dialog_safe():
	if _get_client_executable_dialog.is_valid():
		return _get_client_executable_dialog.call()
	return null


func _get_localized_text(key: String) -> String:
	if _localization == null:
		return key
	return _localization.get_text(key)


func _call_show_message(message: String) -> void:
	if _show_message.is_valid():
		_show_message.call(message)


func _call_show_confirmation(message: String, on_confirmed: Callable) -> void:
	if _show_confirmation.is_valid():
		_show_confirmation.call(message, on_confirmed)
		return
	if on_confirmed.is_valid():
		on_confirmed.call()


func _call_refresh_dock() -> void:
	if _refresh_dock.is_valid():
		_refresh_dock.call()


func _call_save_settings() -> void:
	if _save_settings.is_valid():
		_save_settings.call()


func _call_invalidate_client_install_status_cache() -> void:
	if _invalidate_client_install_status_cache.is_valid():
		_invalidate_client_install_status_cache.call()


func _call_configure_detection_service() -> void:
	if _configure_client_install_detection_service.is_valid():
		_configure_client_install_detection_service.call()


func _call_ensure_client_executable_dialog() -> void:
	if _ensure_client_executable_dialog.is_valid():
		_ensure_client_executable_dialog.call()
