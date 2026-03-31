@tool
extends EditorPlugin

const LocalizationService = preload("res://addons/godot_dotnet_mcp/localization/localization_service.gd")
const PluginRuntimeState = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_state.gd")
const PluginRuntimeStateServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_state_service.gd")
const PluginToolBridgeServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_tool_bridge_service.gd")
const ToolPermissionPolicy = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_permission_policy.gd")
const SettingsStore = preload("res://addons/godot_dotnet_mcp/plugin/config/settings_store.gd")
const ToolCatalogService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_catalog_service.gd")
const CentralServerAttachServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/central_server_attach_service.gd")
const CentralServerProcessServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/central_server_process_service.gd")
const PluginReloadCoordinator = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_reload_coordinator.gd")
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
const MCPRuntimeDebugStore = preload("res://addons/godot_dotnet_mcp/tools/shared/mcp_runtime_debug_store.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const PluginActionRouter = preload("res://addons/godot_dotnet_mcp/plugin/plugin_action_router.gd")
const PluginBootstrap = preload("res://addons/godot_dotnet_mcp/plugin/plugin_bootstrap.gd")
const PluginDockCoordinator = preload("res://addons/godot_dotnet_mcp/plugin/plugin_dock_coordinator.gd")
const PluginRuntimeCoordinator = preload("res://addons/godot_dotnet_mcp/plugin/plugin_runtime_coordinator.gd")
const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const MCP_DOCK_SCENE_PATH := "res://addons/godot_dotnet_mcp/ui/mcp_dock.tscn"
const MCP_DOCK_SCRIPT_PATH := "res://addons/godot_dotnet_mcp/ui/mcp_dock.gd"
const PLUGIN_ID := "godot_dotnet_mcp"
const PENDING_FOCUS_SNAPSHOT_KEY := "_pending_focus_snapshot"
const RUNTIME_BRIDGE_AUTOLOAD_NAME := "MCPRuntimeBridge"
const RUNTIME_BRIDGE_AUTOLOAD_PATH := "res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_bridge.gd"

var _state := PluginRuntimeState.new()
var _action_router := PluginActionRouter.new()
var _bootstrap := PluginBootstrap.new()
var _dock_coordinator := PluginDockCoordinator.new()
var _runtime_coordinator := PluginRuntimeCoordinator.new()
var _runtime_state_service = PluginRuntimeStateServiceScript.new()
var _tool_bridge_service = PluginToolBridgeServiceScript.new()
var _settings_store := SettingsStore.new()
var _server_controller = null
var _tool_catalog := ToolCatalogService.new()
var _config_service := ClientConfigService.new()
var _client_install_detection_service := ClientInstallDetectionService.new()
var _server_feature = ServerFeatureScript.new()
var _config_feature = ConfigFeatureScript.new()
var _user_tool_feature = UserToolFeatureScript.new()
var _reload_feature = ReloadFeatureScript.new()
var _tool_profile_feature = ToolProfileFeatureScript.new()
var _tool_access_feature = ToolAccessFeatureScript.new()
var _self_diagnostic_feature = SelfDiagnosticFeatureScript.new()
var _ui_state_feature = UIStateFeatureScript.new()
var _dock_presenter = DockPresenterScript.new()
var _dock_model_service = DockModelServiceScript.new()
var _user_tool_service := UserToolService.new()
var _user_tool_watch_service := UserToolWatchService.new()
var _central_server_attach_service: CentralServerAttachService
var _central_server_process_service: CentralServerProcessService
var _localization: LocalizationService
var _dock: Control
var _client_executable_dialog: FileDialog
var _status_poll_accumulator := 0.0
var _editor_debugger_bridge: EditorDebuggerPlugin
var _last_central_server_endpoint_reachable := false


func _enter_tree() -> void:
	PluginSelfDiagnosticStore.clear()
	var operation = PluginSelfDiagnosticStore.begin_operation("plugin_enter_tree", "_enter_tree")
	_state = PluginRuntimeState.new()
	_status_poll_accumulator = 0.0
	_bootstrap.refresh_plugin_service_instances(self)
	_load_state()
	_validate_permission_configuration()
	LocalizationService.reset_instance()
	_localization = LocalizationService.get_instance()
	_localization.set_language(str(_state.settings.get("language", "")))
	_state.settings["debug_mode"] = true
	MCPDebugBuffer.set_minimum_level(str(_state.settings.get("log_level", "info")))

	_attach_server_controller()
	_configure_user_tool_watch_service()
	_runtime_coordinator.ensure_runtime_bridge_autoload(self, RUNTIME_BRIDGE_AUTOLOAD_NAME, RUNTIME_BRIDGE_AUTOLOAD_PATH)
	_editor_debugger_bridge = _runtime_coordinator.install_editor_debugger_bridge(self, _editor_debugger_bridge)
	_configure_central_server_process_service()
	_configure_central_server_attach_service()
	_bootstrap.configure_plugin_workflows(self, _action_router, RUNTIME_BRIDGE_AUTOLOAD_NAME, RUNTIME_BRIDGE_AUTOLOAD_PATH)

	_create_dock()
	_bootstrap.apply_initial_tool_profile_if_needed(self)
	_action_router.refresh_dock()
	set_process(true)

	if bool(_state.settings.get("auto_start", true)):
		_server_controller.start(_state.settings, "auto_start")
		_action_router.refresh_dock()

	_bootstrap.restore_pending_focus_snapshot_if_needed(self, PENDING_FOCUS_SNAPSHOT_KEY)
	_finish_self_operation(operation, true, "plugin", "_enter_tree")

	MCPDebugBuffer.record("info", "plugin", "Plugin initialized")


func _exit_tree() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("plugin_exit_tree", "_exit_tree")
	set_process(false)
	_save_settings()
	if _user_tool_watch_service != null:
		_user_tool_watch_service.stop()
	if _central_server_attach_service != null:
		_central_server_attach_service.stop()
	if _central_server_process_service != null:
		_central_server_process_service.stop_service()
	_remove_dock()
	_bootstrap.remove_plugin_client_executable_dialog(self)
	_editor_debugger_bridge = _runtime_coordinator.uninstall_editor_debugger_bridge(self, _editor_debugger_bridge)
	_dispose_server_controller()
	_bootstrap.dispose_plugin_service_instances(self)
	LocalizationService.reset_instance()
	_localization = null
	_user_tool_service = null
	_user_tool_watch_service = null
	_central_server_attach_service = null
	_central_server_process_service = null
	_last_central_server_endpoint_reachable = false
	_config_service = null
	_client_install_detection_service = null
	_server_feature = null
	_config_feature = null
	_user_tool_feature = null
	_reload_feature = null
	_tool_profile_feature = null
	_tool_access_feature = null
	_self_diagnostic_feature = null
	_ui_state_feature = null
	_dock_presenter = null
	_dock_model_service = null
	_tool_catalog = null
	_settings_store = null
	_state = null
	_finish_self_operation(operation, true, "plugin", "_exit_tree")


func _disable_plugin() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("plugin_disable", "_disable_plugin")
	MCPRuntimeDebugStore.set_bridge_status(
		_runtime_coordinator.is_runtime_bridge_autoload_path(
			RUNTIME_BRIDGE_AUTOLOAD_PATH,
			str(ProjectSettings.get_setting("autoload/%s" % RUNTIME_BRIDGE_AUTOLOAD_NAME, ""))
		),
		RUNTIME_BRIDGE_AUTOLOAD_NAME,
		RUNTIME_BRIDGE_AUTOLOAD_PATH,
		"Plugin disabled without removing runtime bridge autoload"
	)
	_finish_self_operation(operation, true, "plugin", "_disable_plugin")


func _validate_permission_configuration() -> void:
	for issue in ToolPermissionPolicy.get_domain_category_consistency_issues():
		push_warning("[Godot MCP] Permission configuration issue: %s" % issue)
		MCPDebugBuffer.record("warning", "plugin", "Permission config issue: %s" % issue)


func _process(delta: float) -> void:
	if _user_tool_watch_service != null:
		_user_tool_watch_service.tick()
	if _central_server_attach_service != null:
		_central_server_attach_service.tick()
	if _central_server_process_service != null:
		_central_server_process_service.tick()
		_ensure_local_central_server_if_needed()
	_status_poll_accumulator += delta
	if _status_poll_accumulator >= 0.5:
		_status_poll_accumulator = 0.0
		_action_router.refresh_dock()


func get_server() -> Node:
	return _server_controller.get_server()


func get_tool_access_provider():
	return _tool_access_feature


func get_editor_debugger_bridge():
	return _editor_debugger_bridge


func get_central_server_attach_service():
	return _central_server_attach_service


func start_server() -> void:
	_action_router.handle_start_requested()


func stop_server() -> void:
	_action_router.handle_stop_requested()


func _attach_server_controller() -> void:
	_server_controller = _runtime_coordinator.attach_server_controller(
		_server_controller,
		self,
		_state.settings,
		_action_router
	)


func _dispose_server_controller() -> void:
	_server_controller = _runtime_coordinator.dispose_server_controller(_server_controller, _action_router)


func _recreate_server_controller() -> void:
	_server_controller = _runtime_coordinator.recreate_server_controller(
		_server_controller,
		self,
		_state.settings,
		_action_router
	)
	_configure_user_tool_watch_service()


func _load_state() -> void:
	_bootstrap.load_state(_runtime_state_service, _settings_store, _state, _client_install_detection_service)


func _save_settings() -> void:
	_bootstrap.save_settings(_runtime_state_service, _settings_store, _state)


func _create_dock() -> void:
	var result: Dictionary = _dock_coordinator.create_plugin_dock(
		self,
		_dock,
		_action_router,
		DOCK_SLOT_RIGHT_UL,
		MCP_DOCK_SCENE_PATH,
		MCP_DOCK_SCRIPT_PATH
	)
	_dock = result.get("dock", null)


func _remove_dock() -> void:
	var result: Dictionary = _dock_coordinator.remove_plugin_dock(self, _dock, MCP_DOCK_SCRIPT_PATH)
	_dock = result.get("dock", null)

func _schedule_user_tool_catalog_refresh() -> void:
	call_deferred("_apply_user_tool_catalog_refresh")


func _apply_user_tool_catalog_refresh(script_path: String = "", reason: String = "user_tool_catalog_refresh") -> void:
	_action_router.apply_user_tool_catalog_refresh(script_path, reason)


func execute_plugin_evolution_tool(tool_name: String, args: Dictionary = {}) -> Dictionary:
	if _tool_bridge_service != null:
		return _tool_bridge_service.execute_evolution_tool(tool_name, args)
	return {"success": false, "error": "Plugin evolution bridge is unavailable"}


func execute_plugin_runtime_tool(tool_name: String, args: Dictionary = {}) -> Dictionary:
	if _tool_bridge_service != null:
		return _tool_bridge_service.execute_runtime_tool(tool_name, args)
	return {"success": false, "error": "Plugin runtime bridge is unavailable"}


func execute_plugin_developer_tool(tool_name: String, args: Dictionary = {}) -> Dictionary:
	if _tool_bridge_service != null:
		return _tool_bridge_service.execute_developer_tool(tool_name, args)
	return {"success": false, "error": "Plugin developer bridge is unavailable"}


func _runtime_reload_is_server_running() -> bool:
	return _server_controller != null and _server_controller.is_running()


func _runtime_reload_start_server(reason: String) -> bool:
	if _server_controller == null:
		return false
	return _server_controller.start(_state.settings, reason)


func _runtime_reload_reinitialize_server(reason: String) -> bool:
	if _server_controller == null:
		return false
	return _server_controller.reinitialize(_state.settings, reason)


func _runtime_reload_reset_localization() -> void:
	LocalizationService.reset_instance()
	_localization = LocalizationService.get_instance()
	_localization.set_language(str(_state.settings.get("language", "")))


func _get_editor_scale() -> float:
	var editor_interface = get_editor_interface()
	if editor_interface:
		return float(editor_interface.get_editor_scale())
	return 1.0


func _finish_self_operation(operation: Dictionary, success: bool, component: String, phase: String, anomaly_codes: Array = [], context: Dictionary = {}) -> void:
	if operation.is_empty():
		return
	var merged_context = context.duplicate(true)
	merged_context["component"] = component
	merged_context["phase"] = phase
	var finished = PluginSelfDiagnosticStore.end_operation(str(operation.get("operation_id", "")), success, anomaly_codes, merged_context)
	PluginSelfDiagnosticStore.record_slow_operation(finished, component, phase)


func _is_live_dock_present() -> bool:
	return _dock != null and is_instance_valid(_dock)


func _has_runtime_bridge_root_instance() -> bool:
	return _runtime_coordinator.has_runtime_bridge_root_instance(self, RUNTIME_BRIDGE_AUTOLOAD_NAME)


func _recreate_dock() -> void:
	var result: Dictionary = _dock_coordinator.recreate_plugin_dock(
		self,
		_dock,
		_action_router,
		DOCK_SLOT_RIGHT_UL,
		MCP_DOCK_SCENE_PATH,
		MCP_DOCK_SCRIPT_PATH
	)
	_dock = result.get("dock", null)
	_action_router.refresh_dock()


func _schedule_plugin_reenable() -> void:
	var editor_interface = get_editor_interface()
	if editor_interface == null:
		return
	var base_control = editor_interface.get_base_control()
	if base_control == null:
		return

	var coordinator = PluginReloadCoordinator.new()
	coordinator.name = "MCPPluginReloadCoordinator"
	coordinator.configure(PLUGIN_ID, editor_interface, _server_controller)
	base_control.add_child(coordinator)


func _create_reload_coordinator():
	var coordinator = PluginReloadCoordinator.new()
	coordinator.configure(PLUGIN_ID, get_editor_interface(), _server_controller)
	return coordinator


func _configure_user_tool_watch_service() -> void:
	_user_tool_watch_service = _runtime_coordinator.configure_user_tool_watch_service(
		_user_tool_watch_service,
		self,
		Callable(self, "_create_reload_coordinator"),
		_user_tool_service,
		Callable(_action_router, "apply_external_user_tool_catalog_refresh")
	)


func _configure_central_server_process_service() -> void:
	_central_server_process_service = _runtime_coordinator.configure_central_server_process_service(
		_central_server_process_service,
		self,
		_state.settings
	)


func _ensure_local_central_server_if_needed() -> void:
	var result: Dictionary = _runtime_coordinator.ensure_local_central_server_if_needed(
		_central_server_process_service,
		_central_server_attach_service,
		_last_central_server_endpoint_reachable
	)
	_last_central_server_endpoint_reachable = bool(result.get("last_endpoint_reachable", _last_central_server_endpoint_reachable))


func _configure_central_server_attach_service() -> void:
	_central_server_attach_service = _runtime_coordinator.configure_central_server_attach_service(
		_central_server_attach_service,
		self,
		_state.settings,
		Callable(self, "_save_settings")
	)
