@tool
extends EditorPlugin

const LocalizationService = preload("res://addons/godot_dotnet_mcp/localization/localization_service.gd")
const PluginRuntimeStateScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_state.gd")
const TreeCollapseState = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tree_collapse_state.gd")
const SettingsStoreScript = preload("res://addons/godot_dotnet_mcp/plugin/config/settings_store.gd")
const ServerRuntimeControllerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/server_runtime_controller.gd")
const ToolCatalogServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_catalog_service.gd")
const PluginRuntimeCoordinatorScript = preload("res://addons/godot_dotnet_mcp/plugin/plugin_runtime_coordinator.gd")
const PluginLifecycleServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/plugin_lifecycle_service.gd")
const PluginLifecycleContextServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/plugin_lifecycle_context_service.gd")
const PluginConfigReloadWiringServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/plugin_config_reload_wiring_service.gd")
const PluginConfigReloadContextServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/plugin_config_reload_context_service.gd")
const DockModelServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/presenters/dock_model_service.gd")
const DockMcpCatalogPreviewServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/presenters/dock_mcp_catalog_preview_service.gd")
const PluginActionRouterScript = preload("res://addons/godot_dotnet_mcp/plugin/plugin_action_router.gd")
const PluginDockCoordinatorScript = preload("res://addons/godot_dotnet_mcp/plugin/plugin_dock_coordinator.gd")
const ClientConfigServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_service.gd")
const UserToolServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_service.gd")
const PluginRuntimeReloadRequestServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_reload_request_service.gd")
const MCPEditorDebuggerBridge = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_editor_debugger_bridge.gd")
const MCPRuntimeDebugStore = preload("res://addons/godot_dotnet_mcp/tools/shared/mcp_runtime_debug_store.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const PluginInstanceFreshness = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_instance_freshness.gd")
const MCPMaintenanceContract = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_maintenance_contract.gd")
const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const PluginPerformanceMonitorScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_performance_monitor.gd")
const PluginUpdateToolFacadeServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_tool_facade_service.gd")
const PluginUpdateSyncMirrorServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_sync_mirror_service.gd")
const PluginUsageGuideServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_usage_guide_service.gd")
const PluginSelfDiagnosticsServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostics_service.gd")
const PluginProfileConfigServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_profile_config_service.gd")
const PluginDeveloperSettingsServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_developer_settings_service.gd")
const PluginClientConfigStateServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_client_config_state_service.gd")
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
const UPDATE_BRANCH_REF_URL_TEMPLATE := "https://api.github.com/repos/LuoxuanLove/godot-dotnet-mcp/branches/%s"
const UPDATE_TARGET_PLUGIN_CFG_BRANCH_URL_TEMPLATE := "https://raw.githubusercontent.com/LuoxuanLove/godot-dotnet-mcp/refs/heads/%s/addons/godot_dotnet_mcp/plugin.cfg"
const UPDATE_TARGET_PLUGIN_CFG_TAG_URL_TEMPLATE := "https://raw.githubusercontent.com/LuoxuanLove/godot-dotnet-mcp/refs/tags/%s/addons/godot_dotnet_mcp/plugin.cfg"
const UPDATE_REFS_HTTP_TIMEOUT := 10.0
const UPDATE_REFS_BODY_SIZE_LIMIT := 16777216
const UPDATE_REFS_MAX_PAGES := 20
const UPDATE_SYNC_COMMIT_ARCHIVE_URL_PREFIX := "https://codeload.github.com/LuoxuanLove/godot-dotnet-mcp/zip/"
const UPDATE_SYNC_BRANCH_ARCHIVE_URL_PREFIX := "https://codeload.github.com/LuoxuanLove/godot-dotnet-mcp/zip/refs/heads/"
const UPDATE_SYNC_TAG_ARCHIVE_URL_PREFIX := "https://codeload.github.com/LuoxuanLove/godot-dotnet-mcp/zip/refs/tags/"
const UPDATE_SYNC_GITHUB_BRANCH_ARCHIVE_URL_PREFIX := "https://github.com/LuoxuanLove/godot-dotnet-mcp/archive/refs/heads/"
const UPDATE_SYNC_GITHUB_TAG_ARCHIVE_URL_PREFIX := "https://github.com/LuoxuanLove/godot-dotnet-mcp/archive/refs/tags/"
const UPDATE_SYNC_GITHUB_COMMIT_ARCHIVE_URL_PREFIX := "https://github.com/LuoxuanLove/godot-dotnet-mcp/archive/"
const UPDATE_SYNC_ARCHIVE_PATH := "user://godot_dotnet_mcp/update_branch.zip"
const UPDATE_SYNC_MARKER_PATH := "res://addons/godot_dotnet_mcp/.mcp_sync.json"
const UPDATE_SYNC_REPO_URL := "https://github.com/LuoxuanLove/godot-dotnet-mcp"
const UPDATE_SYNC_HTTP_TIMEOUT := 60.0
const UPDATE_SYNC_BODY_SIZE_LIMIT := 67108864
const UPDATE_SYNC_ADDON_ROOT := "res://addons/godot_dotnet_mcp"
const UPDATE_SYNC_EDITOR_REFRESH_TIMEOUT_MS := 15000

var _state = null
var _settings_store = null
var _server_controller = null
var _tool_catalog = null
var _config_service = null
var _config_tab_action_service = null
var _dock_model_service = null
var _mcp_catalog_preview_service = null
var _runtime_coordinator := PluginRuntimeCoordinatorScript.new()
var _plugin_lifecycle_service := PluginLifecycleServiceScript.new()
var _plugin_lifecycle_context_service := PluginLifecycleContextServiceScript.new()
var _config_reload_wiring_service := PluginConfigReloadWiringServiceScript.new()
var _config_reload_context_service := PluginConfigReloadContextServiceScript.new()
var _runtime_reload_request_service := PluginRuntimeReloadRequestServiceScript.new()
var _plugin_update_tool_facade := PluginUpdateToolFacadeServiceScript.new()
var _plugin_update_sync_mirror_service := PluginUpdateSyncMirrorServiceScript.new()
var _plugin_usage_guide_service := PluginUsageGuideServiceScript.new()
var _plugin_self_diagnostics_service := PluginSelfDiagnosticsServiceScript.new()
var _plugin_profile_config_service := PluginProfileConfigServiceScript.new()
var _plugin_developer_settings_service := PluginDeveloperSettingsServiceScript.new()
var _plugin_client_config_state_service := PluginClientConfigStateServiceScript.new()
var _user_tool_service = null
var _user_tool_watch_service = null
var _action_router := PluginActionRouterScript.new()
var _dock_coordinator := PluginDockCoordinatorScript.new()
var _performance_monitor := PluginPerformanceMonitorScript.new()
var _localization: LocalizationService
var _dock: Control
var _status_poll_accumulator := 0.0
var _user_tool_watch_tick_accumulator := 0.0
var _editor_debugger_bridge: EditorDebuggerPlugin
var _pending_runtime_reload_action := ""
var _plugin_reenable_pending := false
var _dock_recreate_pending := false
var _dock_recreate_attempted := false
var _update_refs_request_serial := 0
var _update_refs_pending := {}
var _update_refs_discovery_loaded := false
var _update_refs_discovery_retry_pending := false
var _update_sync_after_refs_discovery_pending := false
var _update_compare_request_serial := 0
var _update_ref_version_request_serial := 0
var _update_ref_version_requests_in_flight := {}
var _update_sync_request_serial := 0
var _last_dock_refresh_status_signature := ""
var _cached_lifecycle_context: Dictionary = {}
var _cached_config_reload_wiring_context: Dictionary = {}
var _tree_collapse_save_pending := false
const USER_TOOL_WATCH_TICK_INTERVAL := 0.25


func _init() -> void:
	_ensure_runtime_state()


func _get_localized_text(key: String) -> String:
	if _localization != null:
		return _localization.get_text(key)
	return LocalizationService.translate(key)


func _enter_tree() -> void:
	if _plugin_lifecycle_service == null:
		_plugin_lifecycle_service = PluginLifecycleServiceScript.new()
	_plugin_lifecycle_service.enter_tree(_build_plugin_lifecycle_context())


func _exit_tree() -> void:
	_flush_tree_collapse_save_if_pending()
	if _plugin_lifecycle_service == null:
		_plugin_lifecycle_service = PluginLifecycleServiceScript.new()
	_plugin_lifecycle_service.exit_tree(_build_plugin_lifecycle_context())


func _disable_plugin() -> void:
	if _plugin_lifecycle_service == null:
		_plugin_lifecycle_service = PluginLifecycleServiceScript.new()
	_plugin_lifecycle_service.disable_plugin(_build_plugin_lifecycle_context())


func _process(delta: float) -> void:
	if _plugin_lifecycle_service == null:
		_plugin_lifecycle_service = PluginLifecycleServiceScript.new()
	var started_usec := Time.get_ticks_usec()
	_user_tool_watch_tick_accumulator += maxf(delta, 0.0)
	_status_poll_accumulator = _plugin_lifecycle_service.process(delta, _status_poll_accumulator, _update_refs_discovery_retry_pending, _get_plugin_lifecycle_context())
	_record_process_perf(started_usec, delta)


func _build_plugin_lifecycle_context() -> Dictionary:
	return _plugin_lifecycle_context_service.build_plugin_lifecycle_context(self, {
		"runtime_bridge_autoload_name": RUNTIME_BRIDGE_AUTOLOAD_NAME,
		"runtime_bridge_autoload_path": RUNTIME_BRIDGE_AUTOLOAD_PATH
	})


func _get_plugin_lifecycle_context() -> Dictionary:
	if _cached_lifecycle_context.is_empty():
		_cached_lifecycle_context = _build_plugin_lifecycle_context()
	return _cached_lifecycle_context


func _invalidate_plugin_lifecycle_context() -> void:
	_cached_lifecycle_context = {}


func _build_config_reload_wiring_context() -> Dictionary:
	if _config_reload_context_service == null:
		_config_reload_context_service = PluginConfigReloadContextServiceScript.new()
	return _config_reload_context_service.build_config_reload_context(self, {
		"plugin_id": PLUGIN_ID,
		"server_controller": _server_controller,
		"state": _state,
		"localization": _localization,
		"config_service": _config_service,
		"client_install_detection_service": _get_client_install_detection_service(),
		"user_tool_service": _user_tool_service
	})


func _get_config_reload_wiring_context() -> Dictionary:
	if _cached_config_reload_wiring_context.is_empty():
		_cached_config_reload_wiring_context = _build_config_reload_wiring_context()
	return _cached_config_reload_wiring_context


func _invalidate_config_reload_wiring_context() -> void:
	_cached_config_reload_wiring_context = {}


func _configure_lifecycle_enter_state() -> void:
	LocalizationService.reset_instance()
	_localization = LocalizationService.get_instance()
	_localization.set_language(str(_state.settings.get("language", "")))
	MCPDebugBuffer.set_minimum_level(str(_state.settings.get("log_level", "info")))
	_state.settings["log_level"] = MCPDebugBuffer.get_minimum_level()


func _ensure_action_router() -> void:
	if _action_router == null:
		_action_router = PluginActionRouterScript.new()
	_action_router.configure(self, RUNTIME_BRIDGE_AUTOLOAD_NAME, RUNTIME_BRIDGE_AUTOLOAD_PATH)


func _ensure_dock_coordinator() -> void:
	if _dock_coordinator == null:
		_dock_coordinator = PluginDockCoordinatorScript.new()


func _set_plugin_process_enabled(enabled: bool) -> void:
	set_process(enabled)


func _should_auto_start_server() -> bool:
	return _state != null and bool(_state.settings.get("auto_start", true))


func _start_server_for_lifecycle() -> void:
	if _server_controller != null:
		_server_controller.start(_state.settings, "auto_start")
		_refresh_dock_if_status_changed()


func _defer_start_server_for_lifecycle() -> void:
	call_deferred("_start_server_for_lifecycle")


func _defer_initial_dock_refresh() -> void:
	call_deferred("_refresh_dock")


func _defer_saved_update_source_discovery_request() -> void:
	call_deferred("_ensure_saved_update_source_discovery_requested")


func _stop_user_tool_watch_service() -> void:
	_user_tool_watch_tick_accumulator = 0.0
	if _user_tool_watch_service != null:
		_user_tool_watch_service.stop()


func _dispose_action_router() -> void:
	if _action_router != null:
		_action_router.dispose()
		_action_router = null
	_dock_coordinator = null


func _dispose_lifecycle_services() -> void:
	_invalidate_plugin_lifecycle_context()
	_invalidate_config_reload_wiring_context()
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
	if _mcp_catalog_preview_service != null:
		_mcp_catalog_preview_service.dispose()
	_mcp_catalog_preview_service = null
	_runtime_coordinator = null
	_config_reload_context_service = null
	_plugin_update_tool_facade = null
	_plugin_update_sync_mirror_service = null
	_plugin_usage_guide_service = null
	_plugin_self_diagnostics_service = null
	_plugin_profile_config_service = null
	_plugin_developer_settings_service = null
	if _plugin_client_config_state_service != null:
		_plugin_client_config_state_service.dispose()
	_plugin_client_config_state_service = null
	_tool_catalog = null
	_settings_store = null
	_state = null


func _is_runtime_bridge_currently_owned() -> bool:
	return _is_runtime_bridge_autoload_path(str(ProjectSettings.get_setting("autoload/%s" % RUNTIME_BRIDGE_AUTOLOAD_NAME, "")))


func _tick_user_tool_watch_service() -> void:
	if _user_tool_watch_service == null:
		return
	if _user_tool_watch_tick_accumulator < USER_TOOL_WATCH_TICK_INTERVAL:
		return
	_user_tool_watch_tick_accumulator = 0.0
	_user_tool_watch_service.tick()


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


func _defer_tree_collapse_save() -> void:
	if _tree_collapse_save_pending:
		return
	_tree_collapse_save_pending = true
	call_deferred("_flush_tree_collapse_save_if_pending")


func _flush_tree_collapse_save_if_pending() -> void:
	if not _tree_collapse_save_pending:
		return
	_tree_collapse_save_pending = false
	_save_settings()


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
	_ensure_plugin_client_config_state_service().configure_client_executable_dialog(
		get_editor_interface(),
		Callable(self, "_on_client_executable_file_selected")
	)


func _remove_client_executable_dialog() -> void:
	_ensure_plugin_client_config_state_service().remove_client_executable_dialog()


func _get_client_executable_dialog():
	return _ensure_plugin_client_config_state_service().get_client_executable_dialog()


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
	if _state != null and _state.current_tab == 5 and _ensure_update_refs_discovery_requested():
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
		_get_client_install_detection_service(),
		_user_tool_watch_service,
		Callable(self, "_get_editor_scale")
	)
	var model: Dictionary = _dock_model_service.build_model()
	_last_dock_refresh_status_signature = _build_dock_refresh_status_signature()
	_dock.call("apply_model", model)


func _refresh_dock_if_status_changed() -> void:
	var signature := _build_dock_refresh_status_signature()
	if signature == _last_dock_refresh_status_signature:
		return
	_refresh_dock()


func _build_dock_refresh_status_signature() -> String:
	if _state == null:
		return ""
	var data := _build_dock_refresh_status_signature_data()
	var parts := PackedStringArray()
	for key in [
		"tab",
		"running",
		"connections",
		"total_requests",
		"rejected_requests",
		"last_request_id",
		"loader_initialized",
		"loader_status",
		"tool_count",
		"exposed_tool_count",
		"category_count",
		"tool_load_error_count",
		"user_watch_enabled",
		"user_watch_watching",
		"user_watch_count",
		"user_watch_change",
		"user_watch_error",
		"update_refs_state",
		"update_compare_state",
		"update_sync_state"
	]:
		parts.append("%s=%s" % [key, str(data.get(key, ""))])
	return "|".join(parts)


func _build_dock_refresh_status_signature_data() -> Dictionary:
	var server_running := false
	var connection_count := 0
	var tool_loader_status := {}
	var user_watch_status := {}
	var connection_stats := {}
	if _server_controller != null:
		if _server_controller.has_method("is_running"):
			server_running = bool(_server_controller.is_running())
		if _server_controller.has_method("get_connection_count"):
			connection_count = int(_server_controller.get_connection_count())
		var status = {}
		if _server_controller.has_method("peek_light_tool_loader_status"):
			status = _server_controller.peek_light_tool_loader_status()
		elif _server_controller.has_method("peek_tool_loader_status"):
			status = _server_controller.peek_tool_loader_status()
		elif _server_controller.has_method("get_tool_loader_status"):
			status = _server_controller.get_tool_loader_status()
		if status is Dictionary:
			tool_loader_status = status
		if _server_controller.has_method("get_connection_stats"):
			var stats = _server_controller.get_connection_stats()
			if stats is Dictionary:
				connection_stats = stats
	if _user_tool_watch_service != null:
		var watch_status = _user_tool_watch_service.get_status_snapshot() if _user_tool_watch_service.has_method("get_status_snapshot") else _user_tool_watch_service.get_status()
		if watch_status is Dictionary:
			user_watch_status = watch_status
	return {
		"tab": int(_state.current_tab),
		"running": server_running,
		"connections": connection_count,
		"total_requests": int(connection_stats.get("total_requests", 0)),
		"rejected_requests": int(connection_stats.get("rejected_requests", 0)),
		"last_request_id": str(connection_stats.get("last_request_id", "")),
		"loader_initialized": bool(tool_loader_status.get("initialized", false)),
		"loader_status": str(tool_loader_status.get("status", "")),
		"tool_count": int(tool_loader_status.get("tool_count", 0)),
		"exposed_tool_count": int(tool_loader_status.get("exposed_tool_count", 0)),
		"category_count": int(tool_loader_status.get("category_count", 0)),
		"tool_load_error_count": int(tool_loader_status.get("tool_load_error_count", 0)),
		"user_watch_enabled": bool(user_watch_status.get("enabled", false)),
		"user_watch_watching": bool(user_watch_status.get("watching", false)),
		"user_watch_count": int(user_watch_status.get("known_script_count", 0)),
		"user_watch_change": str(user_watch_status.get("last_change_reason", "")),
		"user_watch_error": str(user_watch_status.get("last_error", "")),
		"update_refs_state": str(_get_state_value("update_refs_state", "idle")),
		"update_compare_state": str(_get_state_value("update_compare_state", "idle")),
		"update_sync_state": str(_get_state_value("update_sync_state", "idle"))
	}


func _get_state_value(property_name: String, default_value = null):
	if _state == null:
		return default_value
	var value = _state.get(property_name)
	return default_value if value == null else value


func _apply_initial_tool_profile_if_needed() -> void:
	if not _state.needs_initial_tool_profile_apply:
		return

	var profile_id := str(_state.settings.get("tool_profile_id", "default"))
	if profile_id == "default":
		_state.needs_initial_tool_profile_apply = false
		_state.settings["disabled_tools"] = []
		_save_settings()
		return

	var tool_names = _tool_catalog.build_tool_name_index(_server_controller.get_all_tools_by_category())
	if tool_names.is_empty():
		return

	_state.settings["disabled_tools"] = _tool_catalog.get_disabled_tools_for_profile(
		profile_id,
		PluginRuntimeStateScript.BUILTIN_TOOL_PROFILES,
		_state.custom_tool_profiles,
		tool_names,
		_state.settings.get("disabled_tools", [])
	)
	_state.needs_initial_tool_profile_apply = false
	_server_controller.set_disabled_tools(_state.settings["disabled_tools"])
	_save_settings()


func _get_client_install_statuses() -> Dictionary:
	if _state == null:
		return {}
	return _ensure_plugin_client_config_state_service().get_client_install_statuses(_state.settings)


func _invalidate_client_install_status_cache() -> void:
	_ensure_plugin_client_config_state_service().invalidate_client_install_status_cache()


func _configure_client_install_detection_service() -> void:
	if _state == null:
		return
	_ensure_plugin_client_config_state_service().configure_client_install_detection_service(_state.settings)


func _get_client_install_detection_service():
	return _ensure_plugin_client_config_state_service().get_client_install_detection_service()


func _on_current_tab_changed(index: int) -> void:
	_state.current_tab = index
	if _state.current_tab == 4:
		_invalidate_client_install_status_cache()
	if _state.current_tab == 5 and _ensure_update_refs_discovery_requested():
		return
	_refresh_dock()


func _on_tool_view_changed(view_id: String) -> void:
	if _state == null:
		return
	var normalized := view_id.strip_edges()
	if not ["agent_tools", "internal_executors", "tool_diagnostics"].has(normalized):
		normalized = "agent_tools"
	if str(_state.current_tools_view) == normalized:
		return
	_state.current_tools_view = normalized
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
	_update_sync_after_refs_discovery_pending = false
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
	_update_sync_after_refs_discovery_pending = false
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
	var target := _resolve_update_sync_target()
	var target_ref := str(target.get("ref", "")).strip_edges()
	if target_ref.is_empty():
		_state.update_sync_state = "error"
		_state.update_sync_error = _localization.get_text("settings_update_sync_no_target") if _localization != null else "Select an update target before syncing."
		_state.update_sync_status = ""
		_state.update_sync_progress = 0.0
		_refresh_dock()
		return
	_request_update_sync(target, "dock")


func _request_update_sync(target: Dictionary, source: String = "unknown") -> bool:
	if _state == null:
		return false
	if str(_state.update_sync_state) == "loading":
		_refresh_dock()
		return false
	var target_ref := str(target.get("ref", "")).strip_edges()
	if target_ref.is_empty():
		return false
	_update_sync_after_refs_discovery_pending = false
	_update_sync_request_serial += 1
	var serial := _update_sync_request_serial
	_state.update_sync_state = "loading"
	_state.update_sync_target_ref = target_ref
	_state.update_sync_target_kind = str(target.get("kind", "branch"))
	_state.update_sync_error = ""
	_state.update_sync_status = (_localization.get_text("settings_update_sync_loading") % target_ref) if _localization != null else "Syncing %s..." % target_ref
	_state.update_sync_progress = 0.08
	_refresh_dock()
	MCPDebugBuffer.record("info", "plugin", "Plugin update sync requested from %s for %s" % [source, target_ref])
	_start_update_archive_sync_request(target, serial)
	return true


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
	if _should_resolve_update_branch_commit_before_archive(target):
		_state.update_sync_status = _get_localized_text("settings_update_sync_resolving_target")
		_state.update_sync_progress = max(float(_state.update_sync_progress), 0.18)
		_refresh_dock()
		_start_update_archive_branch_ref_request(target, serial)
		return
	var attempts := _build_update_archive_request_attempts(target)
	if attempts.is_empty():
		_mark_update_sync_failed("Update sync target has no usable archive URL: %s" % target_ref, serial)
		return
	_start_update_archive_sync_request_attempt(target, serial, attempts, 0, [])


func _should_resolve_update_branch_commit_before_archive(target: Dictionary) -> bool:
	if str(target.get("kind", "branch")) != "branch":
		return false
	return str(target.get("ref", "")).strip_edges() != "" and str(target.get("commit", "")).strip_edges() == ""


func _start_update_archive_branch_ref_request(target: Dictionary, serial: int) -> void:
	var request_parent := _get_update_request_parent()
	if request_parent == null:
		_mark_update_sync_failed("No active update sync request host.", serial)
		return
	var target_ref := str(target.get("ref", "")).strip_edges()
	var request_node := HTTPRequest.new()
	request_node.name = "UpdateArchiveBranchRefRequest"
	request_node.timeout = UPDATE_REFS_HTTP_TIMEOUT
	request_node.body_size_limit = 65536
	request_parent.add_child(request_node)
	request_node.request_completed.connect(Callable(self, "_on_update_archive_branch_ref_request_completed").bind(target, serial, request_node), CONNECT_ONE_SHOT)
	var error := request_node.request(_get_update_branch_ref_url(target_ref), _get_update_refs_headers())
	if error != OK:
		request_node.queue_free()
		_start_update_archive_sync_request_attempt(target, serial, _build_update_archive_request_attempts(target), 0, ["branch ref request start failed: %s" % error])


func _get_update_branch_ref_url(target_ref: String) -> String:
	return UPDATE_BRANCH_REF_URL_TEMPLATE % target_ref.strip_edges().uri_encode()


func _on_update_archive_branch_ref_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, target: Dictionary, serial: int, request_node: HTTPRequest) -> void:
	if request_node != null and is_instance_valid(request_node):
		request_node.queue_free()
	if _state == null or serial != _update_sync_request_serial:
		return
	var failures: Array[String] = []
	var resolved_target := target.duplicate(true)
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		var parse_result := _parse_update_branch_ref_response(body)
		if bool(parse_result.get("success", false)):
			resolved_target["commit"] = str(parse_result.get("commit", "")).strip_edges()
			var commits: Dictionary = _state.update_ref_commits
			if not str(resolved_target.get("commit", "")).is_empty():
				commits[str(resolved_target.get("ref", ""))] = str(resolved_target.get("commit", ""))
				_state.update_ref_commits = commits
		else:
			failures.append("branch ref response parse failed: %s" % str(parse_result.get("error", "Invalid JSON response")))
	else:
		failures.append("branch ref request failed with result %s and HTTP %s" % [result, response_code])
	_start_update_archive_sync_request_attempt(resolved_target, serial, _build_update_archive_request_attempts(resolved_target), 0, failures)


func _parse_update_branch_ref_response(body: PackedByteArray) -> Dictionary:
	var json := JSON.new()
	var parse_error := json.parse(body.get_string_from_utf8())
	if parse_error != OK:
		return {"success": false, "error": json.get_error_message()}
	if not (json.data is Dictionary):
		return {"success": false, "error": "Expected a JSON object"}
	var data: Dictionary = json.data
	var commit_value = data.get("commit", {})
	if commit_value is Dictionary:
		var sha := str((commit_value as Dictionary).get("sha", "")).strip_edges()
		if not sha.is_empty():
			return {"success": true, "commit": sha}
	return {"success": false, "error": "Branch response did not include commit.sha"}


func _build_update_archive_request_attempts(target: Dictionary) -> Array:
	var target_kind := str(target.get("kind", "branch"))
	var target_ref := str(target.get("ref", "")).strip_edges()
	var target_commit := str(target.get("commit", "")).strip_edges()
	var encoded_ref := _encode_update_archive_ref_path(target_ref)
	var attempts: Array = []
	if target_kind == "branch" and not target_commit.is_empty():
		attempts.append({
			"label": "codeload commit archive",
			"url": "%s%s" % [UPDATE_SYNC_COMMIT_ARCHIVE_URL_PREFIX, target_commit.uri_encode()]
		})
		attempts.append({
			"label": "github commit archive",
			"url": "%s%s.zip" % [UPDATE_SYNC_GITHUB_COMMIT_ARCHIVE_URL_PREFIX, target_commit.uri_encode()]
		})
	if not encoded_ref.is_empty():
		if target_kind == "tag":
			attempts.append({
				"label": "codeload tag archive",
				"url": "%s%s" % [UPDATE_SYNC_TAG_ARCHIVE_URL_PREFIX, encoded_ref]
			})
			attempts.append({
				"label": "github tag archive",
				"url": "%s%s.zip" % [UPDATE_SYNC_GITHUB_TAG_ARCHIVE_URL_PREFIX, encoded_ref]
			})
		elif target_commit.is_empty():
			attempts.append({
				"label": "codeload branch archive",
				"url": "%s%s" % [UPDATE_SYNC_BRANCH_ARCHIVE_URL_PREFIX, encoded_ref]
			})
			attempts.append({
				"label": "github branch archive",
				"url": "%s%s.zip" % [UPDATE_SYNC_GITHUB_BRANCH_ARCHIVE_URL_PREFIX, encoded_ref]
			})
	return attempts


func _encode_update_archive_ref_path(target_ref: String) -> String:
	return target_ref.strip_edges().uri_encode().replace("%2F", "/")


func _start_update_archive_sync_request_attempt(target: Dictionary, serial: int, attempts: Array, attempt_index: int, failures: Array) -> void:
	if _state == null or serial != _update_sync_request_serial:
		return
	if attempt_index < 0 or attempt_index >= attempts.size():
		_mark_update_sync_failed(_format_update_archive_failures(failures), serial)
		return
	var request_parent := _get_update_request_parent()
	if request_parent == null:
		_mark_update_sync_failed("No active update sync request host.", serial)
		return
	var attempt: Dictionary = attempts[attempt_index]
	_state.update_sync_status = _get_localized_text("settings_update_sync_downloading_archive")
	_state.update_sync_progress = max(float(_state.update_sync_progress), min(0.55, 0.28 + float(attempt_index) * 0.08))
	_refresh_dock()
	if FileAccess.file_exists(UPDATE_SYNC_ARCHIVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(UPDATE_SYNC_ARCHIVE_PATH))
	var request_node := HTTPRequest.new()
	request_node.name = "UpdateArchiveSyncRequest"
	request_node.timeout = UPDATE_SYNC_HTTP_TIMEOUT
	request_node.body_size_limit = UPDATE_SYNC_BODY_SIZE_LIMIT
	request_node.download_file = UPDATE_SYNC_ARCHIVE_PATH
	request_parent.add_child(request_node)
	request_node.request_completed.connect(Callable(self, "_on_update_archive_sync_request_attempt_completed").bind(target, serial, request_node, attempts, attempt_index, failures), CONNECT_ONE_SHOT)
	var error := request_node.request(str(attempt.get("url", "")), _get_update_archive_headers())
	if error != OK:
		request_node.queue_free()
		var next_failures := failures.duplicate()
		next_failures.append("%s start failed: %s" % [str(attempt.get("label", "archive request")), error])
		_start_update_archive_sync_request_attempt(target, serial, attempts, attempt_index + 1, next_failures)


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


func _fail_pending_update_sync_after_refs_discovery(message: String) -> void:
	if not _update_sync_after_refs_discovery_pending or _state == null:
		return
	_update_sync_after_refs_discovery_pending = false
	_state.update_sync_state = "error"
	_state.update_sync_error = message
	_state.update_sync_status = ""
	_state.update_sync_progress = 0.0


func _mark_update_sync_failed(message: String, serial: int) -> void:
	if _state == null or serial != _update_sync_request_serial:
		return
	_state.update_sync_state = "error"
	_state.update_sync_error = message
	_state.update_sync_status = ""
	_state.update_sync_progress = 0.0
	_refresh_dock()


func _on_update_archive_sync_request_attempt_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray, target: Dictionary, serial: int, request_node: HTTPRequest, attempts: Array, attempt_index: int, failures: Array) -> void:
	if request_node != null and is_instance_valid(request_node):
		request_node.queue_free()
	if _state == null or serial != _update_sync_request_serial:
		return
	var attempt: Dictionary = attempts[attempt_index] if attempt_index >= 0 and attempt_index < attempts.size() else {}
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		var next_failures := failures.duplicate()
		next_failures.append("%s failed with result %s and HTTP %s" % [str(attempt.get("label", "archive request")), result, response_code])
		_start_update_archive_sync_request_attempt(target, serial, attempts, attempt_index + 1, next_failures)
		return
	await _complete_update_archive_sync_download(target, serial, attempts, attempt_index, failures)


func _on_update_archive_sync_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray, target: Dictionary, serial: int, request_node: HTTPRequest) -> void:
	if request_node != null and is_instance_valid(request_node):
		request_node.queue_free()
	if _state == null or serial != _update_sync_request_serial:
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_mark_update_sync_failed("Update archive request failed with result %s and HTTP %s" % [result, response_code], serial)
		return
	await _complete_update_archive_sync_download(target, serial)


func _complete_update_archive_sync_download(target: Dictionary, serial: int, attempts: Array = [], attempt_index: int = -1, failures: Array = []) -> void:
	if _state == null or serial != _update_sync_request_serial:
		return
	var target_ref := str(target.get("ref", ""))
	_state.update_sync_status = _get_localized_text("settings_update_sync_writing_files")
	_state.update_sync_progress = max(float(_state.update_sync_progress), 0.68)
	_refresh_dock()
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		await tree.process_frame
	var sync_result := _sync_update_archive_to_addon(UPDATE_SYNC_ARCHIVE_PATH)
	if not bool(sync_result.get("success", false)):
		if _should_try_next_update_archive_attempt(str(sync_result.get("error", "")), attempts, attempt_index):
			var next_failures := failures.duplicate()
			var attempt: Dictionary = attempts[attempt_index] if attempt_index >= 0 and attempt_index < attempts.size() else {}
			next_failures.append("%s downloaded an unusable archive: %s" % [str(attempt.get("label", "archive request")), str(sync_result.get("error", "archive sync failed"))])
			_start_update_archive_sync_request_attempt(target, serial, attempts, attempt_index + 1, next_failures)
			return
		_mark_update_sync_failed(str(sync_result.get("error", "Update sync failed.")), serial)
		return
	var marker_error := _write_update_sync_marker(target, int(sync_result.get("written", 0)))
	if marker_error != OK:
		_mark_update_sync_failed("Update files were written, but sync marker write failed: %s" % marker_error, serial)
		return
	_state.update_sync_status = _get_localized_text("settings_update_sync_refreshing_editor")
	_state.update_sync_progress = 0.88
	_refresh_dock()
	await _complete_update_sync_after_editor_refresh(target_ref, sync_result, serial)


func _should_try_next_update_archive_attempt(error: String, attempts: Array, attempt_index: int) -> bool:
	if attempt_index < 0 or attempt_index + 1 >= attempts.size():
		return false
	return error.begins_with("Failed to open branch archive") or error.begins_with("Branch archive does not contain")


func _format_update_archive_failures(failures: Array) -> String:
	if failures.is_empty():
		return "Update archive request failed before a download could start."
	var details: Array[String] = []
	for failure in failures:
		details.append(str(failure))
	return "Update archive request failed after %s attempt(s): %s" % [details.size(), "; ".join(details)]


func _complete_update_sync_after_editor_refresh(target_ref: String, sync_result: Dictionary, serial: int) -> void:
	var refresh_result: Dictionary = await _request_update_sync_editor_refresh(serial)
	if _state == null or serial != _update_sync_request_serial:
		return
	if not bool(refresh_result.get("success", false)):
		_mark_update_sync_failed(_get_localized_text("settings_update_sync_refresh_timeout"), serial)
		return
	_state.update_sync_state = "success"
	_state.update_sync_error = ""
	_state.update_sync_status = _get_localized_text("settings_update_sync_success") % [target_ref, int(sync_result.get("written", 0))]
	_state.update_sync_progress = 1.0
	_refresh_update_compare_for_current_target()
	_refresh_dock()
	_request_update_sync_lifecycle_reload()


func _request_update_sync_lifecycle_reload() -> void:
	if _plugin_reenable_pending:
		return
	_request_plugin_lifecycle_reload("settings_sync")


func _request_update_sync_editor_refresh(_serial: int) -> Dictionary:
	var file_system = null
	var editor_interface = get_editor_interface()
	if editor_interface != null:
		file_system = editor_interface.get_resource_filesystem()
	if file_system != null:
		file_system.scan()
	var tree := get_tree()
	var scan_completed := true
	if tree != null:
		await tree.process_frame
		if file_system != null and file_system.has_method("is_scanning"):
			var deadline_msec := Time.get_ticks_msec() + UPDATE_SYNC_EDITOR_REFRESH_TIMEOUT_MS
			scan_completed = not bool(file_system.is_scanning())
			while not scan_completed and Time.get_ticks_msec() < deadline_msec:
				await tree.process_frame
				scan_completed = not bool(file_system.is_scanning())
	return {
		"success": scan_completed,
		"scan_requested": file_system != null,
		"scan_completed": scan_completed
	}


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
	return _plugin_update_sync_mirror_service.sync_archive_to_addon(archive_path, _get_update_sync_addon_root())


func _get_update_sync_addon_root() -> String:
	return UPDATE_SYNC_ADDON_ROOT


func _cleanup_stale_update_sync_addon_files() -> Dictionary:
	var result := _plugin_update_sync_mirror_service.cleanup_stale_addon_files(_get_update_sync_addon_root())
	var deleted := int(result.get("deleted", 0))
	if deleted > 0:
		MCPDebugBuffer.record("info", "plugin", "Removed %s stale update sync addon file(s)" % deleted)
	return result


func _find_update_archive_addon_prefix(files: PackedStringArray) -> String:
	return _plugin_update_sync_mirror_service.find_archive_addon_prefix(files)


func _normalize_update_sync_relative_path(relative_path: String) -> String:
	return _plugin_update_sync_mirror_service.normalize_relative_path(relative_path)


func _validate_update_sync_archive_files(expected_files: Dictionary) -> String:
	return _plugin_update_sync_mirror_service.validate_archive_files(expected_files)


func _should_skip_update_sync_path(relative_path: String) -> bool:
	return _plugin_update_sync_mirror_service.should_skip_path(relative_path)


func _delete_update_sync_stale_paths(addon_root: String, expected_files: Dictionary) -> Dictionary:
	return _plugin_update_sync_mirror_service.delete_stale_paths(addon_root, expected_files)


func _is_update_sync_directory_empty(path: String) -> bool:
	return _plugin_update_sync_mirror_service.is_directory_empty(path)


func _is_update_sync_path_inside_root(addon_root: String, path: String) -> bool:
	return _plugin_update_sync_mirror_service.is_path_inside_root(addon_root, path)


func _is_update_sync_path_or_ancestor_link(addon_root: String, relative_path: String) -> bool:
	return _plugin_update_sync_mirror_service.is_path_or_ancestor_link(addon_root, relative_path)


func _is_update_sync_link_path(path: String) -> bool:
	return _plugin_update_sync_mirror_service.is_link_path(path)


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
		_fail_pending_update_sync_after_refs_discovery("Update target discovery failed before sync: %s" % _state.update_refs_error)
	var continued_sync := _continue_pending_update_sync_after_refs_discovery()
	if continued_sync:
		return
	_refresh_dock()


func _continue_pending_update_sync_after_refs_discovery() -> bool:
	if not _update_sync_after_refs_discovery_pending or _state == null:
		return false
	if str(_state.update_refs_state) != "success":
		return false
	var target := _resolve_update_sync_target()
	var target_ref := str(target.get("ref", "")).strip_edges()
	if target_ref.is_empty():
		_update_sync_after_refs_discovery_pending = false
		_state.update_sync_state = "error"
		_state.update_sync_error = _localization.get_text("settings_update_sync_no_target") if _localization != null else "Select an update target before syncing."
		_state.update_sync_status = ""
		return false
	_update_sync_after_refs_discovery_pending = false
	return _request_update_sync(target, "refs_discovery")


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
	return _ensure_plugin_update_tool_facade().build_current_response()


func get_plugin_update_status_from_tools() -> Dictionary:
	return _ensure_plugin_update_tool_facade().build_status_response(_build_plugin_update_status_snapshot())


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
	return _build_plugin_update_tool_response({
		"success": true,
		"accepted": false,
		"loading": str(_state.update_refs_state) == "loading",
		"status": "selected",
		"data": data,
		"message": "Plugin update source selected"
	})


func discover_plugin_update_refs_from_tools(force_refresh: bool = true) -> Dictionary:
	var accepted := _ensure_update_refs_discovery_requested(force_refresh)
	var action_status := _resolve_plugin_update_request_status("refs", accepted)
	var data := _build_plugin_update_status_snapshot()
	data["accepted"] = accepted
	data["action_status"] = action_status
	return _build_plugin_update_tool_response({
		"success": true,
		"accepted": accepted,
		"loading": str(_state.update_refs_state) == "loading",
		"status": action_status,
		"data": data,
		"message": "Plugin update ref discovery requested"
	})


func start_plugin_update_sync_from_tools() -> Dictionary:
	if str(_state.update_sync_state) == "loading":
		var loading_data := _build_plugin_update_status_snapshot()
		loading_data["accepted"] = false
		loading_data["action_status"] = "loading"
		return _build_plugin_update_tool_response({
			"success": true,
			"accepted": false,
			"loading": true,
			"status": "loading",
			"data": loading_data,
			"message": "Plugin update sync is already running"
		})
	var target := _resolve_update_sync_target()
	var target_ref := str(target.get("ref", "")).strip_edges()
	if target_ref.is_empty():
		if _should_discover_update_target_before_sync():
			_update_sync_after_refs_discovery_pending = true
			var discovery_accepted := _ensure_update_refs_discovery_requested(true)
			var discovery_data := _build_plugin_update_status_snapshot()
			var discovery_loading := str(_state.update_refs_state) == "loading" or _update_refs_discovery_retry_pending
			discovery_data["accepted"] = discovery_accepted or discovery_loading
			discovery_data["discovery_accepted"] = discovery_accepted
			discovery_data["pending_sync_after_refs_discovery"] = _update_sync_after_refs_discovery_pending
			discovery_data["next_action"] = "poll_update_status"
			discovery_data["action_status"] = "preparing_sync" if discovery_loading else _resolve_plugin_update_request_status("refs", discovery_accepted)
			return _build_plugin_update_tool_response({
				"success": true,
				"accepted": bool(discovery_data.get("accepted", false)),
				"loading": discovery_loading,
				"status": str(discovery_data.get("action_status", "")),
				"data": discovery_data,
				"message": "Plugin update target discovery started before sync"
			})
		_on_update_sync_requested()
		var missing_target_data := _build_plugin_update_status_snapshot()
		missing_target_data["accepted"] = false
		missing_target_data["action_status"] = str(_state.update_sync_state)
		return _build_plugin_update_tool_response({
			"success": true,
			"accepted": false,
			"loading": false,
			"status": str(_state.update_sync_state),
			"data": missing_target_data,
			"message": "Plugin update sync target is unavailable"
		})
	if _get_update_request_parent() == null:
		var unavailable_data := _build_plugin_update_status_snapshot()
		unavailable_data["accepted"] = false
		unavailable_data["action_status"] = "unavailable"
		return _build_plugin_update_tool_response({
			"success": true,
			"accepted": false,
			"loading": false,
			"status": "unavailable",
			"data": unavailable_data,
			"message": "Plugin update sync request host is unavailable"
		})
	_request_update_sync(target, "tool")
	var data := _build_plugin_update_status_snapshot()
	data["accepted"] = str(_state.update_sync_state) == "loading"
	data["action_status"] = _resolve_plugin_update_request_status("sync", bool(data.get("accepted", false)))
	return _build_plugin_update_tool_response({
		"success": true,
		"accepted": bool(data.get("accepted", false)),
		"loading": str(_state.update_sync_state) == "loading",
		"status": str(data.get("action_status", "")),
		"data": data,
		"message": "Plugin update sync requested"
	})


func _should_discover_update_target_before_sync() -> bool:
	var source := _normalize_update_source(str(_state.settings.get("update_source", "latest_stable")))
	return source == "latest_stable" or source == "latest_release"


func _ensure_plugin_update_tool_facade():
	if _plugin_update_tool_facade == null:
		_plugin_update_tool_facade = PluginUpdateToolFacadeServiceScript.new()
	return _plugin_update_tool_facade


func _build_plugin_update_tool_context(target: Dictionary = {}) -> Dictionary:
	if target.is_empty():
		target = _resolve_update_sync_target()
	var source := _normalize_update_source(str(_state.settings.get("update_source", "latest_stable")))
	return {
		"source": source,
		"custom_branch": str(_state.settings.get("update_custom_branch", "")),
		"release_tag": str(_state.settings.get("update_release_tag", "")),
		"target": target,
		"current_commit": _resolve_current_update_commit(),
		"request_host_available": _get_update_request_parent() != null,
		"discovery_retry_pending": _update_refs_discovery_retry_pending,
		"pending_sync_after_refs_discovery": _update_sync_after_refs_discovery_pending,
		"refs_state": str(_state.update_refs_state),
		"refs_status": str(_state.update_refs_status),
		"refs_error": str(_state.update_refs_error),
		"branches": _state.update_ref_branches,
		"releases": _state.update_ref_releases,
		"latest_stable_release": str(_state.update_ref_latest_stable_release),
		"latest_release": str(_state.update_ref_latest_release),
		"release_source": str(_state.update_refs_release_source),
		"commits": _state.update_ref_commits,
		"versions": _state.update_ref_versions,
		"compare_state": str(_state.update_compare_state),
		"compare_error": str(_state.update_compare_error),
		"compare_base_commit": str(_state.update_compare_base_commit),
		"compare_target_ref": str(_state.update_compare_target_ref),
		"compare_target_commit": str(_state.update_compare_target_commit),
		"compare_ahead_by": int(_state.update_compare_ahead_by),
		"compare_behind_by": int(_state.update_compare_behind_by),
		"sync_state": str(_state.update_sync_state),
		"sync_status": str(_state.update_sync_status),
		"sync_error": str(_state.update_sync_error),
		"sync_target_ref": str(_state.update_sync_target_ref),
		"sync_target_kind": str(_state.update_sync_target_kind)
	}


func _build_plugin_update_current_snapshot() -> Dictionary:
	return _ensure_plugin_update_tool_facade().build_current_snapshot()


func _build_plugin_update_status_snapshot() -> Dictionary:
	var target := _resolve_update_sync_target()
	return _ensure_plugin_update_tool_facade().build_status_snapshot(_build_plugin_update_tool_context(target))


func _build_plugin_update_tool_response(response: Dictionary) -> Dictionary:
	return _ensure_plugin_update_tool_facade().enrich_tool_response(response)


func _build_plugin_update_refs_status() -> Dictionary:
	return _ensure_plugin_update_tool_facade().build_refs_status(_build_plugin_update_tool_context())


func _build_plugin_update_compare_status() -> Dictionary:
	return _ensure_plugin_update_tool_facade().build_compare_status(_build_plugin_update_tool_context())


func _build_plugin_update_sync_status() -> Dictionary:
	return _ensure_plugin_update_tool_facade().build_sync_status(_build_plugin_update_tool_context())


func _resolve_plugin_update_overall_status() -> String:
	return _ensure_plugin_update_tool_facade().resolve_overall_status(_build_plugin_update_tool_context())


func _resolve_plugin_update_request_status(kind: String, accepted: bool) -> String:
	return _ensure_plugin_update_tool_facade().resolve_request_status(kind, accepted, _build_plugin_update_tool_context())


func _shorten_plugin_update_fingerprint(source_fingerprint: String) -> String:
	return _ensure_plugin_update_tool_facade().shorten_fingerprint(source_fingerprint)


func _request_plugin_lifecycle_reload(source: String = "unknown") -> Dictionary:
	if _plugin_reenable_pending:
		var pending_freshness := PluginInstanceFreshness.get_freshness_snapshot()
		var pending_maintenance := MCPMaintenanceContract.build_from_freshness(pending_freshness)
		return MCPMaintenanceContract.enrich_response({
			"success": false,
			"error": "Plugin lifecycle reload already scheduled",
			"data": {"freshness": pending_freshness}
		}, pending_maintenance)
	var focus_snapshot := {}
	if _dock and is_instance_valid(_dock) and _dock.has_method("capture_focus_snapshot"):
		focus_snapshot = _dock.capture_focus_snapshot()
	_store_pending_focus_snapshot(focus_snapshot)
	_save_settings()
	var lifecycle_reload: Dictionary = PluginInstanceFreshness.mark_lifecycle_reload_requested(source)
	var freshness := PluginInstanceFreshness.get_freshness_snapshot()
	var maintenance := MCPMaintenanceContract.build_from_lifecycle(lifecycle_reload, freshness)
	if not _schedule_plugin_reenable_deferred():
		lifecycle_reload = PluginInstanceFreshness.mark_lifecycle_reload_failed("Plugin lifecycle reload bridge is unavailable", str(lifecycle_reload.get("last_request_id", "")))
		freshness = PluginInstanceFreshness.get_freshness_snapshot()
		maintenance = MCPMaintenanceContract.build_from_lifecycle(lifecycle_reload, freshness)
		return MCPMaintenanceContract.enrich_response({
			"success": false,
			"error": "Plugin lifecycle reload bridge is unavailable",
			"data": {"lifecycle_reload": lifecycle_reload, "freshness": freshness}
		}, maintenance)
	_plugin_reenable_pending = true
	return MCPMaintenanceContract.enrich_response({
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
			"freshness": freshness,
			"reconnect_hint": str(maintenance.get("reconnect_hint", ""))
		}
	}, maintenance)


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
	_ensure_plugin_profile_config_service().apply_tool_profile(_build_plugin_profile_config_context(), profile_id)
	_refresh_dock()


func _save_custom_profile(profile_name: String) -> Dictionary:
	return _ensure_plugin_profile_config_service().save_custom_profile(_build_plugin_profile_config_context(), profile_name)


func _rename_custom_profile(profile_id: String, profile_name: String) -> Dictionary:
	return _ensure_plugin_profile_config_service().rename_custom_profile(_build_plugin_profile_config_context(), profile_id, profile_name)


func _delete_custom_profile(profile_id: String) -> Dictionary:
	return _ensure_plugin_profile_config_service().delete_custom_profile(_build_plugin_profile_config_context(), profile_id)


func _is_builtin_profile_id(profile_id: String) -> bool:
	return not profile_id.begins_with("custom:")


func _get_custom_profile_error_text(error_code: String) -> String:
	return _ensure_plugin_profile_config_service().map_custom_profile_error(_localization, error_code)


func _get_tool_config_error_text(error_code: String) -> String:
	return _ensure_plugin_profile_config_service().map_tool_config_error(_localization, error_code)


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
	_defer_tree_collapse_save()


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


func _on_mcp_catalog_preview_requested(kind: String, id: String, arguments: Dictionary) -> void:
	if _mcp_catalog_preview_service == null:
		_mcp_catalog_preview_service = DockMcpCatalogPreviewServiceScript.new()
	_mcp_catalog_preview_service.configure(_server_controller)
	_state.mcp_catalog_preview = _mcp_catalog_preview_service.build_preview(kind, id, arguments)
	_refresh_dock()


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
	if _runtime_reload_request_service == null:
		_runtime_reload_request_service = PluginRuntimeReloadRequestServiceScript.new()
	if not script_path.is_empty():
		return _runtime_reload_request_service.request_reload_by_script(script_path, reason, _server_controller)
	return _runtime_reload_request_service.request_reload("user", reason, _server_controller)


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


func get_user_tool_runtime_diagnostics_from_tools(limit: int = 10, runtime_state: Array = []) -> Dictionary:
	return {
		"success": true,
		"data": _user_tool_service.get_runtime_diagnostics(_get_user_tool_watch_status(), limit, runtime_state)
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
	if _state != null and _state.current_tab == 5:
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
	return _ensure_plugin_self_diagnostics_service().build_health_response(_build_self_diagnostics_context())


func get_self_diagnostic_errors_from_tools(severity: String = "", category: String = "", limit: int = 20) -> Dictionary:
	return _ensure_plugin_self_diagnostics_service().build_errors_response(severity, category, limit)


func get_self_diagnostic_timeline_from_tools(limit: int = 20) -> Dictionary:
	return _ensure_plugin_self_diagnostics_service().build_timeline_response(limit)


func clear_self_diagnostics_from_tools() -> Dictionary:
	var response = _ensure_plugin_self_diagnostics_service().build_clear_response()
	_refresh_dock()
	return response


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
	return _ensure_plugin_developer_settings_service().build_settings_response(_build_plugin_developer_settings_context())


func set_language_from_tools(language_code: String) -> Dictionary:
	var validation = _ensure_plugin_developer_settings_service().validate_language(_localization, language_code)
	if not bool(validation.get("success", false)):
		return validation
	_on_language_changed(language_code)
	return _ensure_plugin_developer_settings_service().build_language_set_response(_state, _localization)


func get_languages_for_tools() -> Dictionary:
	return _ensure_plugin_developer_settings_service().build_languages_response(_state, _localization)


func list_profiles_from_tools() -> Dictionary:
	return _ensure_plugin_developer_settings_service().build_profiles_response(_state, PluginRuntimeStateScript.BUILTIN_TOOL_PROFILES)


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
	return _ensure_plugin_profile_config_service().export_config(_build_plugin_profile_config_context(), file_path)


func import_config_from_tools(file_path: String) -> Dictionary:
	var response = _ensure_plugin_profile_config_service().import_config(_build_plugin_profile_config_context(), file_path)
	if bool(response.get("success", false)):
		_cleanup_disabled_tools()
		_save_settings()
		_refresh_dock()
	return response


func get_runtime_usage_guide_from_tools() -> Dictionary:
	return _ensure_plugin_usage_guide_service().build_runtime_usage_guide()


func get_evolution_usage_guide_from_tools() -> Dictionary:
	return _ensure_plugin_usage_guide_service().build_evolution_usage_guide()


func get_usage_guide_from_tools() -> Dictionary:
	return _ensure_plugin_usage_guide_service().build_developer_usage_guide()


func _ensure_plugin_usage_guide_service():
	if _plugin_usage_guide_service == null:
		_plugin_usage_guide_service = PluginUsageGuideServiceScript.new()
	return _plugin_usage_guide_service


func _get_editor_scale() -> float:
	var editor_interface = get_editor_interface()
	if editor_interface:
		return float(editor_interface.get_editor_scale())
	return 1.0


func _build_self_diagnostic_health_snapshot() -> Dictionary:
	return _ensure_plugin_self_diagnostics_service().build_health_snapshot(_build_self_diagnostics_context())


func _build_self_diagnostics_context() -> Dictionary:
	return {
		"server_controller": _server_controller,
		"runtime_bridge_autoload_name": RUNTIME_BRIDGE_AUTOLOAD_NAME,
		"runtime_bridge_root_instance_present": _has_runtime_bridge_root_instance(),
		"dock_present": _dock != null and is_instance_valid(_dock),
		"dock_count": _count_dock_instances(),
		"process_performance_status": _get_process_performance_status(),
		"user_tool_watch_status": _get_user_tool_watch_status()
	}


func _ensure_plugin_self_diagnostics_service():
	if _plugin_self_diagnostics_service == null:
		_plugin_self_diagnostics_service = PluginSelfDiagnosticsServiceScript.new()
	return _plugin_self_diagnostics_service


func _build_plugin_profile_config_context() -> Dictionary:
	return {
		"state": _state,
		"settings_store": _settings_store,
		"tool_catalog": _tool_catalog,
		"server_controller": _server_controller,
		"localization": _localization,
		"settings_path": PluginRuntimeStateScript.SETTINGS_PATH,
		"profile_dir": PluginRuntimeStateScript.TOOL_PROFILE_DIR,
		"builtin_profiles": PluginRuntimeStateScript.BUILTIN_TOOL_PROFILES
	}


func _ensure_plugin_profile_config_service():
	if _plugin_profile_config_service == null:
		_plugin_profile_config_service = PluginProfileConfigServiceScript.new()
	return _plugin_profile_config_service


func _build_plugin_developer_settings_context() -> Dictionary:
	return {
		"state": _state,
		"localization": _localization,
		"log_level": get_log_level_for_tools()
	}


func _ensure_plugin_developer_settings_service():
	if _plugin_developer_settings_service == null:
		_plugin_developer_settings_service = PluginDeveloperSettingsServiceScript.new()
	return _plugin_developer_settings_service


func _ensure_plugin_client_config_state_service():
	if _plugin_client_config_state_service == null:
		_plugin_client_config_state_service = PluginClientConfigStateServiceScript.new()
	return _plugin_client_config_state_service


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
	if _state.current_tab == 5:
		_ensure_update_refs_discovery_requested()

func _schedule_plugin_reenable() -> bool:
	return _config_reload_wiring_service.schedule_plugin_reenable(_get_config_reload_wiring_context())


func _schedule_plugin_reenable_deferred() -> bool:
	return _config_reload_wiring_service.schedule_plugin_reenable_deferred(_get_config_reload_wiring_context())


func _complete_plugin_reenable_schedule() -> void:
	if not _schedule_plugin_reenable():
		return


func _create_reload_coordinator():
	return _config_reload_wiring_service.create_reload_coordinator(_get_config_reload_wiring_context())


func _configure_user_tool_watch_service() -> void:
	_user_tool_watch_service = _config_reload_wiring_service.configure_user_tool_watch_service(
		_user_tool_watch_service,
		_get_config_reload_wiring_context()
	)
	_invalidate_plugin_lifecycle_context()


func _configure_config_tab_action_service() -> void:
	_config_tab_action_service = _config_reload_wiring_service.configure_config_tab_action_service(
		_config_tab_action_service,
		_get_config_reload_wiring_context()
	)


func _get_user_tool_watch_status() -> Dictionary:
	if _user_tool_watch_service == null:
		return {}
	return _user_tool_watch_service.get_status()


func _install_performance_monitors() -> void:
	if _performance_monitor == null:
		_performance_monitor = PluginPerformanceMonitorScript.new()
	_performance_monitor.install_custom_monitors()


func _remove_performance_monitors() -> void:
	if _performance_monitor != null:
		_performance_monitor.remove_custom_monitors()


func _record_process_perf(started_usec: int, delta: float) -> void:
	if _performance_monitor == null:
		_performance_monitor = PluginPerformanceMonitorScript.new()
	_performance_monitor.record_process_frame(started_usec, delta)


func _get_process_performance_status() -> Dictionary:
	if _performance_monitor == null:
		_performance_monitor = PluginPerformanceMonitorScript.new()
	return _performance_monitor.get_status()


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
	_invalidate_config_reload_wiring_context()
	_settings_store = SettingsStoreScript.new()
	if _server_controller == null:
		_server_controller = ServerRuntimeControllerScript.new()
	_tool_catalog = ToolCatalogServiceScript.new()
	_config_service = ClientConfigServiceScript.new()
	if _dock_model_service == null:
		_dock_model_service = DockModelServiceScript.new()
	_plugin_client_config_state_service = PluginClientConfigStateServiceScript.new()
	_user_tool_service = UserToolServiceScript.new()


func _ensure_runtime_state() -> void:
	if _state == null:
		_state = PluginRuntimeStateScript.new()
