extends RefCounted

# {"name": "plugin_lifecycle_service_contracts"}

const PluginLifecycleServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/plugin_lifecycle_service.gd")
const PluginLifecycleContextServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/plugin_lifecycle_context_service.gd")


class FakeLifecycleContext:
	extends RefCounted

	var calls: Array[String] = []
	var process_enabled_values: Array = []
	var auto_start := true
	var runtime_bridge_owned := true
	var ensure_update_result := false
	var finished_operations: Array[Dictionary] = []

	func build() -> Dictionary:
		return {
			"runtime_bridge_autoload_name": "MCPRuntimeBridge",
			"runtime_bridge_autoload_path": "res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_bridge.gd",
			"refresh_service_instances": Callable(self, "refresh_service_instances"),
			"load_state": Callable(self, "load_state"),
			"configure_lifecycle_enter_state": Callable(self, "configure_lifecycle_enter_state"),
			"ensure_action_router": Callable(self, "ensure_action_router"),
			"ensure_dock_coordinator": Callable(self, "ensure_dock_coordinator"),
			"attach_server_controller": Callable(self, "attach_server_controller"),
			"configure_user_tool_watch_service": Callable(self, "configure_user_tool_watch_service"),
			"configure_config_tab_action_service": Callable(self, "configure_config_tab_action_service"),
			"ensure_runtime_bridge_autoload": Callable(self, "ensure_runtime_bridge_autoload"),
			"install_editor_debugger_bridge": Callable(self, "install_editor_debugger_bridge"),
			"create_dock": Callable(self, "create_dock"),
			"apply_initial_tool_profile_if_needed": Callable(self, "apply_initial_tool_profile_if_needed"),
			"refresh_dock": Callable(self, "refresh_dock"),
			"refresh_dock_if_status_changed": Callable(self, "refresh_dock_if_status_changed"),
			"set_process_enabled": Callable(self, "set_process_enabled"),
			"should_auto_start_server": Callable(self, "should_auto_start_server"),
			"start_server_for_lifecycle": Callable(self, "start_server_for_lifecycle"),
			"defer_start_server_for_lifecycle": Callable(self, "defer_start_server_for_lifecycle"),
			"restore_pending_focus_snapshot_if_needed": Callable(self, "restore_pending_focus_snapshot_if_needed"),
			"ensure_saved_update_source_discovery_requested": Callable(self, "ensure_saved_update_source_discovery_requested"),
			"save_settings": Callable(self, "save_settings"),
			"stop_user_tool_watch_service": Callable(self, "stop_user_tool_watch_service"),
			"remove_dock": Callable(self, "remove_dock"),
			"remove_client_executable_dialog": Callable(self, "remove_client_executable_dialog"),
			"uninstall_editor_debugger_bridge": Callable(self, "uninstall_editor_debugger_bridge"),
			"remove_runtime_bridge_autoload": Callable(self, "remove_runtime_bridge_autoload"),
			"dispose_action_router": Callable(self, "dispose_action_router"),
			"dispose_server_controller": Callable(self, "dispose_server_controller"),
			"dispose_lifecycle_services": Callable(self, "dispose_lifecycle_services"),
			"is_runtime_bridge_currently_owned": Callable(self, "is_runtime_bridge_currently_owned"),
			"tick_user_tool_watch_service": Callable(self, "tick_user_tool_watch_service"),
			"ensure_update_refs_discovery_requested": Callable(self, "ensure_update_refs_discovery_requested"),
			"finish_self_operation": Callable(self, "finish_self_operation")
		}

	func refresh_service_instances() -> void: calls.append("refresh_service_instances")
	func load_state() -> void: calls.append("load_state")
	func configure_lifecycle_enter_state() -> void: calls.append("configure_lifecycle_enter_state")
	func ensure_action_router() -> void: calls.append("ensure_action_router")
	func ensure_dock_coordinator() -> void: calls.append("ensure_dock_coordinator")
	func attach_server_controller() -> void: calls.append("attach_server_controller")
	func configure_user_tool_watch_service() -> void: calls.append("configure_user_tool_watch_service")
	func configure_config_tab_action_service() -> void: calls.append("configure_config_tab_action_service")
	func ensure_runtime_bridge_autoload() -> void: calls.append("ensure_runtime_bridge_autoload")
	func install_editor_debugger_bridge() -> void: calls.append("install_editor_debugger_bridge")
	func create_dock() -> void: calls.append("create_dock")
	func apply_initial_tool_profile_if_needed() -> void: calls.append("apply_initial_tool_profile_if_needed")
	func refresh_dock() -> void: calls.append("refresh_dock")
	func refresh_dock_if_status_changed() -> void: calls.append("refresh_dock_if_status_changed")
	func start_server_for_lifecycle() -> void: calls.append("start_server_for_lifecycle")
	func defer_start_server_for_lifecycle() -> void: calls.append("defer_start_server_for_lifecycle")
	func restore_pending_focus_snapshot_if_needed() -> void: calls.append("restore_pending_focus_snapshot_if_needed")
	func ensure_saved_update_source_discovery_requested() -> void: calls.append("ensure_saved_update_source_discovery_requested")
	func save_settings() -> void: calls.append("save_settings")
	func stop_user_tool_watch_service() -> void: calls.append("stop_user_tool_watch_service")
	func remove_dock() -> void: calls.append("remove_dock")
	func remove_client_executable_dialog() -> void: calls.append("remove_client_executable_dialog")
	func uninstall_editor_debugger_bridge() -> void: calls.append("uninstall_editor_debugger_bridge")
	func remove_runtime_bridge_autoload() -> void: calls.append("remove_runtime_bridge_autoload")
	func dispose_action_router() -> void: calls.append("dispose_action_router")
	func dispose_server_controller() -> void: calls.append("dispose_server_controller")
	func dispose_lifecycle_services() -> void: calls.append("dispose_lifecycle_services")
	func tick_user_tool_watch_service() -> void: calls.append("tick_user_tool_watch_service")

	func set_process_enabled(enabled: bool) -> void:
		calls.append("set_process_enabled:%s" % str(enabled))
		process_enabled_values.append(enabled)

	func should_auto_start_server() -> bool:
		calls.append("should_auto_start_server")
		return auto_start

	func is_runtime_bridge_currently_owned() -> bool:
		calls.append("is_runtime_bridge_currently_owned")
		return runtime_bridge_owned

	func ensure_update_refs_discovery_requested() -> bool:
		calls.append("ensure_update_refs_discovery_requested")
		return ensure_update_result

	func finish_self_operation(operation: Dictionary, success: bool, component: String, phase: String) -> void:
		calls.append("finish_self_operation:%s" % phase)
		finished_operations.append({
			"operation": operation.duplicate(true),
			"success": success,
			"component": component,
			"phase": phase
		})

	func _refresh_service_instances() -> void: refresh_service_instances()
	func _load_state() -> void: load_state()
	func _configure_lifecycle_enter_state() -> void: configure_lifecycle_enter_state()
	func _ensure_action_router() -> void: ensure_action_router()
	func _ensure_dock_coordinator() -> void: ensure_dock_coordinator()
	func _attach_server_controller() -> void: attach_server_controller()
	func _configure_user_tool_watch_service() -> void: configure_user_tool_watch_service()
	func _configure_config_tab_action_service() -> void: configure_config_tab_action_service()
	func _ensure_runtime_bridge_autoload() -> void: ensure_runtime_bridge_autoload()
	func _install_editor_debugger_bridge() -> void: install_editor_debugger_bridge()
	func _create_dock() -> void: create_dock()
	func _apply_initial_tool_profile_if_needed() -> void: apply_initial_tool_profile_if_needed()
	func _refresh_dock() -> void: refresh_dock()
	func _refresh_dock_if_status_changed() -> void: refresh_dock_if_status_changed()
	func _set_plugin_process_enabled(enabled: bool) -> void: set_process_enabled(enabled)
	func _should_auto_start_server() -> bool: return should_auto_start_server()
	func _start_server_for_lifecycle() -> void: start_server_for_lifecycle()
	func _defer_start_server_for_lifecycle() -> void: defer_start_server_for_lifecycle()
	func _restore_pending_focus_snapshot_if_needed() -> void: restore_pending_focus_snapshot_if_needed()
	func _defer_saved_update_source_discovery_request() -> void: ensure_saved_update_source_discovery_requested()
	func _save_settings() -> void: save_settings()
	func _stop_user_tool_watch_service() -> void: stop_user_tool_watch_service()
	func _remove_dock() -> void: remove_dock()
	func _remove_client_executable_dialog() -> void: remove_client_executable_dialog()
	func _uninstall_editor_debugger_bridge() -> void: uninstall_editor_debugger_bridge()
	func _remove_runtime_bridge_autoload() -> void: remove_runtime_bridge_autoload()
	func _dispose_action_router() -> void: dispose_action_router()
	func _dispose_server_controller() -> void: dispose_server_controller()
	func _dispose_lifecycle_services() -> void: dispose_lifecycle_services()
	func _is_runtime_bridge_currently_owned() -> bool: return is_runtime_bridge_currently_owned()
	func _tick_user_tool_watch_service() -> void: tick_user_tool_watch_service()
	func _ensure_update_refs_discovery_requested() -> bool: return ensure_update_refs_discovery_requested()
	func _finish_self_operation(operation: Dictionary, success: bool, component: String, phase: String) -> void:
		finish_self_operation(operation, success, component, phase)


func run_case(_tree: SceneTree) -> Dictionary:
	var source_guard := _assert_plugin_entrypoint_delegates_to_lifecycle_service()
	if not source_guard.is_empty():
		return _failure(source_guard)
	var context_guard := _assert_plugin_lifecycle_context_service_builds_entrypoint_context()
	if not context_guard.is_empty():
		return _failure(context_guard)

	var service = PluginLifecycleServiceScript.new()
	var enter_context := FakeLifecycleContext.new()
	service.enter_tree(enter_context.build())
	var enter_calls := enter_context.calls
	var expected_enter := [
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
		"apply_initial_tool_profile_if_needed",
		"refresh_dock",
		"set_process_enabled:true",
		"should_auto_start_server",
		"defer_start_server_for_lifecycle",
		"restore_pending_focus_snapshot_if_needed",
		"ensure_saved_update_source_discovery_requested"
	]
	if not _array_starts_with(enter_calls, expected_enter):
		return _failure("Plugin lifecycle service should preserve enter_tree wiring order.", {"calls": enter_calls})
	if enter_context.finished_operations.is_empty() or str((enter_context.finished_operations[0] as Dictionary).get("phase", "")) != "_enter_tree":
		return _failure("Plugin lifecycle service should finish the enter_tree diagnostic operation.")

	var no_autostart_context := FakeLifecycleContext.new()
	no_autostart_context.auto_start = false
	service.enter_tree(no_autostart_context.build())
	if no_autostart_context.calls.has("start_server_for_lifecycle") or no_autostart_context.calls.has("defer_start_server_for_lifecycle"):
		return _failure("Plugin lifecycle service should not start the server when auto_start is disabled.")

	var exit_context := FakeLifecycleContext.new()
	service.exit_tree(exit_context.build())
	var expected_exit := [
		"set_process_enabled:false",
		"save_settings",
		"stop_user_tool_watch_service",
		"remove_dock",
		"remove_client_executable_dialog",
		"uninstall_editor_debugger_bridge",
		"remove_runtime_bridge_autoload",
		"dispose_action_router",
		"dispose_server_controller",
		"dispose_lifecycle_services"
	]
	if not _array_starts_with(exit_context.calls, expected_exit):
		return _failure("Plugin lifecycle service should preserve exit_tree teardown order.", {"calls": exit_context.calls})
	if exit_context.finished_operations.is_empty() or str((exit_context.finished_operations[0] as Dictionary).get("phase", "")) != "_exit_tree":
		return _failure("Plugin lifecycle service should finish the exit_tree diagnostic operation.")

	var process_context := FakeLifecycleContext.new()
	var accumulator := service.process(0.25, 0.2, false, process_context.build())
	if not is_equal_approx(accumulator, 0.45) or process_context.calls != ["tick_user_tool_watch_service"]:
		return _failure("Plugin lifecycle service should tick watchers and accumulate status polling below threshold.", {"calls": process_context.calls, "accumulator": accumulator})
	process_context.calls.clear()
	accumulator = service.process(0.1, 1.95, false, process_context.build())
	if not is_zero_approx(accumulator) or process_context.calls != ["tick_user_tool_watch_service", "refresh_dock_if_status_changed"]:
		return _failure("Plugin lifecycle service should request a lightweight dock refresh only when the status poll interval elapses.", {"calls": process_context.calls, "accumulator": accumulator})
	process_context.calls.clear()
	process_context.ensure_update_result = true
	accumulator = service.process(0.5, 0.1, true, process_context.build())
	if not is_equal_approx(accumulator, 0.1) or process_context.calls != ["tick_user_tool_watch_service", "ensure_update_refs_discovery_requested"]:
		return _failure("Plugin lifecycle service should keep the poll accumulator when update discovery retry consumes the frame.", {"calls": process_context.calls, "accumulator": accumulator})

	var disable_context := FakeLifecycleContext.new()
	service.disable_plugin(disable_context.build())
	if not disable_context.calls.has("is_runtime_bridge_currently_owned"):
		return _failure("Plugin lifecycle service should query runtime bridge ownership during disable.")
	if disable_context.finished_operations.is_empty() or str((disable_context.finished_operations[0] as Dictionary).get("phase", "")) != "_disable_plugin":
		return _failure("Plugin lifecycle service should finish the disable diagnostic operation.")

	return {
		"name": "plugin_lifecycle_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"enter_steps": expected_enter.size(),
			"exit_steps": expected_exit.size(),
			"process_refresh_calls": 1
		}
	}


func _assert_plugin_entrypoint_delegates_to_lifecycle_service() -> String:
	var source_path := "res://addons/godot_dotnet_mcp/plugin.gd"
	if not FileAccess.file_exists(source_path):
		return "Plugin entrypoint source should exist for lifecycle delegation guard."
	var source := FileAccess.get_file_as_string(source_path)
	for required in [
		"PluginLifecycleContextServiceScript.new()",
		"_plugin_lifecycle_context_service.build_plugin_lifecycle_context(self,",
		"_plugin_lifecycle_service.enter_tree(_build_plugin_lifecycle_context())",
		"_plugin_lifecycle_service.exit_tree(_build_plugin_lifecycle_context())",
		"_plugin_lifecycle_service.disable_plugin(_build_plugin_lifecycle_context())",
		"_plugin_lifecycle_service.process(delta, _status_poll_accumulator, _update_refs_discovery_retry_pending, _get_plugin_lifecycle_context())",
		"func _defer_start_server_for_lifecycle()",
		"call_deferred(\"_start_server_for_lifecycle\")",
		"_user_tool_watch_tick_accumulator += maxf(delta, 0.0)",
		"const USER_TOOL_WATCH_TICK_INTERVAL := 0.25",
		"func _get_plugin_lifecycle_context()",
		"_cached_lifecycle_context = _build_plugin_lifecycle_context()",
		"func _invalidate_plugin_lifecycle_context()"
	]:
		if source.find(required) == -1:
			return "Plugin entrypoint should delegate lifecycle wiring through PluginLifecycleService: %s" % required
	for forbidden in [
		"\"refresh_service_instances\": Callable(self",
		"\"load_state\": Callable(self",
		"\"finish_self_operation\": Callable(self",
		"_plugin_lifecycle_service.enter_tree(_get_plugin_lifecycle_context())"
	]:
		if source.find(forbidden) != -1:
			return "Plugin entrypoint should not rebuild lifecycle context callback maps: %s" % forbidden
	return ""


func _assert_plugin_lifecycle_context_service_builds_entrypoint_context() -> String:
	var service = PluginLifecycleContextServiceScript.new()
	var fake := FakeLifecycleContext.new()
	var context: Dictionary = service.build_plugin_lifecycle_context(fake, {
		"runtime_bridge_autoload_name": "MCPRuntimeBridge",
		"runtime_bridge_autoload_path": "res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_bridge.gd"
	})
	for key in fake.build().keys():
		if not context.has(key):
			return "PluginLifecycleContextService should preserve lifecycle context key: %s" % str(key)
		if key.ends_with("_name") or key.ends_with("_path"):
			continue
		if not (context.get(key, Callable()) is Callable) or not (context[key] as Callable).is_valid():
			return "PluginLifecycleContextService should expose a valid callable for key: %s" % str(key)
	if str(context.get("runtime_bridge_autoload_name", "")) != "MCPRuntimeBridge":
		return "PluginLifecycleContextService should preserve runtime bridge autoload name."
	(context["refresh_service_instances"] as Callable).call()
	if fake.calls != ["refresh_service_instances"]:
		return "PluginLifecycleContextService should wire callbacks to the plugin host."
	return ""


func _array_starts_with(actual: Array, expected: Array) -> bool:
	if actual.size() < expected.size():
		return false
	for index in range(expected.size()):
		if str(actual[index]) != str(expected[index]):
			return false
	return true


func _failure(message: String, details: Dictionary = {}) -> Dictionary:
	return {
		"name": "plugin_lifecycle_service_contracts",
		"success": false,
		"error": message,
		"details": details
	}
