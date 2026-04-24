@tool
extends RefCounted
class_name ConfigTabActionService

const MCP_SERVER_KEY := "godot-mcp"

var _state
var _localization
var _config_service
var _client_install_detection_service
var _get_client_install_statuses := Callable()
var _invalidate_client_install_status_cache := Callable()
var _configure_client_install_detection_service := Callable()
var _refresh_dock := Callable()
var _save_settings := Callable()
var _show_message := Callable()
var _show_confirmation := Callable()
var _ensure_client_executable_dialog := Callable()
var _get_client_executable_dialog := Callable()
var _pending_client_path_request := {}


func configure(context) -> void:
	if context == null:
		dispose()
		return
	_state = context.state
	_localization = context.localization
	_config_service = context.config_service
	_client_install_detection_service = context.client_install_detection_service
	_get_client_install_statuses = context.get_client_install_statuses
	_invalidate_client_install_status_cache = context.invalidate_client_install_status_cache
	_configure_client_install_detection_service = context.configure_client_install_detection_service
	_refresh_dock = context.refresh_dock
	_save_settings = context.save_settings
	_show_message = context.show_message
	_show_confirmation = context.show_confirmation
	_ensure_client_executable_dialog = context.ensure_client_executable_dialog
	_get_client_executable_dialog = context.get_client_executable_dialog


func dispose() -> void:
	_state = null
	_localization = null
	_config_service = null
	_client_install_detection_service = null
	_get_client_install_statuses = Callable()
	_invalidate_client_install_status_cache = Callable()
	_configure_client_install_detection_service = Callable()
	_refresh_dock = Callable()
	_save_settings = Callable()
	_show_message = Callable()
	_show_confirmation = Callable()
	_ensure_client_executable_dialog = Callable()
	_get_client_executable_dialog = Callable()
	_pending_client_path_request = {}


func handle_config_client_action_requested(client_id: String) -> void:
	var client_statuses = _get_client_install_statuses.call() if _get_client_install_statuses.is_valid() else {}
	match client_id:
		"claude_code":
			_toggle_claude_code_mcp_config(client_statuses.get("claude_code", {}))
		"codex":
			_toggle_codex_mcp_config(client_statuses.get("codex", {}))
		"gemini":
			_toggle_gemini_mcp_config(client_statuses.get("gemini", {}))
		"qwen":
			_toggle_qwen_mcp_config(client_statuses.get("qwen", {}))
		_:
			pass


func handle_config_client_launch_requested(client_id: String) -> void:
	var client_statuses = _get_client_install_statuses.call() if _get_client_install_statuses.is_valid() else {}
	match client_id:
		"claude_desktop":
			_launch_desktop_agent(_get_client_display_name("claude_desktop"), client_statuses.get("claude_desktop", {}), PackedStringArray())
		"cursor":
			_launch_cursor_for_current_project(client_statuses.get("cursor", {}))
		"trae":
			_launch_desktop_agent_for_current_project(
				_get_client_display_name("trae"),
				client_statuses.get("trae", {})
			)
		"codex_desktop":
			_launch_desktop_agent(_get_client_display_name("codex_desktop"), client_statuses.get("codex_desktop", {}), PackedStringArray())
		"claude_code":
			_launch_cli_agent_for_current_project(client_id, _get_client_display_name("claude_code"), client_statuses.get("claude_code", {}))
		"codex":
			_launch_cli_agent_for_current_project(client_id, _get_client_display_name("codex"), client_statuses.get("codex", {}))
		"gemini":
			_launch_cli_agent_for_current_project(client_id, _get_client_display_name("gemini"), client_statuses.get("gemini", {}))
		"opencode_desktop":
			_launch_desktop_agent(_get_client_display_name("opencode_desktop"), client_statuses.get("opencode_desktop", {}), PackedStringArray())
		"opencode":
			_launch_cli_agent_for_current_project(client_id, _get_client_display_name("opencode"), client_statuses.get("opencode", {}))
		"windsurf":
			_launch_desktop_agent_for_current_project(
				_get_client_display_name("windsurf"),
				client_statuses.get("windsurf", {})
			)
		"qwen":
			_launch_cli_agent_for_current_project(client_id, _get_client_display_name("qwen"), client_statuses.get("qwen", {}))
		"cherry_studio":
			_launch_desktop_agent(_get_client_display_name("cherry_studio"), client_statuses.get("cherry_studio", {}), PackedStringArray())
		_:
			_show_config_message(_localization.get_text("msg_client_launch_unsupported"))


func handle_config_client_path_pick_requested(client_id: String) -> void:
	var client_statuses = _get_client_install_statuses.call() if _get_client_install_statuses.is_valid() else {}
	_open_client_executable_dialog(client_id, client_statuses.get(client_id, {}))


func handle_config_client_path_clear_requested(client_id: String) -> void:
	var manual_paths = _get_client_manual_paths()
	if not manual_paths.has(client_id):
		_show_config_message(_localization.get_text("msg_client_manual_path_missing"))
		return
	manual_paths.erase(client_id)
	_state.settings["client_manual_paths"] = manual_paths
	_save_settings_if_possible()
	_configure_client_install_detection_service_if_possible()
	_invalidate_client_install_status_cache_if_possible()
	_refresh_dock_if_possible()
	_show_config_message(_localization.get_text("msg_client_path_cleared") % _get_client_display_name(client_id))


func handle_config_client_open_config_dir_requested(client_id: String) -> void:
	var client_statuses = _get_client_install_statuses.call() if _get_client_install_statuses.is_valid() else {}
	var detection: Dictionary = client_statuses.get(client_id, {})
	var config_path = str(detection.get("config_path", "")).strip_edges()
	if config_path.is_empty():
		_show_config_message(_localization.get_text("msg_client_open_config_dir_failed") % _get_client_display_name(client_id))
		return
	var dir_path = config_path.get_base_dir()
	if dir_path.is_empty():
		_show_config_message(_localization.get_text("msg_client_open_config_dir_failed") % _get_client_display_name(client_id))
		return
	if not DirAccess.dir_exists_absolute(dir_path):
		var dir_error = DirAccess.make_dir_recursive_absolute(dir_path)
		if dir_error != OK:
			_show_config_message(_localization.get_text("msg_client_open_config_dir_failed") % _get_client_display_name(client_id))
			return
	var result = _config_service.open_target_path(dir_path)
	if not bool(result.get("success", false)):
		_show_config_message(_localization.get_text("msg_client_open_config_dir_failed") % _get_client_display_name(client_id))
		return
	_show_config_message(_localization.get_text("msg_client_open_config_dir_success") % _get_client_display_name(client_id))


func handle_config_client_open_config_file_requested(client_id: String) -> void:
	var client_statuses = _get_client_install_statuses.call() if _get_client_install_statuses.is_valid() else {}
	var detection: Dictionary = client_statuses.get(client_id, {})
	var config_path = str(detection.get("config_path", "")).strip_edges()
	if config_path.is_empty() or not FileAccess.file_exists(config_path):
		_show_config_message(_localization.get_text("msg_client_open_config_file_missing") % _get_client_display_name(client_id))
		return
	var result = _config_service.open_text_file(config_path)
	if not bool(result.get("success", false)):
		_show_config_message(_localization.get_text("msg_client_open_config_file_failed") % _get_client_display_name(client_id))
		return
	_show_config_message(_localization.get_text("msg_client_open_config_file_success") % _get_client_display_name(client_id))


func handle_config_write_requested(config_type: String, filepath: String, config: String, client_name: String) -> void:
	var preflight = _config_service.preflight_write_config(config_type, filepath, config)
	if not bool(preflight.get("success", false)):
		_show_config_message(_build_config_write_failure_message(preflight, filepath))
		return

	if bool(preflight.get("requires_confirmation", false)):
		_show_config_confirmation(
			_build_config_write_confirmation_message(client_name, preflight),
			func() -> void:
				_perform_config_write(config_type, filepath, config, client_name, preflight, true)
		)
		return

	_perform_config_write(config_type, filepath, config, client_name, preflight, false)


func handle_config_remove_requested(config_type: String, filepath: String, client_name: String) -> void:
	var inspection = _config_service.inspect_config_entry(config_type, filepath)
	if not bool(inspection.get("success", false)):
		_show_config_message(_build_config_remove_failure_message(inspection, filepath))
		return

	var status = str(inspection.get("status", "missing_file"))
	if status != "present":
		_show_config_message(_build_config_remove_noop_message(inspection, client_name))
		return

	_show_config_confirmation(
		_build_config_remove_confirmation_message(client_name, inspection),
		func() -> void:
			_perform_config_remove(config_type, filepath, client_name, inspection)
	)


func on_client_executable_file_selected(path: String) -> void:
	var client_id = str(_pending_client_path_request.get("client_id", "")).strip_edges()
	_pending_client_path_request = {}
	if client_id.is_empty():
		return

	var normalized_path = path.replace("\\", "/").strip_edges()
	if normalized_path.is_empty() or not FileAccess.file_exists(normalized_path):
		_show_config_message(_localization.get_text("msg_client_path_invalid"))
		return

	var manual_paths = _get_client_manual_paths()
	manual_paths[client_id] = normalized_path
	_state.settings["client_manual_paths"] = manual_paths
	_save_settings_if_possible()
	_configure_client_install_detection_service_if_possible()
	_invalidate_client_install_status_cache_if_possible()
	_refresh_dock_if_possible()
	_show_config_message("%s\n\n%s" % [
		_localization.get_text("msg_client_path_saved") % _get_client_display_name(client_id),
		normalized_path
	])


func _open_client_executable_dialog(client_id: String, detection: Dictionary) -> void:
	if _ensure_client_executable_dialog.is_valid():
		_ensure_client_executable_dialog.call()
	if not _get_client_executable_dialog.is_valid():
		_show_config_message(_localization.get_text("msg_client_path_dialog_unavailable"))
		return
	var client_executable_dialog = _get_client_executable_dialog.call()
	if client_executable_dialog == null or not is_instance_valid(client_executable_dialog):
		_show_config_message(_localization.get_text("msg_client_path_dialog_unavailable"))
		return

	var current_path = str(detection.get("executable_path", detection.get("manual_path", ""))).strip_edges()
	_pending_client_path_request = {"client_id": client_id}
	client_executable_dialog.title = _localization.get_text("msg_client_path_dialog_title") % _get_client_display_name(client_id)
	if not current_path.is_empty():
		client_executable_dialog.current_path = current_path
		client_executable_dialog.current_dir = current_path.get_base_dir()
	else:
		client_executable_dialog.current_dir = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	client_executable_dialog.popup_centered_ratio(0.75)


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
		_show_config_message(_build_config_write_failure_message(result, filepath))
		return

	_invalidate_client_install_status_cache_if_possible()
	_refresh_dock_if_possible()

	var success_lines: PackedStringArray = PackedStringArray([
		_localization.get_text("msg_config_success") % client_name,
		_localization.get_text("msg_config_verified") % str(result.get("path", filepath))
	])
	var backup_path = str(result.get("backup_path", "")).strip_edges()
	if not backup_path.is_empty():
		success_lines.append(_localization.get_text("msg_config_backup_created") % backup_path)
	success_lines.append(_localization.get_text("msg_config_effect_hint"))
	success_lines.append(_build_client_runtime_followup_message(config_type))
	_show_config_message("\n\n".join(success_lines))


func _perform_config_remove(config_type: String, filepath: String, client_name: String, inspection: Dictionary) -> void:
	var result = _config_service.remove_config_entry(config_type, filepath, {"inspection": inspection})
	if not bool(result.get("success", false)):
		_show_config_message(_build_config_remove_failure_message(result, filepath))
		return

	if not bool(result.get("removed", false)):
		_show_config_message(_build_config_remove_noop_message(result, client_name))
		return

	_invalidate_client_install_status_cache_if_possible()
	_refresh_dock_if_possible()

	var success_lines: PackedStringArray = PackedStringArray([
		_localization.get_text("msg_config_remove_success") % client_name
	])
	var backup_path = str(result.get("backup_path", "")).strip_edges()
	if not backup_path.is_empty():
		success_lines.append(_localization.get_text("msg_config_backup_created") % backup_path)
	success_lines.append(_build_client_runtime_followup_message(config_type))
	_show_config_message("\n\n".join(success_lines))


func _build_config_write_confirmation_message(client_name: String, preflight: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray([
		_localization.get_text("msg_config_overwrite_confirm") % client_name
	])
	var filepath = str(preflight.get("path", ""))
	match str(preflight.get("status", "")):
		"invalid_json":
			lines.append(_localization.get_text("msg_config_precheck_invalid_json") % filepath)
		"incompatible_root":
			lines.append(_localization.get_text("msg_config_precheck_incompatible_root") % filepath)
		"incompatible_mcp_servers":
			lines.append(_localization.get_text("msg_config_precheck_incompatible_servers") % filepath)
		"incompatible_mcp":
			lines.append(_localization.get_text("msg_config_precheck_incompatible_mcp") % filepath)
		_:
			lines.append(_localization.get_text("msg_write_error"))

	var backup_path = str(preflight.get("backup_path", "")).strip_edges()
	if not backup_path.is_empty():
		lines.append(_localization.get_text("msg_config_backup_notice") % backup_path)
	return "\n\n".join(lines)


func _build_config_remove_confirmation_message(client_name: String, inspection: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray([
		_localization.get_text("msg_config_remove_confirm") % client_name,
		_localization.get_text("msg_config_remove_safe_scope")
	])
	var backup_path = str(inspection.get("backup_path", "")).strip_edges()
	if not backup_path.is_empty():
		lines.append(_localization.get_text("msg_config_backup_notice") % backup_path)
	return "\n\n".join(lines)


func _build_config_write_failure_message(result: Dictionary, filepath: String) -> String:
	var message := ""
	match str(result.get("error", "")):
		"parse_error":
			message = _localization.get_text("msg_parse_error")
		"dir_error":
			message = _localization.get_text("msg_dir_error") + str(result.get("path", ""))
		"precheck_read_error":
			message = _localization.get_text("msg_config_precheck_read_error") % str(result.get("path", filepath))
		"precheck_confirmation_required":
			message = _build_config_write_confirmation_message("MCP", result)
		"backup_error":
			message = _localization.get_text("msg_config_backup_failed") % str(result.get("backup_path", filepath + ".bak"))
		"readback_missing_file":
			message = "%s\n\n%s" % [
				_localization.get_text("msg_config_readback_failed"),
				_localization.get_text("msg_config_readback_missing_file") % str(result.get("path", filepath))
			]
		"readback_open_error":
			message = "%s\n\n%s" % [
				_localization.get_text("msg_config_readback_failed"),
				_localization.get_text("msg_config_readback_open_error") % str(result.get("path", filepath))
			]
		"readback_parse_error", "readback_missing_servers":
			message = "%s\n\n%s" % [
				_localization.get_text("msg_config_readback_failed"),
				_localization.get_text("msg_config_readback_parse_error") % str(result.get("path", filepath))
			]
		"readback_missing_server":
			message = "%s\n\n%s" % [
				_localization.get_text("msg_config_readback_failed"),
				_localization.get_text("msg_config_readback_missing_server") % [
					str(result.get("server_name", "godot-mcp")),
					str(result.get("path", filepath))
				]
			]
		"readback_mismatch":
			message = "%s\n\n%s" % [
				_localization.get_text("msg_config_readback_failed"),
				_localization.get_text("msg_config_readback_mismatch") % [
					str(result.get("server_name", "godot-mcp")),
					str(result.get("path", filepath))
				]
			]
		_:
			message = _localization.get_text("msg_write_error")

	if bool(result.get("rollback_restored", false)):
		message = "%s\n\n%s" % [message, _localization.get_text("msg_config_restored_backup")]
	elif str(result.get("rollback_error", "")) == "restore_failed":
		message = "%s\n\n%s" % [
			message,
			_localization.get_text("msg_config_restore_failed") % str(result.get("backup_path", filepath + ".bak"))
		]
	return message


func _build_config_remove_failure_message(result: Dictionary, filepath: String) -> String:
	var message := ""
	match str(result.get("error", "")):
		"precheck_read_error":
			message = _localization.get_text("msg_config_precheck_read_error") % str(result.get("path", filepath))
		"backup_error":
			message = _localization.get_text("msg_config_backup_failed") % str(result.get("backup_path", filepath + ".bak"))
		"remove_blocked_invalid_json":
			message = _localization.get_text("msg_config_remove_blocked_invalid_json") % str(result.get("path", filepath))
		"remove_blocked_incompatible_root", "remove_blocked_incompatible_mcp_servers", "remove_blocked_incompatible_mcp":
			message = _localization.get_text("msg_config_remove_blocked_incompatible") % str(result.get("path", filepath))
		"readback_missing_file":
			message = _localization.get_text("msg_config_remove_readback_failed") % str(result.get("path", filepath))
		"readback_open_error", "readback_parse_error", "readback_missing_servers":
			message = _localization.get_text("msg_config_remove_readback_failed") % str(result.get("path", filepath))
		"readback_remove_mismatch":
			message = _localization.get_text("msg_config_remove_readback_mismatch") % [
				str(result.get("server_name", "godot-mcp")),
				str(result.get("path", filepath))
			]
		_:
			message = _localization.get_text("msg_config_remove_failed")

	if bool(result.get("rollback_restored", false)):
		message = "%s\n\n%s" % [message, _localization.get_text("msg_config_restored_backup")]
	elif str(result.get("rollback_error", "")) == "restore_failed":
		message = "%s\n\n%s" % [
			message,
			_localization.get_text("msg_config_restore_failed") % str(result.get("backup_path", filepath + ".bak"))
		]
	return message


func _build_config_remove_noop_message(result: Dictionary, client_name: String) -> String:
	match str(result.get("status", result.get("noop_reason", ""))):
		"missing_file":
			return _localization.get_text("msg_config_remove_noop_missing_file") % client_name
		"empty", "missing_server":
			return _localization.get_text("msg_config_remove_noop_missing_entry") % client_name
		_:
			return _localization.get_text("msg_config_remove_failed")


func _build_client_runtime_followup_message(client_id: String) -> String:
	var detection = _get_client_install_statuses.call().get(client_id, {}) if _get_client_install_statuses.is_valid() else {}
	var runtime_status = str(detection.get("runtime_status", {}).get("status", "unknown"))
	if runtime_status == "running":
		match client_id:
			"claude_desktop":
				return _localization.get_text("msg_config_restart_claude")
			"cursor":
				return _localization.get_text("msg_config_restart_cursor")
			"trae":
				return _localization.get_text("msg_config_restart_trae")
			"opencode", "opencode_desktop":
				return _localization.get_text("msg_config_restart_opencode")
			_:
				return _localization.get_text("msg_config_effect_hint")
	if runtime_status == "not_running":
		return _localization.get_text("msg_config_client_not_running")
	return _localization.get_text("msg_config_effect_hint")


func _get_client_manual_paths() -> Dictionary:
	var manual_paths = _state.settings.get("client_manual_paths", {})
	if manual_paths is Dictionary:
		return manual_paths.duplicate(true)
	return {}


func _get_client_display_name(client_id: String) -> String:
	match client_id:
		"claude_desktop":
			return _localization.get_text("config_client_claude_desktop")
		"claude_code":
			return _localization.get_text("config_client_claude_code")
		"cursor":
			return _localization.get_text("config_client_cursor")
		"trae":
			return _localization.get_text("config_client_trae")
		"codex_desktop":
			return _localization.get_text("config_client_codex_desktop")
		"codex":
			return _localization.get_text("config_client_codex")
		"opencode_desktop":
			return _localization.get_text("config_client_opencode_desktop")
		"opencode":
			return _localization.get_text("config_client_opencode")
		"gemini":
			return _localization.get_text("config_client_gemini")
		"windsurf":
			return _localization.get_text("config_client_windsurf")
		"cline":
			return _localization.get_text("config_client_cline")
		"roo_code":
			return _localization.get_text("config_client_roo_code")
		"qwen":
			return _localization.get_text("config_client_qwen")
		"cherry_studio":
			return _localization.get_text("config_client_cherry_studio")
		_:
			return client_id


func _toggle_claude_code_mcp_config(detection: Dictionary) -> void:
	if detection.is_empty() or str(detection.get("status", "")) != "ready":
		_show_config_message(_get_client_install_message_text("claude_code", str(detection.get("status", "missing"))))
		return

	var executable_path = str(detection.get("executable_path", "")).strip_edges()
	if executable_path.is_empty():
		_show_config_message(_localization.get_text("msg_client_action_missing_executable") % _localization.get_text("config_client_claude_code"))
		return

	var entry_status = str(detection.get("config_entry_status", {}).get("status", "missing_server"))
	var client_name = _localization.get_text("config_client_claude_code")
	if entry_status == "present":
		var remove_result = _config_service.execute_cli_command(executable_path, PackedStringArray(["mcp", "remove", MCP_SERVER_KEY]))
		if not bool(remove_result.get("success", false)):
			_show_config_message("%s\n\n%s" % [
				_localization.get_text("msg_config_remove_failed"),
				str(remove_result.get("message", ""))
			])
			return
		_invalidate_client_install_status_cache_if_possible()
		_refresh_dock_if_possible()
		_show_config_message(_localization.get_text("msg_config_remove_success") % client_name)
		return

	var add_result = _config_service.execute_cli_command(executable_path, _build_claude_code_add_arguments())
	if not bool(add_result.get("success", false)):
		_show_config_message("%s\n\n%s" % [
			_localization.get_text("msg_client_action_failed") % client_name,
			str(add_result.get("message", ""))
		])
		return

	_invalidate_client_install_status_cache_if_possible()
	_refresh_dock_if_possible()
	_show_config_message(_localization.get_text("msg_client_action_success") % client_name)


func _toggle_codex_mcp_config(detection: Dictionary) -> void:
	if detection.is_empty() or str(detection.get("status", "")) != "ready":
		_show_config_message(_get_client_install_message_text("codex", str(detection.get("status", "missing"))))
		return

	var executable_path = str(detection.get("executable_path", "")).strip_edges()
	if executable_path.is_empty():
		_show_config_message(_localization.get_text("msg_client_action_missing_executable") % _localization.get_text("config_client_codex"))
		return

	var client_name = _localization.get_text("config_client_codex")
	var entry_status = str(detection.get("config_entry_status", {}).get("status", "missing_server"))
	if entry_status == "present":
		var remove_result = _config_service.execute_cli_command(executable_path, PackedStringArray(["mcp", "remove", MCP_SERVER_KEY]))
		if not bool(remove_result.get("success", false)):
			_show_config_message("%s\n\n%s" % [
				_localization.get_text("msg_config_remove_failed"),
				str(remove_result.get("message", ""))
			])
			return
		_invalidate_client_install_status_cache_if_possible()
		_refresh_dock_if_possible()
		_show_config_message(_localization.get_text("msg_config_remove_success") % client_name)
		return

	var transport = _build_client_transport_model(str(_state.settings.get("host", "127.0.0.1")), int(_state.settings.get("port", 3000)))
	var add_result = _config_service.execute_cli_command(executable_path, _build_codex_add_arguments(transport))
	if not bool(add_result.get("success", false)):
		_show_config_message("%s\n\n%s" % [
			_localization.get_text("msg_client_action_failed") % client_name,
			str(add_result.get("message", ""))
		])
		return

	_invalidate_client_install_status_cache_if_possible()
	_refresh_dock_if_possible()
	_show_config_message(_localization.get_text("msg_client_action_success") % client_name)


func _toggle_gemini_mcp_config(detection: Dictionary) -> void:
	if detection.is_empty() or str(detection.get("status", "")) != "ready":
		_show_config_message(_get_client_install_message_text("gemini", str(detection.get("status", "missing"))))
		return

	var executable_path = str(detection.get("executable_path", "")).strip_edges()
	if executable_path.is_empty():
		_show_config_message(_localization.get_text("msg_client_action_missing_executable") % _localization.get_text("config_client_gemini"))
		return

	var client_name = _localization.get_text("config_client_gemini")
	var entry_status = str(detection.get("config_entry_status", {}).get("status", "missing_server"))
	if entry_status == "present":
		var remove_result = _config_service.execute_cli_command(executable_path, PackedStringArray(["mcp", "remove", MCP_SERVER_KEY]))
		if not bool(remove_result.get("success", false)):
			_show_config_message("%s\n\n%s" % [
				_localization.get_text("msg_config_remove_failed"),
				str(remove_result.get("message", ""))
			])
			return
		_invalidate_client_install_status_cache_if_possible()
		_refresh_dock_if_possible()
		_show_config_message(_localization.get_text("msg_config_remove_success") % client_name)
		return

	var add_result = _config_service.execute_cli_command(executable_path, _build_gemini_add_arguments())
	if not bool(add_result.get("success", false)):
		_show_config_message("%s\n\n%s" % [
			_localization.get_text("msg_client_action_failed") % client_name,
			str(add_result.get("message", ""))
		])
		return

	_invalidate_client_install_status_cache_if_possible()
	_refresh_dock_if_possible()
	_show_config_message(_localization.get_text("msg_client_action_success") % client_name)


func _toggle_qwen_mcp_config(detection: Dictionary) -> void:
	if detection.is_empty() or str(detection.get("status", "")) != "ready":
		_show_config_message(_get_client_install_message_text("qwen", str(detection.get("status", "missing"))))
		return

	var executable_path = str(detection.get("executable_path", "")).strip_edges()
	if executable_path.is_empty():
		_show_config_message(_localization.get_text("msg_client_action_missing_executable") % _localization.get_text("config_client_qwen"))
		return

	var client_name = _localization.get_text("config_client_qwen")
	var entry_status = str(detection.get("config_entry_status", {}).get("status", "missing_server"))
	if entry_status == "present":
		var remove_result = _config_service.execute_cli_command(executable_path, PackedStringArray(["mcp", "remove", MCP_SERVER_KEY]))
		if not bool(remove_result.get("success", false)):
			_show_config_message("%s\n\n%s" % [
				_localization.get_text("msg_config_remove_failed"),
				str(remove_result.get("message", ""))
			])
			return
		_invalidate_client_install_status_cache_if_possible()
		_refresh_dock_if_possible()
		_show_config_message(_localization.get_text("msg_config_remove_success") % client_name)
		return

	var add_result = _config_service.execute_cli_command(executable_path, _build_qwen_add_arguments())
	if not bool(add_result.get("success", false)):
		_show_config_message("%s\n\n%s" % [
			_localization.get_text("msg_client_action_failed") % client_name,
			str(add_result.get("message", ""))
		])
		return

	_invalidate_client_install_status_cache_if_possible()
	_refresh_dock_if_possible()
	_show_config_message(_localization.get_text("msg_client_action_success") % client_name)


func _launch_cursor_for_current_project(detection: Dictionary) -> void:
	_launch_desktop_agent_for_current_project(_localization.get_text("config_client_cursor"), detection)


func _launch_desktop_agent(client_name: String, detection: Dictionary, arguments: PackedStringArray) -> void:
	var executable_path = str(detection.get("executable_path", "")).strip_edges()
	if executable_path.is_empty():
		_show_config_message(_localization.get_text("msg_client_action_missing_executable") % client_name)
		return

	var project_root = _get_current_project_root()
	var result = _config_service.launch_desktop_client(executable_path, arguments, project_root)
	if not bool(result.get("success", false)):
		_show_config_message("%s\n\n%s" % [
			_localization.get_text("msg_client_launch_failed") % client_name,
			str(result.get("message", ""))
		])
		return

	_invalidate_client_install_status_cache_if_possible()
	_refresh_dock_if_possible()
	_show_config_message(_localization.get_text("msg_client_launch_success") % client_name)


func _launch_desktop_agent_for_current_project(client_name: String, detection: Dictionary) -> void:
	var executable_path = str(detection.get("executable_path", "")).strip_edges()
	if executable_path.is_empty():
		_show_config_message(_localization.get_text("msg_client_action_missing_executable") % client_name)
		return

	var project_root = _get_current_project_root()
	var result = _config_service.launch_desktop_client(
		executable_path,
		PackedStringArray([project_root]),
		project_root
	)
	if not bool(result.get("success", false)):
		_show_config_message("%s\n\n%s" % [
			_localization.get_text("msg_client_launch_failed") % client_name,
			str(result.get("message", ""))
		])
		return

	_invalidate_client_install_status_cache_if_possible()
	_refresh_dock_if_possible()
	_show_config_message("%s\n\n%s" % [
		_localization.get_text("msg_client_launch_success") % client_name,
		_localization.get_text("msg_client_launch_workdir") % project_root
	])


func _launch_cli_agent_for_current_project(client_id: String, client_name: String, detection: Dictionary) -> void:
	var executable_path = str(detection.get("executable_path", "")).strip_edges()
	if executable_path.is_empty():
		_show_config_message(_localization.get_text("msg_client_action_missing_executable") % client_name)
		return

	var project_root = _get_current_project_root()
	var arguments := PackedStringArray()
	match client_id:
		"claude_code", "codex":
			arguments = PackedStringArray()
		"gemini", "qwen":
			arguments = PackedStringArray()
		"opencode":
			arguments = PackedStringArray([project_root])
		_:
			_show_config_message(_localization.get_text("msg_client_launch_unsupported"))
			return

	var result = _config_service.launch_cli_client_in_terminal(executable_path, arguments, project_root)
	if not bool(result.get("success", false)):
		_show_config_message("%s\n\n%s" % [
			_localization.get_text("msg_client_launch_failed") % client_name,
			str(result.get("message", ""))
		])
		return

	_invalidate_client_install_status_cache_if_possible()
	_refresh_dock_if_possible()
	var followup_text = _localization.get_text("msg_client_launch_workdir") % project_root
	followup_text += "\n" + _localization.get_text("msg_client_launch_terminal_hint")
	_show_config_message("%s\n\n%s" % [
		_localization.get_text("msg_client_launch_success") % client_name,
		followup_text
	])


func _get_current_project_root() -> String:
	return ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")


func _build_client_transport_model(host: String, port: int) -> Dictionary:
	return {
		"mode": "http",
		"host": host,
		"port": port,
		"mode_label_key": "config_transport_http_fallback"
	}


func _build_codex_add_arguments(transport: Dictionary) -> PackedStringArray:
	return PackedStringArray([
		"mcp",
		"add",
		"godot-mcp",
		"--url",
		"http://%s:%d/mcp" % [str(transport.get("host", "127.0.0.1")), int(transport.get("port", 3000))]
	])


func _build_claude_code_add_arguments() -> PackedStringArray:
	return PackedStringArray([
		"mcp",
		"add",
		"--transport",
		"http",
		"--scope",
		str(_state.current_cli_scope),
		MCP_SERVER_KEY,
		"http://%s:%d/mcp" % [str(_state.settings.get("host", "127.0.0.1")), int(_state.settings.get("port", 3000))]
	])


func _build_gemini_add_arguments() -> PackedStringArray:
	return PackedStringArray([
		"mcp",
		"add",
		"--transport",
		"http",
		"--scope",
		str(_state.current_cli_scope),
		MCP_SERVER_KEY,
		"http://%s:%d/mcp" % [str(_state.settings.get("host", "127.0.0.1")), int(_state.settings.get("port", 3000))]
	])


func _build_qwen_add_arguments() -> PackedStringArray:
	return PackedStringArray([
		"mcp",
		"add",
		"--transport",
		"http",
		"--scope",
		str(_state.current_cli_scope),
		MCP_SERVER_KEY,
		"http://%s:%d/mcp" % [str(_state.settings.get("host", "127.0.0.1")), int(_state.settings.get("port", 3000))]
	])


func _get_client_install_message_text(client_id: String, status: String) -> String:
	var key := "config_client_%s_%s_msg" % [client_id, status]
	var localized = _localization.get_text(key)
	if localized == key:
		return ""
	return localized


func _show_config_message(message: String) -> void:
	if _show_message.is_valid():
		_show_message.call(message)


func _show_config_confirmation(message: String, on_confirmed: Callable) -> void:
	if _show_confirmation.is_valid():
		_show_confirmation.call(message, on_confirmed)
		return
	if on_confirmed.is_valid():
		on_confirmed.call()


func _save_settings_if_possible() -> void:
	if _save_settings.is_valid():
		_save_settings.call()


func _refresh_dock_if_possible() -> void:
	if _refresh_dock.is_valid():
		_refresh_dock.call()


func _invalidate_client_install_status_cache_if_possible() -> void:
	if _invalidate_client_install_status_cache.is_valid():
		_invalidate_client_install_status_cache.call()


func _configure_client_install_detection_service_if_possible() -> void:
	if _configure_client_install_detection_service.is_valid():
		_configure_client_install_detection_service.call()
