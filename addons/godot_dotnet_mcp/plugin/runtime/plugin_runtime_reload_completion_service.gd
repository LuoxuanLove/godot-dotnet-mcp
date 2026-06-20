@tool
extends RefCounted
class_name PluginRuntimeReloadCompletionService


func complete_server_restart(context: Dictionary) -> bool:
	var state = context.get("state", null)
	var server_controller = _get_server_controller(context)
	if state == null or server_controller == null:
		return false
	var success = server_controller.start(state.settings, "tool_runtime_restart")
	_call_void(context.get("refresh_dock", Callable()))
	return bool(success)


func complete_soft_reload(context: Dictionary, was_running: bool, focus_snapshot: Dictionary = {}) -> bool:
	return _complete_plugin_reload(context, was_running, focus_snapshot, "tool_soft_reload")


func complete_full_reload(context: Dictionary, was_running: bool, focus_snapshot: Dictionary = {}) -> bool:
	return _complete_plugin_reload(context, was_running, focus_snapshot, "tool_full_reload")


func capture_dock_focus_snapshot(dock, state) -> Dictionary:
	if dock != null and is_instance_valid(dock) and dock.has_method("capture_focus_snapshot"):
		return dock.capture_focus_snapshot()
	var tab_index := 0
	if state != null:
		tab_index = int(state.current_tab)
	return {"tab_index": tab_index, "focus_path": ""}


func restore_dock_focus_snapshot(context: Dictionary, snapshot: Dictionary) -> void:
	var dock = context.get("dock", null)
	if dock == null or not is_instance_valid(dock):
		return
	var state = context.get("state", null)
	if state != null:
		state.current_tab = int(snapshot.get("tab_index", state.current_tab))
	if dock.has_method("activate_editor_dock_tab"):
		dock.activate_editor_dock_tab()
	if dock.has_method("restore_focus_snapshot"):
		dock.restore_focus_snapshot(snapshot)
	if dock.has_method("focus_active_panel"):
		dock.call_deferred("focus_active_panel")
	if state != null and int(state.current_tab) == 5:
		_call_bool(context.get("ensure_update_refs_discovery_requested", Callable()), false)


func _complete_plugin_reload(context: Dictionary, was_running: bool, focus_snapshot: Dictionary, reason: String) -> bool:
	var state = context.get("state", null)
	var server_controller = _get_server_controller(context)
	if state == null or server_controller == null:
		return false
	_call_void(context.get("refresh_service_instances", Callable()))
	_call_void(context.get("recreate_server_controller", Callable()))
	_call_void(context.get("reset_localization", Callable()))
	server_controller = _get_server_controller(context)
	if server_controller == null:
		return false
	var success := false
	if was_running:
		success = bool(server_controller.start(state.settings, reason))
	else:
		success = bool(server_controller.reinitialize(state.settings, reason))
	_call_void(context.get("recreate_dock", Callable()))
	_call_void(context.get("refresh_dock", Callable()))
	restore_dock_focus_snapshot(context, focus_snapshot)
	return success


func _call_void(callable: Callable) -> void:
	if callable.is_valid():
		callable.call()


func _call_bool(callable: Callable, default_value: bool) -> bool:
	if not callable.is_valid():
		return default_value
	var value = callable.call()
	if value is bool:
		return bool(value)
	return value != null


func _get_server_controller(context: Dictionary):
	var callback: Callable = context.get("get_server_controller", Callable())
	if callback.is_valid():
		return callback.call()
	return context.get("server_controller", null)
