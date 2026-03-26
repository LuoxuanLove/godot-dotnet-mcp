@tool
extends RefCounted

const PluginRuntimeStateServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_state_service.gd")
const PluginToolBridgeServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_tool_bridge_service.gd")
const SettingsStore = preload("res://addons/godot_dotnet_mcp/plugin/config/settings_store.gd")
const ToolCatalogService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_catalog_service.gd")
const CentralServerAttachServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/central_server_attach_service.gd")
const CentralServerProcessServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/central_server_process_service.gd")
const ClientConfigService = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_service.gd")
const ClientInstallDetectionService = preload("res://addons/godot_dotnet_mcp/plugin/config/client_install_detection_service.gd")
const ServerFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/server_feature.gd")
const ConfigFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/config_feature.gd")
const UserToolFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/user_tool_feature.gd")
const ReloadFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/reload_feature.gd")
const ToolProfileFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/tool_profile_feature.gd")
const ToolAccessFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/tool_access_feature.gd")
const SelfDiagnosticFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/self_diagnostic_feature.gd")
const UIStateFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/ui_state_feature.gd")
const DockPresenterScript = preload("res://addons/godot_dotnet_mcp/plugin/presenters/dock_presenter.gd")
const DockModelServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/presenters/dock_model_service.gd")
const UserToolService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_service.gd")
const UserToolWatchService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_watch_service.gd")


func refresh_service_instances() -> Dictionary:
	var settings_store = SettingsStore.new()
	var runtime_state_service = PluginRuntimeStateServiceScript.new()
	runtime_state_service.configure(settings_store)
	return {
		"settings_store": settings_store,
		"runtime_state_service": runtime_state_service,
		"tool_bridge_service": PluginToolBridgeServiceScript.new(),
		"tool_catalog": ToolCatalogService.new(),
		"config_service": ClientConfigService.new(),
		"client_install_detection_service": ClientInstallDetectionService.new(),
		"server_feature": ServerFeatureScript.new(),
		"config_feature": ConfigFeatureScript.new(),
		"user_tool_feature": UserToolFeatureScript.new(),
		"reload_feature": ReloadFeatureScript.new(),
		"tool_profile_feature": ToolProfileFeatureScript.new(),
		"tool_access_feature": ToolAccessFeatureScript.new(),
		"self_diagnostic_feature": SelfDiagnosticFeatureScript.new(),
		"ui_state_feature": UIStateFeatureScript.new(),
		"dock_presenter": DockPresenterScript.new(),
		"dock_model_service": DockModelServiceScript.new(),
		"user_tool_service": UserToolService.new(),
		"user_tool_watch_service": UserToolWatchService.new(),
		"central_server_attach_service": CentralServerAttachServiceScript.new(),
		"central_server_process_service": CentralServerProcessServiceScript.new()
	}


func load_state(runtime_state_service, settings_store, state, client_install_detection_service) -> void:
	var state_service = runtime_state_service
	if state_service == null:
		state_service = PluginRuntimeStateServiceScript.new()
		state_service.configure(settings_store)
	state_service.load_into(state)
	if client_install_detection_service != null:
		client_install_detection_service.configure(state.settings)


func save_settings(runtime_state_service, settings_store, state) -> void:
	var state_service = runtime_state_service
	if state_service == null:
		state_service = PluginRuntimeStateServiceScript.new()
		state_service.configure(settings_store)
	state_service.save_settings(state)


func configure_feature_workflows(context: Dictionary) -> Dictionary:
	var server_feature = _ensure_instance(context.get("server_feature", null), ServerFeatureScript)
	server_feature.configure(
		context.get("central_server_process_service", null),
		context.get("central_server_attach_service", null),
		context.get("localization", null),
		context.get("dock_presenter", null),
		{
			"show_message": context.get("show_message", Callable()),
			"show_confirmation": context.get("show_confirmation", Callable()),
			"refresh_dock": context.get("refresh_dock", Callable())
		}
	)

	var config_feature = _ensure_instance(context.get("config_feature", null), ConfigFeatureScript)
	config_feature.configure(
		context.get("state_settings", {}),
		context.get("localization", null),
		context.get("config_service", null),
		context.get("dock_presenter", null),
		context.get("central_server_process_service", null),
		context.get("client_install_detection_service", null),
		{
			"show_message": context.get("show_message", Callable()),
			"show_confirmation": context.get("show_confirmation", Callable()),
			"refresh_dock": context.get("refresh_dock", Callable()),
			"save_settings": context.get("save_settings", Callable()),
			"ensure_client_executable_dialog": context.get("ensure_client_executable_dialog", Callable()),
			"get_client_executable_dialog": context.get("get_client_executable_dialog", Callable())
		}
	)

	var ui_state_feature = _ensure_instance(context.get("ui_state_feature", null), UIStateFeatureScript)
	ui_state_feature.configure(
		context.get("state", null),
		context.get("localization", null),
		context.get("client_install_detection_service", null),
		{
			"save_settings": context.get("save_settings", Callable()),
			"refresh_dock": context.get("refresh_dock", Callable()),
			"show_message": context.get("show_message", Callable()),
			"capture_dock_focus_snapshot": context.get("capture_dock_focus_snapshot", Callable()),
			"restore_dock_focus_snapshot": context.get("restore_dock_focus_snapshot", Callable())
		}
	)

	var tool_access_feature = _ensure_instance(context.get("tool_access_feature", null), ToolAccessFeatureScript)
	tool_access_feature.configure(
		context.get("state", null),
		context.get("localization", null),
		context.get("tool_catalog", null),
		{
			"get_all_tools_by_category": context.get("get_all_tools_by_category", Callable()),
			"set_disabled_tools": context.get("set_disabled_tools", Callable()),
			"save_settings": context.get("save_settings", Callable()),
			"refresh_dock": context.get("refresh_dock", Callable()),
			"show_message": context.get("show_message", Callable()),
			"change_language": Callable(ui_state_feature, "handle_language_changed")
		}
	)

	var user_tool_feature = _ensure_instance(context.get("user_tool_feature", null), UserToolFeatureScript)
	user_tool_feature.configure(
		context.get("user_tool_service", null),
		{
			"show_message": context.get("show_message", Callable()),
			"refresh_dock": context.get("refresh_dock", Callable()),
			"save_settings": context.get("save_settings", Callable()),
			"cleanup_disabled_tools": Callable(tool_access_feature, "cleanup_disabled_tools"),
			"create_reload_coordinator": context.get("create_reload_coordinator", Callable()),
			"reload_all_domains": context.get("reload_all_domains", Callable())
		}
	)

	var reload_feature = _ensure_instance(context.get("reload_feature", null), ReloadFeatureScript)
	reload_feature.configure(
		context.get("plugin", null),
		{
			"is_server_running": context.get("runtime_reload_is_server_running", Callable()),
			"start_server": context.get("runtime_reload_start_server", Callable()),
			"reinitialize_server": context.get("runtime_reload_reinitialize_server", Callable()),
			"refresh_service_instances": context.get("refresh_service_instances", Callable()),
			"reset_localization": context.get("runtime_reload_reset_localization", Callable()),
			"recreate_server_controller": context.get("recreate_server_controller", Callable()),
			"configure_central_server_process_service": context.get("configure_central_server_process_service", Callable()),
			"configure_central_server_attach_service": context.get("configure_central_server_attach_service", Callable()),
			"configure_feature_workflows": context.get("configure_feature_workflows", Callable()),
			"recreate_dock": context.get("recreate_dock", Callable()),
			"refresh_dock": context.get("refresh_dock", Callable()),
			"capture_dock_focus_snapshot": context.get("capture_dock_focus_snapshot", Callable()),
			"restore_runtime_dock_focus_snapshot": context.get("restore_runtime_dock_focus_snapshot", Callable()),
			"finish_self_operation": context.get("finish_self_operation", Callable())
		}
	)

	var tool_profile_feature = _ensure_instance(context.get("tool_profile_feature", null), ToolProfileFeatureScript)
	tool_profile_feature.configure(
		context.get("state", null),
		context.get("localization", null),
		context.get("settings_store", null),
		context.get("tool_catalog", null),
		{
			"get_all_tools_by_category": context.get("get_all_tools_by_category", Callable()),
			"set_disabled_tools": context.get("set_disabled_tools", Callable()),
			"cleanup_disabled_tools": Callable(tool_access_feature, "cleanup_disabled_tools"),
			"save_settings": context.get("save_settings", Callable()),
			"refresh_dock": context.get("refresh_dock", Callable())
		}
	)

	var self_diagnostic_feature = _ensure_instance(context.get("self_diagnostic_feature", null), SelfDiagnosticFeatureScript)
	self_diagnostic_feature.configure(
		context.get("localization", null),
		str(context.get("runtime_bridge_autoload_name", "")),
		str(context.get("runtime_bridge_autoload_path", "")),
		{
			"count_dock_instances": context.get("count_dock_instances", Callable()),
			"has_runtime_bridge_root_instance": context.get("has_runtime_bridge_root_instance", Callable()),
			"is_server_running": context.get("is_server_running", Callable()),
			"get_connection_stats": context.get("get_connection_stats", Callable()),
			"get_tool_load_errors": context.get("get_tool_load_errors", Callable()),
			"get_reload_status": context.get("get_reload_status", Callable()),
			"get_performance_summary": context.get("get_performance_summary", Callable()),
			"get_permission_level": Callable(tool_access_feature, "get_permission_level"),
			"refresh_dock": context.get("refresh_dock", Callable()),
			"show_message": context.get("show_message", Callable()),
			"is_dock_present": context.get("is_dock_present", Callable())
		}
	)

	var tool_bridge_service = _ensure_instance(context.get("tool_bridge_service", null), PluginToolBridgeServiceScript)
	tool_bridge_service.configure(
		context.get("server_controller", null),
		reload_feature,
		self_diagnostic_feature,
		tool_access_feature,
		tool_profile_feature,
		user_tool_feature
	)

	var dock_model_service = _configure_dock_model_service(context, tool_access_feature, self_diagnostic_feature)

	return {
		"server_feature": server_feature,
		"config_feature": config_feature,
		"ui_state_feature": ui_state_feature,
		"tool_access_feature": tool_access_feature,
		"user_tool_feature": user_tool_feature,
		"reload_feature": reload_feature,
		"tool_profile_feature": tool_profile_feature,
		"self_diagnostic_feature": self_diagnostic_feature,
		"tool_bridge_service": tool_bridge_service,
		"dock_model_service": dock_model_service
	}


func configure_dock_model_service(context: Dictionary, tool_access_feature, self_diagnostic_feature):
	return _configure_dock_model_service(context, tool_access_feature, self_diagnostic_feature)


func _configure_dock_model_service(context: Dictionary, tool_access_feature, self_diagnostic_feature):
	var dock_model_service = _ensure_instance(context.get("dock_model_service", null), DockModelServiceScript)
	dock_model_service.configure(
		context.get("state", null),
		context.get("localization", null),
		context.get("server_controller", null),
		context.get("tool_catalog", null),
		context.get("config_service", null),
		context.get("dock_presenter", null),
		context.get("user_tool_service", null),
		context.get("client_install_detection_service", null),
		context.get("central_server_attach_service", null),
		context.get("central_server_process_service", null),
		context.get("user_tool_watch_service", null),
		tool_access_feature,
		self_diagnostic_feature,
		{
			"get_editor_scale": context.get("get_editor_scale", Callable())
		}
	)
	return dock_model_service


func _ensure_instance(instance, script):
	if instance != null:
		return instance
	return script.new()
