@tool
extends RefCounted
class_name PluginConfigReloadContextService


func build_config_reload_context(plugin, dependencies: Dictionary) -> Dictionary:
	return {
		"plugin_id": str(dependencies.get("plugin_id", "")),
		"plugin_host": plugin,
		"server_controller": dependencies.get("server_controller", null),
		"state": dependencies.get("state", null),
		"localization": dependencies.get("localization", null),
		"config_service": dependencies.get("config_service", null),
		"client_install_detection_service": dependencies.get("client_install_detection_service", null),
		"user_tool_service": dependencies.get("user_tool_service", null),
		"get_editor_interface": _plugin_callable(plugin, "get_editor_interface"),
		"is_inside_tree": _plugin_callable(plugin, "is_inside_tree"),
		"get_tree": _plugin_callable(plugin, "get_tree"),
		"schedule_plugin_reenable": _plugin_callable(plugin, "_schedule_plugin_reenable"),
		"complete_plugin_reenable_schedule": _plugin_callable(plugin, "_complete_plugin_reenable_schedule"),
		"apply_external_user_tool_catalog_refresh": _plugin_callable(plugin, "_apply_external_user_tool_catalog_refresh"),
		"get_client_install_statuses": _plugin_callable(plugin, "_get_client_install_statuses"),
		"invalidate_client_install_status_cache": _plugin_callable(plugin, "_invalidate_client_install_status_cache"),
		"configure_client_install_detection_service": _plugin_callable(plugin, "_configure_client_install_detection_service"),
		"refresh_dock": _plugin_callable(plugin, "_refresh_dock"),
		"save_settings": _plugin_callable(plugin, "_save_settings"),
		"show_message": _plugin_callable(plugin, "_show_message"),
		"show_confirmation": _plugin_callable(plugin, "_show_confirmation"),
		"ensure_client_executable_dialog": _plugin_callable(plugin, "_configure_client_executable_dialog"),
		"get_client_executable_dialog": _plugin_callable(plugin, "_get_client_executable_dialog")
	}


func _plugin_callable(plugin, method_name: String) -> Callable:
	if plugin == null:
		return Callable()
	return Callable(plugin, method_name)
