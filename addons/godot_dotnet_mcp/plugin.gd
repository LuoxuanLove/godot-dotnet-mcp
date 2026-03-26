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
const MCPEditorDebuggerBridge = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_editor_debugger_bridge.gd")
const MCPRuntimeDebugStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_debug_store.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const MCP_DOCK_SCENE_PATH := "res://addons/godot_dotnet_mcp/ui/mcp_dock.tscn"
const MCP_DOCK_SCRIPT_PATH := "res://addons/godot_dotnet_mcp/ui/mcp_dock.gd"
const PLUGIN_ID := "godot_dotnet_mcp"
const PENDING_FOCUS_SNAPSHOT_KEY := "_pending_focus_snapshot"
const RUNTIME_BRIDGE_AUTOLOAD_NAME := "MCPRuntimeBridge"
const RUNTIME_BRIDGE_AUTOLOAD_PATH := "res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_bridge.gd"

var _state := PluginRuntimeState.new()
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
	_ensure_runtime_bridge_autoload()
	_install_editor_debugger_bridge()
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
	_uninstall_editor_debugger_bridge()
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
		_is_runtime_bridge_autoload_path(str(ProjectSettings.get_setting("autoload/%s" % RUNTIME_BRIDGE_AUTOLOAD_NAME, ""))),
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
	_on_start_requested()


func stop_server() -> void:
	_on_stop_requested()


func _attach_server_controller() -> void:
	if _server_controller == null:
		_server_controller = ServerRuntimeController.new()
	_server_controller.attach(self, _state.settings)
	_connect_server_controller_signals()


func _connect_server_controller_signals() -> void:
	if _server_controller == null:
		return
	if not _server_controller.server_started.is_connected(_on_server_started):
		_server_controller.server_started.connect(_on_server_started)
	if not _server_controller.server_stopped.is_connected(_on_server_stopped):
		_server_controller.server_stopped.connect(_on_server_stopped)
	if not _server_controller.request_received.is_connected(_on_request_received):
		_server_controller.request_received.connect(_on_request_received)


func _disconnect_server_controller_signals() -> void:
	if _server_controller == null:
		return
	if _server_controller.server_started.is_connected(_on_server_started):
		_server_controller.server_started.disconnect(_on_server_started)
	if _server_controller.server_stopped.is_connected(_on_server_stopped):
		_server_controller.server_stopped.disconnect(_on_server_stopped)
	if _server_controller.request_received.is_connected(_on_request_received):
		_server_controller.request_received.disconnect(_on_request_received)


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
	if _runtime_state_service == null:
		_runtime_state_service = PluginRuntimeStateServiceScript.new()
	_runtime_state_service.configure(_settings_store)
	_runtime_state_service.load_into(_state)
	if _client_install_detection_service != null:
		_client_install_detection_service.configure(_state.settings)


func _save_settings() -> void:
	if _runtime_state_service == null:
		_runtime_state_service = PluginRuntimeStateServiceScript.new()
	_runtime_state_service.configure(_settings_store)
	_runtime_state_service.save_settings(_state)


func _ensure_runtime_bridge_autoload() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("runtime_bridge_autoload", "_ensure_runtime_bridge_autoload")
	if not ResourceLoader.exists(RUNTIME_BRIDGE_AUTOLOAD_PATH):
		MCPRuntimeDebugStore.set_bridge_status(false, RUNTIME_BRIDGE_AUTOLOAD_NAME, RUNTIME_BRIDGE_AUTOLOAD_PATH, "Runtime bridge script missing")
		push_error("[Godot MCP] Runtime bridge autoload script not found: %s" % RUNTIME_BRIDGE_AUTOLOAD_PATH)
		MCPDebugBuffer.record("error", "plugin", "Runtime bridge script not found: %s" % RUNTIME_BRIDGE_AUTOLOAD_PATH)
		_record_self_incident("error", "resource_missing", "runtime_bridge_script_missing", "Runtime bridge autoload script not found", "plugin", "_ensure_runtime_bridge_autoload", RUNTIME_BRIDGE_AUTOLOAD_PATH, "", str(operation.get("operation_id", "")), true, "Verify that the runtime bridge script exists and is enabled.")
		_finish_self_operation(operation, false, "plugin", "_ensure_runtime_bridge_autoload")
		return
	var setting_key := "autoload/%s" % RUNTIME_BRIDGE_AUTOLOAD_NAME
	var current_path := str(ProjectSettings.get_setting(setting_key, ""))
	if _is_runtime_bridge_autoload_path(current_path):
		MCPRuntimeDebugStore.set_bridge_status(true, RUNTIME_BRIDGE_AUTOLOAD_NAME, RUNTIME_BRIDGE_AUTOLOAD_PATH, "Runtime bridge autoload already installed")
		_finish_self_operation(operation, true, "plugin", "_ensure_runtime_bridge_autoload")
		return
	if not current_path.is_empty():
		MCPRuntimeDebugStore.set_bridge_status(false, RUNTIME_BRIDGE_AUTOLOAD_NAME, current_path, "Autoload name is occupied by another script")
		push_warning("[Godot MCP] Runtime bridge autoload name is already used: %s" % current_path)
		MCPDebugBuffer.record("warning", "plugin", "Runtime bridge autoload name conflict: %s" % current_path)
		_record_self_incident("warning", "autoload_conflict", "autoload_name_occupied", "Runtime bridge autoload name is already occupied", "plugin", "_ensure_runtime_bridge_autoload", current_path, "", str(operation.get("operation_id", "")), true, "Resolve the conflicting autoload entry before enabling the runtime bridge.", {"setting_key": setting_key})
		_finish_self_operation(operation, false, "plugin", "_ensure_runtime_bridge_autoload")
		return
	_clear_runtime_bridge_root_instance()
	add_autoload_singleton(RUNTIME_BRIDGE_AUTOLOAD_NAME, RUNTIME_BRIDGE_AUTOLOAD_PATH)
	ProjectSettings.save()
	MCPRuntimeDebugStore.set_bridge_status(true, RUNTIME_BRIDGE_AUTOLOAD_NAME, RUNTIME_BRIDGE_AUTOLOAD_PATH, "Runtime bridge autoload installed")
	_record_runtime_bridge_stale_instance("_ensure_runtime_bridge_autoload", str(operation.get("operation_id", "")))
	_finish_self_operation(operation, true, "plugin", "_ensure_runtime_bridge_autoload")
	MCPDebugBuffer.record("info", "plugin", "Runtime bridge autoload registered")


func _remove_runtime_bridge_autoload() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("runtime_bridge_remove_autoload", "_remove_runtime_bridge_autoload")
	var setting_key := "autoload/%s" % RUNTIME_BRIDGE_AUTOLOAD_NAME
	var current_path := str(ProjectSettings.get_setting(setting_key, ""))
	if not _is_runtime_bridge_autoload_path(current_path):
		MCPRuntimeDebugStore.set_bridge_status(false, RUNTIME_BRIDGE_AUTOLOAD_NAME, current_path, "Runtime bridge autoload not owned by this plugin")
		_finish_self_operation(operation, true, "plugin", "_remove_runtime_bridge_autoload")
		return
	_clear_runtime_bridge_root_instance()
	remove_autoload_singleton(RUNTIME_BRIDGE_AUTOLOAD_NAME)
	ProjectSettings.save()
	MCPRuntimeDebugStore.set_bridge_status(false, RUNTIME_BRIDGE_AUTOLOAD_NAME, RUNTIME_BRIDGE_AUTOLOAD_PATH, "Runtime bridge autoload removed")
	_record_runtime_bridge_stale_instance("_remove_runtime_bridge_autoload", str(operation.get("operation_id", "")))
	_finish_self_operation(operation, true, "plugin", "_remove_runtime_bridge_autoload")
	MCPDebugBuffer.record("info", "plugin", "Runtime bridge autoload removed")


func _is_runtime_bridge_autoload_path(setting_value: String) -> bool:
	var normalized := setting_value.trim_prefix("*")
	if normalized == RUNTIME_BRIDGE_AUTOLOAD_PATH:
		return true
	if normalized.is_empty() or not ResourceLoader.exists(normalized):
		return false
	var resource := ResourceLoader.load(normalized)
	return resource != null and str(resource.resource_path) == RUNTIME_BRIDGE_AUTOLOAD_PATH


func _clear_runtime_bridge_root_instance() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return

	var runtime_bridge = tree.root.get_node_or_null(NodePath(RUNTIME_BRIDGE_AUTOLOAD_NAME))
	if runtime_bridge == null or not is_instance_valid(runtime_bridge):
		return

	if runtime_bridge.get_parent() != null:
		runtime_bridge.get_parent().remove_child(runtime_bridge)
	runtime_bridge.set_script(null)
	runtime_bridge.free()


func _install_editor_debugger_bridge() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("install_editor_debugger_bridge", "_install_editor_debugger_bridge")
	if _editor_debugger_bridge != null:
		_finish_self_operation(operation, true, "plugin", "_install_editor_debugger_bridge")
		return
	_editor_debugger_bridge = MCPEditorDebuggerBridge.new()
	if _editor_debugger_bridge == null:
		_record_self_incident("error", "lifecycle_error", "editor_debugger_bridge_create_failed", "Failed to instantiate the editor debugger bridge", "plugin", "_install_editor_debugger_bridge", "", "", str(operation.get("operation_id", "")), true, "Inspect the editor debugger bridge script and plugin lifecycle output.")
		_finish_self_operation(operation, false, "plugin", "_install_editor_debugger_bridge")
		return
	add_debugger_plugin(_editor_debugger_bridge)
	_finish_self_operation(operation, true, "plugin", "_install_editor_debugger_bridge")


func _uninstall_editor_debugger_bridge() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("uninstall_editor_debugger_bridge", "_uninstall_editor_debugger_bridge")
	if _editor_debugger_bridge == null:
		_finish_self_operation(operation, true, "plugin", "_uninstall_editor_debugger_bridge")
		return
	remove_debugger_plugin(_editor_debugger_bridge)
	_editor_debugger_bridge.set_script(null)
	_editor_debugger_bridge = null
	_finish_self_operation(operation, true, "plugin", "_uninstall_editor_debugger_bridge")


func _create_dock() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("create_dock", "_create_dock")
	_remove_dock()
	_remove_stale_docks()
	var dock_scene = _load_packed_scene(MCP_DOCK_SCENE_PATH)
	if dock_scene == null:
		push_error("[Godot MCP] Failed to load dock scene: %s" % MCP_DOCK_SCENE_PATH)
		MCPDebugBuffer.record("error", "plugin", "Failed to load dock scene: %s" % MCP_DOCK_SCENE_PATH)
		_record_self_incident("error", "resource_missing", "dock_scene_load_failed", "Failed to load dock scene", "plugin", "_create_dock", MCP_DOCK_SCENE_PATH, "", str(operation.get("operation_id", "")), true, "Inspect the dock scene resource and script dependencies.")
		_finish_self_operation(operation, false, "plugin", "_create_dock")
		return
	_dock = dock_scene.instantiate()
	if _dock == null:
		_record_self_incident("error", "resource_missing", "dock_scene_load_failed", "Dock scene instantiation returned null", "plugin", "_create_dock", MCP_DOCK_SCENE_PATH, "", str(operation.get("operation_id", "")), true, "Inspect the dock scene resource and its script.")
		_finish_self_operation(operation, false, "plugin", "_create_dock")
		return
	if not _wire_dock_signals(str(operation.get("operation_id", ""))):
		_finish_self_operation(operation, false, "plugin", "_create_dock")
		return
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	var dock_count = _count_dock_instances()
	if dock_count > 1:
		_record_self_incident("warning", "reload_conflict", "dock_duplicate_instance", "More than one MCP dock instance is present after dock creation", "plugin", "_create_dock", MCP_DOCK_SCRIPT_PATH, "", str(operation.get("operation_id", "")), true, "Inspect stale dock cleanup and plugin reload ordering.", {"dock_count": dock_count})
	_finish_self_operation(operation, true, "plugin", "_create_dock")


func _remove_dock() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("remove_dock", "_remove_dock")
	if _dock != null and is_instance_valid(_dock):
		if _dock.get_parent() != null:
			remove_control_from_docks(_dock)
			_dock.get_parent().remove_child(_dock)
		_dock.set_script(null)
		_dock.free()
	_dock = null
	if _count_dock_instances() > 0:
		_record_self_incident("warning", "reload_conflict", "instance_cleanup_incomplete", "Dock instances remain after dock removal", "plugin", "_remove_dock", MCP_DOCK_SCRIPT_PATH, "", str(operation.get("operation_id", "")), true, "Inspect dock cleanup and plugin reload ordering.", {"remaining_dock_instances": _count_dock_instances()})
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

	_client_executable_dialog = FileDialog.new()
	_client_executable_dialog.name = "ClientExecutableDialog"
	_client_executable_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_client_executable_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_client_executable_dialog.filters = PackedStringArray([
		"*.exe ; Executable",
		"*.cmd ; Command Script",
		"*.bat ; Batch Script",
		"* ; All Files"
	])
	_client_executable_dialog.file_selected.connect(_on_client_executable_file_selected)
	base_control.add_child(_client_executable_dialog)


func _remove_client_executable_dialog() -> void:
	if _client_executable_dialog == null:
		return
	if is_instance_valid(_client_executable_dialog):
		_client_executable_dialog.queue_free()
	_client_executable_dialog = null
	if _config_feature != null:
		_config_feature.reset_client_path_request()


func _get_client_executable_dialog():
	return _client_executable_dialog


func _on_central_server_detect_requested() -> void:
	if _server_feature != null:
		_server_feature.handle_detect_requested()


func _on_central_server_install_requested() -> void:
	if _server_feature != null:
		_server_feature.handle_install_requested()


func _on_central_server_start_requested() -> void:
	if _server_feature != null:
		_server_feature.handle_start_requested()


func _on_central_server_stop_requested() -> void:
	if _server_feature != null:
		_server_feature.handle_stop_requested()


func _on_central_server_open_install_dir_requested() -> void:
	if _server_feature != null:
		_server_feature.handle_open_install_dir_requested()


func _on_central_server_open_logs_requested() -> void:
	if _server_feature != null:
		_server_feature.handle_open_logs_requested()


func _on_clear_self_diagnostics_requested() -> void:
	if _self_diagnostic_feature != null:
		_self_diagnostic_feature.handle_clear_requested()


func _remove_stale_docks() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("remove_stale_docks", "_remove_stale_docks")
	var editor_interface = get_editor_interface()
	if editor_interface == null:
		_finish_self_operation(operation, true, "plugin", "_remove_stale_docks")
		return
	var base_control = editor_interface.get_base_control()
	if base_control == null:
		_finish_self_operation(operation, true, "plugin", "_remove_stale_docks")
		return

	for child in base_control.find_children("*", "Control", true, false):
		if child == null or not is_instance_valid(child):
			continue
		if child == _dock:
			continue
		var script = child.get_script()
		var script_path := ""
		if script != null:
			script_path = str(script.resource_path)
		if child.name != "MCPDock" and script_path != MCP_DOCK_SCRIPT_PATH:
			continue
		if child.get_parent() != null:
			remove_control_from_docks(child)
			child.get_parent().remove_child(child)
		child.set_script(null)
		child.free()
		MCPDebugBuffer.record("debug", "plugin",
			"Removed stale dock instance: %s path=%s" % [child.get_instance_id(), script_path])
	var remaining_count = _count_dock_instances()
	if remaining_count > 1:
		_record_self_incident("warning", "reload_conflict", "dock_duplicate_instance", "More than one MCP dock instance remains after stale-dock cleanup", "plugin", "_remove_stale_docks", MCP_DOCK_SCRIPT_PATH, "", str(operation.get("operation_id", "")), true, "Inspect stale dock cleanup and editor plugin reload ordering.", {"dock_count": remaining_count})
	_finish_self_operation(operation, true, "plugin", "_remove_stale_docks")


func _wire_dock_signals(operation_id: String = "") -> bool:
	if _dock == null or not is_instance_valid(_dock):
		_record_self_incident("error", "ui_binding_error", "dock_signal_binding_failed", "Dock signal wiring was requested before the dock instance was ready", "plugin", "_wire_dock_signals", MCP_DOCK_SCRIPT_PATH, "", operation_id, true, "Inspect dock creation order.")
		return false
	var connected = true
	connected = _connect_dock_signal("current_tab_changed", Callable(_ui_state_feature, "handle_current_tab_changed"), operation_id) and connected
	connected = _connect_dock_signal("port_changed", Callable(_ui_state_feature, "handle_port_changed"), operation_id) and connected
	connected = _connect_dock_signal("log_level_changed", _on_log_level_changed, operation_id) and connected
	connected = _connect_dock_signal("permission_level_changed", _on_permission_level_changed, operation_id) and connected
	connected = _connect_dock_signal("language_changed", Callable(_ui_state_feature, "handle_language_changed"), operation_id) and connected
	connected = _connect_dock_signal("start_requested", _on_start_requested, operation_id) and connected
	connected = _connect_dock_signal("restart_requested", _on_restart_requested, operation_id) and connected
	connected = _connect_dock_signal("stop_requested", _on_stop_requested, operation_id) and connected
	connected = _connect_dock_signal("full_reload_requested", Callable(_reload_feature, "runtime_full_reload"), operation_id) and connected
	connected = _connect_dock_signal("central_server_detect_requested", _on_central_server_detect_requested, operation_id) and connected
	connected = _connect_dock_signal("central_server_install_requested", _on_central_server_install_requested, operation_id) and connected
	connected = _connect_dock_signal("central_server_start_requested", _on_central_server_start_requested, operation_id) and connected
	connected = _connect_dock_signal("central_server_stop_requested", _on_central_server_stop_requested, operation_id) and connected
	connected = _connect_dock_signal("central_server_open_install_dir_requested", _on_central_server_open_install_dir_requested, operation_id) and connected
	connected = _connect_dock_signal("central_server_open_logs_requested", _on_central_server_open_logs_requested, operation_id) and connected
	connected = _connect_dock_signal("clear_self_diagnostics_requested", _on_clear_self_diagnostics_requested, operation_id) and connected
	connected = _connect_dock_signal("delete_user_tool_requested", _on_delete_user_tool_requested, operation_id) and connected
	connected = _connect_dock_signal("tool_toggled", _on_tool_toggled, operation_id) and connected
	connected = _connect_dock_signal("category_toggled", _on_category_toggled, operation_id) and connected
	connected = _connect_dock_signal("domain_toggled", _on_domain_toggled, operation_id) and connected
	connected = _connect_dock_signal("tree_collapse_changed", Callable(_ui_state_feature, "handle_tree_collapse_changed"), operation_id) and connected
	connected = _connect_dock_signal("cli_scope_changed", Callable(_ui_state_feature, "handle_cli_scope_changed"), operation_id) and connected
	connected = _connect_dock_signal("config_platform_changed", Callable(_ui_state_feature, "handle_config_platform_changed"), operation_id) and connected
	connected = _connect_dock_signal("config_validate_requested", _on_config_validate_requested, operation_id) and connected
	connected = _connect_dock_signal("config_client_action_requested", _on_config_client_action_requested, operation_id) and connected
	connected = _connect_dock_signal("config_client_launch_requested", _on_config_client_launch_requested, operation_id) and connected
	connected = _connect_dock_signal("config_client_path_pick_requested", _on_config_client_path_pick_requested, operation_id) and connected
	connected = _connect_dock_signal("config_client_path_clear_requested", _on_config_client_path_clear_requested, operation_id) and connected
	connected = _connect_dock_signal("config_client_open_config_dir_requested", _on_config_client_open_config_dir_requested, operation_id) and connected
	connected = _connect_dock_signal("config_client_open_config_file_requested", _on_config_client_open_config_file_requested, operation_id) and connected
	connected = _connect_dock_signal("config_write_requested", _on_config_write_requested, operation_id) and connected
	connected = _connect_dock_signal("config_remove_requested", _on_config_remove_requested, operation_id) and connected
	connected = _connect_dock_signal("copy_requested", Callable(_ui_state_feature, "handle_copy_requested"), operation_id) and connected
	return connected


func _build_dock_model() -> Dictionary:
	if _dock_model_service == null:
		_configure_dock_model_service()
	if _dock_model_service == null:
		return {}
	return _dock_model_service.build_model()


func _refresh_dock() -> void:
	if _dock == null or not is_instance_valid(_dock):
		return
	if not _dock.is_visible_in_tree():
		return
	_dock.apply_model(_build_dock_model())


func _apply_initial_tool_profile_if_needed() -> void:
	if _tool_profile_feature != null:
		_tool_profile_feature.apply_initial_tool_profile_if_needed()


func _on_start_requested() -> void:
	_server_controller.start(_state.settings, "ui_start")
	_refresh_dock()


func _on_restart_requested() -> void:
	_server_controller.start(_state.settings, "ui_restart")
	_refresh_dock()


func _on_stop_requested() -> void:
	_server_controller.stop()
	_refresh_dock()


func _on_log_level_changed(level: String) -> void:
	if _tool_access_feature != null:
		_tool_access_feature.handle_log_level_changed(level)


func _on_permission_level_changed(level: String) -> void:
	if _tool_access_feature != null:
		_tool_access_feature.handle_permission_level_changed(level)


func _on_show_user_tools_changed(enabled: bool) -> void:
	if _tool_access_feature != null:
		_tool_access_feature.handle_show_user_tools_changed(enabled)


func _on_delete_user_tool_requested(script_path: String) -> void:
	if _user_tool_feature != null:
		_user_tool_feature.handle_delete_requested(script_path)


func _on_tool_toggled(tool_name: String, enabled: bool) -> void:
	if _tool_access_feature != null:
		_tool_access_feature.handle_tool_toggled(tool_name, enabled)


func _on_category_toggled(category: String, enabled: bool) -> void:
	if _tool_access_feature != null:
		_tool_access_feature.handle_category_toggled(category, enabled)


func _on_domain_toggled(domain_key: String, enabled: bool) -> void:
	if _tool_access_feature != null:
		_tool_access_feature.handle_domain_toggled(domain_key, enabled)


func _on_config_validate_requested(_platform_id: String) -> void:
	if _config_feature != null:
		_config_feature.handle_validate_requested()


func _on_config_client_action_requested(client_id: String) -> void:
	if _config_feature != null:
		_config_feature.handle_client_action_requested(client_id)


func _on_config_client_launch_requested(client_id: String) -> void:
	if _config_feature != null:
		_config_feature.handle_client_launch_requested(client_id)


func _on_config_client_path_pick_requested(client_id: String) -> void:
	if _config_feature != null:
		_config_feature.handle_client_path_pick_requested(client_id)


func _on_config_client_path_clear_requested(client_id: String) -> void:
	if _config_feature != null:
		_config_feature.handle_client_path_clear_requested(client_id)


func _on_config_client_open_config_dir_requested(client_id: String) -> void:
	if _config_feature != null:
		_config_feature.handle_client_open_config_dir_requested(client_id)


func _on_config_client_open_config_file_requested(client_id: String) -> void:
	if _config_feature != null:
		_config_feature.handle_client_open_config_file_requested(client_id)


func _on_config_write_requested(config_type: String, filepath: String, config: String, client_name: String) -> void:
	if _config_feature != null:
		_config_feature.handle_write_requested(config_type, filepath, config, client_name)


func _on_config_remove_requested(config_type: String, filepath: String, client_name: String) -> void:
	if _config_feature != null:
		_config_feature.handle_remove_requested(config_type, filepath, client_name)


func _on_server_started() -> void:
	_refresh_dock()


func _on_server_stopped() -> void:
	_refresh_dock()


func _on_request_received(_method: String, _params: Dictionary) -> void:
	_refresh_dock()


func _show_message(message: String) -> void:
	MCPDebugBuffer.record("info", "plugin", message)
	if _dock and is_instance_valid(_dock):
		_dock.show_message(_localization.get_text("dialog_title"), message)


func _show_confirmation(message: String, on_confirmed: Callable) -> void:
	MCPDebugBuffer.record("info", "plugin", message)
	if _dock and is_instance_valid(_dock) and _dock.has_method("show_confirmation"):
		_dock.show_confirmation(_localization.get_text("dialog_title"), message, on_confirmed)
		return
	if on_confirmed.is_valid():
		on_confirmed.call()


func _on_client_executable_file_selected(path: String) -> void:
	if _config_feature != null:
		_config_feature.handle_client_executable_file_selected(path)


func _schedule_user_tool_catalog_refresh() -> void:
	call_deferred("_apply_user_tool_catalog_refresh")


func _apply_user_tool_catalog_refresh(script_path: String = "", reason: String = "user_tool_catalog_refresh") -> void:
	if _user_tool_feature != null:
		_user_tool_feature.apply_user_tool_catalog_refresh(script_path, reason)


func _apply_external_user_tool_catalog_refresh(changed_paths: Array[String], reason: String = "external_watch") -> void:
	if _user_tool_feature != null:
		_user_tool_feature.apply_external_user_tool_catalog_refresh(changed_paths, reason)


func _refresh_user_tool_registry() -> Array[Dictionary]:
	if _user_tool_feature != null:
		return _user_tool_feature.refresh_user_tool_registry()
	return []


func _reload_user_tool_runtime(script_path: String, reason: String) -> Dictionary:
	if _user_tool_feature != null:
		return _user_tool_feature.reload_user_tool_runtime(script_path, reason)
	return {"success": false, "error": "User tool feature is unavailable"}


func _rebuild_user_tool_ui_model() -> void:
	if _user_tool_feature != null:
		_user_tool_feature.rebuild_user_tool_ui_model()


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


func _reload_all_tool_domains() -> Dictionary:
	if _server_controller == null:
		return {"success": false, "error": "Server controller is unavailable"}
	return _server_controller.reload_all_domains()


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


func _connect_dock_signal(signal_name: String, callable: Callable, operation_id: String) -> bool:
	if _dock == null or not is_instance_valid(_dock):
		return false
	if not _dock.has_signal(signal_name):
		_record_self_incident("error", "ui_binding_error", "dock_signal_binding_failed", "Dock signal is missing: %s" % signal_name, "plugin", "_wire_dock_signals", MCP_DOCK_SCRIPT_PATH, "", operation_id, true, "Inspect the dock script signal declarations.")
		return false
	if _dock.is_connected(signal_name, callable):
		return true
	var error = _dock.connect(signal_name, callable)
	if error != OK:
		_record_self_incident("error", "ui_binding_error", "dock_signal_binding_failed", "Dock signal failed to connect: %s" % signal_name, "plugin", "_wire_dock_signals", MCP_DOCK_SCRIPT_PATH, "", operation_id, true, "Inspect the dock script signal declarations and connection target.", {"error_code": error})
		return false
	return true


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
	var tree := get_tree()
	if tree == null or tree.root == null:
		return false
	var runtime_bridge = tree.root.get_node_or_null(NodePath(RUNTIME_BRIDGE_AUTOLOAD_NAME))
	return runtime_bridge != null and is_instance_valid(runtime_bridge)


func _record_runtime_bridge_stale_instance(phase: String, operation_id: String) -> void:
	var setting_key := "autoload/%s" % RUNTIME_BRIDGE_AUTOLOAD_NAME
	var current_path := str(ProjectSettings.get_setting(setting_key, ""))
	var root_present = _has_runtime_bridge_root_instance()
	var autoload_owned = _is_runtime_bridge_autoload_path(current_path)
	if root_present and not autoload_owned:
		_record_self_incident("warning", "autoload_conflict", "runtime_bridge_stale_instance", "Runtime bridge root instance is still present after autoload ownership changed", "plugin", phase, RUNTIME_BRIDGE_AUTOLOAD_PATH, "", operation_id, true, "Inspect autoload cleanup and editor reload ordering.", {"current_path": current_path})


func _load_packed_scene(path: String) -> PackedScene:
	var scene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE)
	return scene as PackedScene


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
	if _user_tool_watch_service == null:
		_user_tool_watch_service = UserToolWatchService.new()
	_user_tool_watch_service.stop()
	_user_tool_watch_service.configure(self, _create_reload_coordinator(), _user_tool_service)
	_user_tool_watch_service.start()


func _configure_central_server_process_service() -> void:
	if _central_server_process_service == null:
		_central_server_process_service = CentralServerProcessServiceScript.new()
	_central_server_process_service.configure(self, _state.settings)
	_central_server_process_service.refresh_detection()


func _ensure_local_central_server_if_needed() -> void:
	if _central_server_process_service == null or _central_server_attach_service == null:
		return

	var attach_status = _central_server_attach_service.get_status()
	if not bool(attach_status.get("enabled", true)):
		return

	var attach_state = str(attach_status.get("status", "idle"))
	if attach_state == "attached" or attach_state == "attaching" or attach_state == "heartbeat_pending":
		var attached_status = _central_server_process_service.get_status()
		_last_central_server_endpoint_reachable = bool(attached_status.get("endpoint_reachable", false))
		return

	var status = _central_server_process_service.ensure_service_running()
	var endpoint_reachable = bool(status.get("endpoint_reachable", false))
	if endpoint_reachable and not _last_central_server_endpoint_reachable:
		_central_server_attach_service.request_attach_soon()
	_last_central_server_endpoint_reachable = endpoint_reachable
	if str(status.get("status", "")) == "starting":
		_central_server_attach_service.request_attach_soon()


func _configure_central_server_attach_service() -> void:
	if _central_server_attach_service == null:
		_central_server_attach_service = CentralServerAttachServiceScript.new()
	_central_server_attach_service.configure(self, _state.settings, {
		"save_settings": Callable(self, "_save_settings")
	})
	_central_server_attach_service.start()


func _configure_feature_workflows() -> void:
	if _server_feature == null:
		_server_feature = ServerFeatureScript.new()
	_server_feature.configure(
		_central_server_process_service,
		_central_server_attach_service,
		_localization,
		_dock_presenter,
		{
			"show_message": Callable(self, "_show_message"),
			"show_confirmation": Callable(self, "_show_confirmation"),
			"refresh_dock": Callable(self, "_refresh_dock")
		}
	)

	if _config_feature == null:
		_config_feature = ConfigFeatureScript.new()
	_config_feature.configure(
		_state.settings,
		_localization,
		_config_service,
		_dock_presenter,
		_central_server_process_service,
		_client_install_detection_service,
		{
			"show_message": Callable(self, "_show_message"),
			"show_confirmation": Callable(self, "_show_confirmation"),
			"refresh_dock": Callable(self, "_refresh_dock"),
			"save_settings": Callable(self, "_save_settings"),
			"ensure_client_executable_dialog": Callable(self, "_ensure_client_executable_dialog"),
			"get_client_executable_dialog": Callable(self, "_get_client_executable_dialog")
		}
	)

	if _ui_state_feature == null:
		_ui_state_feature = UIStateFeatureScript.new()
	_ui_state_feature.configure(
		_state,
		_localization,
		_client_install_detection_service,
		{
			"save_settings": Callable(self, "_save_settings"),
			"refresh_dock": Callable(self, "_refresh_dock"),
			"show_message": Callable(self, "_show_message"),
			"capture_dock_focus_snapshot": Callable(self, "_capture_dock_focus_snapshot"),
			"restore_dock_focus_snapshot": Callable(self, "_restore_runtime_dock_focus_snapshot")
		}
	)

	if _tool_access_feature == null:
		_tool_access_feature = ToolAccessFeatureScript.new()
	_tool_access_feature.configure(
		_state,
		_localization,
		_tool_catalog,
		{
			"get_all_tools_by_category": Callable(_server_controller, "get_all_tools_by_category"),
			"set_disabled_tools": Callable(_server_controller, "set_disabled_tools"),
			"save_settings": Callable(self, "_save_settings"),
			"refresh_dock": Callable(self, "_refresh_dock"),
			"show_message": Callable(self, "_show_message"),
			"change_language": Callable(_ui_state_feature, "handle_language_changed")
		}
	)

	if _user_tool_feature == null:
		_user_tool_feature = UserToolFeatureScript.new()
	_user_tool_feature.configure(
		_user_tool_service,
		{
			"show_message": Callable(self, "_show_message"),
			"refresh_dock": Callable(self, "_refresh_dock"),
			"save_settings": Callable(self, "_save_settings"),
			"cleanup_disabled_tools": Callable(_tool_access_feature, "cleanup_disabled_tools"),
			"create_reload_coordinator": Callable(self, "_create_reload_coordinator"),
			"reload_all_domains": Callable(self, "_reload_all_tool_domains")
		}
	)

	if _reload_feature == null:
		_reload_feature = ReloadFeatureScript.new()
	_reload_feature.configure(
		self,
		{
			"is_server_running": Callable(self, "_runtime_reload_is_server_running"),
			"start_server": Callable(self, "_runtime_reload_start_server"),
			"reinitialize_server": Callable(self, "_runtime_reload_reinitialize_server"),
			"refresh_service_instances": Callable(self, "_refresh_service_instances"),
			"reset_localization": Callable(self, "_runtime_reload_reset_localization"),
			"recreate_server_controller": Callable(self, "_recreate_server_controller"),
			"configure_central_server_process_service": Callable(self, "_configure_central_server_process_service"),
			"configure_central_server_attach_service": Callable(self, "_configure_central_server_attach_service"),
			"configure_feature_workflows": Callable(self, "_configure_feature_workflows"),
			"recreate_dock": Callable(self, "_recreate_dock"),
			"refresh_dock": Callable(self, "_refresh_dock"),
			"capture_dock_focus_snapshot": Callable(self, "_capture_dock_focus_snapshot"),
			"restore_runtime_dock_focus_snapshot": Callable(self, "_restore_runtime_dock_focus_snapshot"),
			"finish_self_operation": Callable(self, "_finish_self_operation")
		}
	)

	if _tool_profile_feature == null:
		_tool_profile_feature = ToolProfileFeatureScript.new()
	_tool_profile_feature.configure(
		_state,
		_localization,
		_settings_store,
		_tool_catalog,
		{
			"get_all_tools_by_category": Callable(_server_controller, "get_all_tools_by_category"),
			"set_disabled_tools": Callable(_server_controller, "set_disabled_tools"),
			"cleanup_disabled_tools": Callable(_tool_access_feature, "cleanup_disabled_tools"),
			"save_settings": Callable(self, "_save_settings"),
			"refresh_dock": Callable(self, "_refresh_dock")
		}
	)

	if _self_diagnostic_feature == null:
		_self_diagnostic_feature = SelfDiagnosticFeatureScript.new()
	_self_diagnostic_feature.configure(
		_localization,
		RUNTIME_BRIDGE_AUTOLOAD_NAME,
		RUNTIME_BRIDGE_AUTOLOAD_PATH,
		{
			"count_dock_instances": Callable(self, "_count_dock_instances"),
			"has_runtime_bridge_root_instance": Callable(self, "_has_runtime_bridge_root_instance"),
			"is_server_running": Callable(_server_controller, "is_running"),
			"get_connection_stats": Callable(_server_controller, "get_connection_stats"),
			"get_tool_load_errors": Callable(_server_controller, "get_tool_load_errors"),
			"get_reload_status": Callable(_server_controller, "get_reload_status"),
			"get_performance_summary": Callable(_server_controller, "get_performance_summary"),
			"get_permission_level": Callable(_tool_access_feature, "get_permission_level"),
			"refresh_dock": Callable(self, "_refresh_dock"),
			"show_message": Callable(self, "_show_message"),
			"is_dock_present": Callable(self, "_is_live_dock_present")
		}
	)

	if _tool_bridge_service == null:
		_tool_bridge_service = PluginToolBridgeServiceScript.new()
	_tool_bridge_service.configure(
		_server_controller,
		_reload_feature,
		_self_diagnostic_feature,
		_tool_access_feature,
		_tool_profile_feature,
		_user_tool_feature
	)

	_configure_dock_model_service()


func _configure_dock_model_service() -> void:
	if _dock_model_service == null:
		_dock_model_service = DockModelServiceScript.new()
	_dock_model_service.configure(
		_state,
		_localization,
		_server_controller,
		_tool_catalog,
		_config_service,
		_dock_presenter,
		_user_tool_service,
		_client_install_detection_service,
		_central_server_attach_service,
		_central_server_process_service,
		_user_tool_watch_service,
		_tool_access_feature,
		_self_diagnostic_feature,
		{
			"get_editor_scale": Callable(self, "_get_editor_scale")
		}
	)


func _refresh_service_instances() -> void:
	_settings_store = SettingsStore.new()
	_runtime_state_service = PluginRuntimeStateServiceScript.new()
	_runtime_state_service.configure(_settings_store)
	_tool_bridge_service = PluginToolBridgeServiceScript.new()
	_tool_catalog = ToolCatalogService.new()
	_config_service = ClientConfigService.new()
	_client_install_detection_service = ClientInstallDetectionService.new()
	_server_feature = ServerFeatureScript.new()
	_config_feature = ConfigFeatureScript.new()
	_user_tool_feature = UserToolFeatureScript.new()
	_reload_feature = ReloadFeatureScript.new()
	_tool_profile_feature = ToolProfileFeatureScript.new()
	_tool_access_feature = ToolAccessFeatureScript.new()
	_self_diagnostic_feature = SelfDiagnosticFeatureScript.new()
	_ui_state_feature = UIStateFeatureScript.new()
	_dock_presenter = DockPresenterScript.new()
	_dock_model_service = DockModelServiceScript.new()
	_user_tool_service = UserToolService.new()
	_user_tool_watch_service = UserToolWatchService.new()
	_central_server_attach_service = CentralServerAttachServiceScript.new()
	_central_server_process_service = CentralServerProcessServiceScript.new()
