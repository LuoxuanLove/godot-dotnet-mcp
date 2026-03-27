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

const SERVICE_BUNDLE_KEYS := [
	"settings_store",
	"runtime_state_service",
	"tool_bridge_service",
	"tool_catalog",
	"config_service",
	"client_install_detection_service",
	"server_feature",
	"config_feature",
	"user_tool_feature",
	"reload_feature",
	"tool_profile_feature",
	"tool_access_feature",
	"self_diagnostic_feature",
	"ui_state_feature",
	"dock_presenter",
	"dock_model_service",
	"user_tool_service",
	"user_tool_watch_service",
	"central_server_attach_service",
	"central_server_process_service"
]

const FEATURE_RESULT_KEYS := [
	"server_feature",
	"config_feature",
	"ui_state_feature",
	"tool_access_feature",
	"user_tool_feature",
	"reload_feature",
	"tool_profile_feature",
	"self_diagnostic_feature",
	"tool_bridge_service",
	"dock_model_service"
]


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


func refresh_plugin_service_instances(plugin) -> void:
	if plugin == null:
		return
	_apply_service_bundle(plugin, refresh_service_instances())


func configure_plugin_workflows(plugin, action_router, runtime_bridge_autoload_name: String, runtime_bridge_autoload_path: String) -> void:
	if plugin == null:
		return
	_configure_action_router(action_router, plugin)
	var result: Dictionary = configure_feature_workflows(
		_build_feature_workflow_context(plugin, runtime_bridge_autoload_name, runtime_bridge_autoload_path)
	)
	_apply_feature_result(plugin, result)
	_configure_action_router(action_router, plugin)


func configure_plugin_dock_model_service(plugin):
	if plugin == null:
		return null
	plugin._dock_model_service = _configure_dock_model_service(
		_build_dock_model_context(plugin),
		plugin._tool_access_feature,
		plugin._self_diagnostic_feature
	)
	return plugin._dock_model_service


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


func _configure_action_router(action_router, plugin) -> void:
	if action_router == null or plugin == null:
		return
	action_router.configure(_build_action_router_context(plugin))


func _build_action_router_context(plugin) -> Dictionary:
	return {
		"server_controller": plugin._server_controller,
		"state": plugin._state,
		"localization": plugin._localization,
		"server_feature": plugin._server_feature,
		"config_feature": plugin._config_feature,
		"user_tool_feature": plugin._user_tool_feature,
		"tool_access_feature": plugin._tool_access_feature,
		"self_diagnostic_feature": plugin._self_diagnostic_feature,
		"ui_state_feature": plugin._ui_state_feature,
		"reload_feature": plugin._reload_feature,
		"build_dock_model": Callable(plugin, "_build_dock_model"),
		"get_dock": Callable(plugin, "_get_dock")
	}


func _build_feature_workflow_context(plugin, runtime_bridge_autoload_name: String, runtime_bridge_autoload_path: String) -> Dictionary:
	return {
		"plugin": plugin,
		"state": plugin._state,
		"state_settings": plugin._state.settings,
		"localization": plugin._localization,
		"settings_store": plugin._settings_store,
		"server_controller": plugin._server_controller,
		"tool_catalog": plugin._tool_catalog,
		"config_service": plugin._config_service,
		"dock_presenter": plugin._dock_presenter,
		"user_tool_service": plugin._user_tool_service,
		"user_tool_watch_service": plugin._user_tool_watch_service,
		"client_install_detection_service": plugin._client_install_detection_service,
		"central_server_attach_service": plugin._central_server_attach_service,
		"central_server_process_service": plugin._central_server_process_service,
		"server_feature": plugin._server_feature,
		"config_feature": plugin._config_feature,
		"user_tool_feature": plugin._user_tool_feature,
		"reload_feature": plugin._reload_feature,
		"tool_profile_feature": plugin._tool_profile_feature,
		"tool_access_feature": plugin._tool_access_feature,
		"self_diagnostic_feature": plugin._self_diagnostic_feature,
		"ui_state_feature": plugin._ui_state_feature,
		"tool_bridge_service": plugin._tool_bridge_service,
		"dock_model_service": plugin._dock_model_service,
		"runtime_bridge_autoload_name": runtime_bridge_autoload_name,
		"runtime_bridge_autoload_path": runtime_bridge_autoload_path,
		"show_message": Callable(plugin._action_router, "show_message"),
		"show_confirmation": Callable(plugin._action_router, "show_confirmation"),
		"refresh_dock": Callable(plugin._action_router, "refresh_dock"),
		"save_settings": Callable(plugin, "_save_settings"),
		"ensure_client_executable_dialog": Callable(plugin, "_ensure_client_executable_dialog"),
		"get_client_executable_dialog": Callable(plugin, "_get_client_executable_dialog"),
		"capture_dock_focus_snapshot": Callable(plugin, "_capture_dock_focus_snapshot"),
		"restore_dock_focus_snapshot": Callable(plugin, "_restore_runtime_dock_focus_snapshot"),
		"get_all_tools_by_category": Callable(plugin._server_controller, "get_all_tools_by_category"),
		"set_disabled_tools": Callable(plugin._server_controller, "set_disabled_tools"),
		"create_reload_coordinator": Callable(plugin, "_create_reload_coordinator"),
		"reload_all_domains": Callable(plugin._action_router, "reload_all_tool_domains"),
		"runtime_reload_is_server_running": Callable(plugin, "_runtime_reload_is_server_running"),
		"runtime_reload_start_server": Callable(plugin, "_runtime_reload_start_server"),
		"runtime_reload_reinitialize_server": Callable(plugin, "_runtime_reload_reinitialize_server"),
		"refresh_service_instances": Callable(plugin, "_refresh_service_instances"),
		"runtime_reload_reset_localization": Callable(plugin, "_runtime_reload_reset_localization"),
		"recreate_server_controller": Callable(plugin, "_recreate_server_controller"),
		"configure_central_server_process_service": Callable(plugin, "_configure_central_server_process_service"),
		"configure_central_server_attach_service": Callable(plugin, "_configure_central_server_attach_service"),
		"configure_feature_workflows": Callable(plugin, "_configure_feature_workflows"),
		"recreate_dock": Callable(plugin, "_recreate_dock"),
		"restore_runtime_dock_focus_snapshot": Callable(plugin, "_restore_runtime_dock_focus_snapshot"),
		"finish_self_operation": Callable(plugin, "_finish_self_operation"),
		"count_dock_instances": Callable(plugin, "_count_dock_instances"),
		"has_runtime_bridge_root_instance": Callable(plugin, "_has_runtime_bridge_root_instance"),
		"is_server_running": Callable(plugin._server_controller, "is_running"),
		"get_connection_stats": Callable(plugin._server_controller, "get_connection_stats"),
		"get_tool_load_errors": Callable(plugin._server_controller, "get_tool_load_errors"),
		"get_reload_status": Callable(plugin._server_controller, "get_reload_status"),
		"get_performance_summary": Callable(plugin._server_controller, "get_performance_summary"),
		"is_dock_present": Callable(plugin, "_is_live_dock_present"),
		"get_editor_scale": Callable(plugin, "_get_editor_scale")
	}


func _build_dock_model_context(plugin) -> Dictionary:
	return {
		"state": plugin._state,
		"localization": plugin._localization,
		"server_controller": plugin._server_controller,
		"tool_catalog": plugin._tool_catalog,
		"config_service": plugin._config_service,
		"dock_presenter": plugin._dock_presenter,
		"user_tool_service": plugin._user_tool_service,
		"client_install_detection_service": plugin._client_install_detection_service,
		"central_server_attach_service": plugin._central_server_attach_service,
		"central_server_process_service": plugin._central_server_process_service,
		"user_tool_watch_service": plugin._user_tool_watch_service,
		"dock_model_service": plugin._dock_model_service,
		"get_editor_scale": Callable(plugin, "_get_editor_scale")
	}


func _apply_service_bundle(plugin, bundle: Dictionary) -> void:
	for key in SERVICE_BUNDLE_KEYS:
		var current_value = plugin.get("_%s" % key)
		plugin.set("_%s" % key, bundle.get(key, current_value))


func _apply_feature_result(plugin, result: Dictionary) -> void:
	for key in FEATURE_RESULT_KEYS:
		var current_value = plugin.get("_%s" % key)
		plugin.set("_%s" % key, result.get(key, current_value))


func _ensure_instance(instance, script):
	if instance != null:
		return instance
	return script.new()
