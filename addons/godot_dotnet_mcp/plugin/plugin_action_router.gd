@tool
extends RefCounted

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")

var _server_controller = null
var _state = null
var _localization = null
var _server_feature = null
var _config_feature = null
var _user_tool_feature = null
var _tool_access_feature = null
var _self_diagnostic_feature = null
var _ui_state_feature = null
var _reload_feature = null
var _build_dock_model: Callable
var _get_dock: Callable


func configure(context: Dictionary) -> void:
	_server_controller = context.get("server_controller", null)
	_state = context.get("state", null)
	_localization = context.get("localization", null)
	_server_feature = context.get("server_feature", null)
	_config_feature = context.get("config_feature", null)
	_user_tool_feature = context.get("user_tool_feature", null)
	_tool_access_feature = context.get("tool_access_feature", null)
	_self_diagnostic_feature = context.get("self_diagnostic_feature", null)
	_ui_state_feature = context.get("ui_state_feature", null)
	_reload_feature = context.get("reload_feature", null)
	_build_dock_model = context.get("build_dock_model", Callable())
	_get_dock = context.get("get_dock", Callable())


func build_dock_signal_bindings() -> Array[Dictionary]:
	return [
		{"signal": "current_tab_changed", "callable": Callable(_ui_state_feature, "handle_current_tab_changed")},
		{"signal": "port_changed", "callable": Callable(_ui_state_feature, "handle_port_changed")},
		{"signal": "log_level_changed", "callable": Callable(self, "handle_log_level_changed")},
		{"signal": "permission_level_changed", "callable": Callable(self, "handle_permission_level_changed")},
		{"signal": "language_changed", "callable": Callable(_ui_state_feature, "handle_language_changed")},
		{"signal": "start_requested", "callable": Callable(self, "handle_start_requested")},
		{"signal": "restart_requested", "callable": Callable(self, "handle_restart_requested")},
		{"signal": "stop_requested", "callable": Callable(self, "handle_stop_requested")},
		{"signal": "full_reload_requested", "callable": Callable(_reload_feature, "runtime_full_reload")},
		{"signal": "central_server_detect_requested", "callable": Callable(self, "handle_central_server_detect_requested")},
		{"signal": "central_server_install_requested", "callable": Callable(self, "handle_central_server_install_requested")},
		{"signal": "central_server_start_requested", "callable": Callable(self, "handle_central_server_start_requested")},
		{"signal": "central_server_stop_requested", "callable": Callable(self, "handle_central_server_stop_requested")},
		{"signal": "central_server_open_install_dir_requested", "callable": Callable(self, "handle_central_server_open_install_dir_requested")},
		{"signal": "central_server_open_logs_requested", "callable": Callable(self, "handle_central_server_open_logs_requested")},
		{"signal": "clear_self_diagnostics_requested", "callable": Callable(self, "handle_clear_self_diagnostics_requested")},
		{"signal": "delete_user_tool_requested", "callable": Callable(self, "handle_delete_user_tool_requested")},
		{"signal": "tool_toggled", "callable": Callable(self, "handle_tool_toggled")},
		{"signal": "category_toggled", "callable": Callable(self, "handle_category_toggled")},
		{"signal": "domain_toggled", "callable": Callable(self, "handle_domain_toggled")},
		{"signal": "tree_collapse_changed", "callable": Callable(_ui_state_feature, "handle_tree_collapse_changed")},
		{"signal": "cli_scope_changed", "callable": Callable(_ui_state_feature, "handle_cli_scope_changed")},
		{"signal": "config_platform_changed", "callable": Callable(_ui_state_feature, "handle_config_platform_changed")},
		{"signal": "config_validate_requested", "callable": Callable(self, "handle_config_validate_requested")},
		{"signal": "config_client_action_requested", "callable": Callable(self, "handle_config_client_action_requested")},
		{"signal": "config_client_launch_requested", "callable": Callable(self, "handle_config_client_launch_requested")},
		{"signal": "config_client_path_pick_requested", "callable": Callable(self, "handle_config_client_path_pick_requested")},
		{"signal": "config_client_path_clear_requested", "callable": Callable(self, "handle_config_client_path_clear_requested")},
		{"signal": "config_client_open_config_dir_requested", "callable": Callable(self, "handle_config_client_open_config_dir_requested")},
		{"signal": "config_client_open_config_file_requested", "callable": Callable(self, "handle_config_client_open_config_file_requested")},
		{"signal": "config_write_requested", "callable": Callable(self, "handle_config_write_requested")},
		{"signal": "config_remove_requested", "callable": Callable(self, "handle_config_remove_requested")},
		{"signal": "copy_requested", "callable": Callable(_ui_state_feature, "handle_copy_requested")}
	]


func refresh_dock() -> void:
	var dock = _resolve_dock()
	if dock == null or not is_instance_valid(dock):
		return
	if not dock.is_visible_in_tree():
		return
	if _build_dock_model.is_valid():
		dock.apply_model(_build_dock_model.call())


func show_message(message: String) -> void:
	MCPDebugBuffer.record("info", "plugin", message)
	var dock = _resolve_dock()
	if dock != null and is_instance_valid(dock):
		var title := "Godot MCP"
		if _localization != null:
			title = _localization.get_text("dialog_title")
		dock.show_message(title, message)


func show_confirmation(message: String, on_confirmed: Callable) -> void:
	MCPDebugBuffer.record("info", "plugin", message)
	var dock = _resolve_dock()
	if dock != null and is_instance_valid(dock) and dock.has_method("show_confirmation"):
		var title := "Godot MCP"
		if _localization != null:
			title = _localization.get_text("dialog_title")
		dock.show_confirmation(title, message, on_confirmed)
		return
	if on_confirmed.is_valid():
		on_confirmed.call()


func handle_server_started() -> void:
	refresh_dock()


func handle_server_stopped() -> void:
	refresh_dock()


func handle_request_received(_method: String, _params: Dictionary) -> void:
	refresh_dock()


func handle_start_requested() -> void:
	if _server_controller != null and _state != null:
		_server_controller.start(_state.settings, "ui_start")
	refresh_dock()


func handle_restart_requested() -> void:
	if _server_controller != null and _state != null:
		_server_controller.start(_state.settings, "ui_restart")
	refresh_dock()


func handle_stop_requested() -> void:
	if _server_controller != null:
		_server_controller.stop()
	refresh_dock()


func handle_log_level_changed(level: String) -> void:
	if _tool_access_feature != null:
		_tool_access_feature.handle_log_level_changed(level)


func handle_permission_level_changed(level: String) -> void:
	if _tool_access_feature != null:
		_tool_access_feature.handle_permission_level_changed(level)


func handle_show_user_tools_changed(enabled: bool) -> void:
	if _tool_access_feature != null:
		_tool_access_feature.handle_show_user_tools_changed(enabled)


func handle_delete_user_tool_requested(script_path: String) -> void:
	if _user_tool_feature != null:
		_user_tool_feature.handle_delete_requested(script_path)


func handle_tool_toggled(tool_name: String, enabled: bool) -> void:
	if _tool_access_feature != null:
		_tool_access_feature.handle_tool_toggled(tool_name, enabled)


func handle_category_toggled(category: String, enabled: bool) -> void:
	if _tool_access_feature != null:
		_tool_access_feature.handle_category_toggled(category, enabled)


func handle_domain_toggled(domain_key: String, enabled: bool) -> void:
	if _tool_access_feature != null:
		_tool_access_feature.handle_domain_toggled(domain_key, enabled)


func handle_config_validate_requested(_platform_id: String) -> void:
	if _config_feature != null:
		_config_feature.handle_validate_requested()


func handle_config_client_action_requested(client_id: String) -> void:
	if _config_feature != null:
		_config_feature.handle_client_action_requested(client_id)


func handle_config_client_launch_requested(client_id: String) -> void:
	if _config_feature != null:
		_config_feature.handle_client_launch_requested(client_id)


func handle_config_client_path_pick_requested(client_id: String) -> void:
	if _config_feature != null:
		_config_feature.handle_client_path_pick_requested(client_id)


func handle_config_client_path_clear_requested(client_id: String) -> void:
	if _config_feature != null:
		_config_feature.handle_client_path_clear_requested(client_id)


func handle_config_client_open_config_dir_requested(client_id: String) -> void:
	if _config_feature != null:
		_config_feature.handle_client_open_config_dir_requested(client_id)


func handle_config_client_open_config_file_requested(client_id: String) -> void:
	if _config_feature != null:
		_config_feature.handle_client_open_config_file_requested(client_id)


func handle_config_write_requested(config_type: String, filepath: String, config: String, client_name: String) -> void:
	if _config_feature != null:
		_config_feature.handle_write_requested(config_type, filepath, config, client_name)


func handle_config_remove_requested(config_type: String, filepath: String, client_name: String) -> void:
	if _config_feature != null:
		_config_feature.handle_remove_requested(config_type, filepath, client_name)


func handle_client_executable_file_selected(path: String) -> void:
	if _config_feature != null:
		_config_feature.handle_client_executable_file_selected(path)


func apply_user_tool_catalog_refresh(script_path: String = "", reason: String = "user_tool_catalog_refresh") -> void:
	if _user_tool_feature != null:
		_user_tool_feature.apply_user_tool_catalog_refresh(script_path, reason)


func apply_external_user_tool_catalog_refresh(changed_paths: Array[String], reason: String = "external_watch") -> void:
	if _user_tool_feature != null:
		_user_tool_feature.apply_external_user_tool_catalog_refresh(changed_paths, reason)


func reload_user_tool_runtime(script_path: String, reason: String) -> Dictionary:
	if _user_tool_feature != null:
		return _user_tool_feature.reload_user_tool_runtime(script_path, reason)
	return {"success": false, "error": "User tool feature is unavailable"}


func reload_all_tool_domains() -> Dictionary:
	if _server_controller != null:
		return _server_controller.reload_all_domains()
	return {"success": false, "error": "Server controller is unavailable"}


func handle_central_server_detect_requested() -> void:
	if _server_feature != null:
		_server_feature.handle_detect_requested()


func handle_central_server_install_requested() -> void:
	if _server_feature != null:
		_server_feature.handle_install_requested()


func handle_central_server_start_requested() -> void:
	if _server_feature != null:
		_server_feature.handle_start_requested()


func handle_central_server_stop_requested() -> void:
	if _server_feature != null:
		_server_feature.handle_stop_requested()


func handle_central_server_open_install_dir_requested() -> void:
	if _server_feature != null:
		_server_feature.handle_open_install_dir_requested()


func handle_central_server_open_logs_requested() -> void:
	if _server_feature != null:
		_server_feature.handle_open_logs_requested()


func handle_clear_self_diagnostics_requested() -> void:
	if _self_diagnostic_feature != null:
		_self_diagnostic_feature.handle_clear_requested()


func _resolve_dock():
	if not _get_dock.is_valid():
		return null
	return _get_dock.call()
