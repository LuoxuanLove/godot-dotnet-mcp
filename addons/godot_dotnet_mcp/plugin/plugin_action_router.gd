@tool
extends RefCounted
class_name PluginActionRouter

var _plugin = null
var _autoload_name := ""
var _autoload_path := ""


func configure(plugin, autoload_name: String = "", autoload_path: String = "") -> void:
	_plugin = plugin
	_autoload_name = autoload_name
	_autoload_path = autoload_path


func dispose() -> void:
	_plugin = null
	_autoload_name = ""
	_autoload_path = ""


func build_dock_signal_bindings() -> Array[Dictionary]:
	return [
		{"signal": "current_tab_changed", "callable": Callable(self, "current_tab_changed")},
		{"signal": "port_changed", "callable": Callable(self, "port_changed")},
		{"signal": "log_level_changed", "callable": Callable(self, "log_level_changed")},
		{"signal": "language_changed", "callable": Callable(self, "language_changed")},
		{"signal": "update_source_changed", "callable": Callable(self, "update_source_changed")},
		{"signal": "update_custom_branch_changed", "callable": Callable(self, "update_custom_branch_changed")},
		{"signal": "update_check_requested", "callable": Callable(self, "update_check_requested")},
		{"signal": "update_apply_requested", "callable": Callable(self, "update_apply_requested")},
		{"signal": "start_requested", "callable": Callable(self, "start_requested")},
		{"signal": "restart_requested", "callable": Callable(self, "restart_requested")},
		{"signal": "stop_requested", "callable": Callable(self, "stop_requested")},
		{"signal": "full_reload_requested", "callable": Callable(self, "full_reload_requested")},
		{"signal": "clear_self_diagnostics_requested", "callable": Callable(self, "clear_self_diagnostics_requested")},
		{"signal": "delete_user_tool_requested", "callable": Callable(self, "delete_user_tool_requested")},
		{"signal": "tool_toggled", "callable": Callable(self, "tool_toggled")},
		{"signal": "category_toggled", "callable": Callable(self, "category_toggled")},
		{"signal": "domain_toggled", "callable": Callable(self, "domain_toggled")},
		{"signal": "tree_collapse_changed", "callable": Callable(self, "tree_collapse_changed")},
		{"signal": "cli_scope_changed", "callable": Callable(self, "cli_scope_changed")},
		{"signal": "config_platform_changed", "callable": Callable(self, "config_platform_changed")},
		{"signal": "config_client_action_requested", "callable": Callable(self, "config_client_action_requested")},
		{"signal": "config_client_launch_requested", "callable": Callable(self, "config_client_launch_requested")},
		{"signal": "config_client_path_pick_requested", "callable": Callable(self, "config_client_path_pick_requested")},
		{"signal": "config_client_path_clear_requested", "callable": Callable(self, "config_client_path_clear_requested")},
		{"signal": "config_client_open_config_dir_requested", "callable": Callable(self, "config_client_open_config_dir_requested")},
		{"signal": "config_client_open_config_file_requested", "callable": Callable(self, "config_client_open_config_file_requested")},
		{"signal": "config_write_requested", "callable": Callable(self, "config_write_requested")},
		{"signal": "config_remove_requested", "callable": Callable(self, "config_remove_requested")},
		{"signal": "copy_requested", "callable": Callable(self, "copy_requested")}
	]


func current_tab_changed(index: int) -> void:
	_call_plugin_method("_on_current_tab_changed", [index])


func port_changed(value: int) -> void:
	_call_plugin_method("_on_port_changed", [value])


func log_level_changed(level: String) -> void:
	_call_plugin_method("_on_log_level_changed", [level])


func language_changed(language_code: String) -> void:
	_call_plugin_method("_on_language_changed", [language_code])


func update_source_changed(source: String) -> void:
	_call_plugin_method("_on_update_source_changed", [source])


func update_custom_branch_changed(branch: String) -> void:
	_call_plugin_method("_on_update_custom_branch_changed", [branch])



func update_check_requested() -> void:
	_call_plugin_method("_on_update_check_requested")


func update_apply_requested() -> void:
	_call_plugin_method("_on_update_sync_requested")


func start_requested() -> void:
	_call_plugin_method("_on_start_requested")


func restart_requested() -> void:
	_call_plugin_method("_on_restart_requested")


func stop_requested() -> void:
	_call_plugin_method("_on_stop_requested")


func full_reload_requested() -> void:
	_call_plugin_method("_on_full_reload_requested")


func clear_self_diagnostics_requested() -> void:
	_call_plugin_method("_on_clear_self_diagnostics_requested")


func delete_user_tool_requested(script_path: String) -> void:
	_call_plugin_method("_on_delete_user_tool_requested", [script_path])


func tool_toggled(tool_name: String, enabled: bool) -> void:
	_call_plugin_method("_on_tool_toggled", [tool_name, enabled])


func category_toggled(category: String, enabled: bool) -> void:
	_call_plugin_method("_on_category_toggled", [category, enabled])


func domain_toggled(domain_key: String, enabled: bool) -> void:
	_call_plugin_method("_on_domain_toggled", [domain_key, enabled])


func tree_collapse_changed(kind: String, key: String, collapsed: bool) -> void:
	_call_plugin_method("_on_tree_collapse_changed", [kind, key, collapsed])


func cli_scope_changed(scope: String) -> void:
	_call_plugin_method("_on_cli_scope_changed", [scope])


func config_platform_changed(platform_id: String) -> void:
	_call_plugin_method("_on_config_platform_changed", [platform_id])


func config_client_action_requested(client_id: String) -> void:
	_call_plugin_method("_on_config_client_action_requested", [client_id])


func config_client_launch_requested(client_id: String) -> void:
	_call_plugin_method("_on_config_client_launch_requested", [client_id])


func config_client_path_pick_requested(client_id: String) -> void:
	_call_plugin_method("_on_config_client_path_pick_requested", [client_id])


func config_client_path_clear_requested(client_id: String) -> void:
	_call_plugin_method("_on_config_client_path_clear_requested", [client_id])


func config_client_open_config_dir_requested(client_id: String) -> void:
	_call_plugin_method("_on_config_client_open_config_dir_requested", [client_id])


func config_client_open_config_file_requested(client_id: String) -> void:
	_call_plugin_method("_on_config_client_open_config_file_requested", [client_id])


func config_write_requested(config_type: String, filepath: String, config: String, client_name: String) -> void:
	_call_plugin_method("_on_config_write_requested", [config_type, filepath, config, client_name])


func config_remove_requested(config_type: String, filepath: String, client_name: String) -> void:
	_call_plugin_method("_on_config_remove_requested", [config_type, filepath, client_name])


func copy_requested(text: String, source: String) -> void:
	_call_plugin_method("_on_copy_requested", [text, source])


func show_message(message: String) -> void:
	if not _call_plugin_method("_show_message", [message]):
		_call_plugin_method("show_message", [message])


func show_confirmation(message: String, on_confirmed: Callable) -> void:
	if _call_plugin_method("_show_confirmation", [message, on_confirmed]):
		return
	if on_confirmed.is_valid():
		on_confirmed.call()


func refresh_dock() -> void:
	if not _call_plugin_method("_refresh_dock"):
		_call_plugin_method("refresh_dock")


func reload_all_tool_domains() -> Dictionary:
	var result = _call_server_controller_method("reload_all_domains")
	if result is Dictionary:
		return result
	return {"success": false, "error": "Server controller unavailable"}


func handle_server_started() -> void:
	_call_plugin_method("_on_server_started")


func handle_server_stopped() -> void:
	_call_plugin_method("_on_server_stopped")


func handle_request_received(method: String, params: Dictionary) -> void:
	_call_plugin_method("_on_request_received", [method, params])


func _call_plugin_method(method_name: String, args: Array = []) -> bool:
	if _plugin == null or not _plugin.has_method(method_name):
		return false
	_plugin.callv(method_name, args)
	return true


func _call_server_controller_method(method_name: String, args: Array = []):
	var server_controller = _get_server_controller()
	if server_controller == null or not server_controller.has_method(method_name):
		return null
	return server_controller.callv(method_name, args)


func _get_server_controller():
	if _plugin == null:
		return null
	if _plugin.has_method("get_server"):
		var server = _plugin.get_server()
		if server != null:
			return server
	return _plugin.get("_server_controller")
