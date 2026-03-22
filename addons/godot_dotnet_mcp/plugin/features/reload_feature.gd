extends RefCounted

const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")

var _owner: Object
var _is_server_running := Callable()
var _start_server := Callable()
var _reinitialize_server := Callable()
var _refresh_service_instances := Callable()
var _reset_localization := Callable()
var _recreate_server_controller := Callable()
var _configure_central_server_process_service := Callable()
var _configure_central_server_attach_service := Callable()
var _configure_feature_workflows := Callable()
var _recreate_dock := Callable()
var _refresh_dock := Callable()
var _capture_dock_focus_snapshot := Callable()
var _restore_runtime_dock_focus_snapshot := Callable()
var _finish_self_operation := Callable()
var _pending_runtime_reload_action := ""


func configure(owner: Object, callbacks: Dictionary) -> void:
	_owner = owner
	_is_server_running = callbacks.get("is_server_running", Callable())
	_start_server = callbacks.get("start_server", Callable())
	_reinitialize_server = callbacks.get("reinitialize_server", Callable())
	_refresh_service_instances = callbacks.get("refresh_service_instances", Callable())
	_reset_localization = callbacks.get("reset_localization", Callable())
	_recreate_server_controller = callbacks.get("recreate_server_controller", Callable())
	_configure_central_server_process_service = callbacks.get("configure_central_server_process_service", Callable())
	_configure_central_server_attach_service = callbacks.get("configure_central_server_attach_service", Callable())
	_configure_feature_workflows = callbacks.get("configure_feature_workflows", Callable())
	_recreate_dock = callbacks.get("recreate_dock", Callable())
	_refresh_dock = callbacks.get("refresh_dock", Callable())
	_capture_dock_focus_snapshot = callbacks.get("capture_dock_focus_snapshot", Callable())
	_restore_runtime_dock_focus_snapshot = callbacks.get("restore_runtime_dock_focus_snapshot", Callable())
	_finish_self_operation = callbacks.get("finish_self_operation", Callable())


func runtime_restart_server() -> Dictionary:
	var operation = PluginSelfDiagnosticStore.begin_operation("runtime_restart_server", "runtime_restart_server")
	if not _pending_runtime_reload_action.is_empty():
		_finish_operation(operation, false, "plugin", "runtime_restart_server", ["runtime_reload_pending"])
		return {
			"success": false,
			"error": "Runtime reload already scheduled: %s" % _pending_runtime_reload_action
		}

	_pending_runtime_reload_action = "runtime_restart_server"
	_schedule_runtime_reload(Callable(self, "_complete_runtime_server_restart").bind(str(operation.get("operation_id", ""))))
	return {
		"success": true,
		"message": "Runtime server restart scheduled",
		"running": _call_bool(_is_server_running),
		"deferred": true
	}


func runtime_soft_reload() -> Dictionary:
	var operation = PluginSelfDiagnosticStore.begin_operation("runtime_soft_reload", "runtime_soft_reload")
	if not _pending_runtime_reload_action.is_empty():
		_finish_operation(operation, false, "plugin", "runtime_soft_reload", ["runtime_reload_pending"])
		return {
			"success": false,
			"error": "Runtime reload already scheduled: %s" % _pending_runtime_reload_action
		}

	var was_running = _call_bool(_is_server_running)
	var focus_snapshot = _call_capture_focus_snapshot()
	_pending_runtime_reload_action = "runtime_soft_reload"
	_schedule_runtime_reload(Callable(self, "_complete_runtime_soft_reload").bind(str(operation.get("operation_id", "")), was_running, focus_snapshot))
	return {
		"success": true,
		"message": "Plugin soft reload scheduled",
		"running": was_running,
		"deferred": true
	}


func runtime_full_reload() -> Dictionary:
	var operation = PluginSelfDiagnosticStore.begin_operation("runtime_full_reload", "runtime_full_reload")
	var was_running = _call_bool(_is_server_running)
	var focus_snapshot = _call_capture_focus_snapshot()
	_schedule_runtime_reload(Callable(self, "_complete_runtime_full_reload").bind(str(operation.get("operation_id", "")), was_running, focus_snapshot))
	return {"success": true, "message": "Plugin full reload scheduled"}


func _schedule_runtime_reload(callback: Callable) -> void:
	if _owner != null and is_instance_valid(_owner):
		var tree = _owner.get_tree()
		if tree != null:
			var timer = tree.create_timer(0.05)
			timer.timeout.connect(callback, CONNECT_ONE_SHOT)
			return
	callback.call_deferred()


func _complete_runtime_server_restart(operation_id: String) -> void:
	var success = _call_bool(_start_server, ["tool_runtime_restart"])
	_call_void(_refresh_dock)
	_pending_runtime_reload_action = ""
	_finish_operation({"operation_id": operation_id}, success, "plugin", "runtime_restart_server")


func _complete_runtime_soft_reload(operation_id: String, was_running: bool, focus_snapshot: Dictionary = {}) -> void:
	var success := false
	_call_void(_refresh_service_instances)
	_call_void(_recreate_server_controller)
	_call_void(_reset_localization)
	_call_void(_configure_central_server_process_service)
	_call_void(_configure_central_server_attach_service)
	_call_void(_configure_feature_workflows)
	if was_running:
		success = _call_bool(_start_server, ["tool_soft_reload"])
	else:
		success = _call_bool(_reinitialize_server, ["tool_soft_reload"])
	_call_void(_recreate_dock)
	_call_void(_refresh_dock)
	_call_void(_restore_runtime_dock_focus_snapshot, [focus_snapshot])
	_pending_runtime_reload_action = ""
	_finish_operation({"operation_id": operation_id}, success, "plugin", "runtime_soft_reload")


func _complete_runtime_full_reload(operation_id: String, was_running: bool, focus_snapshot: Dictionary = {}) -> void:
	var success := false
	_call_void(_refresh_service_instances)
	_call_void(_recreate_server_controller)
	_call_void(_reset_localization)
	_call_void(_configure_central_server_process_service)
	_call_void(_configure_central_server_attach_service)
	_call_void(_configure_feature_workflows)
	if was_running:
		success = _call_bool(_start_server, ["tool_full_reload"])
	else:
		success = _call_bool(_reinitialize_server, ["tool_full_reload"])
	_call_void(_recreate_dock)
	_call_void(_refresh_dock)
	_call_void(_restore_runtime_dock_focus_snapshot, [focus_snapshot])
	_pending_runtime_reload_action = ""
	_finish_operation({"operation_id": operation_id}, success, "plugin", "runtime_full_reload")


func _call_capture_focus_snapshot() -> Dictionary:
	if _capture_dock_focus_snapshot.is_valid():
		var snapshot = _capture_dock_focus_snapshot.call()
		if snapshot is Dictionary:
			return snapshot
	return {}


func _finish_operation(operation: Dictionary, success: bool, component: String, phase: String, anomaly_codes: Array = [], context: Dictionary = {}) -> void:
	if _finish_self_operation.is_valid():
		_finish_self_operation.call(operation, success, component, phase, anomaly_codes, context)


func _call_void(callback: Callable, args: Array = []) -> void:
	if callback.is_valid():
		callback.callv(args)


func _call_bool(callback: Callable, args: Array = []) -> bool:
	if callback.is_valid():
		return bool(callback.callv(args))
	return false
