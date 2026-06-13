@tool
extends RefCounted
class_name PluginConfigReloadWiringService

const PluginReloadCoordinator = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_reload_coordinator.gd")
const ConfigTabActionServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/config/config_tab_action_service.gd")
const UserToolWatchServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_watch_service.gd")

const REENABLE_DEFER_SECONDS := 0.05


func schedule_plugin_reenable(context: Dictionary) -> bool:
	var editor_interface = _call_value(context.get("get_editor_interface", Callable()), null)
	if editor_interface == null:
		return false
	var base_control = editor_interface.get_base_control()
	if base_control == null:
		return false

	var coordinator = create_reload_coordinator(context)
	coordinator.name = "MCPPluginReloadCoordinator"
	base_control.add_child(coordinator)
	return true


func schedule_plugin_reenable_deferred(context: Dictionary) -> bool:
	var editor_interface = _call_value(context.get("get_editor_interface", Callable()), null)
	if editor_interface == null:
		return false
	var base_control = editor_interface.get_base_control()
	if base_control == null:
		return false
	if not _call_bool(context.get("is_inside_tree", Callable()), false):
		return _schedule_plugin_reenable_via_context(context)
	var tree = _call_value(context.get("get_tree", Callable()), null)
	if tree == null:
		return _schedule_plugin_reenable_via_context(context)
	var timer = tree.create_timer(REENABLE_DEFER_SECONDS)
	var callback: Callable = context.get("complete_plugin_reenable_schedule", Callable())
	if callback.is_valid():
		timer.timeout.connect(callback, CONNECT_ONE_SHOT)
	return true


func create_reload_coordinator(context: Dictionary):
	var coordinator = PluginReloadCoordinator.new()
	coordinator.configure(
		str(context.get("plugin_id", "")),
		_call_value(context.get("get_editor_interface", Callable()), null)
	)
	return coordinator


func _schedule_plugin_reenable_via_context(context: Dictionary) -> bool:
	var callback: Callable = context.get("schedule_plugin_reenable", Callable())
	if callback.is_valid():
		return _call_bool(callback, false)
	return schedule_plugin_reenable(context)


func configure_user_tool_watch_service(existing_service, context: Dictionary):
	var watch_service = existing_service
	if watch_service == null:
		watch_service = UserToolWatchServiceScript.new()
	watch_service.stop()
	watch_service.configure(
		context.get("plugin_host", null),
		null,
		context.get("user_tool_service", null),
		context.get("apply_external_user_tool_catalog_refresh", Callable())
	)
	watch_service.start()
	return watch_service


func configure_config_tab_action_service(existing_service, context: Dictionary):
	var action_service = existing_service
	if action_service == null:
		action_service = ConfigTabActionServiceScript.new()
	action_service.configure(build_config_tab_action_context(context))
	return action_service


func build_config_tab_action_context(context: Dictionary) -> Dictionary:
	return {
		"state": context.get("state", null),
		"localization": context.get("localization", null),
		"config_service": context.get("config_service", null),
		"client_install_detection_service": context.get("client_install_detection_service", null),
		"get_client_install_statuses": context.get("get_client_install_statuses", Callable()),
		"invalidate_client_install_status_cache": context.get("invalidate_client_install_status_cache", Callable()),
		"configure_client_install_detection_service": context.get("configure_client_install_detection_service", Callable()),
		"refresh_dock": context.get("refresh_dock", Callable()),
		"save_settings": context.get("save_settings", Callable()),
		"show_message": context.get("show_message", Callable()),
		"show_confirmation": context.get("show_confirmation", Callable()),
		"ensure_client_executable_dialog": context.get("ensure_client_executable_dialog", Callable()),
		"get_client_executable_dialog": context.get("get_client_executable_dialog", Callable())
	}


func _call_value(callable: Callable, default_value):
	if not callable.is_valid():
		return default_value
	return callable.call()


func _call_bool(callable: Callable, default_value: bool) -> bool:
	var value = _call_value(callable, default_value)
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
