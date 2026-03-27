@tool
extends EditorPlugin

const LocalizationService = preload("res://addons/godot_dotnet_mcp/localization/localization_service.gd")
const PluginRuntimeState = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_state.gd")
const PluginRuntimeStateServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_state_service.gd")
const PluginToolBridgeServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_tool_bridge_service.gd")
const ToolPermissionPolicy = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_permission_policy.gd")
const SettingsStore = preload("res://addons/godot_dotnet_mcp/plugin/config/settings_store.gd")
const ServerRuntimeController = preload("res://addons/godot_dotnet_mcp/plugin/runtime/server_runtime_controller.gd")
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
const MCPRuntimeDebugStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_debug_store.gd")
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
var _server_controller := ServerRuntimeController.new()
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
	_refresh_service_instances()
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
	_configure_feature_workflows()

	_create_dock()
	_apply_initial_tool_profile_if_needed()
	_refresh_dock()
	set_process(true)

	if bool(_state.settings.get("auto_start", true)):
		_server_controller.start(_state.settings, "auto_start")
		_refresh_dock()

	_restore_pending_focus_snapshot_if_needed()
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
	_remove_client_executable_dialog()
	_editor_debugger_bridge = _runtime_coordinator.uninstall_editor_debugger_bridge(self, _editor_debugger_bridge)
	_dispose_server_controller()
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
		_refresh_dock()


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
	if _server_controller == null:
		_server_controller = ServerRuntimeController.new()
	_server_controller.attach(self, _state.settings)
	_connect_server_controller_signals()


func _connect_server_controller_signals() -> void:
	if _server_controller == null:
		return
	var server_started_callable := Callable(_action_router, "handle_server_started")
	var server_stopped_callable := Callable(_action_router, "handle_server_stopped")
	var request_received_callable := Callable(_action_router, "handle_request_received")
	if not _server_controller.server_started.is_connected(server_started_callable):
		_server_controller.server_started.connect(server_started_callable)
	if not _server_controller.server_stopped.is_connected(server_stopped_callable):
		_server_controller.server_stopped.connect(server_stopped_callable)
	if not _server_controller.request_received.is_connected(request_received_callable):
		_server_controller.request_received.connect(request_received_callable)


func _disconnect_server_controller_signals() -> void:
	if _server_controller == null:
		return
	var server_started_callable := Callable(_action_router, "handle_server_started")
	var server_stopped_callable := Callable(_action_router, "handle_server_stopped")
	var request_received_callable := Callable(_action_router, "handle_request_received")
	if _server_controller.server_started.is_connected(server_started_callable):
		_server_controller.server_started.disconnect(server_started_callable)
	if _server_controller.server_stopped.is_connected(server_stopped_callable):
		_server_controller.server_stopped.disconnect(server_stopped_callable)
	if _server_controller.request_received.is_connected(request_received_callable):
		_server_controller.request_received.disconnect(request_received_callable)


func _dispose_server_controller() -> void:
	if _server_controller == null:
		return
	_disconnect_server_controller_signals()
	_server_controller.detach()
	_server_controller = null


func _recreate_server_controller() -> void:
	_dispose_server_controller()
	_server_controller = ServerRuntimeController.new()
	_attach_server_controller()
	_configure_user_tool_watch_service()


func _load_state() -> void:
	_bootstrap.load_state(_runtime_state_service, _settings_store, _state, _client_install_detection_service)


func _save_settings() -> void:
	_bootstrap.save_settings(_runtime_state_service, _settings_store, _state)


func _create_dock() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("create_dock", "_create_dock")
	_remove_dock()
	_remove_stale_docks()
	var result: Dictionary = _dock_coordinator.create_dock({
		"plugin": self,
		"dock_scene_path": MCP_DOCK_SCENE_PATH,
		"dock_script_path": MCP_DOCK_SCRIPT_PATH,
		"dock_slot": DOCK_SLOT_RIGHT_UL,
		"operation_id": str(operation.get("operation_id", "")),
		"load_packed_scene": Callable(self, "_load_packed_scene"),
		"wire_dock_signals": Callable(self, "_wire_dock_signals"),
		"count_dock_instances": Callable(self, "_count_dock_instances"),
		"record_self_incident": Callable(self, "_record_self_incident")
	})
	_dock = result.get("dock", null)
	if not bool(result.get("success", false)):
		push_error("[Godot MCP] Failed to load dock scene: %s" % MCP_DOCK_SCENE_PATH)
		MCPDebugBuffer.record("error", "plugin", "Failed to load dock scene: %s" % MCP_DOCK_SCENE_PATH)
		_finish_self_operation(operation, false, "plugin", "_create_dock")
		return
	_finish_self_operation(operation, true, "plugin", "_create_dock")


func _remove_dock() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("remove_dock", "_remove_dock")
	var result: Dictionary = _dock_coordinator.remove_dock({
		"plugin": self,
		"dock": _dock,
		"dock_script_path": MCP_DOCK_SCRIPT_PATH,
		"operation_id": str(operation.get("operation_id", "")),
		"count_dock_instances": Callable(self, "_count_dock_instances"),
		"record_self_incident": Callable(self, "_record_self_incident")
	})
	_dock = result.get("dock", null)
	_finish_self_operation(operation, true, "plugin", "_remove_dock")


func _ensure_client_executable_dialog() -> void:
	if _client_executable_dialog != null and is_instance_valid(_client_executable_dialog):
		return

	var editor_interface = get_editor_interface()
	if editor_interface == null:
		return
	var base_control = editor_interface.get_base_control()
	if base_control == null:
		return
	_client_executable_dialog = _dock_coordinator.ensure_client_executable_dialog(
		_client_executable_dialog,
		base_control,
		Callable(_action_router, "handle_client_executable_file_selected")
	)


func _remove_client_executable_dialog() -> void:
	_client_executable_dialog = _dock_coordinator.remove_client_executable_dialog(
		_client_executable_dialog,
		Callable(_config_feature, "reset_client_path_request") if _config_feature != null else Callable()
	)


func _get_client_executable_dialog():
	return _client_executable_dialog


func _remove_stale_docks() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("remove_stale_docks", "_remove_stale_docks")
	_dock_coordinator.remove_stale_docks({
		"plugin": self,
		"current_dock": _dock,
		"dock_script_path": MCP_DOCK_SCRIPT_PATH,
		"operation_id": str(operation.get("operation_id", "")),
		"count_dock_instances": Callable(self, "_count_dock_instances"),
		"record_self_incident": Callable(self, "_record_self_incident"),
		"record_debug": Callable(self, "_record_plugin_debug")
	})
	_finish_self_operation(operation, true, "plugin", "_remove_stale_docks")


func _wire_dock_signals(dock = null, operation_id: String = "") -> bool:
	if dock == null:
		dock = _dock
	return _dock_coordinator.wire_dock_signals(
		dock,
		_build_dock_signal_bindings(),
		operation_id,
		Callable(self, "_record_self_incident"),
		MCP_DOCK_SCRIPT_PATH
	)


func _build_dock_signal_bindings() -> Array[Dictionary]:
	return _action_router.build_dock_signal_bindings()


func _build_dock_model() -> Dictionary:
	if _dock_model_service == null:
		_configure_dock_model_service()
	if _dock_model_service == null:
		return {}
	return _dock_model_service.build_model()


func _refresh_dock() -> void:
	_action_router.refresh_dock()


func _apply_initial_tool_profile_if_needed() -> void:
	if _tool_profile_feature != null:
		_tool_profile_feature.apply_initial_tool_profile_if_needed()


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


func _capture_dock_focus_snapshot() -> Dictionary:
	if _dock and is_instance_valid(_dock) and _dock.has_method("capture_focus_snapshot"):
		return _dock.capture_focus_snapshot()
	return {"tab_index": _state.current_tab, "focus_path": ""}


func _restore_runtime_dock_focus_snapshot(snapshot: Dictionary) -> void:
	if _dock == null or not is_instance_valid(_dock):
		return
	if _dock.has_method("activate_host_dock_tab"):
		_dock.activate_host_dock_tab()
	if _dock.has_method("restore_focus_snapshot"):
		_dock.restore_focus_snapshot(snapshot)


func _get_editor_scale() -> float:
	var editor_interface = get_editor_interface()
	if editor_interface:
		return float(editor_interface.get_editor_scale())
	return 1.0


func _record_self_incident(
	severity: String,
	category: String,
	code: String,
	message: String,
	component: String,
	phase: String,
	file_path: String = "",
	line = "",
	operation_id: String = "",
	recoverable: bool = true,
	suggested_action: String = "",
	context: Dictionary = {}
) -> void:
	PluginSelfDiagnosticStore.record_incident(
		severity,
		category,
		code,
		message,
		component,
		phase,
		file_path,
		line,
		operation_id,
		recoverable,
		suggested_action,
		context
	)


func _finish_self_operation(operation: Dictionary, success: bool, component: String, phase: String, anomaly_codes: Array = [], context: Dictionary = {}) -> void:
	if operation.is_empty():
		return
	var merged_context = context.duplicate(true)
	merged_context["component"] = component
	merged_context["phase"] = phase
	var finished = PluginSelfDiagnosticStore.end_operation(str(operation.get("operation_id", "")), success, anomaly_codes, merged_context)
	PluginSelfDiagnosticStore.record_slow_operation(finished, component, phase)


func _count_dock_instances() -> int:
	var editor_interface = get_editor_interface()
	if editor_interface == null:
		return 0
	var base_control = editor_interface.get_base_control()
	if base_control == null:
		return 0
	var count := 0
	for child in base_control.find_children("*", "Control", true, false):
		if child == null or not is_instance_valid(child):
			continue
		var script_path := ""
		var script = child.get_script()
		if script != null:
			script_path = str(script.resource_path)
		if child.name == "MCPDock" or script_path == MCP_DOCK_SCRIPT_PATH:
			count += 1
	return count


func _is_live_dock_present() -> bool:
	return _dock != null and is_instance_valid(_dock)


func _has_runtime_bridge_root_instance() -> bool:
	return _runtime_coordinator.has_runtime_bridge_root_instance(self, RUNTIME_BRIDGE_AUTOLOAD_NAME)


func _load_packed_scene(path: String) -> PackedScene:
	var scene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE)
	return scene as PackedScene


func _record_plugin_debug(message: String) -> void:
	MCPDebugBuffer.record("debug", "plugin", message)


func _recreate_dock() -> void:
	_remove_dock()
	_remove_stale_docks()
	_create_dock()
	_refresh_dock()


func _store_pending_focus_snapshot(snapshot: Dictionary) -> void:
	var serialized := {
		"tab_index": int(snapshot.get("tab_index", _state.current_tab)),
		"focus_path": str(snapshot.get("focus_path", ""))
	}
	_state.settings[PENDING_FOCUS_SNAPSHOT_KEY] = serialized


func _restore_pending_focus_snapshot_if_needed() -> void:
	var snapshot = _state.settings.get(PENDING_FOCUS_SNAPSHOT_KEY, {})
	if not (snapshot is Dictionary):
		return
	if _dock and is_instance_valid(_dock):
		if _dock.has_method("activate_host_dock_tab"):
			_dock.activate_host_dock_tab()
		if _dock.has_method("restore_focus_snapshot"):
			_dock.restore_focus_snapshot(snapshot)
	_state.settings.erase(PENDING_FOCUS_SNAPSHOT_KEY)
	_save_settings()


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
		{
			"apply_external_user_tool_catalog_refresh": Callable(_action_router, "apply_external_user_tool_catalog_refresh")
		}
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


func _configure_action_router() -> void:
	_action_router.configure({
		"server_controller": _server_controller,
		"state": _state,
		"localization": _localization,
		"server_feature": _server_feature,
		"config_feature": _config_feature,
		"user_tool_feature": _user_tool_feature,
		"tool_access_feature": _tool_access_feature,
		"self_diagnostic_feature": _self_diagnostic_feature,
		"ui_state_feature": _ui_state_feature,
		"reload_feature": _reload_feature,
		"build_dock_model": Callable(self, "_build_dock_model"),
		"get_dock": Callable(self, "_get_dock")
	})


func _get_dock():
	return _dock


func _configure_feature_workflows() -> void:
	_configure_action_router()
	var result: Dictionary = _bootstrap.configure_feature_workflows({
		"plugin": self,
		"state": _state,
		"state_settings": _state.settings,
		"localization": _localization,
		"settings_store": _settings_store,
		"server_controller": _server_controller,
		"tool_catalog": _tool_catalog,
		"config_service": _config_service,
		"dock_presenter": _dock_presenter,
		"user_tool_service": _user_tool_service,
		"user_tool_watch_service": _user_tool_watch_service,
		"client_install_detection_service": _client_install_detection_service,
		"central_server_attach_service": _central_server_attach_service,
		"central_server_process_service": _central_server_process_service,
		"server_feature": _server_feature,
		"config_feature": _config_feature,
		"user_tool_feature": _user_tool_feature,
		"reload_feature": _reload_feature,
		"tool_profile_feature": _tool_profile_feature,
		"tool_access_feature": _tool_access_feature,
		"self_diagnostic_feature": _self_diagnostic_feature,
		"ui_state_feature": _ui_state_feature,
		"tool_bridge_service": _tool_bridge_service,
		"dock_model_service": _dock_model_service,
		"runtime_bridge_autoload_name": RUNTIME_BRIDGE_AUTOLOAD_NAME,
		"runtime_bridge_autoload_path": RUNTIME_BRIDGE_AUTOLOAD_PATH,
		"show_message": Callable(_action_router, "show_message"),
		"show_confirmation": Callable(_action_router, "show_confirmation"),
		"refresh_dock": Callable(_action_router, "refresh_dock"),
		"save_settings": Callable(self, "_save_settings"),
		"ensure_client_executable_dialog": Callable(self, "_ensure_client_executable_dialog"),
		"get_client_executable_dialog": Callable(self, "_get_client_executable_dialog"),
		"capture_dock_focus_snapshot": Callable(self, "_capture_dock_focus_snapshot"),
		"restore_dock_focus_snapshot": Callable(self, "_restore_runtime_dock_focus_snapshot"),
		"get_all_tools_by_category": Callable(_server_controller, "get_all_tools_by_category"),
		"set_disabled_tools": Callable(_server_controller, "set_disabled_tools"),
		"create_reload_coordinator": Callable(self, "_create_reload_coordinator"),
		"reload_all_domains": Callable(_action_router, "reload_all_tool_domains"),
		"runtime_reload_is_server_running": Callable(self, "_runtime_reload_is_server_running"),
		"runtime_reload_start_server": Callable(self, "_runtime_reload_start_server"),
		"runtime_reload_reinitialize_server": Callable(self, "_runtime_reload_reinitialize_server"),
		"refresh_service_instances": Callable(self, "_refresh_service_instances"),
		"runtime_reload_reset_localization": Callable(self, "_runtime_reload_reset_localization"),
		"recreate_server_controller": Callable(self, "_recreate_server_controller"),
		"configure_central_server_process_service": Callable(self, "_configure_central_server_process_service"),
		"configure_central_server_attach_service": Callable(self, "_configure_central_server_attach_service"),
		"configure_feature_workflows": Callable(self, "_configure_feature_workflows"),
		"recreate_dock": Callable(self, "_recreate_dock"),
		"restore_runtime_dock_focus_snapshot": Callable(self, "_restore_runtime_dock_focus_snapshot"),
		"finish_self_operation": Callable(self, "_finish_self_operation"),
		"count_dock_instances": Callable(self, "_count_dock_instances"),
		"has_runtime_bridge_root_instance": Callable(self, "_has_runtime_bridge_root_instance"),
		"is_server_running": Callable(_server_controller, "is_running"),
		"get_connection_stats": Callable(_server_controller, "get_connection_stats"),
		"get_tool_load_errors": Callable(_server_controller, "get_tool_load_errors"),
		"get_reload_status": Callable(_server_controller, "get_reload_status"),
		"get_performance_summary": Callable(_server_controller, "get_performance_summary"),
		"is_dock_present": Callable(self, "_is_live_dock_present"),
		"get_editor_scale": Callable(self, "_get_editor_scale")
	})
	_server_feature = result.get("server_feature", _server_feature)
	_config_feature = result.get("config_feature", _config_feature)
	_ui_state_feature = result.get("ui_state_feature", _ui_state_feature)
	_tool_access_feature = result.get("tool_access_feature", _tool_access_feature)
	_user_tool_feature = result.get("user_tool_feature", _user_tool_feature)
	_reload_feature = result.get("reload_feature", _reload_feature)
	_tool_profile_feature = result.get("tool_profile_feature", _tool_profile_feature)
	_self_diagnostic_feature = result.get("self_diagnostic_feature", _self_diagnostic_feature)
	_tool_bridge_service = result.get("tool_bridge_service", _tool_bridge_service)
	_dock_model_service = result.get("dock_model_service", _dock_model_service)
	_configure_action_router()


func _configure_dock_model_service() -> void:
	_dock_model_service = _bootstrap.configure_dock_model_service({
		"state": _state,
		"localization": _localization,
		"server_controller": _server_controller,
		"tool_catalog": _tool_catalog,
		"config_service": _config_service,
		"dock_presenter": _dock_presenter,
		"user_tool_service": _user_tool_service,
		"client_install_detection_service": _client_install_detection_service,
		"central_server_attach_service": _central_server_attach_service,
		"central_server_process_service": _central_server_process_service,
		"user_tool_watch_service": _user_tool_watch_service,
		"dock_model_service": _dock_model_service,
		"get_editor_scale": Callable(self, "_get_editor_scale")
	}, _tool_access_feature, _self_diagnostic_feature)


func _refresh_service_instances() -> void:
	var bundle: Dictionary = _bootstrap.refresh_service_instances()
	_apply_service_bundle(bundle)


func _apply_service_bundle(bundle: Dictionary) -> void:
	_settings_store = bundle.get("settings_store", _settings_store)
	_runtime_state_service = bundle.get("runtime_state_service", _runtime_state_service)
	_tool_bridge_service = bundle.get("tool_bridge_service", _tool_bridge_service)
	_tool_catalog = bundle.get("tool_catalog", _tool_catalog)
	_config_service = bundle.get("config_service", _config_service)
	_client_install_detection_service = bundle.get("client_install_detection_service", _client_install_detection_service)
	_server_feature = bundle.get("server_feature", _server_feature)
	_config_feature = bundle.get("config_feature", _config_feature)
	_user_tool_feature = bundle.get("user_tool_feature", _user_tool_feature)
	_reload_feature = bundle.get("reload_feature", _reload_feature)
	_tool_profile_feature = bundle.get("tool_profile_feature", _tool_profile_feature)
	_tool_access_feature = bundle.get("tool_access_feature", _tool_access_feature)
	_self_diagnostic_feature = bundle.get("self_diagnostic_feature", _self_diagnostic_feature)
	_ui_state_feature = bundle.get("ui_state_feature", _ui_state_feature)
	_dock_presenter = bundle.get("dock_presenter", _dock_presenter)
	_dock_model_service = bundle.get("dock_model_service", _dock_model_service)
	_user_tool_service = bundle.get("user_tool_service", _user_tool_service)
	_user_tool_watch_service = bundle.get("user_tool_watch_service", _user_tool_watch_service)
	_central_server_attach_service = bundle.get("central_server_attach_service", _central_server_attach_service)
	_central_server_process_service = bundle.get("central_server_process_service", _central_server_process_service)
