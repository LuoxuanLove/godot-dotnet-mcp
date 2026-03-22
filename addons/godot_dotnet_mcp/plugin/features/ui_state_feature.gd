extends RefCounted

const TreeCollapseState = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tree_collapse_state.gd")

var _state
var _localization
var _save_settings := Callable()
var _refresh_dock := Callable()
var _show_message := Callable()
var _invalidate_client_install_status_cache := Callable()
var _capture_dock_focus_snapshot := Callable()
var _restore_dock_focus_snapshot := Callable()


func configure(state, localization, callbacks: Dictionary) -> void:
	_state = state
	_localization = localization
	_save_settings = callbacks.get("save_settings", Callable())
	_refresh_dock = callbacks.get("refresh_dock", Callable())
	_show_message = callbacks.get("show_message", Callable())
	_invalidate_client_install_status_cache = callbacks.get("invalidate_client_install_status_cache", Callable())
	_capture_dock_focus_snapshot = callbacks.get("capture_dock_focus_snapshot", Callable())
	_restore_dock_focus_snapshot = callbacks.get("restore_dock_focus_snapshot", Callable())


func handle_current_tab_changed(index: int) -> void:
	if _state == null:
		return
	_state.current_tab = index
	if _state.current_tab == 2:
		_call_invalidate_client_install_status_cache()
	_call_refresh_dock()


func handle_port_changed(value: int) -> void:
	if _state == null:
		return
	_state.settings["port"] = value
	_call_save_settings()
	_call_refresh_dock()


func handle_language_changed(language_code: String) -> void:
	if _state == null:
		return
	var focus_snapshot = _capture_focus_snapshot()
	_state.settings["language"] = language_code
	if _localization != null:
		_localization.set_language(language_code)
	_call_save_settings()
	_call_refresh_dock()
	_restore_focus_snapshot(focus_snapshot)


func handle_tree_collapse_changed(kind: String, key: String, collapsed: bool) -> void:
	if _state == null:
		return
	TreeCollapseState.set_node_collapsed(_state.settings, kind, key, collapsed)
	_call_save_settings()


func handle_cli_scope_changed(scope: String) -> void:
	if _state == null:
		return
	_state.current_cli_scope = scope
	_state.settings["current_cli_scope"] = scope
	_call_save_settings()
	_call_refresh_dock()


func handle_config_platform_changed(platform_id: String) -> void:
	if _state == null:
		return
	_state.current_config_platform = platform_id
	_state.settings["current_config_platform"] = platform_id
	_call_save_settings()
	_call_refresh_dock()


func handle_copy_requested(text: String, source: String) -> void:
	DisplayServer.clipboard_set(text)
	var message := "Copied: %s" % source
	if _localization != null:
		message = _localization.get_text("msg_copied") % source
	_call_show_message(message)


func _capture_focus_snapshot() -> Dictionary:
	if not _capture_dock_focus_snapshot.is_valid():
		return {}
	var snapshot = _capture_dock_focus_snapshot.call()
	if snapshot is Dictionary:
		return snapshot
	return {}


func _restore_focus_snapshot(snapshot: Dictionary) -> void:
	if _restore_dock_focus_snapshot.is_valid():
		_restore_dock_focus_snapshot.call(snapshot)


func _call_save_settings() -> void:
	if _save_settings.is_valid():
		_save_settings.call()


func _call_refresh_dock() -> void:
	if _refresh_dock.is_valid():
		_refresh_dock.call()


func _call_show_message(message: String) -> void:
	if _show_message.is_valid():
		_show_message.call(message)


func _call_invalidate_client_install_status_cache() -> void:
	if _invalidate_client_install_status_cache.is_valid():
		_invalidate_client_install_status_cache.call()
