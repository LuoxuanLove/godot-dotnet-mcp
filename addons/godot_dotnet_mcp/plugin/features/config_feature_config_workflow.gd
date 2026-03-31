extends RefCounted

var _localization
var _config_service
var _get_statuses := Callable()
var _show_message := Callable()
var _show_confirmation := Callable()
var _refresh_dock := Callable()
var _invalidate_client_install_status_cache := Callable()


func configure(context) -> void:
	if context == null:
		dispose()
		return
	_localization = context.localization
	_config_service = context.config_service
	_get_statuses = context.get_statuses
	_show_message = context.show_message
	_show_confirmation = context.show_confirmation
	_refresh_dock = context.refresh_dock
	_invalidate_client_install_status_cache = context.invalidate_client_install_status_cache


func dispose() -> void:
	_localization = null
	_config_service = null
	_get_statuses = Callable()
	_show_message = Callable()
	_show_confirmation = Callable()
	_refresh_dock = Callable()
	_invalidate_client_install_status_cache = Callable()


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
	var detection = _get_statuses_safe().get(client_id, {})
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


func _get_statuses_safe() -> Dictionary:
	if _get_statuses.is_valid():
		var result = _get_statuses.call()
		if result is Dictionary:
			return result
	return {}


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


func _call_invalidate_client_install_status_cache() -> void:
	if _invalidate_client_install_status_cache.is_valid():
		_invalidate_client_install_status_cache.call()
