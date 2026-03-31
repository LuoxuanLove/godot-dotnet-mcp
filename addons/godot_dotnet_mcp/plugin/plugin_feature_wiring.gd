@tool
extends RefCounted
class_name PluginFeatureWiring

const PluginToolBridgeServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_tool_bridge_service.gd")
const ServerFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/server_feature.gd")
const ConfigFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/config_feature.gd")
const UserToolFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/user_tool_feature.gd")
const ReloadFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/reload_feature.gd")
const ToolProfileFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/tool_profile_feature.gd")
const ToolAccessFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/tool_access_feature.gd")
const SelfDiagnosticFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/self_diagnostic_feature.gd")
const UIStateFeatureScript = preload("res://addons/godot_dotnet_mcp/plugin/features/ui_state_feature.gd")
const DockModelServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/presenters/dock_model_service.gd")
const PluginServerFeatureContext = preload("res://addons/godot_dotnet_mcp/plugin/plugin_server_feature_context.gd")
const PluginConfigFeatureContext = preload("res://addons/godot_dotnet_mcp/plugin/plugin_config_feature_context.gd")
const PluginUiStateContext = preload("res://addons/godot_dotnet_mcp/plugin/plugin_ui_state_context.gd")
const PluginUserToolContext = preload("res://addons/godot_dotnet_mcp/plugin/plugin_user_tool_context.gd")
const PluginToolAccessContext = preload("res://addons/godot_dotnet_mcp/plugin/plugin_tool_access_context.gd")
const PluginToolProfileContext = preload("res://addons/godot_dotnet_mcp/plugin/plugin_tool_profile_context.gd")
const PluginSelfDiagnosticContext = preload("res://addons/godot_dotnet_mcp/plugin/plugin_self_diagnostic_context.gd")
const PluginDockModelContext = preload("res://addons/godot_dotnet_mcp/plugin/plugin_dock_model_context.gd")
const PluginReloadRuntimeContext = preload("res://addons/godot_dotnet_mcp/plugin/plugin_reload_runtime_context.gd")

const FEATURE_RESULT_KEYS := [
	"server_feature",
	"config_feature",
	"ui_state_feature",
	"tool_access_feature",
	"user_tool_feature",
	"reload_feature",
	"tool_profile_feature",
	"self_diagnostic_feature",
	"tool_bridge_service"
]


func get_feature_result_keys() -> Array[String]:
	var keys: Array[String] = []
	for key in FEATURE_RESULT_KEYS:
		keys.append(str(key))
	return keys


func configure_feature_workflows(plugin, bootstrap, runtime_bridge_autoload_name: String, runtime_bridge_autoload_path: String) -> void:
	if plugin == null or bootstrap == null:
		return

	plugin._server_feature = _ensure_instance(plugin._server_feature, ServerFeatureScript)
	plugin._server_feature.configure(_build_server_feature_context(plugin))

	plugin._config_feature = _ensure_instance(plugin._config_feature, ConfigFeatureScript)
	plugin._config_feature.configure(_build_config_feature_context(plugin, bootstrap))

	plugin._ui_state_feature = _ensure_instance(plugin._ui_state_feature, UIStateFeatureScript)
	plugin._ui_state_feature.configure(_build_ui_state_context(plugin, bootstrap))

	plugin._tool_access_feature = _ensure_instance(plugin._tool_access_feature, ToolAccessFeatureScript)
	plugin._tool_access_feature.configure(_build_tool_access_context(plugin))

	plugin._user_tool_feature = _ensure_instance(plugin._user_tool_feature, UserToolFeatureScript)
	plugin._user_tool_feature.configure(_build_user_tool_context(plugin))

	plugin._reload_feature = _ensure_instance(plugin._reload_feature, ReloadFeatureScript)
	plugin._reload_feature.configure(
		_build_reload_runtime_context(
			plugin,
			bootstrap,
			runtime_bridge_autoload_name,
			runtime_bridge_autoload_path
		)
	)

	plugin._tool_profile_feature = _ensure_instance(plugin._tool_profile_feature, ToolProfileFeatureScript)
	plugin._tool_profile_feature.configure(_build_tool_profile_context(plugin))

	plugin._self_diagnostic_feature = _ensure_instance(plugin._self_diagnostic_feature, SelfDiagnosticFeatureScript)
	plugin._self_diagnostic_feature.configure(
		_build_self_diagnostic_context(
			plugin,
			runtime_bridge_autoload_name,
			runtime_bridge_autoload_path
		)
	)

	plugin._tool_bridge_service = _ensure_instance(plugin._tool_bridge_service, PluginToolBridgeServiceScript)
	plugin._tool_bridge_service.configure(
		plugin._server_controller,
		plugin._reload_feature,
		plugin._self_diagnostic_feature,
		plugin._tool_access_feature,
		plugin._tool_profile_feature,
		plugin._user_tool_feature
	)


func configure_dock_model_service(plugin):
	if plugin == null:
		return null
	plugin._dock_model_service = _ensure_instance(plugin._dock_model_service, DockModelServiceScript)
	plugin._dock_model_service.configure(_build_dock_model_context(plugin))
	return plugin._dock_model_service


func _build_server_feature_context(plugin):
	var typed_context = PluginServerFeatureContext.new()
	typed_context.process_service = plugin._central_server_process_service
	typed_context.attach_service = plugin._central_server_attach_service
	typed_context.localization = plugin._localization
	typed_context.dock_presenter = plugin._dock_presenter
	typed_context.show_message = _bind_callable(plugin._action_router, "show_message")
	typed_context.show_confirmation = _bind_callable(plugin._action_router, "show_confirmation")
	typed_context.refresh_dock = _bind_callable(plugin._action_router, "refresh_dock")
	return typed_context


func _build_config_feature_context(plugin, bootstrap):
	var typed_context = PluginConfigFeatureContext.new()
	typed_context.settings = plugin._state.settings if plugin._state != null else {}
	typed_context.localization = plugin._localization
	typed_context.config_service = plugin._config_service
	typed_context.dock_presenter = plugin._dock_presenter
	typed_context.central_server_process_service = plugin._central_server_process_service
	typed_context.client_install_detection_service = plugin._client_install_detection_service
	typed_context.show_message = _bind_callable(plugin._action_router, "show_message")
	typed_context.show_confirmation = _bind_callable(plugin._action_router, "show_confirmation")
	typed_context.refresh_dock = _bind_callable(plugin._action_router, "refresh_dock")
	typed_context.save_settings = _bind_callable(plugin, "_save_settings")
	typed_context.ensure_client_executable_dialog = _bind_callable(bootstrap, "ensure_plugin_client_executable_dialog", [plugin])
	typed_context.get_client_executable_dialog = _bind_callable(bootstrap, "get_plugin_client_executable_dialog", [plugin])
	return typed_context


func _build_ui_state_context(plugin, bootstrap):
	var typed_context = PluginUiStateContext.new()
	typed_context.state = plugin._state
	typed_context.localization = plugin._localization
	typed_context.client_install_detection_service = plugin._client_install_detection_service
	typed_context.save_settings = _bind_callable(plugin, "_save_settings")
	typed_context.refresh_dock = _bind_callable(plugin._action_router, "refresh_dock")
	typed_context.show_message = _bind_callable(plugin._action_router, "show_message")
	typed_context.capture_dock_focus_snapshot = _bind_callable(bootstrap, "capture_plugin_dock_focus_snapshot", [plugin])
	typed_context.restore_dock_focus_snapshot = _bind_callable(bootstrap, "restore_plugin_dock_focus_snapshot", [plugin])
	return typed_context


func _build_user_tool_context(plugin):
	var typed_context = PluginUserToolContext.new()
	typed_context.user_tool_service = plugin._user_tool_service
	typed_context.show_message = _bind_callable(plugin._action_router, "show_message")
	typed_context.refresh_dock = _bind_callable(plugin._action_router, "refresh_dock")
	typed_context.save_settings = _bind_callable(plugin, "_save_settings")
	typed_context.cleanup_disabled_tools = Callable(plugin._tool_access_feature, "cleanup_disabled_tools")
	typed_context.create_reload_coordinator = _bind_callable(plugin, "_create_reload_coordinator")
	typed_context.reload_all_domains = _bind_callable(plugin._action_router, "reload_all_tool_domains")
	return typed_context


func _build_tool_access_context(plugin):
	var typed_context = PluginToolAccessContext.new()
	typed_context.state = plugin._state
	typed_context.localization = plugin._localization
	typed_context.tool_catalog = plugin._tool_catalog
	typed_context.get_all_tools_by_category = _bind_callable(plugin._server_controller, "get_all_tools_by_category")
	typed_context.set_disabled_tools = _bind_callable(plugin._server_controller, "set_disabled_tools")
	typed_context.save_settings = _bind_callable(plugin, "_save_settings")
	typed_context.refresh_dock = _bind_callable(plugin._action_router, "refresh_dock")
	typed_context.show_message = _bind_callable(plugin._action_router, "show_message")
	typed_context.change_language = Callable(plugin._ui_state_feature, "handle_language_changed")
	return typed_context


func _build_tool_profile_context(plugin):
	var typed_context = PluginToolProfileContext.new()
	typed_context.state = plugin._state
	typed_context.localization = plugin._localization
	typed_context.settings_store = plugin._settings_store
	typed_context.tool_catalog = plugin._tool_catalog
	typed_context.get_all_tools_by_category = _bind_callable(plugin._server_controller, "get_all_tools_by_category")
	typed_context.set_disabled_tools = _bind_callable(plugin._server_controller, "set_disabled_tools")
	typed_context.cleanup_disabled_tools = Callable(plugin._tool_access_feature, "cleanup_disabled_tools")
	typed_context.save_settings = _bind_callable(plugin, "_save_settings")
	typed_context.refresh_dock = _bind_callable(plugin._action_router, "refresh_dock")
	return typed_context


func _build_self_diagnostic_context(plugin, runtime_bridge_autoload_name: String, runtime_bridge_autoload_path: String):
	var typed_context = PluginSelfDiagnosticContext.new()
	typed_context.localization = plugin._localization
	typed_context.runtime_bridge_autoload_name = runtime_bridge_autoload_name
	typed_context.runtime_bridge_autoload_path = runtime_bridge_autoload_path
	typed_context.count_dock_instances = _bind_callable(
		plugin._dock_coordinator,
		"count_plugin_dock_instances",
		[plugin, "res://addons/godot_dotnet_mcp/ui/mcp_dock.gd"]
	)
	typed_context.has_runtime_bridge_root_instance = _bind_callable(plugin, "_has_runtime_bridge_root_instance")
	typed_context.is_server_running = _bind_callable(plugin._server_controller, "is_running")
	typed_context.get_connection_stats = _bind_callable(plugin._server_controller, "get_connection_stats")
	typed_context.get_tool_load_errors = _bind_callable(plugin._server_controller, "get_tool_load_errors")
	typed_context.get_reload_status = _bind_callable(plugin._server_controller, "get_reload_status")
	typed_context.get_performance_summary = _bind_callable(plugin._server_controller, "get_performance_summary")
	typed_context.get_permission_level = Callable(plugin._tool_access_feature, "get_permission_level")
	typed_context.refresh_dock = _bind_callable(plugin._action_router, "refresh_dock")
	typed_context.show_message = _bind_callable(plugin._action_router, "show_message")
	typed_context.is_dock_present = _bind_callable(plugin, "_is_live_dock_present")
	return typed_context


func _build_dock_model_context(plugin):
	var context = PluginDockModelContext.new()
	context.state = plugin._state
	context.localization = plugin._localization
	context.server_controller = plugin._server_controller
	context.tool_catalog = plugin._tool_catalog
	context.config_service = plugin._config_service
	context.dock_presenter = plugin._dock_presenter
	context.user_tool_service = plugin._user_tool_service
	context.client_install_detection_service = plugin._client_install_detection_service
	context.central_server_attach_service = plugin._central_server_attach_service
	context.central_server_process_service = plugin._central_server_process_service
	context.user_tool_watch_service = plugin._user_tool_watch_service
	context.tool_access_feature = plugin._tool_access_feature
	context.self_diagnostic_feature = plugin._self_diagnostic_feature
	context.get_editor_scale = _bind_callable(plugin, "_get_editor_scale")
	return context


func _build_reload_runtime_context(plugin, bootstrap, runtime_bridge_autoload_name: String, runtime_bridge_autoload_path: String):
	var context = PluginReloadRuntimeContext.new()
	context.owner = plugin
	context.is_server_running = _bind_callable(plugin, "_runtime_reload_is_server_running")
	context.start_server = _bind_callable(plugin, "_runtime_reload_start_server")
	context.reinitialize_server = _bind_callable(plugin, "_runtime_reload_reinitialize_server")
	context.refresh_service_instances = _bind_callable(bootstrap, "refresh_plugin_service_instances", [plugin])
	context.reset_localization = _bind_callable(plugin, "_runtime_reload_reset_localization")
	context.recreate_server_controller = _bind_callable(plugin, "_recreate_server_controller")
	context.configure_central_server_process_service = _bind_callable(plugin, "_configure_central_server_process_service")
	context.configure_central_server_attach_service = _bind_callable(plugin, "_configure_central_server_attach_service")
	context.configure_feature_workflows = _bind_callable(
		bootstrap,
		"configure_plugin_workflows",
		[plugin, plugin._action_router, runtime_bridge_autoload_name, runtime_bridge_autoload_path]
	)
	context.recreate_dock = _bind_callable(plugin, "_recreate_dock")
	context.refresh_dock = _bind_callable(plugin._action_router, "refresh_dock")
	context.capture_dock_focus_snapshot = _bind_callable(bootstrap, "capture_plugin_dock_focus_snapshot", [plugin])
	context.restore_runtime_dock_focus_snapshot = _bind_callable(bootstrap, "restore_plugin_dock_focus_snapshot", [plugin])
	context.finish_self_operation = _bind_callable(plugin, "_finish_self_operation")
	return context


func _ensure_instance(instance, script):
	if instance != null:
		return instance
	return script.new()


func _bind_callable(target, method_name: String, bind_args: Array = []) -> Callable:
	if target == null or method_name.is_empty():
		return Callable()
	var callable := Callable(target, method_name)
	return callable.bindv(bind_args) if not bind_args.is_empty() else callable
