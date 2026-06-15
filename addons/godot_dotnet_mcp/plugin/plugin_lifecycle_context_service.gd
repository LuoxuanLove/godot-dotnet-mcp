@tool
extends RefCounted
class_name PluginLifecycleContextService


func build_plugin_lifecycle_context(plugin, constants: Dictionary) -> Dictionary:
	return {
		"runtime_bridge_autoload_name": str(constants.get("runtime_bridge_autoload_name", "")),
		"runtime_bridge_autoload_path": str(constants.get("runtime_bridge_autoload_path", "")),
		"cleanup_stale_update_sync_addon_files": _plugin_callable(plugin, "_cleanup_stale_update_sync_addon_files"),
		"refresh_service_instances": _plugin_callable(plugin, "_refresh_service_instances"),
		"load_state": _plugin_callable(plugin, "_load_state"),
		"configure_lifecycle_enter_state": _plugin_callable(plugin, "_configure_lifecycle_enter_state"),
		"ensure_action_router": _plugin_callable(plugin, "_ensure_action_router"),
		"ensure_dock_coordinator": _plugin_callable(plugin, "_ensure_dock_coordinator"),
		"attach_server_controller": _plugin_callable(plugin, "_attach_server_controller"),
		"configure_user_tool_watch_service": _plugin_callable(plugin, "_configure_user_tool_watch_service"),
		"configure_config_tab_action_service": _plugin_callable(plugin, "_configure_config_tab_action_service"),
		"ensure_runtime_bridge_autoload": _plugin_callable(plugin, "_ensure_runtime_bridge_autoload"),
		"install_editor_debugger_bridge": _plugin_callable(plugin, "_install_editor_debugger_bridge"),
		"create_dock": _plugin_callable(plugin, "_create_dock"),
		"apply_initial_tool_profile_if_needed": _plugin_callable(plugin, "_apply_initial_tool_profile_if_needed"),
		"refresh_dock": _plugin_callable(plugin, "_refresh_dock"),
		"defer_initial_dock_refresh": _plugin_callable(plugin, "_defer_initial_dock_refresh"),
		"refresh_dock_if_status_changed": _plugin_callable(plugin, "_refresh_dock_if_status_changed"),
		"set_process_enabled": _plugin_callable(plugin, "_set_plugin_process_enabled"),
		"should_auto_start_server": _plugin_callable(plugin, "_should_auto_start_server"),
		"start_server_for_lifecycle": _plugin_callable(plugin, "_start_server_for_lifecycle"),
		"defer_start_server_for_lifecycle": _plugin_callable(plugin, "_defer_start_server_for_lifecycle"),
		"restore_pending_focus_snapshot_if_needed": _plugin_callable(plugin, "_restore_pending_focus_snapshot_if_needed"),
		"ensure_saved_update_source_discovery_requested": _plugin_callable(plugin, "_defer_saved_update_source_discovery_request"),
		"save_settings": _plugin_callable(plugin, "_save_settings"),
		"stop_user_tool_watch_service": _plugin_callable(plugin, "_stop_user_tool_watch_service"),
		"remove_dock": _plugin_callable(plugin, "_remove_dock"),
		"remove_client_executable_dialog": _plugin_callable(plugin, "_remove_client_executable_dialog"),
		"uninstall_editor_debugger_bridge": _plugin_callable(plugin, "_uninstall_editor_debugger_bridge"),
		"remove_runtime_bridge_autoload": _plugin_callable(plugin, "_remove_runtime_bridge_autoload"),
		"dispose_action_router": _plugin_callable(plugin, "_dispose_action_router"),
		"dispose_server_controller": _plugin_callable(plugin, "_dispose_server_controller"),
		"dispose_lifecycle_services": _plugin_callable(plugin, "_dispose_lifecycle_services"),
		"is_runtime_bridge_currently_owned": _plugin_callable(plugin, "_is_runtime_bridge_currently_owned"),
		"tick_user_tool_watch_service": _plugin_callable(plugin, "_tick_user_tool_watch_service"),
		"ensure_update_refs_discovery_requested": _plugin_callable(plugin, "_ensure_update_refs_discovery_requested"),
		"finish_self_operation": _plugin_callable(plugin, "_finish_self_operation")
	}


func _plugin_callable(plugin, method_name: String) -> Callable:
	if plugin == null:
		return Callable()
	return Callable(plugin, method_name)
