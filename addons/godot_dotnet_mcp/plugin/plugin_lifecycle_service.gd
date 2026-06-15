@tool
extends RefCounted
class_name PluginLifecycleService

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const MCPRuntimeDebugStore = preload("res://addons/godot_dotnet_mcp/tools/shared/mcp_runtime_debug_store.gd")
const PluginInstanceFreshness = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_instance_freshness.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")

const STATUS_POLL_INTERVAL_SECONDS := 2.0


func enter_tree(context: Dictionary) -> void:
	PluginSelfDiagnosticStore.clear()
	var operation = PluginSelfDiagnosticStore.begin_operation("plugin_enter_tree", "_enter_tree")
	PluginInstanceFreshness.capture_running_instance("plugin_enter_tree")

	for step in [
		"cleanup_stale_update_sync_addon_files",
		"refresh_service_instances",
		"load_state",
		"configure_lifecycle_enter_state",
		"ensure_action_router",
		"ensure_dock_coordinator",
		"attach_server_controller",
		"configure_user_tool_watch_service",
		"configure_config_tab_action_service",
		"ensure_runtime_bridge_autoload",
		"install_editor_debugger_bridge",
		"create_dock",
		"apply_initial_tool_profile_if_needed"
	]:
		_call_void(context.get(step, Callable()))

	_call_void(context.get("set_process_enabled", Callable()), [true])
	_call_void(context.get("defer_initial_dock_refresh", Callable()))
	if _call_bool(context.get("should_auto_start_server", Callable()), false):
		_call_void(context.get("defer_start_server_for_lifecycle", Callable()))

	_call_void(context.get("restore_pending_focus_snapshot_if_needed", Callable()))
	_call_void(context.get("ensure_saved_update_source_discovery_requested", Callable()))
	_finish_operation(context, operation, true, "plugin", "_enter_tree")
	MCPDebugBuffer.record("info", "plugin", "Plugin initialized")


func exit_tree(context: Dictionary) -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("plugin_exit_tree", "_exit_tree")
	_call_void(context.get("set_process_enabled", Callable()), [false])
	for step in [
		"save_settings",
		"stop_user_tool_watch_service",
		"remove_dock",
		"remove_client_executable_dialog",
		"uninstall_editor_debugger_bridge",
		"remove_runtime_bridge_autoload",
		"dispose_action_router",
		"dispose_server_controller",
		"dispose_lifecycle_services"
	]:
		_call_void(context.get(step, Callable()))
	_finish_operation(context, operation, true, "plugin", "_exit_tree")


func disable_plugin(context: Dictionary) -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("plugin_disable", "_disable_plugin")
	MCPRuntimeDebugStore.set_bridge_status(
		_call_bool(context.get("is_runtime_bridge_currently_owned", Callable()), false),
		str(context.get("runtime_bridge_autoload_name", "")),
		str(context.get("runtime_bridge_autoload_path", "")),
		"Plugin disabled without removing runtime bridge autoload"
	)
	_finish_operation(context, operation, true, "plugin", "_disable_plugin")


func process(delta: float, status_poll_accumulator: float, update_refs_retry_pending: bool, context: Dictionary) -> float:
	_call_void(context.get("tick_user_tool_watch_service", Callable()))
	if update_refs_retry_pending and _call_bool(context.get("ensure_update_refs_discovery_requested", Callable()), false):
		return status_poll_accumulator
	status_poll_accumulator += delta
	if status_poll_accumulator >= STATUS_POLL_INTERVAL_SECONDS:
		status_poll_accumulator = 0.0
		_call_void(context.get("refresh_dock_if_status_changed", Callable()))
	return status_poll_accumulator


func _finish_operation(context: Dictionary, operation: Dictionary, success: bool, component: String, phase: String) -> void:
	var callback: Callable = context.get("finish_self_operation", Callable())
	if callback.is_valid():
		callback.call(operation, success, component, phase)
		return
	if operation.is_empty():
		return
	PluginSelfDiagnosticStore.end_operation(str(operation.get("operation_id", "")), success, [], {
		"component": component,
		"phase": phase
	})


func _call_void(callable: Callable, args: Array = []) -> void:
	if callable.is_valid():
		callable.callv(args)


func _call_bool(callable: Callable, default_value: bool) -> bool:
	if not callable.is_valid():
		return default_value
	var value = callable.call()
	if value is bool:
		return bool(value)
	if value is int:
		return int(value) != 0
	if value is float:
		return !is_zero_approx(float(value))
	if value is String:
		var normalized = str(value).strip_edges().to_lower()
		return normalized == "true" or normalized == "1" or normalized == "yes" or normalized == "on"
	return value != null
