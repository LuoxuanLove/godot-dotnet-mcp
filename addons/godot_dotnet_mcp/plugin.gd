@tool
extends EditorPlugin

const LocalizationService = preload("res://addons/godot_dotnet_mcp/localization/localization_service.gd")
const PluginRuntimeState = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_state.gd")
const TreeCollapseState = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tree_collapse_state.gd")
const SettingsStore = preload("res://addons/godot_dotnet_mcp/plugin/config/settings_store.gd")
const ServerRuntimeController = preload("res://addons/godot_dotnet_mcp/plugin/runtime/server_runtime_controller.gd")
const ToolCatalogService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_catalog_service.gd")
const BridgeInstallServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/bridge_install_service.gd")
const CentralServerAttachServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/central_server_attach_service.gd")
const CentralServerProcessServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/central_server_process_service.gd")
const PluginReloadCoordinator = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_reload_coordinator.gd")
const ClientConfigService = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_service.gd")
const ClientInstallDetectionService = preload("res://addons/godot_dotnet_mcp/plugin/config/client_install_detection_service.gd")
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
var _settings_store := SettingsStore.new()
var _server_controller := ServerRuntimeController.new()
var _tool_catalog := ToolCatalogService.new()
var _config_service := ClientConfigService.new()
var _client_install_detection_service := ClientInstallDetectionService.new()
var _user_tool_service := UserToolService.new()
var _user_tool_watch_service := UserToolWatchService.new()
var _bridge_install_service: BridgeInstallService
var _central_server_attach_service: CentralServerAttachService
var _central_server_process_service: CentralServerProcessService
var _localization: LocalizationService
var _dock: Control
var _bridge_install_dialog: FileDialog
var _client_executable_dialog: FileDialog
var _pending_client_path_request := {}
var _status_poll_accumulator := 0.0
var _editor_debugger_bridge: EditorDebuggerPlugin
var _pending_runtime_reload_action := ""
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
	_remove_bridge_install_dialog()
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
	for issue in PluginRuntimeState.get_domain_category_consistency_issues():
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
	var load_result = _settings_store.load_plugin_settings(
		PluginRuntimeState.DEFAULT_SETTINGS,
		PluginRuntimeState.SETTINGS_PATH,
		PluginRuntimeState.ALL_TOOL_CATEGORIES,
		PluginRuntimeState.DEFAULT_COLLAPSED_DOMAINS
	)
	_state.settings = load_result["settings"]
	_state.settings["auto_start"] = true
	if not (_state.settings.get("client_manual_paths", {}) is Dictionary):
		_state.settings["client_manual_paths"] = {}
	_state.current_cli_scope = str(_state.settings.get("current_cli_scope", _state.current_cli_scope))
	_state.current_config_platform = str(_state.settings.get("current_config_platform", _state.current_config_platform))
	_state.needs_initial_tool_profile_apply = not bool(load_result["has_settings_file"])
	_state.custom_tool_profiles = _settings_store.load_custom_profiles(PluginRuntimeState.TOOL_PROFILE_DIR)
	_configure_client_install_detection_service()


func _save_settings() -> void:
	_settings_store.save_plugin_settings(PluginRuntimeState.SETTINGS_PATH, _state.settings)


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
		_record_self_incident("error", "lifecycle_error", "editor_debugger_bridge_install_failed", "Failed to instantiate the editor debugger bridge", "plugin", "_install_editor_debugger_bridge", "", "", str(operation.get("operation_id", "")), true, "Inspect the editor debugger bridge script and plugin lifecycle output.")
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
	_ensure_bridge_install_dialog()
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


func _ensure_bridge_install_dialog() -> void:
	if _bridge_install_dialog != null and is_instance_valid(_bridge_install_dialog):
		return

	var editor_interface = get_editor_interface()
	if editor_interface == null:
		return
	var base_control = editor_interface.get_base_control()
	if base_control == null:
		return

	_bridge_install_dialog = FileDialog.new()
	_bridge_install_dialog.name = "BridgeInstallDialog"
	_bridge_install_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_bridge_install_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_bridge_install_dialog.title = _localization.get_text("bridge_install_dialog_title") if _localization else "Select Bridge Executable"
	_bridge_install_dialog.filters = PackedStringArray(["*.exe ; Bridge Executable"])
	_bridge_install_dialog.file_selected.connect(_on_bridge_install_file_selected)
	base_control.add_child(_bridge_install_dialog)


func _remove_bridge_install_dialog() -> void:
	if _bridge_install_dialog == null:
		return
	if is_instance_valid(_bridge_install_dialog):
		_bridge_install_dialog.queue_free()
	_bridge_install_dialog = null


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
	_pending_client_path_request = {}


func _open_bridge_install_dialog() -> void:
	_ensure_bridge_install_dialog()
	if _bridge_install_dialog == null or not is_instance_valid(_bridge_install_dialog):
		_record_self_incident("error", "ui_binding_error", "bridge_install_dialog_missing", "Bridge install dialog could not be created", "plugin", "_open_bridge_install_dialog", "", "", "", true, "Inspect the editor base control and dock lifecycle.")
		return
	var current_bridge_path = str(_state.settings.get("bridge_executable_path", ""))
	if not current_bridge_path.is_empty():
		_bridge_install_dialog.current_dir = current_bridge_path.get_base_dir()
	_bridge_install_dialog.title = _localization.get_text("bridge_install_dialog_title") if _localization else "Select Bridge Executable"
	_bridge_install_dialog.popup_centered_ratio(0.6)


func _on_bridge_install_requested() -> void:
	_open_bridge_install_dialog()


func _on_bridge_validate_requested() -> void:
	var bridge_install_service = _get_bridge_install_service()
	var result = bridge_install_service.validate_executable(str(_state.settings.get("bridge_executable_path", "")))
	if not bool(result.get("success", false)):
		_state.settings["bridge_install_state"] = BridgeInstallService.STATUS_INVALID
		_state.settings["bridge_install_message"] = str(result.get("message", "Bridge validation failed."))
		_save_settings()
		_refresh_dock()
		_show_bridge_install_feedback("bridge_install_validation_failed", str(result.get("message", "Bridge validation failed.")))
		return

	var registered = bridge_install_service.register_executable(_state.settings, str(_state.settings.get("bridge_executable_path", "")))
	if bool(registered.get("success", false)):
		_save_settings()
		_refresh_dock()
		_show_bridge_install_feedback("bridge_install_selected", str(registered.get("message", "Bridge executable registered.")))
		return

	_show_bridge_install_feedback("bridge_install_validation_failed", str(registered.get("message", "Bridge validation failed.")))


func _on_bridge_clear_requested() -> void:
	var bridge_install_service = _get_bridge_install_service()
	var result = bridge_install_service.clear_executable(_state.settings)
	if bool(result.get("success", false)):
		_save_settings()
		_refresh_dock()
		_show_bridge_install_feedback("bridge_install_cleared", str(result.get("message", "Bridge registration cleared.")))


func _on_central_server_detect_requested() -> void:
	if _central_server_process_service == null:
		return
	var status = _central_server_process_service.refresh_detection()
	_refresh_dock()
	_show_message(_resolve_central_server_process_feedback(status, "detect"))


func _on_central_server_install_requested() -> void:
	if _central_server_process_service == null:
		return
	var preview = _central_server_process_service.refresh_detection()
	if not bool(preview.get("install_available", false)):
		_show_message(_resolve_central_server_process_feedback(preview, "detect"))
		return
	_show_confirmation(_build_central_server_install_confirmation(preview), Callable(self, "_perform_central_server_install"))


func _perform_central_server_install() -> void:
	if _central_server_process_service == null:
		return
	var status = _central_server_process_service.install_or_update_service()
	_refresh_dock()
	if not bool(status.get("success", false)):
		_show_message(_resolve_central_server_process_feedback(status, "install_error"))
		return
	var running_status = _central_server_process_service.ensure_service_running()
	if _central_server_attach_service != null:
		_central_server_attach_service.request_attach_soon()
	var success_message = _resolve_central_server_process_feedback(status, "install_success")
	var install_details = _build_central_server_install_details(status)
	if install_details.is_empty():
		_show_message(success_message)
	else:
		_show_message("%s\n\n%s" % [success_message, install_details])
	if str(running_status.get("status", "")) == "launch_error":
		_show_message(_resolve_central_server_process_feedback(running_status, "start"))


func _on_central_server_start_requested() -> void:
	if _central_server_process_service == null:
		return
	var status = _central_server_process_service.start_service()
	_refresh_dock()
	if str(status.get("status", "")) == "launch_error":
		_show_message(_resolve_central_server_process_feedback(status, "start"))
		return
	if _central_server_attach_service != null:
		_central_server_attach_service.request_attach_soon()
	_show_message(_resolve_central_server_process_feedback(status, "start"))


func _on_central_server_stop_requested() -> void:
	if _central_server_process_service == null:
		return
	var status = _central_server_process_service.stop_service()
	_refresh_dock()
	if str(status.get("status", "")) == "launch_error":
		_show_message(_resolve_central_server_process_feedback(status, "stop_error"))
		return
	_show_message(_resolve_central_server_process_feedback(status, "stop_success"))


func _on_central_server_open_install_dir_requested() -> void:
	if _central_server_process_service == null:
		return
	var result = _central_server_process_service.open_install_directory()
	if not bool(result.get("success", false)):
		_show_message(_localization.get_text("central_server_open_install_dir_failed"))
		return
	_show_message(_localization.get_text("central_server_open_install_dir_success"))


func _on_central_server_open_logs_requested() -> void:
	if _central_server_process_service == null:
		return
	var result = _central_server_process_service.open_log_location()
	if not bool(result.get("success", false)):
		_show_message(_localization.get_text("central_server_open_logs_failed"))
		return
	_show_message(_localization.get_text("central_server_open_logs_success"))


func _on_clear_self_diagnostics_requested() -> void:
	var result = clear_self_diagnostics_from_tools()
	if bool(result.get("success", false)):
		_show_message(_localization.get_text("self_diag_cleared"))
		return
	_show_message(str(result.get("error", _localization.get_text("self_diag_clear_failed"))))


func _on_bridge_install_file_selected(path: String) -> void:
	var bridge_install_service = _get_bridge_install_service()
	var result = bridge_install_service.register_executable(_state.settings, path, "plugin_file_dialog")
	if not bool(result.get("success", false)):
		_state.settings["bridge_install_state"] = BridgeInstallService.STATUS_INVALID
		_state.settings["bridge_install_message"] = str(result.get("message", "Bridge validation failed."))
		_save_settings()
		_refresh_dock()
		_show_bridge_install_feedback("bridge_install_validation_failed", str(result.get("message", "Bridge validation failed.")))
		return

	_save_settings()
	_refresh_dock()
	_show_bridge_install_feedback("bridge_install_selected", str(result.get("message", "Bridge executable registered.")))


func _show_bridge_install_feedback(title_key: String, message: String) -> void:
	var title = _localization.get_text(title_key) if _localization else title_key
	if title == title_key:
		title = "Bridge"
	if _dock != null and is_instance_valid(_dock) and _dock.has_method("show_message"):
		_dock.show_message(title, message)
	else:
		push_warning("[Godot MCP] %s: %s" % [title, message])


func _get_bridge_install_service() -> BridgeInstallService:
	if _bridge_install_service == null:
		_bridge_install_service = BridgeInstallServiceScript.new()
	return _bridge_install_service


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
	connected = _connect_dock_signal("current_tab_changed", _on_current_tab_changed, operation_id) and connected
	connected = _connect_dock_signal("port_changed", _on_port_changed, operation_id) and connected
	connected = _connect_dock_signal("log_level_changed", _on_log_level_changed, operation_id) and connected
	connected = _connect_dock_signal("permission_level_changed", _on_permission_level_changed, operation_id) and connected
	connected = _connect_dock_signal("language_changed", _on_language_changed, operation_id) and connected
	connected = _connect_dock_signal("start_requested", _on_start_requested, operation_id) and connected
	connected = _connect_dock_signal("restart_requested", _on_restart_requested, operation_id) and connected
	connected = _connect_dock_signal("stop_requested", _on_stop_requested, operation_id) and connected
	connected = _connect_dock_signal("full_reload_requested", runtime_full_reload, operation_id) and connected
	connected = _connect_dock_signal("bridge_install_requested", _on_bridge_install_requested, operation_id) and connected
	connected = _connect_dock_signal("bridge_validate_requested", _on_bridge_validate_requested, operation_id) and connected
	connected = _connect_dock_signal("bridge_clear_requested", _on_bridge_clear_requested, operation_id) and connected
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
	connected = _connect_dock_signal("tree_collapse_changed", _on_tree_collapse_changed, operation_id) and connected
	connected = _connect_dock_signal("cli_scope_changed", _on_cli_scope_changed, operation_id) and connected
	connected = _connect_dock_signal("config_platform_changed", _on_config_platform_changed, operation_id) and connected
	connected = _connect_dock_signal("config_validate_requested", _on_config_validate_requested, operation_id) and connected
	connected = _connect_dock_signal("config_client_action_requested", _on_config_client_action_requested, operation_id) and connected
	connected = _connect_dock_signal("config_client_launch_requested", _on_config_client_launch_requested, operation_id) and connected
	connected = _connect_dock_signal("config_client_path_pick_requested", _on_config_client_path_pick_requested, operation_id) and connected
	connected = _connect_dock_signal("config_client_path_clear_requested", _on_config_client_path_clear_requested, operation_id) and connected
	connected = _connect_dock_signal("config_client_open_config_dir_requested", _on_config_client_open_config_dir_requested, operation_id) and connected
	connected = _connect_dock_signal("config_client_open_config_file_requested", _on_config_client_open_config_file_requested, operation_id) and connected
	connected = _connect_dock_signal("config_write_requested", _on_config_write_requested, operation_id) and connected
	connected = _connect_dock_signal("config_remove_requested", _on_config_remove_requested, operation_id) and connected
	connected = _connect_dock_signal("copy_requested", _on_copy_requested, operation_id) and connected
	return connected


func _build_dock_model() -> Dictionary:
	if _tool_catalog == null:
		_tool_catalog = ToolCatalogService.new()
	if _localization == null:
		LocalizationService.reset_instance()
		_localization = LocalizationService.get_instance()
		_localization.set_language(str(_state.settings.get("language", "")))
	if _user_tool_service == null:
		_user_tool_service = UserToolService.new()

	var all_tools_by_category = _server_controller.get_all_tools_by_category().duplicate(true)
	var tools_by_category = all_tools_by_category.duplicate(true)
	for category in tools_by_category.keys():
		if not is_tool_category_visible_for_permission(str(category)):
			tools_by_category.erase(category)
	var tool_names = _tool_catalog.build_tool_name_index(all_tools_by_category)
	var profile_id = str(_state.settings.get("tool_profile_id", "default"))
	var current_tab = int(_state.current_tab)

	if not _tool_catalog.has_tool_profile(profile_id, PluginRuntimeState.BUILTIN_TOOL_PROFILES, _state.custom_tool_profiles):
		profile_id = _tool_catalog.find_matching_profile_id(
			_state.settings.get("disabled_tools", []),
			PluginRuntimeState.BUILTIN_TOOL_PROFILES,
			_state.custom_tool_profiles,
			tool_names
		)
		if profile_id.is_empty():
			profile_id = "default"
		_state.settings["tool_profile_id"] = profile_id

	var self_diagnostics = _build_self_diagnostic_health_snapshot()
	var bridge_install = _get_bridge_install_service().build_snapshot(_state.settings)
	var central_server_attach = _get_central_server_attach_status()
	var central_server_process = _get_central_server_process_status()
	var user_tool_watch = _get_user_tool_watch_status()
	var user_tools: Array = []
	var desktop_clients: Array[Dictionary] = []
	var cli_clients: Array[Dictionary] = []
	var config_platforms: Array[Dictionary] = []
	var config_connection_mode := {}

	if current_tab == 1:
		user_tools = _user_tool_service.list_user_tools()

	if current_tab == 2:
		var client_install_statuses = _get_client_install_statuses()
		desktop_clients = _build_desktop_client_models(central_server_process, client_install_statuses)
		cli_clients = _build_cli_client_models(central_server_process, client_install_statuses)
		config_platforms = _build_config_platform_models(desktop_clients, cli_clients)
		_state.current_config_platform = _resolve_current_config_platform(config_platforms)
		_state.settings["current_config_platform"] = _state.current_config_platform
		config_connection_mode = _build_config_connection_mode(central_server_process)
	return {
		"localization": _localization,
		"settings": _state.settings,
		"current_language": _state.resolve_active_language(_localization),
		"current_tab": _state.current_tab,
		"permission_levels": PluginRuntimeState.PERMISSION_LEVELS,
		"current_permission_level": _get_permission_level(),
		"log_levels": MCPDebugBuffer.get_available_levels(),
		"current_log_level": str(_state.settings.get("log_level", MCPDebugBuffer.get_minimum_level())),
		"current_cli_scope": _state.current_cli_scope,
		"current_config_platform": _state.current_config_platform,
		"tool_profile_id": profile_id,
		"editor_scale": _get_editor_scale(),
		"is_running": _server_controller.is_running(),
		"stats": _server_controller.get_connection_stats(),
		"domain_states": _server_controller.get_domain_states(),
		"reload_status": _server_controller.get_reload_status(),
		"performance": _server_controller.get_performance_summary(),
		"languages": _localization.get_available_languages(),
		"tools_by_category": tools_by_category,
		"tool_load_errors": _server_controller.get_tool_load_errors(),
		"self_diagnostics": self_diagnostics,
		"self_diagnostic_copy_text": PluginSelfDiagnosticStore.build_copy_text(self_diagnostics),
		"bridge_install": bridge_install,
		"central_server_attach": central_server_attach,
		"central_server_process": central_server_process,
		"builtin_profiles": PluginRuntimeState.BUILTIN_TOOL_PROFILES,
		"custom_profiles": _state.custom_tool_profiles,
		"domain_defs": PluginRuntimeState.TOOL_DOMAIN_DEFS,
		"profile_description": _get_tool_profile_description(profile_id, tool_names),
		"user_tools": user_tools,
		"user_tool_watch": user_tool_watch,
		"desktop_clients": desktop_clients,
		"cli_clients": cli_clients,
		"config_platforms": config_platforms,
		"config_connection_mode": config_connection_mode
	}


func _refresh_dock() -> void:
	if _dock == null or not is_instance_valid(_dock):
		return
	if not _dock.is_visible_in_tree():
		return
	_dock.apply_model(_build_dock_model())


func _apply_initial_tool_profile_if_needed() -> void:
	if not _state.needs_initial_tool_profile_apply:
		return

	var tool_names = _tool_catalog.build_tool_name_index(_server_controller.get_all_tools_by_category())
	if tool_names.is_empty():
		return

	_state.settings["disabled_tools"] = _tool_catalog.get_disabled_tools_for_profile(
		str(_state.settings.get("tool_profile_id", "default")),
		PluginRuntimeState.BUILTIN_TOOL_PROFILES,
		_state.custom_tool_profiles,
		tool_names,
		_state.settings.get("disabled_tools", [])
	)
	_state.needs_initial_tool_profile_apply = false
	_server_controller.set_disabled_tools(_state.settings["disabled_tools"])
	_save_settings()


func _get_tool_profile_description(profile_id: String, tool_names: Array) -> String:
	var description = ""
	for profile in PluginRuntimeState.BUILTIN_TOOL_PROFILES:
		if str(profile.get("id", "")) == profile_id:
			description = _localization.get_text(str(profile.get("desc_key", "")))
			break

	if description.is_empty() and _state.custom_tool_profiles.has(profile_id):
		description = _localization.get_text("tool_profile_custom_desc") % [str(_state.custom_tool_profiles[profile_id].get("name", profile_id))]

	if description.is_empty():
		description = _localization.get_text("tool_profile_default_desc")

	if not _tool_catalog.profile_matches_state(
		profile_id,
		_state.settings.get("disabled_tools", []),
		PluginRuntimeState.BUILTIN_TOOL_PROFILES,
		_state.custom_tool_profiles,
		tool_names
	):
		description = "%s %s" % [description, _localization.get_text("tool_profile_modified_desc")]

	return description


func _build_desktop_client_models(central_server_process: Dictionary = {}, client_install_statuses: Dictionary = {}) -> Array[Dictionary]:
	var host = str(_state.settings.get("host", "127.0.0.1"))
	var port = int(_state.settings.get("port", 3000))
	var transport = _build_client_transport_model(central_server_process, host, port)
	return [
		_build_client_ui_model("claude_desktop", {
			"id": "claude_desktop",
			"name_key": "config_client_claude_desktop",
			"summary_text": _build_client_summary_text(_get_desktop_summary_key("claude_desktop", transport), transport),
			"path": _config_service.get_claude_config_path(),
			"content": _build_desktop_client_config_content(transport),
			"writeable": true
		}, client_install_statuses),
		_build_client_ui_model("cursor", {
			"id": "cursor",
			"name_key": "config_client_cursor",
			"summary_text": _build_client_summary_text(_get_desktop_summary_key("cursor", transport), transport),
			"path": _config_service.get_cursor_config_path(),
			"content": _build_desktop_client_config_content(transport),
			"writeable": true
		}, client_install_statuses),
		_build_client_ui_model("trae", {
			"id": "trae",
			"name_key": "config_client_trae",
			"summary_text": _build_client_summary_text(_get_desktop_summary_key("trae", transport), transport),
			"path": _config_service.get_trae_config_path(),
			"content": _build_desktop_client_config_content(transport),
			"writeable": true
		}, client_install_statuses),
		_build_client_ui_model("codex_desktop", {
			"id": "codex_desktop",
			"name_key": "config_client_codex_desktop",
			"summary_text": _build_client_summary_text(_get_desktop_summary_key("codex_desktop", transport), transport),
			"content": "",
			"writeable": false
		}, client_install_statuses),
		_build_client_ui_model("opencode_desktop", {
			"id": "opencode_desktop",
			"name_key": "config_client_opencode_desktop",
			"summary_text": _build_client_summary_text(_get_desktop_summary_key("opencode_desktop", transport), transport),
			"content": "",
			"writeable": false
		}, client_install_statuses),
		_build_client_ui_model("gemini", {
			"id": "gemini",
			"name_key": "config_client_gemini",
			"summary_text": _build_client_summary_text(_get_desktop_summary_key("gemini", transport), transport),
			"path": _config_service.get_gemini_config_path(),
			"content": _build_gemini_client_config_content(transport),
			"writeable": true
		}, client_install_statuses)
	]


func _build_cli_client_models(central_server_process: Dictionary = {}, client_install_statuses: Dictionary = {}) -> Array[Dictionary]:
	var host = str(_state.settings.get("host", "127.0.0.1"))
	var port = int(_state.settings.get("port", 3000))
	var transport = _build_client_transport_model(central_server_process, host, port)
	return [
		_build_client_ui_model("claude_code", {
			"id": "claude_code",
			"name_key": "config_client_claude_code",
			"summary_text": _build_client_summary_text(_get_cli_summary_key("claude_code", transport), transport),
			"content": _build_claude_code_cli_content(transport),
			"launch_action_label_key": "config_client_action_open_terminal"
		}, client_install_statuses),
		_build_client_ui_model("codex", {
			"id": "codex",
			"name_key": "config_client_codex",
			"summary_text": _build_client_summary_text(_get_cli_summary_key("codex", transport), transport),
			"content": _build_codex_cli_content(transport),
			"primary_action_label_key": "config_client_action_add",
			"launch_action_label_key": "config_client_action_open_terminal"
		}, client_install_statuses),
		_build_client_ui_model("opencode", {
			"id": "opencode",
			"name_key": "config_client_opencode",
			"summary_text": _build_client_summary_text(_get_cli_summary_key("opencode", transport), transport),
			"path": _config_service.get_opencode_config_path(),
			"content": _build_opencode_cli_content(transport),
			"writeable": true,
			"launch_action_label_key": "config_client_action_open_terminal"
		}, client_install_statuses)
	]


func _build_client_transport_model(central_server_process: Dictionary, host: String, port: int) -> Dictionary:
	var launch_available = bool(central_server_process.get("client_launch_available", false))
	var executable_path = str(central_server_process.get("client_executable_path", "")).strip_edges()
	var arguments = central_server_process.get("client_arguments", [])
	var argument_list: Array = []
	if arguments is Array:
		argument_list.assign(arguments)
	elif arguments is PackedStringArray:
		argument_list.assign(Array(arguments))

	if launch_available and not executable_path.is_empty():
		return {
			"mode": "stdio",
			"command": executable_path,
			"args": argument_list,
			"mode_label_key": "config_transport_local_stdio"
		}

	return {
		"mode": "http",
		"host": host,
		"port": port,
		"mode_label_key": "config_transport_http_fallback"
	}


func _build_client_summary_text(base_key: String, transport: Dictionary) -> String:
	var base_text = _localization.get_text(base_key)
	var transport_text = _localization.get_text(str(transport.get("mode_label_key", "")))
	if transport_text.is_empty() or transport_text == str(transport.get("mode_label_key", "")):
		return base_text
	return "%s\n%s" % [base_text, transport_text]


func _build_desktop_client_config_content(transport: Dictionary) -> String:
	if str(transport.get("mode", "")) == "stdio":
		return _config_service.get_command_config(
			str(transport.get("command", "")),
			Array(transport.get("args", []))
		)
	return _config_service.get_url_config(str(transport.get("host", "127.0.0.1")), int(transport.get("port", 3000)))


func _build_gemini_client_config_content(transport: Dictionary) -> String:
	if str(transport.get("mode", "")) == "stdio":
		return _config_service.get_command_config(
			str(transport.get("command", "")),
			Array(transport.get("args", []))
		)
	return _config_service.get_http_url_config(str(transport.get("host", "127.0.0.1")), int(transport.get("port", 3000)))


func _build_claude_code_cli_content(transport: Dictionary) -> String:
	if str(transport.get("mode", "")) == "stdio":
		return _config_service.get_claude_code_stdio_command(
			_state.current_cli_scope,
			str(transport.get("command", "")),
			Array(transport.get("args", []))
		)
	return _config_service.get_claude_code_command(
		_state.current_cli_scope,
		str(transport.get("host", "127.0.0.1")),
		int(transport.get("port", 3000))
	)


func _build_codex_cli_content(transport: Dictionary) -> String:
	if str(transport.get("mode", "")) == "stdio":
		return _config_service.get_codex_stdio_command(
			str(transport.get("command", "")),
			Array(transport.get("args", []))
		)
	return _config_service.get_codex_command(
		str(transport.get("host", "127.0.0.1")),
		int(transport.get("port", 3000))
	)


func _build_opencode_cli_content(transport: Dictionary) -> String:
	if str(transport.get("mode", "")) == "stdio":
		return _config_service.get_opencode_local_config(
			str(transport.get("command", "")),
			Array(transport.get("args", []))
		)
	return _config_service.get_opencode_remote_config(
		str(transport.get("host", "127.0.0.1")),
		int(transport.get("port", 3000))
	)


func _get_cli_summary_key(client_id: String, transport: Dictionary) -> String:
	if str(transport.get("mode", "")) == "stdio":
		match client_id:
			"claude_code":
				return "config_client_claude_code_stdio_desc"
			"codex":
				return "config_client_codex_stdio_desc"
			"opencode":
				return "config_client_opencode_stdio_desc"
	return "config_client_%s_desc" % client_id


func _get_desktop_summary_key(client_id: String, transport: Dictionary) -> String:
	if str(transport.get("mode", "")) == "stdio":
		match client_id:
			"claude_desktop":
				return "config_client_claude_desktop_stdio_desc"
			"cursor":
				return "config_client_cursor_stdio_desc"
			"trae":
				return "config_client_trae_stdio_desc"
			"gemini":
				return "config_client_gemini_stdio_desc"
	return "config_client_%s_desc" % client_id


func _build_config_connection_mode(central_server_process: Dictionary) -> Dictionary:
	var transport = _build_client_transport_model(
		central_server_process,
		str(_state.settings.get("host", "127.0.0.1")),
		int(_state.settings.get("port", 3000))
	)
	var description = _localization.get_text(str(transport.get("mode_label_key", "")))
	if str(transport.get("mode", "")) == "stdio":
		var command = str(central_server_process.get("client_command", "")).strip_edges()
		return {
			"mode": "stdio",
			"label": _localization.get_text("config_mode_local_stdio_title"),
			"description": "%s\n%s" % [_localization.get_text("config_mode_local_stdio_desc"), command],
			"validate_enabled": not command.is_empty()
		}
	var endpoint = "http://%s:%d/mcp" % [str(transport.get("host", "127.0.0.1")), int(transport.get("port", 3000))]
	return {
		"mode": "http",
		"label": description,
		"description": "%s\n%s" % [_localization.get_text("config_mode_http_fallback_desc"), endpoint],
		"validate_enabled": true
	}


func _build_client_ui_model(client_id: String, client: Dictionary, client_install_statuses: Dictionary) -> Dictionary:
	var model = client.duplicate(true)
	var detection: Dictionary = client_install_statuses.get(client_id, {})
	var codex_cli_detection: Dictionary = client_install_statuses.get("codex", {})
	var opencode_cli_detection: Dictionary = client_install_statuses.get("opencode", {})
	model["path_label_text"] = _localization.get_text("config_client_write_path_label")
	if detection.is_empty():
		return model

	var status = str(detection.get("status", ""))
	if not status.is_empty():
		model["install_status_text"] = _get_client_install_status_text(status)
		model["install_message_text"] = _get_client_install_message_text(client_id, status)
	if bool(detection.get("manual_path_invalid", false)):
		model["install_message_text"] = _localization.get_text("config_client_manual_path_invalid_msg")

	var runtime_status = str(detection.get("runtime_status", {}).get("status", ""))
	if not runtime_status.is_empty():
		model["runtime_status_text"] = _get_client_runtime_status_text(runtime_status)

	var entry_status = str(detection.get("config_entry_status", {}).get("status", ""))
	if not entry_status.is_empty():
		model["entry_status_text"] = _get_client_entry_status_text(entry_status)

	var config_path = str(detection.get("config_path", "")).strip_edges()
	if not config_path.is_empty():
		model["path"] = config_path

	var executable_path = str(detection.get("executable_path", "")).strip_edges()
	var using_manual_path = bool(detection.get("using_manual_path", false))
	var has_manual_path = bool(detection.get("has_manual_path", false))
	model["path_source_text"] = _get_client_path_source_text(
		str(detection.get("detected_via", "")),
		using_manual_path,
		not executable_path.is_empty()
	)
	if not executable_path.is_empty():
		if client_id == "codex" or client_id == "claude_code" or client_id == "opencode":
			model["detail_label_text"] = _localization.get_text("config_client_cli_entry_label")
			model["explanation_text"] = _localization.get_text("config_client_cli_detected_explainer")
		else:
			model["detail_label_text"] = _localization.get_text("config_client_program_entry_label")
			model["explanation_text"] = _localization.get_text("config_client_desktop_path_explainer")
		model["detail_value"] = executable_path
	elif client_id == "codex" or client_id == "claude_code" or client_id == "opencode":
		model["detail_label_text"] = _localization.get_text("config_client_cli_path_label")
		model["detail_value"] = executable_path
		model["explanation_text"] = _localization.get_text("config_client_cli_missing_explainer")
	elif client_id == "claude_desktop" or client_id == "cursor" or client_id == "trae":
		model["explanation_text"] = _localization.get_text("config_client_desktop_write_only_explainer")
	else:
		model["explanation_text"] = _localization.get_text("config_client_pick_path_explainer")

	if using_manual_path:
		model["explanation_text"] = _localization.get_text("config_client_custom_path_explainer")

	match client_id:
		"codex_desktop":
			model["guidance_text"] = _localization.get_text(
				"config_client_codex_desktop_cli_recommendation_ready"
				if str(codex_cli_detection.get("status", "")) == "ready"
				else "config_client_codex_desktop_cli_recommendation_missing"
			)
			if str(detection.get("detected_via", "")) == "windows_store":
				var store_note = _localization.get_text("config_client_codex_desktop_store_notice")
				if not store_note.is_empty():
					model["guidance_text"] = "%s\n%s" % [model["guidance_text"], store_note]
		"opencode_desktop":
			model["guidance_text"] = _localization.get_text(
				"config_client_opencode_desktop_cli_recommendation_ready"
				if str(opencode_cli_detection.get("status", "")) == "ready"
				else "config_client_opencode_desktop_cli_recommendation_missing"
			)

	model["launch_supported"] = bool(detection.get("launch_supported", false))
	model["launch_enabled"] = bool(detection.get("launch_supported", false))
	if client_id == "cursor" or client_id == "trae":
		model["launch_action_label_key"] = "config_client_action_open_project"
	elif client_id == "claude_code" or client_id == "codex" or client_id == "opencode":
		model["launch_action_label_key"] = "config_client_action_open_terminal"

	model["path_pick_supported"] = bool(detection.get("path_pick_supported", false))
	model["path_pick_enabled"] = bool(detection.get("path_pick_supported", false))
	model["path_pick_action_label_key"] = "config_client_action_reselect_path" if has_manual_path else (
		"config_client_action_choose_cli_path" if client_id == "codex" or client_id == "claude_code" or client_id == "opencode" else "config_client_action_choose_program_path"
	)
	model["path_clear_supported"] = bool(detection.get("path_clear_supported", false))
	model["path_clear_enabled"] = bool(detection.get("path_clear_supported", false))
	if not config_path.is_empty():
		model["open_config_dir_supported"] = true
		model["open_config_dir_enabled"] = not config_path.get_base_dir().is_empty()
		model["open_config_file_supported"] = true
		model["open_config_file_enabled"] = FileAccess.file_exists(config_path)

	match client_id:
		"claude_desktop", "cursor", "trae", "opencode":
			model["writeable"] = bool(detection.get("write_supported", false))
			model["remove_supported"] = bool(detection.get("write_supported", false))
			model["remove_enabled"] = entry_status == "present"
		"codex":
			model["primary_action_enabled"] = bool(detection.get("auto_add_supported", false))
			if not bool(detection.get("auto_add_supported", false)):
				model["primary_action_disabled_reason"] = _get_client_install_message_text(client_id, status)
		"claude_code", "codex_desktop", "opencode_desktop", "opencode":
			model["writeable"] = false
	return model


func _get_client_install_statuses() -> Dictionary:
	if _client_install_detection_service == null:
		_client_install_detection_service = ClientInstallDetectionService.new()
	_configure_client_install_detection_service()
	return _client_install_detection_service.detect_all()


func _invalidate_client_install_status_cache() -> void:
	if _client_install_detection_service == null:
		return
	_client_install_detection_service.invalidate_cache()


func _configure_client_install_detection_service() -> void:
	if _client_install_detection_service == null or _state == null:
		return
	_client_install_detection_service.configure(_state.settings)


func _get_client_install_status_text(status: String) -> String:
	match status:
		"ready":
			return _localization.get_text("config_client_status_ready")
		"config_only":
			return _localization.get_text("config_client_status_config_only")
		"missing":
			return _localization.get_text("config_client_status_missing")
		_:
			return _localization.get_text("config_client_status_error")


func _get_client_runtime_status_text(status: String) -> String:
	match status:
		"running":
			return _localization.get_text("config_client_runtime_running")
		"not_running":
			return _localization.get_text("config_client_runtime_not_running")
		_:
			return _localization.get_text("config_client_runtime_unknown")


func _get_client_entry_status_text(status: String) -> String:
	match status:
		"present":
			return _localization.get_text("config_client_entry_present")
		"missing_file":
			return _localization.get_text("config_client_entry_missing_file")
		"empty":
			return _localization.get_text("config_client_entry_empty")
		"missing_server":
			return _localization.get_text("config_client_entry_missing_server")
		"invalid_json":
			return _localization.get_text("config_client_entry_invalid_json")
		"incompatible_root", "incompatible_mcp_servers":
			return _localization.get_text("config_client_entry_incompatible")
		_:
			return _localization.get_text("config_client_status_error")


func _get_client_install_message_text(client_id: String, status: String) -> String:
	var key := "config_client_%s_%s_msg" % [client_id, status]
	var localized = _localization.get_text(key)
	if localized == key:
		return ""
	return localized


func _get_client_path_source_text(detected_via: String, using_manual_path: bool, has_detected_path: bool) -> String:
	if using_manual_path:
		return _localization.get_text("config_client_path_source_manual")
	if detected_via == "windows_store":
		return _localization.get_text("config_client_path_source_store")
	if has_detected_path:
		return _localization.get_text("config_client_path_source_auto")
	if not detected_via.is_empty():
		return _localization.get_text("config_client_path_source_auto")
	return _localization.get_text("config_client_path_source_missing")


func _build_config_platform_models(desktop_clients: Array[Dictionary], cli_clients: Array[Dictionary]) -> Array[Dictionary]:
	var platforms: Array[Dictionary] = []
	for client in desktop_clients:
		platforms.append({
			"id": str(client.get("id", "")),
			"name_key": str(client.get("name_key", "")),
			"group": "desktop",
			"display_name_key": "config_platform_desktop_prefix"
		})
	for client in cli_clients:
		platforms.append({
			"id": str(client.get("id", "")),
			"name_key": str(client.get("name_key", "")),
			"group": "cli",
			"display_name_key": "config_platform_cli_prefix"
		})
	return platforms


func _resolve_current_config_platform(platforms: Array[Dictionary]) -> String:
	if platforms.is_empty():
		return ""

	for platform in platforms:
		var platform_id = str(platform.get("id", ""))
		if platform_id == _state.current_config_platform:
			return platform_id

	return str(platforms[0].get("id", ""))


func _on_current_tab_changed(index: int) -> void:
	_state.current_tab = index
	if _state.current_tab == 2:
		_invalidate_client_install_status_cache()
	_refresh_dock()


func _on_port_changed(value: int) -> void:
	_state.settings["port"] = value
	_save_settings()
	_refresh_dock()


func _on_language_changed(language_code: String) -> void:
	var focus_snapshot := {}
	if _dock and is_instance_valid(_dock) and _dock.has_method("capture_focus_snapshot"):
		focus_snapshot = _dock.capture_focus_snapshot()
	_state.settings["language"] = language_code
	_localization.set_language(language_code)
	_save_settings()
	_refresh_dock()
	if _dock and is_instance_valid(_dock) and _dock.has_method("restore_focus_snapshot"):
		_dock.restore_focus_snapshot(focus_snapshot)


func _on_start_requested() -> void:
	_server_controller.start(_state.settings, "ui_start")
	_refresh_dock()


func _on_restart_requested() -> void:
	_server_controller.start(_state.settings, "ui_restart")
	_refresh_dock()


func _on_stop_requested() -> void:
	_server_controller.stop()
	_refresh_dock()


func _on_full_reload_requested() -> void:
	var focus_snapshot := {}
	if _dock and is_instance_valid(_dock) and _dock.has_method("capture_focus_snapshot"):
		focus_snapshot = _dock.capture_focus_snapshot()
	_store_pending_focus_snapshot(focus_snapshot)
	_save_settings()
	_schedule_plugin_reenable()


func _on_log_level_changed(level: String) -> void:
	_state.settings["log_level"] = level
	MCPDebugBuffer.set_minimum_level(level)
	_save_settings()
	_refresh_dock()


func _on_permission_level_changed(level: String) -> void:
	_state.settings["permission_level"] = PluginRuntimeState.normalize_permission_level(level)
	_save_settings()
	_refresh_dock()


func _on_show_user_tools_changed(enabled: bool) -> void:
	_state.settings["show_user_tools"] = true
	_save_settings()
	_refresh_dock()


func _apply_tool_profile(profile_id: String) -> void:
	var tool_names = _tool_catalog.build_tool_name_index(_server_controller.get_all_tools_by_category())
	_state.settings["tool_profile_id"] = profile_id
	_state.settings["disabled_tools"] = _tool_catalog.get_disabled_tools_for_profile(
		profile_id,
		PluginRuntimeState.BUILTIN_TOOL_PROFILES,
		_state.custom_tool_profiles,
		tool_names,
		_state.settings.get("disabled_tools", [])
	)
	_server_controller.set_disabled_tools(_state.settings["disabled_tools"])
	_save_settings()
	_refresh_dock()


func _save_custom_profile(profile_name: String) -> Dictionary:
	if profile_name.is_empty():
		return {
			"success": false,
			"error": _localization.get_text("tool_profile_name_required")
		}

	var result = _settings_store.save_custom_profile(
		PluginRuntimeState.TOOL_PROFILE_DIR,
		profile_name,
		_state.settings.get("disabled_tools", [])
	)
	if not result.get("success", false):
		return {
			"success": false,
			"error": _localization.get_text("tool_profile_save_failed")
		}

	_state.custom_tool_profiles = _settings_store.load_custom_profiles(PluginRuntimeState.TOOL_PROFILE_DIR)
	_state.settings["tool_profile_id"] = "custom:%s" % str(result.get("slug", ""))
	_save_settings()
	return {
		"success": true,
		"profile_id": str(_state.settings.get("tool_profile_id", "")),
		"message": _localization.get_text("tool_profile_saved") % profile_name
	}


func _rename_custom_profile(profile_id: String, profile_name: String) -> Dictionary:
	if _is_builtin_profile_id(profile_id):
		return {"success": false, "error": _localization.get_text("tool_profile_builtin_protected")}

	var result = _settings_store.rename_custom_profile(
		PluginRuntimeState.TOOL_PROFILE_DIR,
		profile_id,
		profile_name
	)
	if not bool(result.get("success", false)):
		return {"success": false, "error": _get_custom_profile_error_text(str(result.get("error_code", "rename_failed")))}

	_state.custom_tool_profiles = _settings_store.load_custom_profiles(PluginRuntimeState.TOOL_PROFILE_DIR)
	if str(_state.settings.get("tool_profile_id", "")) == profile_id:
		_state.settings["tool_profile_id"] = str(result.get("profile_id", profile_id))
	_server_controller.set_disabled_tools(_state.settings.get("disabled_tools", []))
	_save_settings()
	return {
		"success": true,
		"profile_id": str(result.get("profile_id", profile_id)),
		"message": _localization.get_text("tool_profile_renamed") % str(result.get("profile_name", profile_name.strip_edges()))
	}


func _delete_custom_profile(profile_id: String) -> Dictionary:
	if _is_builtin_profile_id(profile_id):
		return {"success": false, "error": _localization.get_text("tool_profile_builtin_protected")}

	var result = _settings_store.delete_custom_profile(PluginRuntimeState.TOOL_PROFILE_DIR, profile_id)
	if not bool(result.get("success", false)):
		return {"success": false, "error": _get_custom_profile_error_text(str(result.get("error_code", "delete_failed")))}

	_state.custom_tool_profiles = _settings_store.load_custom_profiles(PluginRuntimeState.TOOL_PROFILE_DIR)
	if str(_state.settings.get("tool_profile_id", "")) == profile_id:
		var tool_names = _tool_catalog.build_tool_name_index(_server_controller.get_all_tools_by_category())
		_state.settings["tool_profile_id"] = "default"
		_state.settings["disabled_tools"] = _tool_catalog.get_disabled_tools_for_profile(
			"default",
			PluginRuntimeState.BUILTIN_TOOL_PROFILES,
			_state.custom_tool_profiles,
			tool_names,
			_state.settings.get("disabled_tools", [])
		)
	_server_controller.set_disabled_tools(_state.settings.get("disabled_tools", []))
	_save_settings()
	return {
		"success": true,
		"profile_id": "default" if str(_state.settings.get("tool_profile_id", "")) == "default" else profile_id,
		"message": _localization.get_text("tool_profile_deleted")
	}


func _is_builtin_profile_id(profile_id: String) -> bool:
	return not profile_id.begins_with("custom:")


func _get_custom_profile_error_text(error_code: String) -> String:
	match error_code:
		"empty_profile_name":
			return _localization.get_text("tool_profile_name_required")
		"profile_name_conflict":
			return _localization.get_text("tool_profile_name_conflict")
		"profile_not_found", "invalid_profile_id":
			return _localization.get_text("tool_profile_not_found")
		_:
			if error_code.begins_with("rename"):
				return _localization.get_text("tool_profile_rename_failed")
			return _localization.get_text("tool_profile_delete_failed")


func _get_tool_config_error_text(error_code: String) -> String:
	match error_code:
		"config_path_required":
			return _localization.get_text("tool_config_path_required")
		"config_not_found":
			return _localization.get_text("tool_config_not_found")
		"config_profile_required", "config_disabled_tools_invalid", "config_parse_failed":
			return _localization.get_text("tool_config_validation_failed")
		"config_dir_create_failed", "config_write_failed", "config_open_failed":
			return _localization.get_text("tool_config_write_failed")
		_:
			return _localization.get_text("tool_config_validation_failed")


func _on_delete_user_tool_requested(script_path: String) -> void:
	var result = _user_tool_service.delete_tool(script_path, true)
	if not bool(result.get("success", false)):
		_show_message(str(result.get("error", "Failed to delete user tool")))
		return
	_server_controller.reload_all_domains()
	_cleanup_disabled_tools()
	_save_settings()
	_show_message(str(result.get("message", "User tool deleted")))
	_refresh_dock()


func _on_tool_toggled(tool_name: String, enabled: bool) -> void:
	_apply_tool_enabled(tool_name, enabled)


func _on_category_toggled(category: String, enabled: bool) -> void:
	if not enabled and _is_plugin_category_restricted(category):
		for tool_name in _tool_catalog.build_tool_name_index(_server_controller.get_all_tools_by_category()):
			if str(tool_name).begins_with(category + "_"):
				_set_tool_enabled(str(tool_name), false)
		_server_controller.set_disabled_tools(_state.settings["disabled_tools"])
		_save_settings()
		_refresh_dock()
		return

	if enabled and not _can_enable_category(category):
		_show_message(get_permission_denied_message_for_category(category))
		_refresh_dock()
		return

	for tool_name in _tool_catalog.build_tool_name_index(_server_controller.get_all_tools_by_category()):
		if str(tool_name).begins_with(category + "_"):
			_set_tool_enabled(str(tool_name), enabled)
	_server_controller.set_disabled_tools(_state.settings["disabled_tools"])
	_save_settings()
	_refresh_dock()


func _on_domain_toggled(domain_key: String, enabled: bool) -> void:
	if enabled and not _can_enable_domain(domain_key):
		_show_message(get_permission_denied_message_for_domain(domain_key))
		_refresh_dock()
		return

	var target_categories: Array = []
	for domain_def in PluginRuntimeState.TOOL_DOMAIN_DEFS:
		if str(domain_def.get("key", "")) != domain_key:
			continue
		target_categories = domain_def.get("categories", []).duplicate()
		break

	if target_categories.is_empty():
		for category in _server_controller.get_all_tools_by_category().keys():
			var known_domain = _tool_catalog.find_domain_key_for_category(PluginRuntimeState.TOOL_DOMAIN_DEFS, str(category))
			if known_domain.is_empty():
				target_categories.append(str(category))

	for tool_name in _tool_catalog.build_tool_name_index(_server_controller.get_all_tools_by_category()):
		for category in target_categories:
			if _tool_catalog.tool_belongs_to_category(str(tool_name), str(category)):
				_set_tool_enabled(str(tool_name), enabled)
				break

	_server_controller.set_disabled_tools(_state.settings["disabled_tools"])
	_save_settings()
	_refresh_dock()


func _on_tree_collapse_changed(kind: String, key: String, collapsed: bool) -> void:
	TreeCollapseState.set_node_collapsed(_state.settings, kind, key, collapsed)
	_save_settings()


func _on_cli_scope_changed(scope: String) -> void:
	_state.current_cli_scope = scope
	_state.settings["current_cli_scope"] = scope
	_save_settings()
	_refresh_dock()


func _on_config_platform_changed(platform_id: String) -> void:
	_state.current_config_platform = platform_id
	_state.settings["current_config_platform"] = platform_id
	_save_settings()
	_refresh_dock()


func _on_config_validate_requested(_platform_id: String) -> void:
	if _central_server_process_service == null:
		return
	var result = _central_server_process_service.validate_client_transport(
		str(_state.settings.get("host", "127.0.0.1")),
		int(_state.settings.get("port", 3000))
	)
	if not bool(result.get("success", false)):
		_show_message("%s\n\n%s" % [
			_localization.get_text("config_validate_failed"),
			str(result.get("message", ""))
		])
		return
	var mode = str(result.get("mode", "http"))
	var success_key = "config_validate_success_stdio" if mode == "stdio" else "config_validate_success_http"
	_show_message("%s\n\n%s" % [
		_localization.get_text(success_key),
		str(result.get("message", ""))
	])


func _on_config_client_action_requested(client_id: String) -> void:
	var client_statuses = _get_client_install_statuses()
	match client_id:
		"codex":
			_apply_codex_mcp_config(client_statuses.get("codex", {}))
		_:
			pass


func _on_config_client_launch_requested(client_id: String) -> void:
	var client_statuses = _get_client_install_statuses()
	match client_id:
		"cursor":
			_launch_cursor_for_current_project(client_statuses.get("cursor", {}))
		"trae":
			_launch_desktop_agent_for_current_project(
				_localization.get_text("config_client_trae"),
				client_statuses.get("trae", {})
			)
		"claude_code":
			_launch_cli_agent_for_current_project(client_id, _localization.get_text("config_client_claude_code"), client_statuses.get("claude_code", {}))
		"codex":
			_launch_cli_agent_for_current_project(client_id, _localization.get_text("config_client_codex"), client_statuses.get("codex", {}))
		"opencode":
			_launch_cli_agent_for_current_project(client_id, _localization.get_text("config_client_opencode"), client_statuses.get("opencode", {}))
		_:
			_show_message(_localization.get_text("msg_client_launch_unsupported"))


func _on_config_client_path_pick_requested(client_id: String) -> void:
	var client_statuses = _get_client_install_statuses()
	_open_client_executable_dialog(client_id, client_statuses.get(client_id, {}))


func _on_config_client_path_clear_requested(client_id: String) -> void:
	var manual_paths = _get_client_manual_paths()
	if not manual_paths.has(client_id):
		_show_message(_localization.get_text("msg_client_manual_path_missing"))
		return
	manual_paths.erase(client_id)
	_state.settings["client_manual_paths"] = manual_paths
	_save_settings()
	_configure_client_install_detection_service()
	_invalidate_client_install_status_cache()
	_refresh_dock()
	_show_message(_localization.get_text("msg_client_path_cleared") % _get_client_display_name(client_id))


func _on_config_client_open_config_dir_requested(client_id: String) -> void:
	var client_statuses = _get_client_install_statuses()
	var detection: Dictionary = client_statuses.get(client_id, {})
	var config_path = str(detection.get("config_path", "")).strip_edges()
	if config_path.is_empty():
		_show_message(_localization.get_text("msg_client_open_config_dir_failed") % _get_client_display_name(client_id))
		return
	var dir_path = config_path.get_base_dir()
	if dir_path.is_empty():
		_show_message(_localization.get_text("msg_client_open_config_dir_failed") % _get_client_display_name(client_id))
		return
	if not DirAccess.dir_exists_absolute(dir_path):
		var dir_error = DirAccess.make_dir_recursive_absolute(dir_path)
		if dir_error != OK:
			_show_message(_localization.get_text("msg_client_open_config_dir_failed") % _get_client_display_name(client_id))
			return
	var result = _config_service.open_target_path(dir_path)
	if not bool(result.get("success", false)):
		_show_message(_localization.get_text("msg_client_open_config_dir_failed") % _get_client_display_name(client_id))
		return
	_show_message(_localization.get_text("msg_client_open_config_dir_success") % _get_client_display_name(client_id))


func _on_config_client_open_config_file_requested(client_id: String) -> void:
	var client_statuses = _get_client_install_statuses()
	var detection: Dictionary = client_statuses.get(client_id, {})
	var config_path = str(detection.get("config_path", "")).strip_edges()
	if config_path.is_empty() or not FileAccess.file_exists(config_path):
		_show_message(_localization.get_text("msg_client_open_config_file_missing") % _get_client_display_name(client_id))
		return
	var result = _config_service.open_text_file(config_path)
	if not bool(result.get("success", false)):
		_show_message(_localization.get_text("msg_client_open_config_file_failed") % _get_client_display_name(client_id))
		return
	_show_message(_localization.get_text("msg_client_open_config_file_success") % _get_client_display_name(client_id))


func _on_config_write_requested(config_type: String, filepath: String, config: String, client_name: String) -> void:
	var preflight = _config_service.preflight_write_config(config_type, filepath, config)
	if not bool(preflight.get("success", false)):
		_show_message(_build_config_write_failure_message(preflight, filepath))
		return

	if bool(preflight.get("requires_confirmation", false)):
		_show_confirmation(
			_build_config_write_confirmation_message(client_name, preflight),
			func() -> void:
				_perform_config_write(config_type, filepath, config, client_name, preflight, true)
		)
		return

	_perform_config_write(config_type, filepath, config, client_name, preflight, false)


func _perform_config_write(
	config_type: String,
	filepath: String,
	config: String,
	client_name: String,
	preflight: Dictionary,
	allow_incompatible_overwrite: bool
) -> void:
	var result = _config_service.write_config_file(
		config_type,
		filepath,
		config,
		{
			"preflight": preflight,
			"allow_incompatible_overwrite": allow_incompatible_overwrite
		}
	)
	if not bool(result.get("success", false)):
		_show_message(_build_config_write_failure_message(result, filepath))
		return

	_invalidate_client_install_status_cache()
	_refresh_dock()

	var success_lines: PackedStringArray = PackedStringArray([
		_localization.get_text("msg_config_success") % client_name,
		_localization.get_text("msg_config_verified") % str(result.get("path", filepath))
	])
	var backup_path = str(result.get("backup_path", "")).strip_edges()
	if not backup_path.is_empty():
		success_lines.append(_localization.get_text("msg_config_backup_created") % backup_path)
	success_lines.append(_localization.get_text("msg_config_effect_hint"))
	success_lines.append(_build_client_runtime_followup_message(config_type))
	_show_message("\n\n".join(success_lines))


func _on_config_remove_requested(config_type: String, filepath: String, client_name: String) -> void:
	var inspection = _config_service.inspect_config_entry(config_type, filepath)
	if not bool(inspection.get("success", false)):
		_show_message(_build_config_remove_failure_message(inspection, filepath))
		return

	var status = str(inspection.get("status", "missing_file"))
	if status != "present":
		_show_message(_build_config_remove_noop_message(inspection, client_name))
		return

	_show_confirmation(
		_build_config_remove_confirmation_message(client_name, inspection),
		func() -> void:
			_perform_config_remove(config_type, filepath, client_name, inspection)
	)


func _perform_config_remove(config_type: String, filepath: String, client_name: String, inspection: Dictionary) -> void:
	var result = _config_service.remove_config_entry(config_type, filepath, {"inspection": inspection})
	if not bool(result.get("success", false)):
		_show_message(_build_config_remove_failure_message(result, filepath))
		return

	if not bool(result.get("removed", false)):
		_show_message(_build_config_remove_noop_message(result, client_name))
		return

	_invalidate_client_install_status_cache()
	_refresh_dock()

	var success_lines: PackedStringArray = PackedStringArray([
		_localization.get_text("msg_config_remove_success") % client_name
	])
	var backup_path = str(result.get("backup_path", "")).strip_edges()
	if not backup_path.is_empty():
		success_lines.append(_localization.get_text("msg_config_backup_created") % backup_path)
	success_lines.append(_build_client_runtime_followup_message(config_type))
	_show_message("\n\n".join(success_lines))


func _build_config_write_confirmation_message(client_name: String, preflight: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray([
		_localization.get_text("msg_config_overwrite_confirm") % client_name
	])
	var filepath = str(preflight.get("path", ""))
	match str(preflight.get("status", "")):
		"invalid_json":
			lines.append(_localization.get_text("msg_config_precheck_invalid_json") % filepath)
		"incompatible_root":
			lines.append(_localization.get_text("msg_config_precheck_incompatible_root") % filepath)
		"incompatible_mcp_servers":
			lines.append(_localization.get_text("msg_config_precheck_incompatible_servers") % filepath)
		"incompatible_mcp":
			lines.append(_localization.get_text("msg_config_precheck_incompatible_mcp") % filepath)
		_:
			lines.append(_localization.get_text("msg_write_error"))

	var backup_path = str(preflight.get("backup_path", "")).strip_edges()
	if not backup_path.is_empty():
		lines.append(_localization.get_text("msg_config_backup_notice") % backup_path)
	return "\n\n".join(lines)


func _build_config_remove_confirmation_message(client_name: String, inspection: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray([
		_localization.get_text("msg_config_remove_confirm") % client_name,
		_localization.get_text("msg_config_remove_safe_scope")
	])
	var backup_path = str(inspection.get("backup_path", "")).strip_edges()
	if not backup_path.is_empty():
		lines.append(_localization.get_text("msg_config_backup_notice") % backup_path)
	return "\n\n".join(lines)


func _build_config_write_failure_message(result: Dictionary, filepath: String) -> String:
	var message := ""
	match str(result.get("error", "")):
		"parse_error":
			message = _localization.get_text("msg_parse_error")
		"dir_error":
			message = _localization.get_text("msg_dir_error") + str(result.get("path", ""))
		"precheck_read_error":
			message = _localization.get_text("msg_config_precheck_read_error") % str(result.get("path", filepath))
		"precheck_confirmation_required":
			message = _build_config_write_confirmation_message("MCP", result)
		"backup_error":
			message = _localization.get_text("msg_config_backup_failed") % str(result.get("backup_path", filepath + ".bak"))
		"readback_missing_file":
			message = "%s\n\n%s" % [
				_localization.get_text("msg_config_readback_failed"),
				_localization.get_text("msg_config_readback_missing_file") % str(result.get("path", filepath))
			]
		"readback_open_error":
			message = "%s\n\n%s" % [
				_localization.get_text("msg_config_readback_failed"),
				_localization.get_text("msg_config_readback_open_error") % str(result.get("path", filepath))
			]
		"readback_parse_error", "readback_missing_servers":
			message = "%s\n\n%s" % [
				_localization.get_text("msg_config_readback_failed"),
				_localization.get_text("msg_config_readback_parse_error") % str(result.get("path", filepath))
			]
		"readback_missing_server":
			message = "%s\n\n%s" % [
				_localization.get_text("msg_config_readback_failed"),
				_localization.get_text("msg_config_readback_missing_server") % [
					str(result.get("server_name", "godot-mcp")),
					str(result.get("path", filepath))
				]
			]
		"readback_mismatch":
			message = "%s\n\n%s" % [
				_localization.get_text("msg_config_readback_failed"),
				_localization.get_text("msg_config_readback_mismatch") % [
					str(result.get("server_name", "godot-mcp")),
					str(result.get("path", filepath))
				]
			]
		_:
			message = _localization.get_text("msg_write_error")

	if bool(result.get("rollback_restored", false)):
		message = "%s\n\n%s" % [message, _localization.get_text("msg_config_restored_backup")]
	elif str(result.get("rollback_error", "")) == "restore_failed":
		message = "%s\n\n%s" % [
			message,
			_localization.get_text("msg_config_restore_failed") % str(result.get("backup_path", filepath + ".bak"))
		]
	return message


func _build_config_remove_failure_message(result: Dictionary, filepath: String) -> String:
	var message := ""
	match str(result.get("error", "")):
		"precheck_read_error":
			message = _localization.get_text("msg_config_precheck_read_error") % str(result.get("path", filepath))
		"backup_error":
			message = _localization.get_text("msg_config_backup_failed") % str(result.get("backup_path", filepath + ".bak"))
		"remove_blocked_invalid_json":
			message = _localization.get_text("msg_config_remove_blocked_invalid_json") % str(result.get("path", filepath))
		"remove_blocked_incompatible_root", "remove_blocked_incompatible_mcp_servers", "remove_blocked_incompatible_mcp":
			message = _localization.get_text("msg_config_remove_blocked_incompatible") % str(result.get("path", filepath))
		"readback_missing_file":
			message = _localization.get_text("msg_config_remove_readback_failed") % str(result.get("path", filepath))
		"readback_open_error", "readback_parse_error", "readback_missing_servers":
			message = _localization.get_text("msg_config_remove_readback_failed") % str(result.get("path", filepath))
		"readback_remove_mismatch":
			message = _localization.get_text("msg_config_remove_readback_mismatch") % [
				str(result.get("server_name", "godot-mcp")),
				str(result.get("path", filepath))
			]
		_:
			message = _localization.get_text("msg_config_remove_failed")

	if bool(result.get("rollback_restored", false)):
		message = "%s\n\n%s" % [message, _localization.get_text("msg_config_restored_backup")]
	elif str(result.get("rollback_error", "")) == "restore_failed":
		message = "%s\n\n%s" % [
			message,
			_localization.get_text("msg_config_restore_failed") % str(result.get("backup_path", filepath + ".bak"))
		]
	return message


func _build_config_remove_noop_message(result: Dictionary, client_name: String) -> String:
	match str(result.get("status", result.get("noop_reason", ""))):
		"missing_file":
			return _localization.get_text("msg_config_remove_noop_missing_file") % client_name
		"empty", "missing_server":
			return _localization.get_text("msg_config_remove_noop_missing_entry") % client_name
		_:
			return _localization.get_text("msg_config_remove_failed")


func _build_client_runtime_followup_message(client_id: String) -> String:
	var detection = _get_client_install_statuses().get(client_id, {})
	var runtime_status = str(detection.get("runtime_status", {}).get("status", "unknown"))
	if runtime_status == "running":
		match client_id:
			"claude_desktop":
				return _localization.get_text("msg_config_restart_claude")
			"cursor":
				return _localization.get_text("msg_config_restart_cursor")
			"trae":
				return _localization.get_text("msg_config_restart_trae")
			"opencode", "opencode_desktop":
				return _localization.get_text("msg_config_restart_opencode")
			_:
				return _localization.get_text("msg_config_effect_hint")
	if runtime_status == "not_running":
		return _localization.get_text("msg_config_client_not_running")
	return _localization.get_text("msg_config_effect_hint")


func _on_copy_requested(text: String, source: String) -> void:
	DisplayServer.clipboard_set(text)
	_show_message(_localization.get_text("msg_copied") % source)


func _on_server_started() -> void:
	_refresh_dock()


func _on_server_stopped() -> void:
	_refresh_dock()


func _on_request_received(_method: String, _params: Dictionary) -> void:
	_refresh_dock()


func _apply_tool_enabled(tool_name: String, enabled: bool) -> void:
	if enabled and not _can_enable_tool(tool_name):
		_show_message(get_permission_denied_message_for_tool(tool_name))
		_refresh_dock()
		return
	_set_tool_enabled(tool_name, enabled)
	_server_controller.set_disabled_tools(_state.settings["disabled_tools"])
	_save_settings()
	_refresh_dock()


func _set_tool_enabled(tool_name: String, enabled: bool) -> void:
	var disabled_tools: Array = _state.settings.get("disabled_tools", [])
	if enabled:
		disabled_tools.erase(tool_name)
	elif not disabled_tools.has(tool_name):
		disabled_tools.append(tool_name)
	_state.settings["disabled_tools"] = disabled_tools


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


func _open_client_executable_dialog(client_id: String, detection: Dictionary) -> void:
	_ensure_client_executable_dialog()
	if _client_executable_dialog == null or not is_instance_valid(_client_executable_dialog):
		_show_message(_localization.get_text("msg_client_path_dialog_unavailable"))
		return

	var current_path = str(detection.get("executable_path", detection.get("manual_path", ""))).strip_edges()
	_pending_client_path_request = {
		"client_id": client_id
	}
	_client_executable_dialog.title = _localization.get_text("msg_client_path_dialog_title") % _get_client_display_name(client_id)
	if not current_path.is_empty():
		_client_executable_dialog.current_path = current_path
		_client_executable_dialog.current_dir = current_path.get_base_dir()
	else:
		_client_executable_dialog.current_dir = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	_client_executable_dialog.popup_centered_ratio(0.75)


func _on_client_executable_file_selected(path: String) -> void:
	var client_id = str(_pending_client_path_request.get("client_id", "")).strip_edges()
	_pending_client_path_request = {}
	if client_id.is_empty():
		return

	var normalized_path = path.replace("\\", "/").strip_edges()
	if normalized_path.is_empty() or not FileAccess.file_exists(normalized_path):
		_show_message(_localization.get_text("msg_client_path_invalid"))
		return

	var manual_paths = _get_client_manual_paths()
	manual_paths[client_id] = normalized_path
	_state.settings["client_manual_paths"] = manual_paths
	_save_settings()
	_configure_client_install_detection_service()
	_invalidate_client_install_status_cache()
	_refresh_dock()
	_show_message("%s\n\n%s" % [
		_localization.get_text("msg_client_path_saved") % _get_client_display_name(client_id),
		normalized_path
	])


func _get_client_manual_paths() -> Dictionary:
	var manual_paths = _state.settings.get("client_manual_paths", {})
	if manual_paths is Dictionary:
		return manual_paths.duplicate(true)
	return {}


func _get_client_display_name(client_id: String) -> String:
	match client_id:
		"claude_desktop":
			return _localization.get_text("config_client_claude_desktop")
		"claude_code":
			return _localization.get_text("config_client_claude_code")
		"cursor":
			return _localization.get_text("config_client_cursor")
		"trae":
			return _localization.get_text("config_client_trae")
		"codex_desktop":
			return _localization.get_text("config_client_codex_desktop")
		"codex":
			return _localization.get_text("config_client_codex")
		"opencode_desktop":
			return _localization.get_text("config_client_opencode_desktop")
		"opencode":
			return _localization.get_text("config_client_opencode")
		"gemini":
			return _localization.get_text("config_client_gemini")
		_:
			return client_id


func _apply_codex_mcp_config(detection: Dictionary) -> void:
	if detection.is_empty() or str(detection.get("status", "")) != "ready":
		_show_message(_get_client_install_message_text("codex", str(detection.get("status", "missing"))))
		return

	var executable_path = str(detection.get("executable_path", "")).strip_edges()
	if executable_path.is_empty():
		_show_message(_localization.get_text("msg_client_action_missing_executable") % _localization.get_text("config_client_codex"))
		return

	var transport = _build_client_transport_model(
		_get_central_server_process_status(),
		str(_state.settings.get("host", "127.0.0.1")),
		int(_state.settings.get("port", 3000))
	)

	var remove_result = _config_service.execute_cli_command(executable_path, PackedStringArray(["mcp", "remove", "godot-mcp"]))
	if not bool(remove_result.get("success", false)):
		var remove_message = str(remove_result.get("message", ""))
		if remove_message.find("No MCP server named 'godot-mcp' found.") == -1:
			_show_message("%s\n\n%s" % [
				_localization.get_text("msg_client_action_failed") % _localization.get_text("config_client_codex"),
				remove_message
			])
			return

	var add_result = _config_service.execute_cli_command(executable_path, _build_codex_add_arguments(transport))
	if not bool(add_result.get("success", false)):
		_show_message("%s\n\n%s" % [
			_localization.get_text("msg_client_action_failed") % _localization.get_text("config_client_codex"),
			str(add_result.get("message", ""))
		])
		return

	_invalidate_client_install_status_cache()
	_refresh_dock()
	_show_message(_localization.get_text("msg_client_action_success") % _localization.get_text("config_client_codex"))


func _launch_cursor_for_current_project(detection: Dictionary) -> void:
	_launch_desktop_agent_for_current_project(_localization.get_text("config_client_cursor"), detection)


func _launch_desktop_agent_for_current_project(client_name: String, detection: Dictionary) -> void:
	var executable_path = str(detection.get("executable_path", "")).strip_edges()
	if executable_path.is_empty():
		_show_message(_localization.get_text("msg_client_action_missing_executable") % client_name)
		return

	var project_root = _get_current_project_root()
	var result = _config_service.launch_desktop_client(
		executable_path,
		PackedStringArray([project_root]),
		project_root
	)
	if not bool(result.get("success", false)):
		_show_message("%s\n\n%s" % [
			_localization.get_text("msg_client_launch_failed") % client_name,
			str(result.get("message", ""))
		])
		return

	_invalidate_client_install_status_cache()
	_refresh_dock()
	_show_message("%s\n\n%s" % [
		_localization.get_text("msg_client_launch_success") % client_name,
		_localization.get_text("msg_client_launch_workdir") % project_root
	])


func _launch_cli_agent_for_current_project(client_id: String, client_name: String, detection: Dictionary) -> void:
	var executable_path = str(detection.get("executable_path", "")).strip_edges()
	if executable_path.is_empty():
		_show_message(_localization.get_text("msg_client_action_missing_executable") % client_name)
		return

	var project_root = _get_current_project_root()
	var arguments := PackedStringArray()
	match client_id:
		"claude_code", "codex":
			arguments = PackedStringArray()
		"opencode":
			arguments = PackedStringArray([project_root])
		_:
			_show_message(_localization.get_text("msg_client_launch_unsupported"))
			return

	var result = _config_service.launch_cli_client_in_terminal(executable_path, arguments, project_root)
	if not bool(result.get("success", false)):
		_show_message("%s\n\n%s" % [
			_localization.get_text("msg_client_launch_failed") % client_name,
			str(result.get("message", ""))
		])
		return

	_invalidate_client_install_status_cache()
	_refresh_dock()
	_show_message("%s\n\n%s" % [
		_localization.get_text("msg_client_launch_success") % client_name,
		"%s\n%s" % [
			_localization.get_text("msg_client_launch_workdir") % project_root,
			_localization.get_text("msg_client_launch_terminal_hint")
		]
	])


func _get_current_project_root() -> String:
	return ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")


func _build_codex_add_arguments(transport: Dictionary) -> PackedStringArray:
	if str(transport.get("mode", "")) == "stdio":
		var args := PackedStringArray(["mcp", "add", "godot-mcp", "--", str(transport.get("command", ""))])
		for value in transport.get("args", []):
			args.append(str(value))
		return args

	return PackedStringArray([
		"mcp",
		"add",
		"godot-mcp",
		"--url",
		"http://%s:%d/mcp" % [str(transport.get("host", "127.0.0.1")), int(transport.get("port", 3000))]
	])


func set_log_level_for_tools(level: String) -> Dictionary:
	_on_log_level_changed(level)
	return {"success": true, "log_level": str(_state.settings.get("log_level", level))}


func get_log_level_for_tools() -> String:
	return str(_state.settings.get("log_level", MCPDebugBuffer.get_minimum_level()))


func get_user_tool_summaries() -> Array[Dictionary]:
	return _user_tool_service.list_user_tools()


func create_user_tool_from_tools(args: Dictionary) -> Dictionary:
	var result = _user_tool_service.create_tool_scaffold(
		str(args.get("tool_name", "")),
		str(args.get("display_name", "")),
		str(args.get("description", "")),
		bool(args.get("authorized", false)),
		str(args.get("agent_hint", ""))
	)
	if bool(result.get("success", false)):
		_apply_user_tool_catalog_refresh(str((result.get("data", {}) as Dictionary).get("script_path", "")), "create_user_tool")
	return result


func delete_user_tool_from_tools(script_path: String, authorized: bool, agent_hint: String = "") -> Dictionary:
	var result = _user_tool_service.delete_tool(script_path, authorized, agent_hint)
	if bool(result.get("success", false)):
		_apply_user_tool_catalog_refresh(str((result.get("data", {}) as Dictionary).get("script_path", script_path)), "delete_user_tool")
	return result


func restore_user_tool_from_tools(authorized: bool, agent_hint: String = "") -> Dictionary:
	var result = _user_tool_service.restore_latest_backup(authorized, agent_hint)
	if bool(result.get("success", false)):
		_apply_user_tool_catalog_refresh(str((result.get("data", {}) as Dictionary).get("script_path", "")), "restore_user_tool")
	return result


func _schedule_user_tool_catalog_refresh() -> void:
	call_deferred("_apply_user_tool_catalog_refresh")


func _apply_user_tool_catalog_refresh(script_path: String = "", reason: String = "user_tool_catalog_refresh") -> void:
	_refresh_user_tool_registry()
	_reload_user_tool_runtime(script_path, reason)
	_rebuild_user_tool_ui_model()


func _apply_external_user_tool_catalog_refresh(changed_paths: Array[String], reason: String = "external_watch") -> void:
	_refresh_user_tool_registry()
	if changed_paths.is_empty():
		_reload_user_tool_runtime("", reason)
	else:
		for script_path in changed_paths:
			_reload_user_tool_runtime(str(script_path), reason)
	_rebuild_user_tool_ui_model()


func _refresh_user_tool_registry() -> Array[Dictionary]:
	return _user_tool_service.list_user_tools()


func _reload_user_tool_runtime(script_path: String, reason: String) -> Dictionary:
	var coordinator = _create_reload_coordinator()
	if coordinator == null:
		return {"success": false, "error": "Reload coordinator is unavailable"}
	if not script_path.is_empty():
		return coordinator.request_reload_by_script(script_path, reason)
	return coordinator.request_reload("user", reason)


func _rebuild_user_tool_ui_model() -> void:
	_cleanup_disabled_tools()
	_save_settings()
	_refresh_dock()


func get_user_tool_audit(limit: int = 20, filter_action: String = "", filter_session: String = "") -> Array[Dictionary]:
	return _user_tool_service.get_audit_entries(limit, filter_action, filter_session)


func get_user_tool_compatibility_from_tools() -> Dictionary:
	return {
		"success": true,
		"data": _user_tool_service.get_compatibility_report()
	}


func runtime_restart_server() -> Dictionary:
	var operation = PluginSelfDiagnosticStore.begin_operation("runtime_restart_server", "runtime_restart_server")
	if not _pending_runtime_reload_action.is_empty():
		_finish_self_operation(operation, false, "plugin", "runtime_restart_server", ["runtime_reload_pending"])
		return {
			"success": false,
			"error": "Runtime reload already scheduled: %s" % _pending_runtime_reload_action
		}

	_pending_runtime_reload_action = "runtime_restart_server"
	_schedule_runtime_reload("_complete_runtime_server_restart", [str(operation.get("operation_id", ""))])
	return {
		"success": true,
		"message": "Runtime server restart scheduled",
		"running": _server_controller.is_running(),
		"deferred": true
	}


func runtime_soft_reload() -> Dictionary:
	var operation = PluginSelfDiagnosticStore.begin_operation("runtime_soft_reload", "runtime_soft_reload")
	if not _pending_runtime_reload_action.is_empty():
		_finish_self_operation(operation, false, "plugin", "runtime_soft_reload", ["runtime_reload_pending"])
		return {
			"success": false,
			"error": "Runtime reload already scheduled: %s" % _pending_runtime_reload_action
		}

	var was_running = _server_controller.is_running()
	var focus_snapshot := _capture_dock_focus_snapshot()
	_pending_runtime_reload_action = "runtime_soft_reload"
	_schedule_runtime_reload("_complete_runtime_soft_reload", [str(operation.get("operation_id", "")), was_running, focus_snapshot])
	return {
		"success": true,
		"message": "Plugin soft reload scheduled",
		"running": was_running,
		"deferred": true
	}


func runtime_full_reload() -> Dictionary:
	var operation = PluginSelfDiagnosticStore.begin_operation("runtime_full_reload", "runtime_full_reload")
	var was_running := _server_controller != null and _server_controller.is_running()
	var focus_snapshot := _capture_dock_focus_snapshot()
	_schedule_runtime_reload("_complete_runtime_full_reload", [str(operation.get("operation_id", "")), was_running, focus_snapshot])
	return {"success": true, "message": "Plugin full reload scheduled"}


func _schedule_runtime_reload(method_name: String, bound_args: Array = []) -> void:
	var callback = Callable(self, method_name)
	if not bound_args.is_empty():
		callback = callback.bindv(bound_args)

	var tree := get_tree()
	if tree == null:
		callback.call_deferred()
		return

	var timer = tree.create_timer(0.05)
	timer.timeout.connect(callback, CONNECT_ONE_SHOT)


func _complete_runtime_server_restart(operation_id: String) -> void:
	var success := false
	if _state != null and _server_controller != null:
		success = _server_controller.start(_state.settings, "tool_runtime_restart")
		_refresh_dock()
	_pending_runtime_reload_action = ""
	_finish_self_operation(
		{"operation_id": operation_id},
		success,
		"plugin",
		"runtime_restart_server"
	)


func _complete_runtime_soft_reload(operation_id: String, was_running: bool, focus_snapshot: Dictionary = {}) -> void:
	var success := false
	if _state != null and _server_controller != null:
		_refresh_service_instances()
		_recreate_server_controller()
		LocalizationService.reset_instance()
		_localization = LocalizationService.get_instance()
		_localization.set_language(str(_state.settings.get("language", "")))
		MCPDebugBuffer.set_minimum_level(str(_state.settings.get("log_level", "info")))
		if was_running:
			success = _server_controller.start(_state.settings, "tool_soft_reload")
		else:
			success = _server_controller.reinitialize(_state.settings, "tool_soft_reload")
		_recreate_dock()
		_refresh_dock()
		_restore_runtime_dock_focus_snapshot(focus_snapshot)
	_pending_runtime_reload_action = ""
	_finish_self_operation(
		{"operation_id": operation_id},
		success,
		"plugin",
		"runtime_soft_reload"
	)


func _complete_runtime_full_reload(operation_id: String, was_running: bool, focus_snapshot: Dictionary = {}) -> void:
	var success := false
	if _state != null and _server_controller != null:
		_refresh_service_instances()
		_recreate_server_controller()
		LocalizationService.reset_instance()
		_localization = LocalizationService.get_instance()
		_localization.set_language(str(_state.settings.get("language", "")))
		MCPDebugBuffer.set_minimum_level(str(_state.settings.get("log_level", "info")))
		if was_running:
			success = _server_controller.start(_state.settings, "tool_full_reload")
		else:
			success = _server_controller.reinitialize(_state.settings, "tool_full_reload")
		_recreate_dock()
		_refresh_dock()
		_restore_runtime_dock_focus_snapshot(focus_snapshot)
	_pending_runtime_reload_action = ""
	_finish_self_operation(
		{"operation_id": operation_id},
		success,
		"plugin",
		"runtime_full_reload"
	)


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


func get_self_diagnostic_health_from_tools() -> Dictionary:
	return {
		"success": true,
		"data": _build_self_diagnostic_health_snapshot()
	}


func get_self_diagnostic_errors_from_tools(severity: String = "", category: String = "", limit: int = 20) -> Dictionary:
	var incidents = PluginSelfDiagnosticStore.get_incidents(severity, category, limit)
	return {
		"success": true,
		"data": {
			"count": incidents.size(),
			"incidents": incidents
		}
	}


func get_self_diagnostic_timeline_from_tools(limit: int = 20) -> Dictionary:
	var timeline = PluginSelfDiagnosticStore.get_timeline(limit)
	return {
		"success": true,
		"data": {
			"count": timeline.size(),
			"timeline": timeline
		}
	}


func clear_self_diagnostics_from_tools() -> Dictionary:
	if _get_permission_level() != PluginRuntimeState.PERMISSION_DEVELOPER:
		return {"success": false, "error": "Developer permission level is required to clear self diagnostics"}
	PluginSelfDiagnosticStore.clear()
	_refresh_dock()
	return {"success": true, "message": "Plugin self diagnostics cleared"}


func set_tool_enabled_from_tools(tool_name: String, enabled: bool) -> Dictionary:
	if enabled and not _can_enable_tool(tool_name):
		return {"success": false, "error": get_permission_denied_message_for_tool(tool_name)}
	_apply_tool_enabled(tool_name, enabled)
	return {"success": true, "tool_name": tool_name, "enabled": enabled}


func set_category_enabled_from_tools(category: String, enabled: bool) -> Dictionary:
	if enabled and not _can_enable_category(category):
		return {"success": false, "error": get_permission_denied_message_for_category(category)}
	_on_category_toggled(category, enabled)
	return {"success": true, "category": category, "enabled": enabled}


func set_domain_enabled_from_tools(domain_key: String, enabled: bool) -> Dictionary:
	if enabled and not _can_enable_domain(domain_key):
		return {"success": false, "error": get_permission_denied_message_for_domain(domain_key)}
	_on_domain_toggled(domain_key, enabled)
	return {"success": true, "domain": domain_key, "enabled": enabled}


func set_show_user_tools_from_tools(enabled: bool) -> Dictionary:
	_state.settings["show_user_tools"] = true
	_save_settings()
	_refresh_dock()
	return {"success": true, "show_user_tools": true}


func get_developer_settings_for_tools() -> Dictionary:
	return {
		"success": true,
		"data": {
			"permission_level": _get_permission_level(),
			"log_level": get_log_level_for_tools(),
			"show_user_tools": true,
			"language": str(_state.settings.get("language", "")),
			"resolved_language": _state.resolve_active_language(_localization),
			"tool_profile_id": str(_state.settings.get("tool_profile_id", "default"))
		}
	}


func set_language_from_tools(language_code: String) -> Dictionary:
	if language_code.is_empty():
		return {"success": false, "error": "Language code is required"}
	if not _localization.get_available_languages().has(language_code):
		return {"success": false, "error": "Unsupported language: %s" % language_code}
	_on_language_changed(language_code)
	return {
		"success": true,
		"language": _state.resolve_active_language(_localization)
	}


func get_languages_for_tools() -> Dictionary:
	var languages: Array[Dictionary] = []
	var active_language = _state.resolve_active_language(_localization)
	var codes: Array = _localization.get_available_language_codes()
	for code in codes:
		languages.append({
			"code": str(code),
			"name": _localization.get_language_display_name(str(code), active_language)
		})
	return {
		"success": true,
		"data": {
			"current_language": active_language,
			"languages": languages
		}
	}


func list_profiles_from_tools() -> Dictionary:
	return {
		"success": true,
		"data": {
			"builtin_profiles": PluginRuntimeState.BUILTIN_TOOL_PROFILES,
			"custom_profiles": _state.custom_tool_profiles
		}
	}


func apply_profile_from_tools(profile_id: String) -> Dictionary:
	if profile_id.is_empty():
		return {"success": false, "error": "Profile id is required"}
	if not _tool_catalog.has_tool_profile(profile_id, PluginRuntimeState.BUILTIN_TOOL_PROFILES, _state.custom_tool_profiles):
		return {"success": false, "error": "Unknown profile id: %s" % profile_id}
	_apply_tool_profile(profile_id)
	return {
		"success": true,
		"profile_id": str(_state.settings.get("tool_profile_id", profile_id))
	}


func save_profile_from_tools(profile_name: String) -> Dictionary:
	var result = _save_custom_profile(profile_name)
	if bool(result.get("success", false)):
		_refresh_dock()
	return result


func rename_profile_from_tools(profile_id: String, profile_name: String) -> Dictionary:
	var result = _rename_custom_profile(profile_id, profile_name)
	if bool(result.get("success", false)):
		_refresh_dock()
	return result


func delete_profile_from_tools(profile_id: String) -> Dictionary:
	var result = _delete_custom_profile(profile_id)
	if bool(result.get("success", false)):
		_refresh_dock()
	return result


func export_config_from_tools(file_path: String) -> Dictionary:
	var disabled_tools: Array = _state.settings.get("disabled_tools", [])
	var result = _settings_store.export_tool_config(
		file_path,
		str(_state.settings.get("tool_profile_id", "default")),
		disabled_tools
	)
	if not bool(result.get("success", false)):
		return {"success": false, "error": _get_tool_config_error_text(str(result.get("error_code", "config_write_failed")))}

	return {
		"success": true,
		"data": {
			"path": str(result.get("file_path", file_path)),
			"profile_id": str(_state.settings.get("tool_profile_id", "default")),
			"disabled_tools": disabled_tools.duplicate(),
			"disabled_tool_count": disabled_tools.size()
		},
		"message": _localization.get_text("tool_config_exported")
	}


func import_config_from_tools(file_path: String) -> Dictionary:
	var result = _settings_store.import_tool_config(file_path)
	if not bool(result.get("success", false)):
		return {"success": false, "error": _get_tool_config_error_text(str(result.get("error_code", "config_parse_failed")))}

	var imported_data: Dictionary = result.get("data", {})
	var tool_names = _tool_catalog.build_tool_name_index(_server_controller.get_all_tools_by_category())
	var valid_tools := {}
	for tool_name in tool_names:
		valid_tools[str(tool_name)] = true

	var imported_disabled: Array[String] = []
	var ignored_tools: Array[String] = []
	for tool_name in imported_data.get("disabled_tools", []):
		var normalized_tool_name = str(tool_name)
		if valid_tools.has(normalized_tool_name):
			imported_disabled.append(normalized_tool_name)
		else:
			ignored_tools.append(normalized_tool_name)
	imported_disabled.sort()
	ignored_tools.sort()

	var requested_profile_id = str(imported_data.get("profile_id", "default"))
	var resolved_profile_id = requested_profile_id
	if not _tool_catalog.has_tool_profile(resolved_profile_id, PluginRuntimeState.BUILTIN_TOOL_PROFILES, _state.custom_tool_profiles):
		resolved_profile_id = _tool_catalog.find_matching_profile_id(
			imported_disabled,
			PluginRuntimeState.BUILTIN_TOOL_PROFILES,
			_state.custom_tool_profiles,
			tool_names
		)
		if resolved_profile_id.is_empty():
			resolved_profile_id = "default"

	_state.settings["tool_profile_id"] = resolved_profile_id
	_state.settings["disabled_tools"] = imported_disabled
	_cleanup_disabled_tools()
	_save_settings()
	_refresh_dock()

	return {
		"success": true,
		"data": {
			"path": str(result.get("file_path", file_path)),
			"requested_profile_id": requested_profile_id,
			"resolved_profile_id": resolved_profile_id,
			"disabled_tools": _state.settings.get("disabled_tools", []).duplicate(),
			"disabled_tool_count": _state.settings.get("disabled_tools", []).size(),
			"ignored_tools": ignored_tools
		},
		"message": _localization.get_text("tool_config_imported")
	}


func get_runtime_usage_guide_from_tools() -> Dictionary:
	return {
		"success": true,
		"data": {
			"summary": [
				"Start with plugin_runtime_state before changing toggles or reload state.",
				"Prefer reload_domain or reload_all_domains first, then soft_reload_plugin, and keep full_reload_plugin for editor-side lifecycle resets only.",
				"Use debug_runtime_bridge to read the latest project session state and captured lifecycle events, even after the project has stopped.",
				"Use runtime toggles to disable tools freely, but enabling plugin_evolution or plugin_developer targets requires the matching permission level."
			],
			"recommended_flow": [
				{"step": 1, "name": "Inspect state", "tools": ["plugin_runtime_state"], "purpose": "Read loaded domains, reload status and the active permission mode."},
				{"step": 2, "name": "Toggle carefully", "tools": ["plugin_runtime_toggle"], "purpose": "Disable anything when isolating faults; only enable targets allowed by the current permission level."},
				{"step": 3, "name": "Reload safely", "tools": ["plugin_runtime_reload"], "purpose": "Start with domain reloads, then reload all domains, and escalate to soft/full plugin reload only when necessary."},
				{"step": 4, "name": "Read runtime bridge", "tools": ["debug_runtime_bridge"], "purpose": "Inspect the latest debugger session state and recent lifecycle events from the last editor-run project session."},
				{"step": 5, "name": "Recover transport", "tools": ["plugin_runtime_server"], "purpose": "Restart the embedded MCP server if transport state is stale but plugin state is otherwise valid."},
				{"step": 6, "name": "Verify", "tools": ["debug_log", "debug_log_buffer", "debug_performance"], "purpose": "Read recent errors and a lightweight runtime health snapshot after each change."}
			],
			"warnings": [
				"Do not disable the godot_dotnet_mcp plugin through its own MCP connection when you still need the current transport.",
				"Enabling plugin_evolution or plugin_developer targets from runtime toggles is permission-gated and cannot bypass the user-selected mode.",
				"debug_runtime_bridge is the MCP tool name; runtime state remains readable after stop, but real-time observation still requires the project to be running.",
				"Full plugin reload should be reserved for Dock wiring or plugin lifecycle recreation, not routine executor edits."
			]
		},
		"message": "Plugin runtime usage guide fetched"
	}


func get_evolution_usage_guide_from_tools() -> Dictionary:
	return {
		"success": true,
		"data": {
			"summary": [
				"Self-evolution only manages User-category tools and never writes into builtin categories.",
				"Create, delete and restore actions must pass explicit authorization; otherwise they return preview-only results.",
				"Audit entries should be checked after every authorized change.",
				"Use debug_runtime_bridge if a new User tool is expected to affect the running project and you need to inspect the latest session or lifecycle result."
			],
			"recommended_flow": [
				{"step": 1, "name": "Inspect current User tools", "tools": ["plugin_evolution_list_user_tools"], "purpose": "Read existing User tools before adding or removing scripts."},
				{"step": 2, "name": "Preview scaffold or deletion", "tools": ["plugin_evolution_scaffold_user_tool", "plugin_evolution_delete_user_tool", "plugin_evolution_restore_user_tool"], "purpose": "Run without authorization first to inspect the pending change or the latest restorable backup."},
				{"step": 3, "name": "Authorize and apply", "tools": ["plugin_evolution_scaffold_user_tool", "plugin_evolution_delete_user_tool", "plugin_evolution_restore_user_tool"], "purpose": "Repeat the action with explicit authorization only after user approval."},
				{"step": 4, "name": "Reload and verify", "tools": ["plugin_runtime_reload", "plugin_runtime_state"], "purpose": "Refresh tool domains and verify the updated User tool inventory."},
				{"step": 5, "name": "Audit", "tools": ["plugin_evolution_user_tool_audit"], "purpose": "Confirm that the authorized change has been recorded."}
			],
			"warnings": [
				"Stable mode hides and denies the entire plugin_evolution category.",
				"User tools must stay inside the User category even when generated through MCP.",
				"Deletion and restore requests should be previewed before authorization to avoid mutating the wrong script."
			]
		},
		"message": "Plugin evolution usage guide fetched"
	}


func get_usage_guide_from_tools() -> Dictionary:
	return {
		"success": true,
		"data": {
			"summary": [
				"Developer mode is the only permission level that exposes plugin_developer tools and the legacy plugin compatibility category.",
				"Use this category for Dock-facing settings such as language, preset selection, log level and permission-mode inspection.",
				"Permission level itself is user-controlled from the Dock and is intentionally not mutable through MCP.",
				"Use debug_runtime_bridge for the latest project session and lifecycle readback; it remains readable after the project stops."
			],
			"recommended_flow": [
				{"step": 1, "name": "Inspect settings", "tools": ["plugin_developer_settings", "plugin_runtime_state"], "purpose": "Read permission level, log level, language, active preset and reload status before making changes."},
				{"step": 2, "name": "Tune the session", "tools": ["plugin_developer_log_level", "plugin_developer_set_language", "plugin_developer_apply_profile"], "purpose": "Adjust Dock-facing developer settings for the current debugging session."},
				{"step": 3, "name": "Inspect project runtime result", "tools": ["debug_runtime_bridge"], "purpose": "Read the latest captured project session state and lifecycle events after each run."},
				{"step": 4, "name": "Coordinate with runtime and evolution", "tools": ["plugin_runtime_usage_guide", "plugin_evolution_usage_guide"], "purpose": "Use the sibling guide tools to choose the correct reload or self-evolution flow."},
				{"step": 5, "name": "Save reusable presets", "tools": ["plugin_developer_save_profile"], "purpose": "Persist a known-good tool selection after manual tuning."}
			],
			"permission_levels": {
				"developer": "Shows and allows plugin_runtime, plugin_evolution and plugin_developer.",
				"evolution": "Shows and allows plugin_runtime and plugin_evolution, but hides and denies plugin_developer.",
				"stable": "Shows and allows only plugin_runtime, and hides and denies plugin_evolution and plugin_developer."
			},
			"warnings": [
				"Changing permission level is intentionally restricted to the Dock so external agents cannot raise their own privileges.",
				"Evolution mode hides the developer category at both UI and execution levels.",
				"Use the exact MCP tool name debug_runtime_bridge when reading recent project runtime state.",
				"Stable mode denies both plugin_evolution and plugin_developer, including direct calls from cached wrappers."
			]
		},
		"message": "Plugin usage guide fetched"
	}


func _get_permission_level() -> String:
	return PluginRuntimeState.normalize_permission_level(str(_state.settings.get("permission_level", PluginRuntimeState.PERMISSION_EVOLUTION)))


func is_tool_category_visible_for_permission(category: String) -> bool:
	if category == "user":
		return true
	if category == "plugin":
		return _get_permission_level() == PluginRuntimeState.PERMISSION_DEVELOPER
	return is_tool_category_executable_for_permission(category)


func is_tool_category_executable_for_permission(category: String) -> bool:
	return PluginRuntimeState.permission_allows_category(_get_permission_level(), category)


func get_permission_denied_message_for_category(category: String) -> String:
	return _localization.get_text("permission_denied_category") % [_get_permission_level(), category]


func get_permission_denied_message_for_tool(tool_name: String) -> String:
	var category = PluginRuntimeState.extract_category_from_tool_name(tool_name)
	if category.is_empty():
		return _localization.get_text("permission_denied_tool") % [_get_permission_level(), tool_name]
	return get_permission_denied_message_for_category(category)


func get_permission_denied_message_for_domain(domain_key: String) -> String:
	return _localization.get_text("permission_denied_domain") % [_get_permission_level(), domain_key]


func _can_enable_tool(tool_name: String) -> bool:
	if not PluginRuntimeState.permission_allows_tool(_get_permission_level(), tool_name):
		return false
	return true


func _can_enable_category(category: String) -> bool:
	return PluginRuntimeState.permission_allows_category(_get_permission_level(), category)


func _can_enable_domain(domain_key: String) -> bool:
	return PluginRuntimeState.permission_allows_domain(_get_permission_level(), domain_key, PluginRuntimeState.TOOL_DOMAIN_DEFS)


func _is_plugin_category_restricted(category: String) -> bool:
	return PluginRuntimeState.PLUGIN_CATEGORY_PERMISSION_LEVELS.has(category)


func _get_editor_scale() -> float:
	var editor_interface = get_editor_interface()
	if editor_interface:
		return float(editor_interface.get_editor_scale())
	return 1.0


func _build_self_diagnostic_health_snapshot() -> Dictionary:
	var bridge_status = MCPRuntimeDebugStore.get_bridge_status()
	var dock_count = _count_dock_instances()
	var tool_load_errors = _server_controller.get_tool_load_errors()
	return PluginSelfDiagnosticStore.get_health_snapshot({
		"autoload": {
			"installed": bool(bridge_status.get("installed", false)),
			"autoload_name": str(bridge_status.get("autoload_name", RUNTIME_BRIDGE_AUTOLOAD_NAME)),
			"autoload_path": str(bridge_status.get("autoload_path", "")),
			"message": str(bridge_status.get("message", "")),
			"root_instance_present": _has_runtime_bridge_root_instance()
		},
		"server": {
			"running": _server_controller.is_running(),
			"connection_stats": _server_controller.get_connection_stats()
		},
		"dock": {
			"present": _dock != null and is_instance_valid(_dock),
			"dock_count": dock_count,
			"stale_dock_count": maxi(dock_count - 1, 0)
		},
		"tool_loader": {
			"tool_load_error_count": tool_load_errors.size(),
			"tool_load_errors": tool_load_errors,
			"reload_status": _server_controller.get_reload_status(),
			"performance": _server_controller.get_performance_summary()
		}
	})


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
	_central_server_attach_service.configure(self, _state.settings)
	_central_server_attach_service.start()


func _get_central_server_attach_status() -> Dictionary:
	if _central_server_attach_service == null:
		return {}
	return _localize_central_server_attach_status(_central_server_attach_service.get_status())


func _get_central_server_process_status() -> Dictionary:
	if _central_server_process_service == null:
		return {}
	return _central_server_process_service.get_status()


func _localize_central_server_attach_status(status: Dictionary) -> Dictionary:
	var localized = status.duplicate(true)
	if _localization == null:
		return localized

	var last_error = str(localized.get("last_error", "")).strip_edges()
	if not last_error.is_empty():
		return localized

	var message_key = "central_server_message_idle"
	match str(localized.get("status", "idle")):
		"disabled":
			message_key = "central_server_message_disabled"
		"configured":
			message_key = "central_server_message_configured"
		"attaching":
			message_key = "central_server_message_attaching"
		"attached":
			message_key = "central_server_message_attached"
		"heartbeat_pending":
			message_key = "central_server_message_heartbeat_pending"
		"stopped":
			message_key = "central_server_message_stopped"
	localized["message"] = _localization.get_text(message_key)
	return localized


func _resolve_central_server_process_feedback(status: Dictionary, action: String) -> String:
	if _localization == null:
		return str(status.get("message", ""))

	match action:
		"detect":
			if bool(status.get("endpoint_reachable", false)):
				return _localization.get_text("central_server_process_message_endpoint_reachable")
			if bool(status.get("local_install_ready", false)):
				return _localization.get_text("central_server_process_message_install_ready")
			if bool(status.get("install_available", false)):
				return _localization.get_text("central_server_process_message_install_available")
			return _localization.get_text("central_server_process_detect_missing")
		"install_error":
			var install_error = str(status.get("message", "")).strip_edges()
			if install_error.is_empty():
				return _localization.get_text("central_server_process_install_failed")
			return "%s\n\n%s" % [_localization.get_text("central_server_process_install_failed"), install_error]
		"install_success":
			if str(status.get("launch_source", "")) == "local_install":
				return _localization.get_text("central_server_process_install_completed")
			return _localization.get_text("central_server_process_install_completed_pending_restart")
		"start":
			if str(status.get("status", "")) == "launch_error":
				return _localization.get_text("central_server_process_start_failed")
			if bool(status.get("endpoint_reachable", false)):
				return _localization.get_text("central_server_process_message_endpoint_reachable")
			return _localization.get_text("central_server_process_starting")
		"stop_error":
			return _localization.get_text("central_server_process_stop_failed")
		"stop_success":
			return _localization.get_text("central_server_process_stopped_message")
	return str(status.get("message", ""))


func _build_central_server_install_confirmation(status: Dictionary) -> String:
	var action_key = "central_server_install_confirm_upgrade" if bool(status.get("local_install_ready", false)) else "central_server_install_confirm_install"
	var summary = _localization.get_text(action_key)
	if int(status.get("pid", 0)) > 0 and str(status.get("launch_source", "")) == "local_install":
		summary += "\n%s" % _localization.get_text("central_server_install_confirm_auto_restart")
	var details = _build_central_server_install_details(status, true)
	if details.is_empty():
		return summary
	return "%s\n\n%s" % [summary, details]


func _build_central_server_install_details(status: Dictionary, include_source_fallback: bool = false) -> String:
	if _localization == null:
		return ""

	var lines: PackedStringArray = PackedStringArray()
	var install_version = str(status.get("install_version", "")).strip_edges()
	var source_version = str(status.get("source_runtime_version", "")).strip_edges()
	var install_dir = str(status.get("local_install_dir", "")).strip_edges()
	var install_source = str(status.get("install_source_dir", "")).strip_edges()
	if install_source.is_empty() and include_source_fallback:
		install_source = str(status.get("source_runtime_dir", "")).strip_edges()

	var resolved_version = install_version if not install_version.is_empty() else source_version
	if not resolved_version.is_empty():
		lines.append("%s %s" % [_localization.get_text("central_server_install_version_label"), resolved_version])
	if not install_dir.is_empty():
		lines.append("%s %s" % [_localization.get_text("central_server_install_dir_label"), install_dir])
	if not install_source.is_empty():
		lines.append("%s %s" % [_localization.get_text("central_server_install_source_label"), install_source])
	return "\n".join(lines)


func _get_user_tool_watch_status() -> Dictionary:
	if _user_tool_watch_service == null:
		return {}
	return _user_tool_watch_service.get_status()


func _cleanup_disabled_tools() -> void:
	var valid_tools := {}
	for tool_name in _tool_catalog.build_tool_name_index(_server_controller.get_all_tools_by_category()):
		valid_tools[str(tool_name)] = true

	var filtered: Array = []
	for tool_name in _state.settings.get("disabled_tools", []):
		if valid_tools.has(str(tool_name)):
			filtered.append(str(tool_name))
	_state.settings["disabled_tools"] = filtered
	_server_controller.set_disabled_tools(filtered)


func _refresh_service_instances() -> void:
	_settings_store = SettingsStore.new()
	_tool_catalog = ToolCatalogService.new()
	_config_service = ClientConfigService.new()
	_client_install_detection_service = ClientInstallDetectionService.new()
	_user_tool_service = UserToolService.new()
	_user_tool_watch_service = UserToolWatchService.new()
	_bridge_install_service = BridgeInstallServiceScript.new()
	_central_server_attach_service = CentralServerAttachServiceScript.new()
	_central_server_process_service = CentralServerProcessServiceScript.new()
