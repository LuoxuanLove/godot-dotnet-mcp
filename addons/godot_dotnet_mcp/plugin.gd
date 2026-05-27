@tool
extends EditorPlugin

const LocalizationService = preload("res://addons/godot_dotnet_mcp/localization/localization_service.gd")
const PluginRuntimeStateScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_state.gd")
const TreeCollapseState = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tree_collapse_state.gd")
const SettingsStoreScript = preload("res://addons/godot_dotnet_mcp/plugin/config/settings_store.gd")
const ServerRuntimeControllerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/server_runtime_controller.gd")
const ToolCatalogServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_catalog_service.gd")
const PluginReloadCoordinator = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_reload_coordinator.gd")
const PluginRuntimeCoordinatorScript = preload("res://addons/godot_dotnet_mcp/plugin/plugin_runtime_coordinator.gd")
const DockModelServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/presenters/dock_model_service.gd")
const PluginActionRouterScript = preload("res://addons/godot_dotnet_mcp/plugin/plugin_action_router.gd")
const PluginDockCoordinatorScript = preload("res://addons/godot_dotnet_mcp/plugin/plugin_dock_coordinator.gd")
const ClientConfigServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_service.gd")
const ConfigTabActionServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/config/config_tab_action_service.gd")
const ClientInstallDetectionServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_install_detection_service.gd")
const UserToolServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_service.gd")
const UserToolWatchServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_watch_service.gd")
const MCPEditorDebuggerBridge = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_editor_debugger_bridge.gd")
const MCPRuntimeDebugStore = preload("res://addons/godot_dotnet_mcp/tools/shared/mcp_runtime_debug_store.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const PluginInstanceFreshness = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_instance_freshness.gd")
const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const MCP_DOCK_SCENE_PATH := "res://addons/godot_dotnet_mcp/ui/mcp_dock.tscn"
const MCP_DOCK_SCRIPT_PATH := "res://addons/godot_dotnet_mcp/ui/mcp_dock.gd"
const PLUGIN_ID := "godot_dotnet_mcp"
const PENDING_FOCUS_SNAPSHOT_KEY := "_pending_focus_snapshot"
const RUNTIME_BRIDGE_AUTOLOAD_NAME := "MCPRuntimeBridge"
const RUNTIME_BRIDGE_AUTOLOAD_PATH := "res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_bridge.gd"
const UPDATE_REFS_BRANCHES_URL := "https://api.github.com/repos/LuoxuanLove/godot-dotnet-mcp/branches?per_page=100&page=1"
const UPDATE_REFS_RELEASES_URL := "https://api.github.com/repos/LuoxuanLove/godot-dotnet-mcp/releases?per_page=100&page=1"
const UPDATE_REFS_TAGS_URL := "https://api.github.com/repos/LuoxuanLove/godot-dotnet-mcp/tags?per_page=100&page=1"
const UPDATE_COMPARE_URL_TEMPLATE := "https://api.github.com/repos/LuoxuanLove/godot-dotnet-mcp/compare/%s...%s"
const UPDATE_TARGET_PLUGIN_CFG_BRANCH_URL_TEMPLATE := "https://raw.githubusercontent.com/LuoxuanLove/godot-dotnet-mcp/refs/heads/%s/addons/godot_dotnet_mcp/plugin.cfg"
const UPDATE_TARGET_PLUGIN_CFG_TAG_URL_TEMPLATE := "https://raw.githubusercontent.com/LuoxuanLove/godot-dotnet-mcp/refs/tags/%s/addons/godot_dotnet_mcp/plugin.cfg"
const UPDATE_REFS_HTTP_TIMEOUT := 10.0
const UPDATE_REFS_BODY_SIZE_LIMIT := 16777216
const UPDATE_REFS_MAX_PAGES := 20
const UPDATE_SYNC_BRANCH_ARCHIVE_URL_PREFIX := "https://codeload.github.com/LuoxuanLove/godot-dotnet-mcp/zip/refs/heads/"
const UPDATE_SYNC_TAG_ARCHIVE_URL_PREFIX := "https://codeload.github.com/LuoxuanLove/godot-dotnet-mcp/zip/refs/tags/"
const UPDATE_SYNC_ARCHIVE_PATH := "user://godot_dotnet_mcp/update_branch.zip"
const UPDATE_SYNC_MARKER_PATH := "res://addons/godot_dotnet_mcp/.mcp_sync.json"
const UPDATE_SYNC_REPO_URL := "https://github.com/LuoxuanLove/godot-dotnet-mcp"
const UPDATE_SYNC_HTTP_TIMEOUT := 60.0
const UPDATE_SYNC_BODY_SIZE_LIMIT := 67108864
const UPDATE_SYNC_ADDON_ROOT := "res://addons/godot_dotnet_mcp"
const UPDATE_SYNC_ADDON_PREFIX := "addons/godot_dotnet_mcp/"

var _state = null
var _settings_store = null
var _server_controller = null
var _tool_catalog = null
var _config_service = null
var _config_tab_action_service = null
var _dock_model_service = null
var _runtime_coordinator := PluginRuntimeCoordinatorScript.new()
var _client_install_detection_service = null
var _user_tool_service = null
var _user_tool_watch_service = null
var _action_router := PluginActionRouterScript.new()
var _dock_coordinator := PluginDockCoordinatorScript.new()
var _localization: LocalizationService
var _dock: Control
var _client_executable_dialog: FileDialog
var _pending_client_path_request := {}
var _status_poll_accumulator := 0.0
var _editor_debugger_bridge: EditorDebuggerPlugin
var _pending_runtime_reload_action := ""
var _plugin_reenable_pending := false
var _dock_recreate_pending := false
var _dock_recreate_attempted := false
var _update_refs_request_serial := 0
var _update_refs_pending := {}
var _update_refs_discovery_loaded := false
var _update_refs_discovery_retry_pending := false
var _update_compare_request_serial := 0
var _update_ref_version_request_serial := 0
var _update_ref_version_requests_in_flight := {}
var _update_sync_request_serial := 0


func _init() -> void:
	_ensure_runtime_state()


func _enter_tree() -> void:
	PluginSelfDiagnosticStore.clear()
	var operation = PluginSelfDiagnosticStore.begin_operation("plugin_enter_tree", "_enter_tree")
	PluginInstanceFreshness.capture_running_instance("plugin_enter_tree")
	_refresh_service_instances()
	_load_state()
	LocalizationService.reset_instance()
	_localization = LocalizationService.get_instance()
	_localization.set_language(str(_state.settings.get("language", "")))
	MCPDebugBuffer.set_minimum_level(str(_state.settings.get("log_level", "info")))
	_state.settings["log_level"] = MCPDebugBuffer.get_minimum_level()

	if _action_router == null:
		_action_router = PluginActionRouterScript.new()
	_action_router.configure(self, RUNTIME_BRIDGE_AUTOLOAD_NAME, RUNTIME_BRIDGE_AUTOLOAD_PATH)
	if _dock_coordinator == null:
		_dock_coordinator = PluginDockCoordinatorScript.new()

	_attach_server_controller()
	_configure_user_tool_watch_service()
	_configure_config_tab_action_service()
	_ensure_runtime_bridge_autoload()
	_install_editor_debugger_bridge()

	_create_dock()
	_apply_initial_tool_profile_if_needed()
	_refresh_dock()
	set_process(true)

	if bool(_state.settings.get("auto_start", true)):
		_server_controller.start(_state.settings, "auto_start")
		_refresh_dock()

	_restore_pending_focus_snapshot_if_needed()
	call_deferred("_ensure_saved_update_source_discovery_requested")
	_finish_self_operation(operation, true, "plugin", "_enter_tree")

	MCPDebugBuffer.record("info", "plugin", "Plugin initialized")


func _exit_tree() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("plugin_exit_tree", "_exit_tree")
	set_process(false)
	_save_settings()
	if _user_tool_watch_service != null:
		_user_tool_watch_service.stop()
	_remove_dock()
	_remove_client_executable_dialog()
	_uninstall_editor_debugger_bridge()
	_remove_runtime_bridge_autoload()
	if _action_router != null:
		_action_router.dispose()
		_action_router = null
	_dock_coordinator = null
	_dispose_server_controller()
	LocalizationService.reset_instance()
	_localization = null
	_user_tool_service = null
	_user_tool_watch_service = null
	_config_service = null
	if _config_tab_action_service != null:
		_config_tab_action_service.dispose()
		_config_tab_action_service = null
	if _dock_model_service != null:
		_dock_model_service.dispose()
	_dock_model_service = null
	_runtime_coordinator = null
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


func _process(delta: float) -> void:
	if _user_tool_watch_service != null:
		_user_tool_watch_service.tick()
	if _update_refs_discovery_retry_pending and _ensure_update_refs_discovery_requested():
		return
	_status_poll_accumulator += delta
	if _status_poll_accumulator >= 0.5:
		_status_poll_accumulator = 0.0
		_refresh_dock()


func get_server() -> Node:
	if _server_controller == null:
		return null
	return _server_controller.get_server()


func start_server() -> void:
	_on_start_requested()


func stop_server() -> void:
	_on_stop_requested()


func _attach_server_controller() -> void:
	if _action_router == null:
		_action_router = PluginActionRouterScript.new()
	_action_router.configure(self, RUNTIME_BRIDGE_AUTOLOAD_NAME, RUNTIME_BRIDGE_AUTOLOAD_PATH)
	if _runtime_coordinator == null:
		_runtime_coordinator = PluginRuntimeCoordinatorScript.new()
	_server_controller = _runtime_coordinator.attach_server_controller(
		_server_controller,
		self,
		_state.settings,
		_action_router,
		Callable(self, "_create_server_controller")
	)


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


func _create_server_controller() -> ServerRuntimeController:
	return ServerRuntimeControllerScript.new()


func _create_editor_debugger_bridge():
	return MCPEditorDebuggerBridge.new()


func _dispose_server_controller() -> void:
	if _server_controller == null:
		return
	if _runtime_coordinator == null:
		_runtime_coordinator = PluginRuntimeCoordinatorScript.new()
	_server_controller = _runtime_coordinator.dispose_server_controller(_server_controller, _action_router)


func _recreate_server_controller() -> void:
	if _action_router == null:
		_action_router = PluginActionRouterScript.new()
	_action_router.configure(self, RUNTIME_BRIDGE_AUTOLOAD_NAME, RUNTIME_BRIDGE_AUTOLOAD_PATH)
	if _runtime_coordinator == null:
		_runtime_coordinator = PluginRuntimeCoordinatorScript.new()
	_server_controller = _runtime_coordinator.recreate_server_controller(
		_server_controller,
		self,
		_state.settings,
		_action_router,
		Callable(self, "_create_server_controller")
	)
	_configure_user_tool_watch_service()


func _load_state() -> void:
	_ensure_runtime_state()
	if _settings_store == null:
		_settings_store = SettingsStoreScript.new()
	var load_result = _settings_store.load_plugin_settings(
		PluginRuntimeStateScript.DEFAULT_SETTINGS,
		PluginRuntimeStateScript.SETTINGS_PATH,
		PluginRuntimeStateScript.ALL_TOOL_CATEGORIES,
		PluginRuntimeStateScript.DEFAULT_COLLAPSED_DOMAINS
	)
	_state.settings = load_result["settings"]
	if not (_state.settings.get("client_manual_paths", {}) is Dictionary):
		_state.settings["client_manual_paths"] = {}
	_state.current_cli_scope = str(_state.settings.get("current_cli_scope", _state.current_cli_scope))
	_state.current_config_platform = str(_state.settings.get("current_config_platform", _state.current_config_platform))
	_state.needs_initial_tool_profile_apply = not bool(load_result["has_settings_file"])
	_state.custom_tool_profiles = _settings_store.load_custom_profiles(PluginRuntimeStateScript.TOOL_PROFILE_DIR)
	_configure_client_install_detection_service()


func _save_settings() -> void:
	if _state == null:
		return
	if _settings_store == null:
		_settings_store = SettingsStoreScript.new()
	_settings_store.save_plugin_settings(PluginRuntimeStateScript.SETTINGS_PATH, _state.settings)


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
	if _runtime_coordinator == null:
		_runtime_coordinator = PluginRuntimeCoordinatorScript.new()
	_runtime_coordinator.ensure_runtime_bridge_autoload(self, RUNTIME_BRIDGE_AUTOLOAD_NAME, RUNTIME_BRIDGE_AUTOLOAD_PATH)
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
	if _runtime_coordinator == null:
		_runtime_coordinator = PluginRuntimeCoordinatorScript.new()
	var removed = _runtime_coordinator.remove_runtime_bridge_autoload(self, RUNTIME_BRIDGE_AUTOLOAD_NAME, RUNTIME_BRIDGE_AUTOLOAD_PATH)
	if not removed:
		_finish_self_operation(operation, false, "plugin", "_remove_runtime_bridge_autoload")
		return
	_record_runtime_bridge_stale_instance("_remove_runtime_bridge_autoload", str(operation.get("operation_id", "")))
	_finish_self_operation(operation, true, "plugin", "_remove_runtime_bridge_autoload")
	MCPDebugBuffer.record("info", "plugin", "Runtime bridge autoload removed")


func _is_runtime_bridge_autoload_path(setting_value: String) -> bool:
	var normalized := setting_value.trim_prefix("*")
	if normalized == RUNTIME_BRIDGE_AUTOLOAD_PATH:
		return true
	if normalized.begins_with("uid://"):
		return _is_runtime_bridge_uid_path(normalized)
	if normalized.is_empty() or not ResourceLoader.exists(normalized):
		return false
	var resource := ResourceLoader.load(normalized)
	return resource != null and str(resource.resource_path) == RUNTIME_BRIDGE_AUTOLOAD_PATH


func _is_runtime_bridge_uid_path(uid_path: String) -> bool:
	var uid := ResourceUID.text_to_id(uid_path)
	if not ResourceUID.has_id(uid):
		return false
	return str(ResourceUID.get_id_path(uid)) == RUNTIME_BRIDGE_AUTOLOAD_PATH


func _clear_runtime_bridge_root_instance() -> void:
	if not is_inside_tree():
		return
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
	if _runtime_coordinator == null:
		_runtime_coordinator = PluginRuntimeCoordinatorScript.new()
	_editor_debugger_bridge = _runtime_coordinator.install_editor_debugger_bridge(self, _editor_debugger_bridge, Callable(self, "_create_editor_debugger_bridge"))
	if _editor_debugger_bridge == null:
		_record_self_incident("error", "lifecycle_error", "editor_debugger_bridge_create_failed", "Failed to instantiate the editor debugger bridge", "plugin", "_install_editor_debugger_bridge", "", "", str(operation.get("operation_id", "")), true, "Inspect the editor debugger bridge script and plugin lifecycle output.")
		_finish_self_operation(operation, false, "plugin", "_install_editor_debugger_bridge")
		return
	_finish_self_operation(operation, true, "plugin", "_install_editor_debugger_bridge")


func _uninstall_editor_debugger_bridge() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("uninstall_editor_debugger_bridge", "_uninstall_editor_debugger_bridge")
	if _editor_debugger_bridge == null:
		_finish_self_operation(operation, true, "plugin", "_uninstall_editor_debugger_bridge")
		return
	if _runtime_coordinator == null:
		_runtime_coordinator = PluginRuntimeCoordinatorScript.new()
	_editor_debugger_bridge = _runtime_coordinator.uninstall_editor_debugger_bridge(self, _editor_debugger_bridge)
	_finish_self_operation(operation, true, "plugin", "_uninstall_editor_debugger_bridge")


func _create_dock() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("create_dock", "_create_dock")
	if _dock_coordinator == null:
		_dock_coordinator = PluginDockCoordinatorScript.new()
	var cleanup_result = _dock_coordinator.remove_stale_plugin_docks(self, _dock, Callable(self, "_record_self_incident"), MCP_DOCK_SCRIPT_PATH)
	if not bool(cleanup_result.get("success", false)):
		_finish_self_operation(operation, false, "plugin", "_create_dock")
		return
	var result = _dock_coordinator.create_plugin_dock(
		self,
		_dock,
		Callable(self, "_record_self_incident"),
		DOCK_SLOT_RIGHT_UL,
		MCP_DOCK_SCENE_PATH,
		MCP_DOCK_SCRIPT_PATH,
		Callable(self, "_load_packed_scene")
	)
	if not bool(result.get("success", false)):
		var error_text = str(result.get("error", "Failed to create dock"))
		push_error("[Godot MCP] %s" % error_text)
		MCPDebugBuffer.record("error", "plugin", error_text)
		_record_self_incident("error", "resource_missing", "dock_scene_load_failed", error_text, "plugin", "_create_dock", MCP_DOCK_SCRIPT_PATH, "", str(operation.get("operation_id", "")), true, "Inspect the dock scene resource and its script.")
		_finish_self_operation(operation, false, "plugin", "_create_dock")
		return
	_dock = result.get("dock", null)
	_dock_recreate_pending = false
	if _dock != null and is_instance_valid(_dock) and _dock.has_method("apply_model"):
		_dock_recreate_attempted = false
	else:
		_record_self_incident("error", "ui_binding_error", "dock_controller_missing", "Dock scene was instantiated without an apply_model() controller", "plugin", "_create_dock", MCP_DOCK_SCRIPT_PATH, "", str(operation.get("operation_id", "")), true, "Inspect the dock scene script for parser or runtime initialization errors.")
	_wire_dock_signals(str(operation.get("operation_id", "")))
	var dock_count = _count_dock_instances()
	if dock_count > 1:
		_record_self_incident("warning", "reload_conflict", "dock_duplicate_instance", "More than one MCP dock instance is present after dock creation", "plugin", "_create_dock", MCP_DOCK_SCRIPT_PATH, "", str(operation.get("operation_id", "")), true, "Inspect stale dock cleanup and plugin reload ordering.", {"dock_count": dock_count})
	_finish_self_operation(operation, true, "plugin", "_create_dock")

func _remove_dock() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("remove_dock", "_remove_dock")
	_dock_recreate_pending = false
	if _dock_coordinator == null:
		_dock_coordinator = PluginDockCoordinatorScript.new()
	var result = _dock_coordinator.remove_plugin_dock(self, _dock, MCP_DOCK_SCRIPT_PATH)
	_dock = result.get("dock", null)
	if _count_dock_instances() > 0:
		_record_self_incident("warning", "reload_conflict", "instance_cleanup_incomplete", "Dock instances remain after dock removal", "plugin", "_remove_dock", MCP_DOCK_SCRIPT_PATH, "", str(operation.get("operation_id", "")), true, "Inspect dock cleanup and plugin reload ordering.", {"remaining_dock_instances": _count_dock_instances()})
	_finish_self_operation(operation, true, "plugin", "_remove_dock")


func _configure_client_executable_dialog() -> void:
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


func _get_client_executable_dialog():
	return _client_executable_dialog


func _on_clear_self_diagnostics_requested() -> void:
	var result = clear_self_diagnostics_from_tools()
	if bool(result.get("success", false)):
		_show_message(_localization.get_text("self_diag_cleared"))
		return
	_show_message(str(result.get("error", _localization.get_text("self_diag_clear_failed"))))


func _remove_stale_docks() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("remove_stale_docks", "_remove_stale_docks")
	if _dock_coordinator == null:
		_dock_coordinator = PluginDockCoordinatorScript.new()
	var result = _dock_coordinator.remove_stale_plugin_docks(self, _dock, Callable(self, "_record_self_incident"), MCP_DOCK_SCRIPT_PATH)
	if not bool(result.get("success", false)):
		_finish_self_operation(operation, false, "plugin", "_remove_stale_docks")
		return
	var remaining_count = _count_dock_instances()
	if remaining_count > 1:
		_record_self_incident("warning", "reload_conflict", "dock_duplicate_instance", "More than one MCP dock instance remains after stale-dock cleanup", "plugin", "_remove_stale_docks", MCP_DOCK_SCRIPT_PATH, "", str(operation.get("operation_id", "")), true, "Inspect stale dock cleanup and editor plugin reload ordering.", {"dock_count": remaining_count})
	_finish_self_operation(operation, true, "plugin", "_remove_stale_docks")


func _wire_dock_signals(operation_id: String = "") -> bool:
	if _dock == null or not is_instance_valid(_dock):
		_record_self_incident("error", "ui_binding_error", "dock_signal_binding_failed", "Dock signal wiring was requested before the dock instance was ready", "plugin", "_wire_dock_signals", MCP_DOCK_SCRIPT_PATH, "", operation_id, true, "Inspect dock creation order.")
		return false
	if _dock_coordinator == null:
		_dock_coordinator = PluginDockCoordinatorScript.new()
	if _action_router == null:
		_action_router = PluginActionRouterScript.new()
	_action_router.configure(self, RUNTIME_BRIDGE_AUTOLOAD_NAME, RUNTIME_BRIDGE_AUTOLOAD_PATH)
	var bindings = _dock_coordinator.build_dock_signal_bindings(_action_router)
	return _dock_coordinator.wire_dock_signals(_dock, bindings, operation_id, Callable(self, "_record_self_incident"), MCP_DOCK_SCRIPT_PATH)


func _refresh_dock() -> void:
	if _dock == null or not is_instance_valid(_dock):
		return
	if not _dock.has_method("apply_model"):
		if _dock_recreate_pending or _dock_recreate_attempted:
			return
		_dock_recreate_pending = true
		_dock_recreate_attempted = true
		call_deferred("_recreate_dock")
		return
	if _update_refs_discovery_retry_pending and _ensure_update_refs_discovery_requested():
		return
	_sync_current_tab_from_dock()
	if _ensure_saved_update_source_discovery_requested():
		return
	if _state != null and _state.current_tab == 3 and _ensure_update_refs_discovery_requested():
		return
	if _dock_model_service == null:
		_dock_model_service = DockModelServiceScript.new()
	_dock_model_service.configure(
		_state,
		_localization,
		_server_controller,
		_tool_catalog,
		_config_service,
		null,
		_user_tool_service,
		_client_install_detection_service,
		_user_tool_watch_service,
		Callable(self, "_get_editor_scale")
	)
	_dock.call("apply_model", _dock_model_service.build_model())


func _apply_initial_tool_profile_if_needed() -> void:
	if not _state.needs_initial_tool_profile_apply:
		return

	var tool_names = _tool_catalog.build_tool_name_index(_server_controller.get_all_tools_by_category())
	if tool_names.is_empty():
		return

	_state.settings["disabled_tools"] = _tool_catalog.get_disabled_tools_for_profile(
		str(_state.settings.get("tool_profile_id", "default")),
		PluginRuntimeStateScript.BUILTIN_TOOL_PROFILES,
		_state.custom_tool_profiles,
		tool_names,
		_state.settings.get("disabled_tools", [])
	)
	_state.needs_initial_tool_profile_apply = false
	_server_controller.set_disabled_tools(_state.settings["disabled_tools"])
	_save_settings()


func _get_client_install_statuses() -> Dictionary:
	if _client_install_detection_service == null:
		_client_install_detection_service = ClientInstallDetectionServiceScript.new()
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


func _on_current_tab_changed(index: int) -> void:
	_state.current_tab = index
	if _state.current_tab == 2:
		_invalidate_client_install_status_cache()
	if _state.current_tab == 3 and _ensure_update_refs_discovery_requested():
		return
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


func _on_update_source_changed(source: String) -> void:
	_ensure_runtime_state()
	_state.settings["update_source"] = _normalize_update_source(source)
	if _state.settings["update_source"] == "custom_branch":
		_state.settings["update_custom_branch"] = "dev"
	_save_settings()
	if _ensure_update_refs_discovery_requested(true):
		return
	_refresh_update_compare_for_current_target()
	_refresh_dock()


func _normalize_update_source(source: String) -> String:
	var normalized := source.strip_edges()
	match normalized:
		"latest_dev", "branch":
			return "custom_branch"
		"release_tag":
			return "latest_release"
		"custom_branch", "latest_stable", "latest_release":
			return normalized
		_:
			return "latest_stable"


func _ensure_update_refs_discovery_requested(force_refresh: bool = false) -> bool:
	if _state == null:
		return false
	if str(_state.update_refs_state) == "loading" or str(_state.update_sync_state) == "loading":
		return false
	if not force_refresh and str(_state.update_refs_state) == "success" and _update_refs_discovery_loaded:
		_update_refs_discovery_retry_pending = false
		return false
	if _get_update_request_parent() == null:
		_update_refs_discovery_retry_pending = true
		return false
	_update_refs_discovery_retry_pending = false
	_on_update_check_requested()
	return true


func _ensure_saved_update_source_discovery_requested() -> bool:
	if _state == null:
		return false
	var source := _normalize_update_source(str(_state.settings.get("update_source", "latest_stable")))
	if not ["custom_branch", "latest_stable", "latest_release"].has(source):
		_update_refs_discovery_retry_pending = false
		return false
	if str(_state.update_refs_state) == "loading" or str(_state.update_sync_state) == "loading":
		return false
	if str(_state.update_refs_state) == "success" and _update_refs_discovery_loaded:
		_update_refs_discovery_retry_pending = false
		return false
	if _get_update_request_parent() == null:
		_update_refs_discovery_retry_pending = true
		return false
	return _ensure_update_refs_discovery_requested()


func _get_update_request_parent() -> Node:
	if is_inside_tree():
		return self
	if _dock != null and is_instance_valid(_dock) and _dock.is_inside_tree():
		return _dock
	return null


func _on_update_custom_branch_changed(branch: String) -> void:
	_ensure_runtime_state()
	_state.settings["update_custom_branch"] = branch
	_save_settings()
	if _ensure_update_refs_discovery_requested(true):
		return
	_refresh_update_compare_for_current_target()
	_refresh_dock()



func _on_update_check_requested() -> void:
	_update_refs_request_serial += 1
	_update_refs_discovery_loaded = false
	var serial := _update_refs_request_serial
	_update_refs_pending = {
		"serial": serial,
		"branch_done": false,
		"release_done": false,
		"tag_done": false,
		"errors": [],
		"branches": [],
		"releases": [],
		"stable_releases": [],
		"tags": [],
		"commits": {},
		"branches_pages": 1,
		"releases_pages": 1,
		"tags_pages": 1
	}
	_state.update_refs_state = "loading"
	_state.update_refs_status = _localization.get_text("settings_update_refs_loading") if _localization != null else "Loading update refs."
	_state.update_refs_error = ""
	var empty_branches: Array[String] = []
	var empty_releases: Array[String] = []
	_state.update_ref_branches = empty_branches
	_state.update_ref_releases = empty_releases
	_state.update_ref_latest_stable_release = ""
	_state.update_ref_latest_release = ""
	_state.update_refs_release_source = ""
	_state.update_ref_commits = {}
	_state.update_ref_versions = {}
	_update_ref_version_requests_in_flight.clear()
	_reset_update_compare_state()
	_refresh_dock()
	_start_update_refs_request("branches", UPDATE_REFS_BRANCHES_URL, serial)
	_start_update_refs_request("releases", UPDATE_REFS_RELEASES_URL, serial)
	_start_update_refs_request("tags", UPDATE_REFS_TAGS_URL, serial)


func _on_update_sync_requested() -> void:
	if str(_state.update_sync_state) == "loading":
		_refresh_dock()
		return
	var target := _resolve_update_sync_target()
	var target_ref := str(target.get("ref", "")).strip_edges()
	if target_ref.is_empty():
		_state.update_sync_state = "error"
		_state.update_sync_error = _localization.get_text("settings_update_sync_no_target") if _localization != null else "Select an update target before syncing."
		_state.update_sync_status = ""
		_refresh_dock()
		return
	_update_sync_request_serial += 1
	var serial := _update_sync_request_serial
	_state.update_sync_state = "loading"
	_state.update_sync_target_ref = target_ref
	_state.update_sync_target_kind = str(target.get("kind", "branch"))
	_state.update_sync_error = ""
	_state.update_sync_status = (_localization.get_text("settings_update_sync_loading") % target_ref) if _localization != null else "Syncing %s..." % target_ref
	_refresh_dock()
	_start_update_archive_sync_request(target, serial)


func _resolve_update_sync_target() -> Dictionary:
	var source := _normalize_update_source(str(_state.settings.get("update_source", "latest_stable")))
	var target_ref := ""
	var target_kind := "branch"
	match source:
		"custom_branch":
			var branch_ref := str(_state.settings.get("update_custom_branch", "")).strip_edges()
			target_ref = branch_ref if not branch_ref.is_empty() else "dev"
		"latest_stable":
			target_ref = str(_state.update_ref_latest_stable_release).strip_edges()
			target_kind = "tag"
		"latest_release":
			var selected_release_tag := str(_state.settings.get("update_release_tag", "")).strip_edges()
			target_ref = selected_release_tag if not selected_release_tag.is_empty() else str(_state.update_ref_latest_release).strip_edges()
			target_kind = "tag"
		_:
			target_ref = str(_state.update_ref_latest_stable_release).strip_edges()
			target_kind = "tag"
	return {
		"kind": target_kind,
		"ref": target_ref,
		"commit": _resolve_update_ref_commit(target_ref)
	}


func _resolve_update_ref_commit(target_ref: String) -> String:
	if _state == null:
		return ""
	var commits: Dictionary = _state.update_ref_commits
	return str(commits.get(target_ref, "")).strip_edges()


func _start_update_refs_request(kind: String, url: String, serial: int) -> void:
	if _state == null or serial != _update_refs_request_serial:
		return
	var request_parent := _get_update_request_parent()
	if request_parent == null:
		_mark_update_refs_request_failed(kind, "No active update refs request host.", serial)
		return
	var request_node := HTTPRequest.new()
	request_node.name = "UpdateRefs%sRequest" % kind.capitalize()
	request_node.timeout = UPDATE_REFS_HTTP_TIMEOUT
	request_node.body_size_limit = UPDATE_REFS_BODY_SIZE_LIMIT
	request_parent.add_child(request_node)
	request_node.request_completed.connect(Callable(self, "_on_update_refs_request_completed").bind(kind, serial, request_node), CONNECT_ONE_SHOT)
	var error := request_node.request(url, _get_update_refs_headers())
	if error != OK:
		request_node.queue_free()
		_mark_update_refs_request_failed(kind, "Failed to start %s request: %s" % [kind, error], serial)


func _start_update_archive_sync_request(target: Dictionary, serial: int) -> void:
	var request_parent := _get_update_request_parent()
	if request_parent == null:
		_mark_update_sync_failed("No active update sync request host.", serial)
		return
	var sync_dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://godot_dotnet_mcp"))
	if sync_dir_error != OK:
		_mark_update_sync_failed("Failed to create update cache: %s" % sync_dir_error, serial)
		return
	var target_kind := str(target.get("kind", "branch"))
	var target_ref := str(target.get("ref", "")).strip_edges()
	var archive_prefix := UPDATE_SYNC_TAG_ARCHIVE_URL_PREFIX if target_kind == "tag" else UPDATE_SYNC_BRANCH_ARCHIVE_URL_PREFIX
	var request_node := HTTPRequest.new()
	request_node.name = "UpdateArchiveSyncRequest"
	request_node.timeout = UPDATE_SYNC_HTTP_TIMEOUT
	request_node.body_size_limit = UPDATE_SYNC_BODY_SIZE_LIMIT
	request_node.download_file = UPDATE_SYNC_ARCHIVE_PATH
	request_parent.add_child(request_node)
	request_node.request_completed.connect(Callable(self, "_on_update_archive_sync_request_completed").bind(target, serial, request_node), CONNECT_ONE_SHOT)
	var error := request_node.request("%s%s" % [archive_prefix, target_ref], _get_update_archive_headers())
	if error != OK:
		request_node.queue_free()
		_mark_update_sync_failed("Failed to start update sync request: %s" % error, serial)


func _get_update_archive_headers() -> PackedStringArray:
	return PackedStringArray([
		"Accept: application/zip",
		"User-Agent: Godot-Dotnet-MCP-Settings-Update-Sync"
	])


func _get_update_refs_headers() -> PackedStringArray:
	return PackedStringArray([
		"Accept: application/vnd.github+json",
		"User-Agent: Godot-Dotnet-MCP-Settings-Update-Checker"
	])


func _start_update_ref_version_request(target_ref: String, target_kind: String = "branch") -> void:
	if _state == null:
		return
	var normalized_ref := target_ref.strip_edges()
	if normalized_ref.is_empty():
		return
	if (_state.update_ref_versions as Dictionary).has(normalized_ref) or _update_ref_version_requests_in_flight.has(normalized_ref):
		return
	_update_ref_version_request_serial += 1
	var serial := _update_ref_version_request_serial
	var request_parent := _get_update_request_parent()
	if request_parent == null:
		return
	_update_ref_version_requests_in_flight[normalized_ref] = true
	var request_node := HTTPRequest.new()
	request_node.name = "UpdateRefVersionRequest"
	request_node.timeout = UPDATE_REFS_HTTP_TIMEOUT
	request_node.body_size_limit = 65536
	request_parent.add_child(request_node)
	request_node.request_completed.connect(Callable(self, "_on_update_ref_version_request_completed").bind(normalized_ref, serial, request_node), CONNECT_ONE_SHOT)
	var url_template := UPDATE_TARGET_PLUGIN_CFG_TAG_URL_TEMPLATE if target_kind == "tag" else UPDATE_TARGET_PLUGIN_CFG_BRANCH_URL_TEMPLATE
	var url := url_template % normalized_ref.uri_encode().replace("%2F", "/")
	var error := request_node.request(url, _get_update_refs_headers())
	if error != OK:
		_update_ref_version_requests_in_flight.erase(normalized_ref)
		request_node.queue_free()


func _on_update_ref_version_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, target_ref: String, serial: int, request_node: HTTPRequest) -> void:
	if request_node != null and is_instance_valid(request_node):
		request_node.queue_free()
	_update_ref_version_requests_in_flight.erase(target_ref)
	if _state == null or serial != _update_ref_version_request_serial:
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var version := _parse_update_target_plugin_cfg_version(body.get_string_from_utf8())
	if version.is_empty():
		return
	_state.update_ref_versions[target_ref] = version
	_refresh_dock()


func _parse_update_target_plugin_cfg_version(content: String) -> String:
	for line in content.split("\n"):
		var normalized := str(line).strip_edges()
		if not normalized.begins_with("version"):
			continue
		var separator := normalized.find("=")
		if separator == -1:
			continue
		var value := normalized.substr(separator + 1).strip_edges()
		if value.length() >= 2 and ((value.begins_with("\"") and value.ends_with("\"")) or (value.begins_with("'") and value.ends_with("'"))):
			value = value.substr(1, value.length() - 2)
		return value.strip_edges()
	return ""


func _on_update_refs_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, kind: String, serial: int, request_node: HTTPRequest) -> void:
	if request_node != null and is_instance_valid(request_node):
		request_node.queue_free()
	if _state == null or serial != _update_refs_request_serial:
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_handle_update_refs_http_failure(kind, result, response_code, serial)
		return
	var parse_result := _parse_update_refs_json_array(body)
	if not bool(parse_result.get("success", false)):
		_handle_update_refs_parse_failure(kind, str(parse_result.get("error", "Invalid JSON response")), serial)
		return
	var items: Array = parse_result.get("items", [])
	match kind:
		"branches":
			_append_update_refs_pending_names("branches", _extract_update_ref_names(items, "name"))
			_append_update_refs_pending_commits(items, "name")
			if _request_next_update_refs_page_if_available(kind, headers, serial):
				return
			_state.update_ref_branches = _to_string_array(_update_refs_pending.get("branches", []))
			_state.update_ref_commits = _duplicate_update_ref_commits(_update_refs_pending.get("commits", {}))
			_update_refs_pending["branch_done"] = true
		"releases":
			_append_update_refs_pending_names("releases", _extract_update_ref_names(items, "tag_name"))
			_append_update_refs_pending_names("stable_releases", _extract_update_stable_release_names(items))
			_append_update_refs_pending_commits(items, "tag_name")
			if _request_next_update_refs_page_if_available(kind, headers, serial):
				return
			_update_refs_pending["release_done"] = true
		"tags":
			_append_update_refs_pending_names("tags", _extract_update_ref_names(items, "name"))
			_append_update_refs_pending_commits(items, "name")
			if _request_next_update_refs_page_if_available(kind, headers, serial):
				return
			_update_refs_pending["tag_done"] = true
	_finalize_update_refs_discovery_if_ready(serial)


func _request_next_update_refs_page_if_available(kind: String, headers: PackedStringArray, serial: int) -> bool:
	var next_url := _extract_update_refs_next_url(headers)
	if next_url.is_empty():
		return false
	var page_key := "%s_pages" % kind
	var page_count := int(_update_refs_pending.get(page_key, 1))
	if page_count >= UPDATE_REFS_MAX_PAGES:
		return false
	_update_refs_pending[page_key] = page_count + 1
	_start_update_refs_request(kind, next_url, serial)
	return true


func _extract_update_refs_next_url(headers: PackedStringArray) -> String:
	for header in headers:
		var header_text := str(header)
		if not header_text.to_lower().begins_with("link:"):
			continue
		var link_value := header_text.substr(header_text.find(":") + 1).strip_edges()
		for segment in link_value.split(","):
			if segment.find('rel="next"') == -1:
				continue
			var start := segment.find("<")
			var end := segment.find(">")
			if start >= 0 and end > start:
				return segment.substr(start + 1, end - start - 1)
	return ""


func _append_update_refs_pending_names(key: String, names: Array[String]) -> void:
	var values: Array[String] = _to_string_array(_update_refs_pending.get(key, []))
	for name in names:
		_append_unique_update_ref(values, name)
	_update_refs_pending[key] = values


func _append_update_refs_pending_commits(items: Array, name_key: String) -> void:
	var commits: Dictionary = _update_refs_pending.get("commits", {})
	for item in items:
		if not (item is Dictionary):
			continue
		var item_dict := item as Dictionary
		var name := str(item_dict.get(name_key, "")).strip_edges()
		var commit := _extract_update_ref_commit(item_dict)
		if not name.is_empty() and not commit.is_empty():
			commits[name] = commit
	_update_refs_pending["commits"] = commits


func _extract_update_ref_commit(item: Dictionary) -> String:
	var commit_value = item.get("commit", "")
	if commit_value is Dictionary:
		return str((commit_value as Dictionary).get("sha", "")).strip_edges()
	return str(item.get("target_commitish", "")).strip_edges()


func _to_string_array(values) -> Array[String]:
	var result: Array[String] = []
	if not (values is Array):
		return result
	for value in values:
		_append_unique_update_ref(result, str(value))
	return result


func _handle_update_refs_http_failure(kind: String, result: int, response_code: int, serial: int) -> void:
	_mark_update_refs_request_failed(kind, "%s request failed with result %s and HTTP %s" % [kind.capitalize(), result, response_code], serial)


func _handle_update_refs_parse_failure(kind: String, error: String, serial: int) -> void:
	_mark_update_refs_request_failed(kind, "%s response parse failed: %s" % [kind.capitalize(), error], serial)


func _mark_update_refs_request_failed(kind: String, message: String, serial: int) -> void:
	if _state == null or serial != _update_refs_request_serial:
		return
	var errors: Array = _update_refs_pending.get("errors", [])
	errors.append(message)
	_update_refs_pending["errors"] = errors
	if kind == "branches":
		_update_refs_pending["branch_done"] = true
	elif kind == "tags":
		_update_refs_pending["tag_done"] = true
	else:
		_update_refs_pending["release_done"] = true
	_finalize_update_refs_discovery_if_ready(serial)


func _mark_update_sync_failed(message: String, serial: int) -> void:
	if _state == null or serial != _update_sync_request_serial:
		return
	_state.update_sync_state = "error"
	_state.update_sync_error = message
	_state.update_sync_status = ""
	_refresh_dock()


func _on_update_archive_sync_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray, target: Dictionary, serial: int, request_node: HTTPRequest) -> void:
	if request_node != null and is_instance_valid(request_node):
		request_node.queue_free()
	if _state == null or serial != _update_sync_request_serial:
		return
	var target_ref := str(target.get("ref", ""))
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_mark_update_sync_failed("Update archive request failed with result %s and HTTP %s" % [result, response_code], serial)
		return
	var sync_result := _sync_update_archive_to_addon(UPDATE_SYNC_ARCHIVE_PATH)
	if not bool(sync_result.get("success", false)):
		_mark_update_sync_failed(str(sync_result.get("error", "Update sync failed.")), serial)
		return
	var marker_error := _write_update_sync_marker(target, int(sync_result.get("written", 0)))
	if marker_error != OK:
		_mark_update_sync_failed("Update files were written, but sync marker write failed: %s" % marker_error, serial)
		return
	_state.update_sync_state = "success"
	_state.update_sync_error = ""
	_state.update_sync_status = (_localization.get_text("settings_update_sync_success") % [target_ref, int(sync_result.get("written", 0))]) if _localization != null else "Synced %s." % target_ref
	_refresh_update_compare_for_current_target()
	_refresh_dock()
	_request_update_sync_lifecycle_reload()


func _request_update_sync_lifecycle_reload() -> void:
	if _plugin_reenable_pending:
		return
	_request_plugin_lifecycle_reload("settings_sync")


func _write_update_sync_marker(target: Dictionary, written: int) -> int:
	var marker := {
		"last_sync_at_unix": int(Time.get_unix_time_from_system()),
		"source_repo_path": "https://github.com/LuoxuanLove/godot-dotnet-mcp",
		"target_addon_path": UPDATE_SYNC_ADDON_ROOT,
		"source_git_commit": str(target.get("commit", "")),
		"source_ref_kind": str(target.get("kind", "")),
		"source_ref": str(target.get("ref", "")),
		"written_files": written
	}
	var file := FileAccess.open(UPDATE_SYNC_MARKER_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(marker, "	"))
	file.close()
	return OK


func _sync_update_archive_to_addon(archive_path: String) -> Dictionary:
	var reader := ZIPReader.new()
	var open_error := reader.open(archive_path)
	if open_error != OK:
		return {"success": false, "error": "Failed to open branch archive: %s" % open_error}
	var files := reader.get_files()
	var archive_prefix := _find_update_archive_addon_prefix(files)
	if archive_prefix.is_empty():
		reader.close()
		return {"success": false, "error": "Branch archive does not contain addons/godot_dotnet_mcp."}
	var written := 0
	for file_path in files:
		if file_path.ends_with("/") or not file_path.begins_with(archive_prefix):
			continue
		var relative_path := file_path.substr(archive_prefix.length()).replace("\\", "/")
		if _should_skip_update_sync_path(relative_path):
			continue
		var target_path := UPDATE_SYNC_ADDON_ROOT.path_join(relative_path).simplify_path()
		var addon_root := "%s/" % UPDATE_SYNC_ADDON_ROOT
		if target_path != UPDATE_SYNC_ADDON_ROOT and not target_path.begins_with(addon_root):
			reader.close()
			return {"success": false, "error": "Update archive entry escapes the plugin directory: %s" % relative_path}
		var target_dir := target_path.get_base_dir()
		var dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_dir))
		if dir_error != OK:
			reader.close()
			return {"success": false, "error": "Failed to create directory %s: %s" % [target_dir, dir_error]}
		var output := FileAccess.open(target_path, FileAccess.WRITE)
		if output == null:
			reader.close()
			return {"success": false, "error": "Failed to write %s: %s" % [target_path, FileAccess.get_open_error()]}
		output.store_buffer(reader.read_file(file_path))
		output.close()
		written += 1
	reader.close()
	if written == 0:
		return {"success": false, "error": "Branch archive contained no plugin files to sync."}
	return {"success": true, "written": written}


func _find_update_archive_addon_prefix(files: PackedStringArray) -> String:
	for file_path in files:
		var normalized := str(file_path).replace("\\", "/")
		var prefix_index := normalized.find(UPDATE_SYNC_ADDON_PREFIX)
		if prefix_index >= 0:
			return normalized.substr(0, prefix_index + UPDATE_SYNC_ADDON_PREFIX.length())
	return ""


func _should_skip_update_sync_path(relative_path: String) -> bool:
	var normalized := relative_path.strip_edges().replace("\\", "/")
	if normalized.is_empty() or normalized.begins_with("/") or normalized.begins_with("../") or normalized.ends_with("/..") or normalized.find("/../") != -1 or normalized.find(":") != -1:
		return true
	if normalized == ".git" or normalized.begins_with(".git/"):
		return true
	if normalized == "custom_tools" or normalized.begins_with("custom_tools/"):
		return true
	if normalized == "dotnet_bridge/bin" or normalized.begins_with("dotnet_bridge/bin/"):
		return true
	if normalized == "dotnet_bridge/obj" or normalized.begins_with("dotnet_bridge/obj/"):
		return true
	if normalized.ends_with(".import"):
		return true
	return false


func _finalize_update_refs_discovery_if_ready(serial: int) -> void:
	if _state == null or serial != _update_refs_request_serial:
		return
	if not bool(_update_refs_pending.get("branch_done", false)) or not bool(_update_refs_pending.get("release_done", false)) or not bool(_update_refs_pending.get("tag_done", false)):
		_refresh_dock()
		return
	var errors: Array = _update_refs_pending.get("errors", [])
	_state.update_ref_commits = _duplicate_update_ref_commits(_update_refs_pending.get("commits", {}))
	var releases := _to_string_array(_update_refs_pending.get("releases", []))
	var stable_releases := _to_string_array(_update_refs_pending.get("stable_releases", []))
	var release_or_tag_values: Array[String] = []
	for release in releases:
		_append_unique_update_ref(release_or_tag_values, release)
	for tag in _to_string_array(_update_refs_pending.get("tags", [])):
		_append_unique_update_ref(release_or_tag_values, tag)
	_state.update_ref_releases = release_or_tag_values
	_state.update_ref_latest_release = releases[0] if not releases.is_empty() else ""
	_state.update_ref_latest_stable_release = stable_releases[0] if not stable_releases.is_empty() else ""
	_state.update_refs_release_source = "releases_and_tags"
	if errors.is_empty() or not _state.update_ref_branches.is_empty() or not release_or_tag_values.is_empty():
		_state.update_refs_state = "success"
		_state.update_refs_error = ""
		_state.update_refs_status = _localization.get_text("settings_update_refs_success") if _localization != null else "Update refs loaded."
		_update_refs_discovery_loaded = true
		_refresh_update_compare_for_current_target()
	else:
		_state.update_refs_state = "error"
		_state.update_refs_error = "; ".join(errors)
		_state.update_refs_status = ""
		_reset_update_compare_state()
	_refresh_dock()


func _refresh_update_compare_for_current_target() -> void:
	if _state == null or str(_state.update_refs_state) != "success":
		return
	var target := _resolve_update_sync_target()
	var base_commit := _resolve_current_update_commit()
	var target_ref := str(target.get("ref", "")).strip_edges()
	var target_commit := str(target.get("commit", "")).strip_edges()
	var compare_head := _resolve_update_compare_head(target)
	_state.update_compare_base_commit = base_commit
	_state.update_compare_target_ref = target_ref
	_state.update_compare_target_commit = target_commit
	_state.update_compare_ahead_by = -1
	_state.update_compare_behind_by = -1
	_state.update_compare_error = ""
	if not (_state.update_ref_versions as Dictionary).has(target_ref):
		_start_update_ref_version_request(target_ref, str(target.get("kind", "branch")))
	if base_commit.is_empty() or compare_head.is_empty():
		_state.update_compare_state = "unavailable"
		return
	if not target_commit.is_empty() and base_commit == target_commit:
		_state.update_compare_state = "success"
		_state.update_compare_ahead_by = 0
		_state.update_compare_behind_by = 0
		return
	_start_update_compare_request(base_commit, compare_head, target_commit)


func _resolve_update_compare_head(target: Dictionary) -> String:
	var target_ref := str(target.get("ref", "")).strip_edges()
	var target_commit := str(target.get("commit", "")).strip_edges()
	if str(target.get("kind", "branch")) == "tag" and not target_ref.is_empty():
		return target_ref
	if not target_commit.is_empty():
		return target_commit
	return target_ref


func _resolve_current_update_commit() -> String:
	var freshness := PluginInstanceFreshness.get_freshness_snapshot()
	if freshness is Dictionary:
		var sync_snapshot = (freshness as Dictionary).get("sync", {})
		if sync_snapshot is Dictionary:
			return str((sync_snapshot as Dictionary).get("source_git_commit", "")).strip_edges()
	return ""


func _reset_update_compare_state() -> void:
	if _state == null:
		return
	_update_compare_request_serial += 1
	_state.update_compare_state = "idle"
	_state.update_compare_error = ""
	_state.update_compare_base_commit = ""
	_state.update_compare_target_ref = ""
	_state.update_compare_target_commit = ""
	_state.update_compare_ahead_by = -1
	_state.update_compare_behind_by = -1


func _start_update_compare_request(base_commit: String, compare_head: String, target_commit: String = "") -> void:
	_update_compare_request_serial += 1
	var serial := _update_compare_request_serial
	_state.update_compare_state = "loading"
	var request_parent := _get_update_request_parent()
	if request_parent == null:
		_mark_update_compare_failed("No active update compare request host.", serial)
		return
	var request_node := HTTPRequest.new()
	request_node.name = "UpdateCompareRequest"
	request_node.timeout = UPDATE_REFS_HTTP_TIMEOUT
	request_node.body_size_limit = UPDATE_REFS_BODY_SIZE_LIMIT
	request_parent.add_child(request_node)
	request_node.request_completed.connect(Callable(self, "_on_update_compare_request_completed").bind(base_commit, target_commit, serial, request_node), CONNECT_ONE_SHOT)
	var compare_url := UPDATE_COMPARE_URL_TEMPLATE % [base_commit.uri_encode(), compare_head.uri_encode()]
	var error := request_node.request(compare_url, _get_update_refs_headers())
	if error != OK:
		request_node.queue_free()
		_mark_update_compare_failed("Failed to start update compare request: %s" % error, serial)


func _on_update_compare_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, base_commit: String, target_commit: String, serial: int, request_node: HTTPRequest) -> void:
	if request_node != null and is_instance_valid(request_node):
		request_node.queue_free()
	if _state == null or serial != _update_compare_request_serial:
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_mark_update_compare_failed("Update compare request failed with result %s and HTTP %s" % [result, response_code], serial)
		return
	var parse_result := _parse_update_compare_json(body)
	if not bool(parse_result.get("success", false)):
		_mark_update_compare_failed(str(parse_result.get("error", "Invalid JSON response")), serial)
		return
	_state.update_compare_state = "success"
	_state.update_compare_error = ""
	_state.update_compare_base_commit = base_commit
	_state.update_compare_target_commit = target_commit
	_state.update_compare_ahead_by = int(parse_result.get("ahead_by", -1))
	_state.update_compare_behind_by = int(parse_result.get("behind_by", -1))
	_refresh_dock()


func _mark_update_compare_failed(message: String, serial: int) -> void:
	if _state == null or serial != _update_compare_request_serial:
		return
	_state.update_compare_state = "error"
	_state.update_compare_error = message
	_state.update_compare_ahead_by = -1
	_state.update_compare_behind_by = -1
	_refresh_dock()


func _parse_update_compare_json(body: PackedByteArray) -> Dictionary:
	var json := JSON.new()
	var parse_error := json.parse(body.get_string_from_utf8())
	if parse_error != OK:
		return {"success": false, "error": json.get_error_message()}
	if not (json.data is Dictionary):
		return {"success": false, "error": "Expected a JSON object"}
	var data := json.data as Dictionary
	return {
		"success": true,
		"ahead_by": int(data.get("ahead_by", -1)),
		"behind_by": int(data.get("behind_by", -1))
	}


func _parse_update_refs_json_array(body: PackedByteArray) -> Dictionary:
	var json := JSON.new()
	var parse_error := json.parse(body.get_string_from_utf8())
	if parse_error != OK:
		return {"success": false, "error": json.get_error_message()}
	if not (json.data is Array):
		return {"success": false, "error": "Expected a JSON array"}
	return {"success": true, "items": json.data}


func _extract_update_ref_names(items: Array, key: String) -> Array[String]:
	var names: Array[String] = []
	for item in items:
		if not (item is Dictionary):
			continue
		_append_unique_update_ref(names, str((item as Dictionary).get(key, "")))
	return names


func _extract_update_stable_release_names(items: Array) -> Array[String]:
	var names: Array[String] = []
	for item in items:
		if not (item is Dictionary):
			continue
		var item_dict := item as Dictionary
		if bool(item_dict.get("prerelease", false)):
			continue
		_append_unique_update_ref(names, str(item_dict.get("tag_name", "")))
	return names


func _duplicate_update_ref_commits(raw_commits) -> Dictionary:
	var commits: Dictionary = {}
	if not (raw_commits is Dictionary):
		return commits
	for key in (raw_commits as Dictionary).keys():
		commits[str(key)] = str((raw_commits as Dictionary).get(key, ""))
	return commits


func _append_unique_update_ref(values: Array[String], value: String) -> void:
	var normalized := value.strip_edges()
	if normalized.is_empty() or values.has(normalized):
		return
	values.append(normalized)


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
	_request_plugin_lifecycle_reload("ui")


func request_plugin_lifecycle_reload_from_tools() -> Dictionary:
	return _request_plugin_lifecycle_reload("tool")


func get_plugin_update_current_from_tools() -> Dictionary:
	return {
		"success": true,
		"data": _build_plugin_update_current_snapshot(),
		"message": "Plugin update current fetched"
	}


func get_plugin_update_status_from_tools() -> Dictionary:
	return {
		"success": true,
		"data": _build_plugin_update_status_snapshot(),
		"message": "Plugin update status fetched"
	}


func set_plugin_update_source_from_tools(source: String, custom_branch: String = "", release_tag: String = "") -> Dictionary:
	var normalized := _normalize_update_source(source)
	_on_update_source_changed(normalized)
	if normalized == "custom_branch" and not custom_branch.strip_edges().is_empty():
		_on_update_custom_branch_changed(custom_branch)
	if normalized == "latest_release":
		_state.settings["update_release_tag"] = release_tag.strip_edges()
		_save_settings()
		_refresh_update_compare_for_current_target()
		_refresh_dock()
	var data := _build_plugin_update_status_snapshot()
	data["accepted"] = false
	data["action_status"] = "selected"
	return {
		"success": true,
		"accepted": false,
		"loading": str(_state.update_refs_state) == "loading",
		"status": "selected",
		"data": data,
		"message": "Plugin update source selected"
	}


func discover_plugin_update_refs_from_tools(force_refresh: bool = true) -> Dictionary:
	var accepted := _ensure_update_refs_discovery_requested(force_refresh)
	var action_status := _resolve_plugin_update_request_status("refs", accepted)
	var data := _build_plugin_update_status_snapshot()
	data["accepted"] = accepted
	data["action_status"] = action_status
	return {
		"success": true,
		"accepted": accepted,
		"loading": str(_state.update_refs_state) == "loading",
		"status": action_status,
		"data": data,
		"message": "Plugin update ref discovery requested"
	}


func start_plugin_update_sync_from_tools() -> Dictionary:
	if str(_state.update_sync_state) == "loading":
		var loading_data := _build_plugin_update_status_snapshot()
		loading_data["accepted"] = false
		loading_data["action_status"] = "loading"
		return {
			"success": true,
			"accepted": false,
			"loading": true,
			"status": "loading",
			"data": loading_data,
			"message": "Plugin update sync is already running"
		}
	var target := _resolve_update_sync_target()
	var target_ref := str(target.get("ref", "")).strip_edges()
	if target_ref.is_empty():
		_on_update_sync_requested()
		var missing_target_data := _build_plugin_update_status_snapshot()
		missing_target_data["accepted"] = false
		missing_target_data["action_status"] = str(_state.update_sync_state)
		return {
			"success": true,
			"accepted": false,
			"loading": false,
			"status": str(_state.update_sync_state),
			"data": missing_target_data,
			"message": "Plugin update sync target is unavailable"
		}
	if _get_update_request_parent() == null:
		var unavailable_data := _build_plugin_update_status_snapshot()
		unavailable_data["accepted"] = false
		unavailable_data["action_status"] = "unavailable"
		return {
			"success": true,
			"accepted": false,
			"loading": false,
			"status": "unavailable",
			"data": unavailable_data,
			"message": "Plugin update sync request host is unavailable"
		}
	_on_update_sync_requested()
	var data := _build_plugin_update_status_snapshot()
	data["accepted"] = str(_state.update_sync_state) == "loading"
	data["action_status"] = _resolve_plugin_update_request_status("sync", bool(data.get("accepted", false)))
	return {
		"success": true,
		"accepted": bool(data.get("accepted", false)),
		"loading": str(_state.update_sync_state) == "loading",
		"status": str(data.get("action_status", "")),
		"data": data,
		"message": "Plugin update sync requested"
	}


func _build_plugin_update_current_snapshot() -> Dictionary:
	var freshness := PluginInstanceFreshness.get_freshness_snapshot()
	var running_instance: Dictionary = freshness.get("running_instance", {})
	var disk_source: Dictionary = freshness.get("disk_source", {})
	var sync_snapshot: Dictionary = freshness.get("sync", {})
	var source_snapshot := disk_source if not disk_source.is_empty() else running_instance
	var source_fingerprint := str(source_snapshot.get("source_fingerprint", running_instance.get("source_fingerprint", "")))
	var short_fingerprint := _shorten_plugin_update_fingerprint(source_fingerprint)
	return {
		"status": str(freshness.get("status", "unknown")),
		"needs_lifecycle_reload": bool(freshness.get("needs_lifecycle_reload", false)),
		"source_version": str(source_snapshot.get("source_version", running_instance.get("source_version", ""))),
		"server_version": str(source_snapshot.get("server_version", running_instance.get("server_version", ""))),
		"protocol_version": str(source_snapshot.get("protocol_version", running_instance.get("protocol_version", ""))),
		"tool_schema_version": str(source_snapshot.get("tool_schema_version", running_instance.get("tool_schema_version", ""))),
		"source_fingerprint": source_fingerprint,
		"source_fingerprint_short": short_fingerprint,
		"short_source_fingerprint": short_fingerprint,
		"source_git_commit": str(sync_snapshot.get("source_git_commit", "")),
		"source_ref_kind": str(sync_snapshot.get("source_ref_kind", "")),
		"source_ref": str(sync_snapshot.get("source_ref", "")),
		"written_files": int(sync_snapshot.get("written_files", 0)),
		"running_instance": running_instance,
		"disk_source": disk_source,
		"sync": sync_snapshot,
		"lifecycle_reload": freshness.get("lifecycle_reload", {}),
		"comparison": freshness.get("comparison", {})
	}


func _build_plugin_update_status_snapshot() -> Dictionary:
	var target := _resolve_update_sync_target()
	var source := _normalize_update_source(str(_state.settings.get("update_source", "latest_stable")))
	return {
		"status": _resolve_plugin_update_overall_status(),
		"current": _build_plugin_update_current_snapshot(),
		"source": source,
		"custom_branch": str(_state.settings.get("update_custom_branch", "")),
		"release_tag": str(_state.settings.get("update_release_tag", "")),
		"target": target,
		"current_commit": _resolve_current_update_commit(),
		"request_host_available": _get_update_request_parent() != null,
		"discovery_retry_pending": _update_refs_discovery_retry_pending,
		"refs": _build_plugin_update_refs_status(),
		"compare": _build_plugin_update_compare_status(),
		"sync": _build_plugin_update_sync_status(),
		"lifecycle_reload": PluginInstanceFreshness.get_freshness_snapshot().get("lifecycle_reload", {})
	}


func _build_plugin_update_refs_status() -> Dictionary:
	return {
		"state": str(_state.update_refs_state),
		"status": str(_state.update_refs_status),
		"error": str(_state.update_refs_error),
		"branches": _state.update_ref_branches.duplicate(),
		"releases": _state.update_ref_releases.duplicate(),
		"latest_stable_release": str(_state.update_ref_latest_stable_release),
		"latest_release": str(_state.update_ref_latest_release),
		"release_source": str(_state.update_refs_release_source),
		"commits": _state.update_ref_commits.duplicate(true),
		"versions": _state.update_ref_versions.duplicate(true)
	}


func _build_plugin_update_compare_status() -> Dictionary:
	return {
		"state": str(_state.update_compare_state),
		"error": str(_state.update_compare_error),
		"base_commit": str(_state.update_compare_base_commit),
		"target_ref": str(_state.update_compare_target_ref),
		"target_commit": str(_state.update_compare_target_commit),
		"ahead_by": int(_state.update_compare_ahead_by),
		"behind_by": int(_state.update_compare_behind_by)
	}


func _build_plugin_update_sync_status() -> Dictionary:
	return {
		"state": str(_state.update_sync_state),
		"status": str(_state.update_sync_status),
		"error": str(_state.update_sync_error),
		"target_ref": str(_state.update_sync_target_ref),
		"target_kind": str(_state.update_sync_target_kind)
	}


func _resolve_plugin_update_overall_status() -> String:
	if str(_state.update_sync_state) == "loading":
		return "syncing"
	if str(_state.update_refs_state) == "loading" or str(_state.update_compare_state) == "loading":
		return "loading"
	if str(_state.update_sync_state) == "error" or str(_state.update_refs_state) == "error" or str(_state.update_compare_state) == "error":
		return "error"
	if _update_refs_discovery_retry_pending:
		return "pending"
	return "ready"


func _resolve_plugin_update_request_status(kind: String, accepted: bool) -> String:
	if accepted:
		return "accepted"
	if _get_update_request_parent() == null and (kind == "refs" or kind == "sync"):
		return "pending" if _update_refs_discovery_retry_pending else "unavailable"
	if kind == "sync":
		return str(_state.update_sync_state)
	return str(_state.update_refs_state)


func _shorten_plugin_update_fingerprint(source_fingerprint: String) -> String:
	var normalized := source_fingerprint.strip_edges()
	if normalized.length() <= 16:
		return normalized
	return normalized.substr(0, 16)


func _request_plugin_lifecycle_reload(source: String = "unknown") -> Dictionary:
	if _plugin_reenable_pending:
		return {
			"success": false,
			"error": "Plugin lifecycle reload already scheduled",
			"data": {"freshness": PluginInstanceFreshness.get_freshness_snapshot()}
		}
	var focus_snapshot := {}
	if _dock and is_instance_valid(_dock) and _dock.has_method("capture_focus_snapshot"):
		focus_snapshot = _dock.capture_focus_snapshot()
	_store_pending_focus_snapshot(focus_snapshot)
	_save_settings()
	var lifecycle_reload: Dictionary = PluginInstanceFreshness.mark_lifecycle_reload_requested(source)
	_plugin_reenable_pending = true
	if not _schedule_plugin_reenable_deferred():
		return {
			"success": false,
			"error": "Plugin lifecycle reload bridge is unavailable",
			"data": {"lifecycle_reload": lifecycle_reload, "freshness": PluginInstanceFreshness.get_freshness_snapshot()}
		}
	return {
		"success": true,
		"message": "Plugin lifecycle reload scheduled",
		"deferred": true,
		"data": {
			"mode": "plugin_lifecycle_reload",
			"source": source,
			"request_id": str(lifecycle_reload.get("last_request_id", "")),
			"state": "scheduled",
			"completion_observed": false,
			"lifecycle_reload": lifecycle_reload,
			"freshness": PluginInstanceFreshness.get_freshness_snapshot(),
			"reconnect_hint": "The MCP transport may disconnect while the Godot editor disables and re-enables the plugin. Reconnect and fetch tools again after reload."
		}
	}


func _on_log_level_changed(level: String) -> void:
	MCPDebugBuffer.set_minimum_level(level)
	_state.settings["log_level"] = MCPDebugBuffer.get_minimum_level()
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
		PluginRuntimeStateScript.BUILTIN_TOOL_PROFILES,
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
		PluginRuntimeStateScript.TOOL_PROFILE_DIR,
		profile_name,
		_state.settings.get("disabled_tools", [])
	)
	if not result.get("success", false):
		return {
			"success": false,
			"error": _localization.get_text("tool_profile_save_failed")
		}

	_state.custom_tool_profiles = _settings_store.load_custom_profiles(PluginRuntimeStateScript.TOOL_PROFILE_DIR)
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
		PluginRuntimeStateScript.TOOL_PROFILE_DIR,
		profile_id,
		profile_name
	)
	if not bool(result.get("success", false)):
		return {"success": false, "error": _get_custom_profile_error_text(str(result.get("error_code", "rename_failed")))}

	_state.custom_tool_profiles = _settings_store.load_custom_profiles(PluginRuntimeStateScript.TOOL_PROFILE_DIR)
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

	var result = _settings_store.delete_custom_profile(PluginRuntimeStateScript.TOOL_PROFILE_DIR, profile_id)
	if not bool(result.get("success", false)):
		return {"success": false, "error": _get_custom_profile_error_text(str(result.get("error_code", "delete_failed")))}

	_state.custom_tool_profiles = _settings_store.load_custom_profiles(PluginRuntimeStateScript.TOOL_PROFILE_DIR)
	if str(_state.settings.get("tool_profile_id", "")) == profile_id:
		var tool_names = _tool_catalog.build_tool_name_index(_server_controller.get_all_tools_by_category())
		_state.settings["tool_profile_id"] = "default"
		_state.settings["disabled_tools"] = _tool_catalog.get_disabled_tools_for_profile(
			"default",
			PluginRuntimeStateScript.BUILTIN_TOOL_PROFILES,
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
	for tool_name in _tool_catalog.build_tool_name_index(_server_controller.get_all_tools_by_category()):
		if str(tool_name).begins_with(category + "_"):
			_set_tool_enabled(str(tool_name), enabled)
	_server_controller.set_disabled_tools(_state.settings["disabled_tools"])
	_save_settings()
	_refresh_dock()


func _on_domain_toggled(domain_key: String, enabled: bool) -> void:
	var target_categories: Array = []
	for domain_def in PluginRuntimeStateScript.TOOL_DOMAIN_DEFS:
		if str(domain_def.get("key", "")) != domain_key:
			continue
		target_categories = domain_def.get("categories", []).duplicate()
		break

	if target_categories.is_empty():
		for category in _server_controller.get_all_tools_by_category().keys():
			var known_domain = _tool_catalog.find_domain_key_for_category(PluginRuntimeStateScript.TOOL_DOMAIN_DEFS, str(category))
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


func _on_config_client_action_requested(client_id: String) -> void:
	_config_tab_action_service.handle_config_client_action_requested(client_id)


func _on_config_client_launch_requested(client_id: String) -> void:
	_config_tab_action_service.handle_config_client_launch_requested(client_id)


func _on_config_client_path_pick_requested(client_id: String) -> void:
	_config_tab_action_service.handle_config_client_path_pick_requested(client_id)


func _on_config_client_path_clear_requested(client_id: String) -> void:
	_config_tab_action_service.handle_config_client_path_clear_requested(client_id)


func _on_config_client_open_config_dir_requested(client_id: String) -> void:
	_config_tab_action_service.handle_config_client_open_config_dir_requested(client_id)


func _on_config_client_open_config_file_requested(client_id: String) -> void:
	_config_tab_action_service.handle_config_client_open_config_file_requested(client_id)


func _on_config_write_requested(config_type: String, filepath: String, config: String, client_name: String) -> void:
	_config_tab_action_service.handle_config_write_requested(config_type, filepath, config, client_name)


func _on_config_remove_requested(config_type: String, filepath: String, client_name: String) -> void:
	_config_tab_action_service.handle_config_remove_requested(config_type, filepath, client_name)


func _on_client_executable_file_selected(path: String) -> void:
	_config_tab_action_service.on_client_executable_file_selected(path)


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
	if not _pending_runtime_reload_action.is_empty():
		_finish_self_operation(operation, false, "plugin", "runtime_full_reload", ["runtime_reload_pending"])
		return {
			"success": false,
			"error": "Runtime reload already scheduled: %s" % _pending_runtime_reload_action
		}

	var was_running: bool = _server_controller != null and _server_controller.is_running()
	var focus_snapshot := _capture_dock_focus_snapshot()
	_pending_runtime_reload_action = "runtime_full_reload"
	_schedule_runtime_reload("_complete_runtime_full_reload", [str(operation.get("operation_id", "")), was_running, focus_snapshot])
	return {
		"success": true,
		"message": "Plugin full reload scheduled",
		"running": was_running,
		"deferred": true
	}


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
	if _state != null:
		_state.current_tab = int(snapshot.get("tab_index", _state.current_tab))
	if _dock.has_method("activate_editor_dock_tab"):
		_dock.activate_editor_dock_tab()
	if _dock.has_method("restore_focus_snapshot"):
		_dock.restore_focus_snapshot(snapshot)
	if _dock.has_method("focus_active_panel"):
		_dock.call_deferred("focus_active_panel")
	if _state != null and _state.current_tab == 3:
		_ensure_update_refs_discovery_requested()


func _sync_current_tab_from_dock() -> void:
	if _state == null or _dock == null or not is_instance_valid(_dock):
		return
	if not _dock.has_method("get_current_tab"):
		return
	var current_tab := int(_dock.call("get_current_tab"))
	if current_tab >= 0:
		_state.current_tab = current_tab


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
	PluginSelfDiagnosticStore.clear()
	_refresh_dock()
	return {"success": true, "message": "Plugin self diagnostics cleared"}


func set_tool_enabled_from_tools(tool_name: String, enabled: bool) -> Dictionary:
	_apply_tool_enabled(tool_name, enabled)
	return {"success": true, "tool_name": tool_name, "enabled": enabled}


func set_category_enabled_from_tools(category: String, enabled: bool) -> Dictionary:
	_on_category_toggled(category, enabled)
	return {"success": true, "category": category, "enabled": enabled}


func set_domain_enabled_from_tools(domain_key: String, enabled: bool) -> Dictionary:
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
			"builtin_profiles": PluginRuntimeStateScript.BUILTIN_TOOL_PROFILES,
			"custom_profiles": _state.custom_tool_profiles
		}
	}


func apply_profile_from_tools(profile_id: String) -> Dictionary:
	if profile_id.is_empty():
		return {"success": false, "error": "Profile id is required"}
	if not _tool_catalog.has_tool_profile(profile_id, PluginRuntimeStateScript.BUILTIN_TOOL_PROFILES, _state.custom_tool_profiles):
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
	if not _tool_catalog.has_tool_profile(resolved_profile_id, PluginRuntimeStateScript.BUILTIN_TOOL_PROFILES, _state.custom_tool_profiles):
		resolved_profile_id = _tool_catalog.find_matching_profile_id(
			imported_disabled,
			PluginRuntimeStateScript.BUILTIN_TOOL_PROFILES,
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
				"All built-in plugin maintenance categories are available internally; public MCP exposure remains limited to high-level system tools."
			],
			"recommended_flow": [
				{"step": 1, "name": "Inspect state", "tools": ["plugin_runtime_state"], "purpose": "Read loaded domains, reload status and health summaries."},
				{"step": 2, "name": "Toggle carefully", "tools": ["plugin_runtime_toggle"], "purpose": "Disable tools when isolating faults, then re-enable them after verification."},
				{"step": 3, "name": "Reload safely", "tools": ["plugin_runtime_reload"], "purpose": "Start with domain reloads, then reload all domains, and escalate to soft/full plugin reload only when necessary."},
				{"step": 4, "name": "Read runtime bridge", "tools": ["debug_runtime_bridge"], "purpose": "Inspect the latest debugger session state and recent lifecycle events from the last editor-run project session."},
				{"step": 5, "name": "Recover transport", "tools": ["plugin_runtime_server"], "purpose": "Restart the embedded MCP server if transport state is stale but plugin state is otherwise valid."},
				{"step": 6, "name": "Verify", "tools": ["debug_log", "debug_log_buffer", "debug_performance"], "purpose": "Read recent errors and a lightweight runtime health snapshot after each change."}
			],
			"warnings": [
				"Do not disable the godot_dotnet_mcp plugin through its own MCP connection when you still need the current transport.",
				"Runtime toggles are diagnostic controls; avoid leaving essential high-level system tools disabled.",
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
				"Plugin developer tools are internal maintenance helpers for Dock-facing settings such as language, preset selection and log level.",
				"The plugin no longer has permission levels; all built-in maintenance capabilities are available internally while public MCP exposure stays high-level.",
				"Use debug_runtime_bridge for the latest project session and lifecycle readback; it remains readable after the project stops."
			],
			"recommended_flow": [
				{"step": 1, "name": "Inspect settings", "tools": ["plugin_developer_settings", "plugin_runtime_state"], "purpose": "Read log level, language, active preset and reload status before making changes."},
				{"step": 2, "name": "Tune the session", "tools": ["plugin_developer_log_level", "plugin_developer_set_language", "plugin_developer_apply_profile"], "purpose": "Adjust Dock-facing developer settings for the current debugging session."},
				{"step": 3, "name": "Inspect project runtime result", "tools": ["debug_runtime_bridge"], "purpose": "Read the latest captured project session state and lifecycle events after each run."},
				{"step": 4, "name": "Coordinate with runtime and evolution", "tools": ["plugin_runtime_usage_guide", "plugin_evolution_usage_guide"], "purpose": "Use the sibling guide tools to choose the correct reload or self-evolution flow."},
				{"step": 5, "name": "Save reusable presets", "tools": ["plugin_developer_save_profile"], "purpose": "Persist a known-good tool selection after manual tuning."}
			],
			"warnings": [
				"Use the exact MCP tool name debug_runtime_bridge when reading recent project runtime state.",
				"Do not expose internal plugin_* categories as public MCP tools; keep public access routed through high-level system tools."
			]
		},
		"message": "Plugin usage guide fetched"
	}


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
		"freshness": PluginInstanceFreshness.get_freshness_snapshot(),
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
	if _dock_coordinator == null:
		_dock_coordinator = PluginDockCoordinatorScript.new()
	return _dock_coordinator.count_plugin_dock_instances(self, MCP_DOCK_SCRIPT_PATH)


func _has_runtime_bridge_root_instance() -> bool:
	if not is_inside_tree():
		return false
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
	_reload_script(MCP_DOCK_SCRIPT_PATH)
	var scene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	return scene as PackedScene


func _reload_script(path: String) -> void:
	var script = ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_REPLACE)
	if script is Script:
		(script as Script).reload(false)


func _recreate_dock() -> void:
	_dock_recreate_pending = false
	_remove_dock()
	_remove_stale_docks()
	_create_dock()
	if _dock != null and is_instance_valid(_dock) and _dock.has_method("apply_model"):
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
	_state.current_tab = int((snapshot as Dictionary).get("tab_index", _state.current_tab))
	if _dock and is_instance_valid(_dock):
		if _dock.has_method("activate_editor_dock_tab"):
			_dock.activate_editor_dock_tab()
		if _dock.has_method("restore_focus_snapshot"):
			_dock.restore_focus_snapshot(snapshot)
		if _dock.has_method("focus_active_panel"):
			_dock.call_deferred("focus_active_panel")
	_state.settings.erase(PENDING_FOCUS_SNAPSHOT_KEY)
	_save_settings()
	if _state.current_tab == 3:
		_ensure_update_refs_discovery_requested()

func _schedule_plugin_reenable() -> bool:
	var editor_interface = get_editor_interface()
	if editor_interface == null:
		return false
	var base_control = editor_interface.get_base_control()
	if base_control == null:
		return false

	var coordinator = PluginReloadCoordinator.new()
	coordinator.name = "MCPPluginReloadCoordinator"
	coordinator.configure(PLUGIN_ID, editor_interface, _server_controller)
	base_control.add_child(coordinator)
	return true


func _schedule_plugin_reenable_deferred() -> bool:
	var editor_interface = get_editor_interface()
	if editor_interface == null:
		return false
	var base_control = editor_interface.get_base_control()
	if base_control == null:
		return false
	if not is_inside_tree():
		return _schedule_plugin_reenable()
	var tree := get_tree()
	if tree == null:
		return _schedule_plugin_reenable()
	var timer := tree.create_timer(0.05)
	timer.timeout.connect(Callable(self, "_complete_plugin_reenable_schedule"), CONNECT_ONE_SHOT)
	return true


func _complete_plugin_reenable_schedule() -> void:
	if not _schedule_plugin_reenable():
		return


func _create_reload_coordinator():
	var coordinator = PluginReloadCoordinator.new()
	coordinator.configure(PLUGIN_ID, get_editor_interface(), _server_controller)
	return coordinator


func _configure_user_tool_watch_service() -> void:
	if _user_tool_watch_service == null:
		_user_tool_watch_service = UserToolWatchServiceScript.new()
	_user_tool_watch_service.stop()
	_user_tool_watch_service.configure(self, _create_reload_coordinator(), _user_tool_service)
	_user_tool_watch_service.start()


func _configure_config_tab_action_service() -> void:
	if _config_tab_action_service == null:
		_config_tab_action_service = ConfigTabActionServiceScript.new()
	_config_tab_action_service.configure({
		"state": _state,
		"localization": _localization,
		"config_service": _config_service,
		"client_install_detection_service": _client_install_detection_service,
		"get_client_install_statuses": Callable(self, "_get_client_install_statuses"),
		"invalidate_client_install_status_cache": Callable(self, "_invalidate_client_install_status_cache"),
		"configure_client_install_detection_service": Callable(self, "_configure_client_install_detection_service"),
		"refresh_dock": Callable(self, "_refresh_dock"),
		"save_settings": Callable(self, "_save_settings"),
		"show_message": Callable(self, "_show_message"),
		"show_confirmation": Callable(self, "_show_confirmation"),
		"ensure_client_executable_dialog": Callable(self, "_configure_client_executable_dialog"),
		"get_client_executable_dialog": Callable(self, "_get_client_executable_dialog")
	})


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
	_ensure_runtime_state()
	_settings_store = SettingsStoreScript.new()
	if _server_controller == null:
		_server_controller = ServerRuntimeControllerScript.new()
	_tool_catalog = ToolCatalogServiceScript.new()
	_config_service = ClientConfigServiceScript.new()
	if _dock_model_service == null:
		_dock_model_service = DockModelServiceScript.new()
	_client_install_detection_service = ClientInstallDetectionServiceScript.new()
	_user_tool_service = UserToolServiceScript.new()
	_user_tool_watch_service = UserToolWatchServiceScript.new()


func _ensure_runtime_state() -> void:
	if _state == null:
		_state = PluginRuntimeStateScript.new()
