@tool
extends RefCounted
class_name PluginReloadRuntimeContext

var owner: Object = null
var is_server_running := Callable()
var start_server := Callable()
var reinitialize_server := Callable()
var refresh_service_instances := Callable()
var reset_localization := Callable()
var recreate_server_controller := Callable()
var configure_central_server_process_service := Callable()
var configure_central_server_attach_service := Callable()
var configure_feature_workflows := Callable()
var recreate_dock := Callable()
var refresh_dock := Callable()
var capture_dock_focus_snapshot := Callable()
var restore_runtime_dock_focus_snapshot := Callable()
var finish_self_operation := Callable()


func dispose() -> void:
	owner = null
	is_server_running = Callable()
	start_server = Callable()
	reinitialize_server = Callable()
	refresh_service_instances = Callable()
	reset_localization = Callable()
	recreate_server_controller = Callable()
	configure_central_server_process_service = Callable()
	configure_central_server_attach_service = Callable()
	configure_feature_workflows = Callable()
	recreate_dock = Callable()
	refresh_dock = Callable()
	capture_dock_focus_snapshot = Callable()
	restore_runtime_dock_focus_snapshot = Callable()
	finish_self_operation = Callable()
