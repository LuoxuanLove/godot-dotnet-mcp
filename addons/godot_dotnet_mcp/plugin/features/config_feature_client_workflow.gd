extends RefCounted

var _settings: Dictionary = {}
var _localization
var _config_service
var _dock_presenter
var _central_server_process_service
var _client_install_detection_service
var _show_message := Callable()
var _refresh_dock := Callable()
var _save_settings := Callable()
var _ensure_client_executable_dialog := Callable()
var _get_client_executable_dialog := Callable()
var _pending_client_path_request := {}


func configure(context) -> void:
	if context == null:
		dispose()
		return
	_settings = context.settings
	_localization = context.localization
	_config_service = context.config_service
	_dock_presenter = context.dock_presenter
	_central_server_process_service = context.central_server_process_service
	_client_install_detection_service = context.client_install_detection_service
	_show_message = context.show_message
	_refresh_dock = context.refresh_dock
	_save_settings = context.save_settings
	_ensure_client_executable_dialog = context.ensure_client_executable_dialog
	_get_client_executable_dialog = context.get_client_executable_dialog


func dispose() -> void:
	_settings = {}
	_localization = null
	_config_service = null
	_dock_presenter = null
	_central_server_process_service = null
	_client_install_detection_service = null
	_show_message = Callable()
	_refresh_dock = Callable()
	_save_settings = Callable()
	_ensure_client_executable_dialog = Callable()
	_get_client_executable_dialog = Callable()
	_pending_client_path_request = {}


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
			_launch_desktop_agent_for_current_project(_get_localized_text("config_client_cursor"), client_statuses.get("cursor", {}))
		"trae":
			_launch_desktop_agent_for_current_project(_get_localized_text("config_client_trae"), client_statuses.get("trae", {}))
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


func get_statuses() -> Dictionary:
	return _get_statuses()


func invalidate_client_install_status_cache() -> void:
	_call_invalidate_client_install_status_cache()


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
	if _client_install_detection_service == null:
		return {}
	_client_install_detection_service.configure(_settings)
	var result = _client_install_detection_service.detect_all()
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


func _call_refresh_dock() -> void:
	if _refresh_dock.is_valid():
		_refresh_dock.call()


func _call_save_settings() -> void:
	if _save_settings.is_valid():
		_save_settings.call()


func _call_invalidate_client_install_status_cache() -> void:
	if _client_install_detection_service != null:
		_client_install_detection_service.invalidate_cache()


func _call_configure_detection_service() -> void:
	if _client_install_detection_service != null:
		_client_install_detection_service.configure(_settings)


func _call_ensure_client_executable_dialog() -> void:
	if _ensure_client_executable_dialog.is_valid():
		_ensure_client_executable_dialog.call()
