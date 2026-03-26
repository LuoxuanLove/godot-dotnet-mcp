@tool
extends RefCounted
class_name MCPEditorLifecycleActionService

var _build_state := Callable()
var _build_state_with_hint := Callable()
var _success := Callable()
var _error := Callable()
var _schedule_action := Callable()
var _get_plugin_host := Callable()
var _log := Callable()


func configure(callbacks: Dictionary = {}) -> void:
	_build_state = callbacks.get("build_state", Callable())
	_build_state_with_hint = callbacks.get("build_state_with_hint", Callable())
	_success = callbacks.get("success", Callable())
	_error = callbacks.get("error", Callable())
	_schedule_action = callbacks.get("schedule_action", Callable())
	_get_plugin_host = callbacks.get("get_plugin_host", Callable())
	_log = callbacks.get("log", Callable())


func execute_close(args: Dictionary) -> Dictionary:
	return _execute_action(
		"close",
		args,
		"Explicit confirmation is required before closing the editor.",
		"Pass save=true for a graceful close or force=true for host-managed fallback.",
		"Graceful editor close requires save=true when called from the editor lifecycle bridge.",
		"Force fallback is handled by the host and should not be routed through the editor lifecycle bridge.",
		"Editor close accepted"
	)


func execute_restart(args: Dictionary) -> Dictionary:
	return _execute_action(
		"restart",
		args,
		"Explicit confirmation is required before restarting the editor.",
		"Pass save=true for a graceful restart or force=true for host-managed fallback.",
		"Graceful editor restart requires save=true when called from the editor lifecycle bridge.",
		"Force fallback is handled by the host and should not be routed through the editor lifecycle bridge.",
		"Editor restart accepted"
	)


func run_deferred_action(action: String) -> void:
	_prepare_shutdown(action)
	var plugin = _get_plugin_host_safe()
	if plugin == null:
		return
	var tree = plugin.get_tree()
	if tree == null:
		_finalize_action(action)
		return
	var timer: SceneTreeTimer = tree.create_timer(0.2)
	timer.timeout.connect(Callable(self, "_finalize_action").bind(action), CONNECT_ONE_SHOT)


func _execute_action(action: String, args: Dictionary, confirmation_message: String, confirmation_hint: String, graceful_message: String, graceful_hint: String, accepted_message: String) -> Dictionary:
	var save := bool(args.get("save", false))
	var force := bool(args.get("force", false))
	if not save and not force:
		return _call_error("editor_confirmation_required", confirmation_message, _build_state_hint(confirmation_hint))
	if not save:
		return _call_error("editor_confirmation_required", graceful_message, _build_state_hint(graceful_hint))

	_schedule(action)
	return _call_success({
		"accepted": true,
		"action": action,
		"save": true,
		"force": false,
		"editor_state": _build_state_safe()
	}, accepted_message)


func _prepare_shutdown(action: String) -> void:
	var plugin = _get_plugin_host_safe()
	if plugin == null:
		return
	var editor_interface = plugin.get_editor_interface()
	if editor_interface != null and editor_interface.has_method("save_all_scenes"):
		editor_interface.save_all_scenes()
	if plugin.has_method("get_central_server_attach_service"):
		var attach_service = plugin.get_central_server_attach_service()
		if attach_service != null and attach_service.has_method("stop"):
			attach_service.stop()
	_log_message("Editor lifecycle %s scheduled" % action, "info")


func _finalize_action(action: String) -> void:
	var plugin = _get_plugin_host_safe()
	if plugin == null:
		return
	if action == "close":
		var tree: SceneTree = plugin.get_tree()
		if tree != null:
			tree.quit()
		return

	var editor_interface = plugin.get_editor_interface()
	if editor_interface != null and editor_interface.has_method("restart_editor"):
		editor_interface.restart_editor(true)


func _schedule(action: String) -> void:
	if _schedule_action.is_valid():
		_schedule_action.call(action)


func _build_state_safe() -> Dictionary:
	if _build_state.is_valid():
		var state = _build_state.call()
		if state is Dictionary:
			return (state as Dictionary).duplicate(true)
	return {}


func _build_state_hint(hint: String) -> Dictionary:
	if _build_state_with_hint.is_valid():
		var state = _build_state_with_hint.call(hint)
		if state is Dictionary:
			return (state as Dictionary).duplicate(true)
	var fallback := _build_state_safe()
	fallback["hint"] = hint
	return fallback


func _call_success(data, message: String) -> Dictionary:
	if _success.is_valid():
		var result = _success.call(data, message)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	return {
		"success": true,
		"data": data,
		"message": message
	}


func _call_error(error: String, message: String, data: Dictionary = {}) -> Dictionary:
	if _error.is_valid():
		var result = _error.call(error, message, data)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	var payload := {
		"success": false,
		"error": error,
		"message": message,
		"status": 400
	}
	if not data.is_empty():
		payload["data"] = data.duplicate(true)
	return payload


func _get_plugin_host_safe():
	if _get_plugin_host.is_valid():
		var plugin = _get_plugin_host.call()
		if plugin != null and is_instance_valid(plugin):
			return plugin
	return null


func _log_message(message: String, level: String) -> void:
	if _log.is_valid():
		_log.call(message, level)
