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
const PluginRuntimeReloadCompletionServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_reload_completion_service.gd")
const MCPEditorDebuggerBridge = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_editor_debugger_bridge.gd")
const MCPRuntimeDebugStore = preload("res://addons/godot_dotnet_mcp/tools/shared/mcp_runtime_debug_store.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const PluginInstanceFreshness = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_instance_freshness.gd")
const MCPMaintenanceContract = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_maintenance_contract.gd")
const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const PluginPerformanceMonitorScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_performance_monitor.gd")
const PluginUpdateToolFacadeServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_tool_facade_service.gd")
const PluginUpdateSyncMirrorServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_sync_mirror_service.gd")
const PluginUpdateRequestPlanningServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_request_planning_service.gd")
const PluginUpdateRefsDiscoveryServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_refs_discovery_service.gd")
const PluginUpdateCompareServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_compare_service.gd")
const PluginUpdateStateTransitionServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_state_transition_service.gd")
const PluginUpdateEndpointConfigServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_endpoint_config_service.gd")
const PluginUpdateHttpRequestServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_http_request_service.gd")
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
const UPDATE_REQUEST_MAINTENANCE_TICK_INTERVAL_SEC := 1.0
const UPDATE_REFS_STALE_REQUEST_GRACE_SEC := 2.0

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
var _runtime_reload_completion_service := PluginRuntimeReloadCompletionServiceScript.new()
var _plugin_update_tool_facade := PluginUpdateToolFacadeServiceScript.new()
var _plugin_update_sync_mirror_service := PluginUpdateSyncMirrorServiceScript.new()
var _plugin_update_request_planning_service := PluginUpdateRequestPlanningServiceScript.new()
var _plugin_update_refs_discovery_service := PluginUpdateRefsDiscoveryServiceScript.new()
var _plugin_update_compare_service := PluginUpdateCompareServiceScript.new()
var _plugin_update_state_transition_service := PluginUpdateStateTransitionServiceScript.new()
var _plugin_update_endpoint_config_service := PluginUpdateEndpointConfigServiceScript.new()
var _plugin_update_http_request_service := PluginUpdateHttpRequestServiceScript.new()
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
var _update_request_maintenance_tick_accumulator := 0.0
var _editor_debugger_bridge: EditorDebuggerPlugin
var _pending_runtime_reload_action := ""
var _plugin_reenable_pending := false
var _dock_recreate_pending := false
var _dock_recreate_attempted := false
var _update_refs_request_serial := 0
var _update_refs_pending := {}
var _update_refs_discovery_loaded := false
var _update_refs_discovery_retry_pending := false
var _update_refs_background_serials := {}
var _update_commit_histories_fallback: Dictionary = {}
var _update_sync_after_refs_discovery_pending := false
var _update_sync_pending_target_ref := ""
var _update_sync_pending_target_kind := ""
var _update_sync_pending_refs_refresh_required := false
var _update_sync_pending_manual_switch := false
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
	_tick_update_request_maintenance(delta)
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
	return


func _request_startup_update_refs_refresh() -> void:
	# Kept as a regression hook: startup update state is restored from cache only.
	return


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
	_runtime_reload_completion_service = null
	_config_reload_context_service = null
	_plugin_update_tool_facade = null
	_plugin_update_sync_mirror_service = null
	_plugin_update_request_planning_service = null
	_plugin_update_refs_discovery_service = null
	_plugin_update_compare_service = null
	_plugin_update_state_transition_service = null
	_plugin_update_endpoint_config_service = null
	_plugin_update_http_request_service = null
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
	_invalidate_plugin_lifecycle_context()


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
	_invalidate_plugin_lifecycle_context()


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
	_restore_update_refs_cache()
	_configure_client_install_detection_service()


func _save_settings() -> void:
	if _state == null:
		return
	if _settings_store == null:
		_settings_store = SettingsStoreScript.new()
	_settings_store.save_plugin_settings(PluginRuntimeStateScript.SETTINGS_PATH, _state.settings)


func _restore_update_refs_cache() -> void:
	if _state == null:
		return
	if _settings_store == null:
		_settings_store = SettingsStoreScript.new()
	var cache: Dictionary = _settings_store.load_update_refs_cache(PluginRuntimeStateScript.UPDATE_REFS_CACHE_PATH)
	if cache.is_empty():
		return
	_apply_update_refs_cache(cache)


func _apply_update_refs_cache(cache: Dictionary) -> void:
	_state.update_refs_state = "success"
	_state.update_refs_status = ""
	_state.update_refs_error = ""
	_state.update_refs_refresh_state = "idle"
	_state.update_refs_refresh_error = ""
	_state.update_refs_last_checked_unix = int(cache.get("last_checked_unix", 0))
	_state.update_refs_last_trigger = str(cache.get("last_trigger", "")).strip_edges()
	_state.update_refs_last_http_status = int(cache.get("last_http_status", 0))
	_state.update_ref_branches = _to_string_array(cache.get("branches", []))
	_state.update_ref_releases = _to_string_array(cache.get("releases", []))
	_state.update_ref_latest_stable_release = str(cache.get("latest_stable_release", "")).strip_edges()
	_state.update_ref_latest_release = str(cache.get("latest_release", "")).strip_edges()
	_state.update_refs_release_source = str(cache.get("release_source", "")).strip_edges()
	_state.update_ref_commits = _duplicate_update_ref_commits(cache.get("commits", {}))
	_state.update_ref_versions = _duplicate_update_ref_commits(cache.get("versions", {}))
	_state.update_ref_release_rows = _duplicate_update_ref_rows(cache.get("release_rows", []))
	_state.update_ref_branch_commit_rows = _duplicate_update_branch_commit_rows(cache.get("branch_commit_rows", {}))
	_set_update_commit_histories(cache.get("commit_histories", {}))
	_update_refs_discovery_loaded = true
	_refresh_update_compare_for_current_target()


func _save_update_refs_cache() -> void:
	if _state == null:
		return
	if _settings_store == null:
		_settings_store = SettingsStoreScript.new()
	_settings_store.save_update_refs_cache(PluginRuntimeStateScript.UPDATE_REFS_CACHE_PATH, _build_update_refs_cache_snapshot())


func _build_update_refs_cache_snapshot() -> Dictionary:
	return {
		"saved_unix": int(Time.get_unix_time_from_system()),
		"last_checked_unix": int(_state.update_refs_last_checked_unix),
		"last_trigger": str(_state.update_refs_last_trigger),
		"last_http_status": int(_state.update_refs_last_http_status),
		"branches": _state.update_ref_branches,
		"releases": _state.update_ref_releases,
		"latest_stable_release": str(_state.update_ref_latest_stable_release),
		"latest_release": str(_state.update_ref_latest_release),
		"release_source": str(_state.update_refs_release_source),
		"commits": _state.update_ref_commits,
		"versions": _state.update_ref_versions,
		"release_rows": _state.update_ref_release_rows,
		"branch_commit_rows": _state.update_ref_branch_commit_rows,
		"commit_histories": _get_update_commit_histories()
	}


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
	_sweep_stale_update_refs_requests()
	_sync_current_tab_from_dock()
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
		"update_source",
		"update_custom_branch",
		"update_release_tag",
		"update_refs_state",
		"update_refs_refresh_state",
		"update_refs_refresh_error",
		"update_refs_last_checked_unix",
		"update_refs_refresh_serial",
		"update_refs_pending_signature",
		"update_refs_branch_count",
		"update_refs_release_count",
		"update_refs_latest_stable_release",
		"update_refs_latest_release",
		"update_refs_commit_signature",
		"update_refs_version_signature",
		"update_refs_release_row_signature",
		"update_refs_branch_commit_row_signature",
		"update_refs_last_trigger",
		"update_refs_last_requested_unix",
		"update_refs_last_http_status",
		"update_refs_rate_limit_remaining",
		"update_refs_rate_limit_reset_unix",
		"update_refs_rate_limit_retry_after",
		"update_compare_state",
		"update_compare_refresh_state",
		"update_compare_refresh_error",
		"update_compare_last_checked_unix",
		"update_compare_refresh_serial",
		"update_compare_target_ref",
		"update_compare_target_commit",
		"update_compare_ahead_by",
		"update_compare_behind_by",
		"update_selected_target_kind",
		"update_selected_target_ref",
		"update_selected_target_commit",
		"update_selection_refresh_pending",
		"update_selection_refresh_pending_ref",
		"update_sync_state",
		"update_sync_status",
		"update_sync_pending_target_ref",
		"update_sync_pending_target_kind"
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
		"update_source": str(_state.settings.get("update_source", "")),
		"update_custom_branch": str(_state.settings.get("update_custom_branch", "")),
		"update_release_tag": str(_state.settings.get("update_release_tag", "")),
		"update_refs_state": str(_get_state_value("update_refs_state", "idle")),
		"update_refs_refresh_state": str(_get_state_value("update_refs_refresh_state", "idle")),
		"update_refs_refresh_error": str(_get_state_value("update_refs_refresh_error", "")),
		"update_refs_last_checked_unix": int(_get_state_value("update_refs_last_checked_unix", 0)),
		"update_refs_refresh_serial": int(_get_state_value("update_refs_refresh_serial", 0)),
		"update_refs_pending_signature": _build_update_refs_pending_signature(),
		"update_refs_branch_count": (_get_state_value("update_ref_branches", []) as Array).size(),
		"update_refs_release_count": (_get_state_value("update_ref_releases", []) as Array).size(),
		"update_refs_latest_stable_release": str(_get_state_value("update_ref_latest_stable_release", "")),
		"update_refs_latest_release": str(_get_state_value("update_ref_latest_release", "")),
		"update_refs_commit_signature": _build_string_dictionary_signature(_get_state_value("update_ref_commits", {})),
		"update_refs_version_signature": _build_string_dictionary_signature(_get_state_value("update_ref_versions", {})),
		"update_refs_release_row_signature": _build_update_ref_rows_signature(_get_state_value("update_ref_release_rows", [])),
		"update_refs_branch_commit_row_signature": _build_update_branch_commit_rows_signature(_get_state_value("update_ref_branch_commit_rows", {})),
		"update_refs_last_trigger": str(_get_state_value("update_refs_last_trigger", "")),
		"update_refs_last_requested_unix": int(_get_state_value("update_refs_last_requested_unix", 0)),
		"update_refs_last_http_status": int(_get_state_value("update_refs_last_http_status", 0)),
		"update_refs_rate_limit_remaining": str(_get_state_value("update_refs_rate_limit_remaining", "")),
		"update_refs_rate_limit_reset_unix": int(_get_state_value("update_refs_rate_limit_reset_unix", 0)),
		"update_refs_rate_limit_retry_after": int(_get_state_value("update_refs_rate_limit_retry_after", 0)),
		"update_compare_state": str(_get_state_value("update_compare_state", "idle")),
		"update_compare_refresh_state": str(_get_state_value("update_compare_refresh_state", "idle")),
		"update_compare_refresh_error": str(_get_state_value("update_compare_refresh_error", "")),
		"update_compare_last_checked_unix": int(_get_state_value("update_compare_last_checked_unix", 0)),
		"update_compare_refresh_serial": int(_get_state_value("update_compare_refresh_serial", 0)),
		"update_compare_target_ref": str(_get_state_value("update_compare_target_ref", "")),
		"update_compare_target_commit": str(_get_state_value("update_compare_target_commit", "")),
		"update_compare_ahead_by": int(_get_state_value("update_compare_ahead_by", -1)),
		"update_compare_behind_by": int(_get_state_value("update_compare_behind_by", -1)),
		"update_selected_target_kind": str(_get_state_value("update_selected_target_kind", "")),
		"update_selected_target_ref": str(_get_state_value("update_selected_target_ref", "")),
		"update_selected_target_commit": str(_get_state_value("update_selected_target_commit", "")),
		"update_selection_refresh_pending": bool(_get_state_value("update_selection_refresh_pending", false)),
		"update_selection_refresh_pending_ref": str(_get_state_value("update_selection_refresh_pending_ref", "")),
		"update_sync_state": str(_get_state_value("update_sync_state", "idle")),
		"update_sync_status": str(_get_state_value("update_sync_status", "")),
		"update_sync_pending_target_ref": str(_update_sync_pending_target_ref),
		"update_sync_pending_target_kind": str(_update_sync_pending_target_kind)
	}


func _get_state_value(property_name: String, default_value = null):
	if _state == null:
		return default_value
	var value = _state.get(property_name)
	return default_value if value == null else value


func _build_string_dictionary_signature(raw_value) -> String:
	if not (raw_value is Dictionary):
		return ""
	var dictionary: Dictionary = raw_value
	var keys := dictionary.keys()
	keys.sort()
	var parts := PackedStringArray()
	for key in keys:
		parts.append("%s=%s" % [str(key), str(dictionary.get(key, ""))])
	return "|".join(parts)


func _build_update_ref_rows_signature(raw_value) -> String:
	if not (raw_value is Array):
		return ""
	var parts: Array[String] = []
	for row in raw_value as Array:
		if not (row is Dictionary):
			continue
		var row_dict := row as Dictionary
		parts.append("%s:%s:%s:%s" % [
			str(row_dict.get("kind", "")),
			str(row_dict.get("ref", "")),
			str(row_dict.get("commit", "")),
			str(row_dict.get("date", ""))
		])
	return "|".join(parts)


func _build_update_branch_commit_rows_signature(raw_value) -> String:
	if not (raw_value is Dictionary):
		return ""
	var dictionary: Dictionary = raw_value
	var keys := dictionary.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append("%s={%s}" % [str(key), _build_update_ref_rows_signature(dictionary.get(key, []))])
	return "|".join(parts)


func _build_update_refs_pending_signature() -> String:
	var pending_status := _build_update_refs_pending_status()
	if pending_status.is_empty():
		return ""
	var waiting_parts := PackedStringArray()
	for kind in (pending_status.get("waiting_kinds", []) as Array):
		waiting_parts.append(str(kind))
	var active_parts := PackedStringArray()
	for request in (pending_status.get("active_requests", []) as Array):
		if not (request is Dictionary):
			continue
		var request_dict: Dictionary = request as Dictionary
		active_parts.append("%s:%s:%s" % [
			str(request_dict.get("kind", "")),
			int(request_dict.get("page", 0)),
			int(request_dict.get("elapsed_msec", 0))
		])
	return "serial=%s|waiting=%s|active=%s" % [
		int(pending_status.get("serial", 0)),
		",".join(waiting_parts),
		",".join(active_parts)
	]


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
	_cancel_pending_update_sync("Update sync target changed before verification completed.")
	_state.settings["update_source"] = _normalize_update_source(source)
	if _state.settings["update_source"] == "custom_branch" and str(_state.settings.get("update_custom_branch", "")).strip_edges().is_empty():
		_state.settings["update_custom_branch"] = "dev"
	_save_settings()
	_clear_update_selection_refresh_pending()
	_clear_update_target_selection()
	_reset_update_compare_state()
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


func _ensure_update_refs_discovery_requested(force_refresh: bool = false, trigger_source: String = "tool") -> bool:
	if _state == null:
		return false
	_sweep_stale_update_refs_requests()
	if str(_state.update_refs_state) == "loading" or str(_state.update_sync_state) == "loading":
		return false
	if not force_refresh and str(_state.update_refs_state) == "success" and _update_refs_discovery_loaded:
		_update_refs_discovery_retry_pending = false
		return false
	if _get_update_request_parent() == null:
		_update_refs_discovery_retry_pending = false
		_record_update_refs_audit(trigger_source, "skipped", 0, "No active update refs request host.", {})
		return false
	_update_refs_discovery_retry_pending = false
	_on_update_check_requested(false, trigger_source)
	return true


func _maybe_start_background_update_info_refresh() -> bool:
	return false


func _tick_update_request_maintenance(delta: float) -> void:
	_update_request_maintenance_tick_accumulator += maxf(delta, 0.0)
	if _update_request_maintenance_tick_accumulator < UPDATE_REQUEST_MAINTENANCE_TICK_INTERVAL_SEC:
		return
	_update_request_maintenance_tick_accumulator = 0.0
	_sweep_stale_update_refs_requests()


func _should_refresh_update_refs_in_background() -> bool:
	return false


func _should_refresh_update_compare_in_background() -> bool:
	return false


func _maybe_refresh_update_compare_in_background() -> bool:
	return false


func _should_refresh_update_refs_before_sync() -> bool:
	if _state == null:
		return false
	if str(_state.update_refs_state) == "loading" or str(_state.update_refs_refresh_state) == "loading":
		return true
	return false


func _should_queue_update_sync_for_verification(target: Dictionary) -> bool:
	if _state == null:
		return false
	if not _should_require_discovered_refs_for_sync(target):
		if str(_state.update_refs_state) != "success" or not _update_refs_discovery_loaded:
			return false
	if _should_refresh_update_refs_before_sync():
		return true
	var compare_refresh_state := str(_state.update_compare_refresh_state)
	if compare_refresh_state == "loading":
		return true
	return not _is_update_sync_target_verified(target, true)


func _should_require_discovered_refs_for_sync(target: Dictionary) -> bool:
	var target_kind := str(target.get("kind", "branch"))
	return target_kind != "branch"


func _start_background_update_refs_refresh() -> bool:
	return false


func _on_update_interaction_refresh_requested() -> void:
	_ensure_runtime_state()
	_refresh_dock()


func _clear_update_selection_refresh_pending() -> void:
	if _state == null:
		return
	_state.update_selection_refresh_pending = false
	_state.update_selection_refresh_pending_ref = ""


func _clear_update_target_selection() -> void:
	if _state == null:
		return
	_state.update_selected_target_kind = ""
	_state.update_selected_target_ref = ""
	_state.update_selected_target_commit = ""


func _is_update_selection_refresh_pending(target: Dictionary = {}) -> bool:
	if _state == null:
		return false
	if not bool(_state.update_selection_refresh_pending):
		return false
	var pending_ref := str(_state.update_selection_refresh_pending_ref).strip_edges()
	if pending_ref.is_empty():
		return false
	if target.is_empty():
		target = _resolve_update_sync_target()
	var target_ref := str(target.get("ref", "")).strip_edges()
	return not target_ref.is_empty() and target_ref == pending_ref


func _is_update_sync_target_verified(target: Dictionary = {}, require_compare: bool = false) -> bool:
	if _state == null:
		return false
	if target.is_empty():
		target = _resolve_update_sync_target()
	var target_ref := str(target.get("ref", "")).strip_edges()
	if target_ref.is_empty():
		return false
	if _is_update_selection_refresh_pending(target):
		return false
	if not require_compare:
		return true
	if str(_state.update_refs_state) != "success" or str(_state.update_refs_refresh_state) == "loading":
		return false
	var compare_refresh_state := str(_state.update_compare_refresh_state)
	if str(_state.update_compare_state) != "success" or compare_refresh_state == "loading" or compare_refresh_state == "error" or compare_refresh_state == "unavailable":
		return false
	if str(_state.update_compare_target_ref).strip_edges() != target_ref:
		return false
	var target_commit := str(target.get("commit", "")).strip_edges()
	if not target_commit.is_empty() and str(_state.update_compare_target_commit).strip_edges() != target_commit:
		return false
	return true


func _clear_pending_update_sync() -> void:
	_update_sync_after_refs_discovery_pending = false
	_update_sync_pending_target_ref = ""
	_update_sync_pending_target_kind = ""
	_update_sync_pending_refs_refresh_required = false
	_update_sync_pending_manual_switch = false


func _cancel_pending_update_sync(message: String) -> void:
	if _state != null and _update_sync_after_refs_discovery_pending:
		_apply_update_state_patch(_ensure_plugin_update_state_transition_service().build_pending_sync_failure(message))
	_clear_pending_update_sync()


func _prepare_pending_update_sync(target: Dictionary, manual_switch: bool = false) -> void:
	if _state == null:
		return
	var target_ref := str(target.get("ref", "")).strip_edges()
	if target_ref.is_empty():
		_clear_pending_update_sync()
		_apply_update_state_patch(_ensure_plugin_update_state_transition_service().build_pending_sync_failure(
			_localization.get_text("settings_update_sync_no_target") if _localization != null else "Select an update target before syncing."
		))
		return
	_update_sync_after_refs_discovery_pending = true
	_update_sync_pending_target_ref = target_ref
	_update_sync_pending_target_kind = str(target.get("kind", "branch"))
	_update_sync_pending_refs_refresh_required = _should_refresh_update_refs_before_sync()
	_update_sync_pending_manual_switch = manual_switch
	_state.update_sync_state = "loading"
	_state.update_sync_error = ""
	_state.update_sync_target_ref = target_ref
	_state.update_sync_target_kind = _update_sync_pending_target_kind
	if _update_sync_pending_refs_refresh_required:
		_state.update_sync_status = _get_localized_text("settings_update_sync_refreshing_refs")
		_state.update_sync_progress = 0.04
	else:
		_state.update_sync_status = _get_localized_text("settings_update_sync_verifying_target")
		_state.update_sync_progress = 0.1


func _ensure_pending_update_sync_verification() -> bool:
	if _state == null or not _update_sync_after_refs_discovery_pending:
		return false
	if _update_sync_pending_refs_refresh_required:
		_state.update_sync_status = _get_localized_text("settings_update_sync_refreshing_refs")
		_state.update_sync_progress = max(float(_state.update_sync_progress), 0.04)
		if str(_state.update_refs_state) == "loading" or str(_state.update_refs_refresh_state) == "loading":
			_update_sync_pending_refs_refresh_required = false
			_refresh_dock()
			return true
		if not _start_pending_sync_refs_refresh():
			_fail_pending_update_sync_after_refs_discovery("No active update refs request host.")
			_refresh_dock()
			return false
		_update_sync_pending_refs_refresh_required = false
		_refresh_dock()
		return true
	if str(_state.update_refs_state) == "loading" or str(_state.update_refs_refresh_state) == "loading":
		_state.update_sync_status = _get_localized_text("settings_update_sync_refreshing_refs")
		_state.update_sync_progress = max(float(_state.update_sync_progress), 0.04)
		_refresh_dock()
		return true
	if str(_state.update_refs_state) != "success" or not _update_refs_discovery_loaded:
		var target_without_refs := _resolve_update_sync_target()
		if _should_require_discovered_refs_for_sync(target_without_refs):
			_fail_pending_update_sync_after_refs_discovery("Run update ref discovery before syncing release-derived targets.")
			_refresh_dock()
			return false
		_clear_pending_update_sync()
		return _request_update_sync(target_without_refs, "manual_sync")
	var target := _resolve_update_sync_target()
	var target_ref := str(target.get("ref", "")).strip_edges()
	if target_ref.is_empty():
		_clear_pending_update_sync()
		_apply_update_state_patch(_ensure_plugin_update_state_transition_service().build_pending_sync_failure(
			_localization.get_text("settings_update_sync_no_target") if _localization != null else "Select an update target before syncing."
		))
		return false
	_update_sync_pending_target_ref = target_ref
	_update_sync_pending_target_kind = str(target.get("kind", "branch"))
	if not _is_update_sync_target_verified(target, true):
		_fail_pending_update_sync_after_refs_discovery(_get_one_click_update_guard_message())
		_refresh_dock()
		return false
	return _continue_pending_update_sync_after_refs_discovery()


func _start_pending_sync_refs_refresh() -> bool:
	return false


func _ensure_saved_update_source_discovery_requested() -> bool:
	_update_refs_discovery_retry_pending = false
	return false


func _get_update_request_parent() -> Node:
	if is_inside_tree():
		return self
	if _dock != null and is_instance_valid(_dock) and _dock.is_inside_tree():
		return _dock
	return null


func _on_update_custom_branch_changed(branch: String) -> void:
	_ensure_runtime_state()
	_cancel_pending_update_sync("Update sync target changed before verification completed.")
	_state.settings["update_custom_branch"] = branch
	_save_settings()
	_clear_update_selection_refresh_pending()
	_clear_update_target_selection()
	_reset_update_compare_state()
	_refresh_dock()


func _on_update_compare_target_selected(kind: String, target_ref: String, target_commit: String = "") -> void:
	_ensure_runtime_state()
	var normalized_ref := target_ref.strip_edges()
	if normalized_ref.is_empty():
		return
	_cancel_pending_update_sync("Update comparison target changed before verification completed.")
	_state.update_selected_target_kind = "tag" if kind == "tag" else "branch"
	_state.update_selected_target_ref = normalized_ref
	_state.update_selected_target_commit = target_commit.strip_edges()
	if _is_update_selected_branch_head(_state.update_selected_target_kind, normalized_ref, _state.update_selected_target_commit):
		_state.update_selected_target_commit = ""
	if str(_state.update_sync_state) != "loading":
		_state.update_sync_state = "idle"
		_state.update_sync_status = ""
		_state.update_sync_error = ""
		_state.update_sync_progress = 0.0
	_reset_update_compare_state()
	_refresh_update_compare_for_current_target()
	_refresh_dock()


func _get_selected_update_branch() -> String:
	if _state == null:
		return "dev"
	var branch := str(_state.settings.get("update_custom_branch", "dev")).strip_edges()
	return branch if not branch.is_empty() else "dev"


func _get_selected_update_branch_commits_url() -> String:
	var template: String = _ensure_plugin_update_endpoint_config_service().get_branch_commits_url_template()
	return template % _get_selected_update_branch().uri_encode().replace("%2F", "/")


func _on_update_check_requested(background_refresh: bool = false, trigger_source: String = "manual") -> void:
	if _is_update_refs_rate_limited():
		_record_update_refs_audit(trigger_source, "rate_limit_cooldown", int(_state.update_refs_last_http_status), _build_update_refs_rate_limit_cooldown_message(), {})
		if not background_refresh:
			_state.update_refs_state = "error"
			_state.update_refs_error = _build_update_refs_rate_limit_cooldown_message()
			_state.update_refs_status = ""
			_refresh_dock()
		return
	_update_refs_request_serial += 1
	var serial := _update_refs_request_serial
	_record_update_refs_audit(trigger_source, "started", 0, "", {})
	var pending := _build_update_refs_pending(serial, background_refresh)
	if background_refresh:
		_state.update_refs_refresh_state = "loading"
		_state.update_refs_refresh_error = ""
		_state.update_refs_refresh_serial = serial
		_update_refs_background_serials[serial] = true
	else:
		_update_refs_discovery_loaded = false
		_state.update_refs_refresh_state = "idle"
		_state.update_refs_refresh_error = ""
		_state.update_refs_refresh_serial = serial
		_update_refs_background_serials.clear()
	_update_refs_pending = pending
	if not background_refresh:
		_state.update_refs_state = "loading"
		_state.update_refs_status = _localization.get_text("settings_update_refs_loading") if _localization != null else "Loading update refs."
		_state.update_refs_error = ""
		_update_ref_version_requests_in_flight.clear()
		_reset_update_compare_state()
		_refresh_dock()
	var refs_request_urls: Dictionary = _ensure_plugin_update_endpoint_config_service().get_refs_request_urls()
	for raw_kind in _update_refs_pending.get("required_kinds", []):
		var kind := str(raw_kind)
		match kind:
			"branches", "releases", "tags":
				_start_update_refs_request(kind, str(refs_request_urls.get(kind, "")), serial)
			"branch_commits":
				_start_update_refs_request(kind, _get_selected_update_branch_commits_url(), serial)
	for head_commit in _get_pending_update_history_heads():
		_start_update_commit_history_request(head_commit, _get_update_commit_history_url(head_commit), serial)


func _build_update_refs_pending(serial: int, background_refresh: bool) -> Dictionary:
	var source := _normalize_update_source(str(_state.settings.get("update_source", "latest_stable")))
	var development := source == "custom_branch"
	var selected_branch := _get_selected_update_branch()
	var cached_branches := _to_string_array(_state.update_ref_branches)
	var cached_releases := _to_string_array(_state.update_ref_releases)
	var cached_commits := _duplicate_update_ref_commits(_state.update_ref_commits)
	var cached_release_rows := _duplicate_update_ref_rows(_state.update_ref_release_rows)
	var cached_branch_rows := _duplicate_update_branch_commit_rows(_state.update_ref_branch_commit_rows)
	if development:
		cached_branch_rows.erase(selected_branch)
	var stable_releases: Array[String] = []
	if development and not str(_state.update_ref_latest_stable_release).strip_edges().is_empty():
		stable_releases.append(str(_state.update_ref_latest_stable_release).strip_edges())
	var pending := {
		"serial": serial,
		"background": background_refresh,
		"required_kinds": ["branches", "branch_commits"] if development else ["releases", "tags"],
		"successful_kinds": [],
		"branch_done": not development,
		"release_done": development,
		"tag_done": development,
		"branch_commits_done": not development,
		"branch_commits_branch": selected_branch,
		"errors": [],
		"branches": [] if development else cached_branches,
		"releases": cached_releases if development else [],
		"stable_releases": stable_releases,
		"tags": [],
		"commits": cached_commits,
		"release_rows": cached_release_rows if development else [],
		"tag_rows": [],
		"branch_commit_rows": cached_branch_rows,
		"commit_histories": {},
		"branches_pages": 1,
		"releases_pages": 1,
		"tags_pages": 1,
		"branch_commits_pages": 1,
		"active_requests": {}
	}
	var current_commit := _resolve_current_update_commit()
	if not current_commit.is_empty():
		pending = _ensure_plugin_update_refs_discovery_service().begin_commit_history(pending, current_commit, true)
	return pending


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
	var cached_guard_message := _get_one_click_cached_target_guard_message(target)
	if not cached_guard_message.is_empty():
		_state.update_sync_state = "error"
		_state.update_sync_error = cached_guard_message
		_state.update_sync_status = ""
		_state.update_sync_progress = 0.0
		_refresh_dock()
		return
	if _is_update_sync_target_verified(target, true):
		var update_guard_message := _get_one_click_update_guard_message()
		if not update_guard_message.is_empty():
			_state.update_sync_state = "error"
			_state.update_sync_error = update_guard_message
			_state.update_sync_status = ""
			_state.update_sync_progress = 0.0
			_refresh_dock()
			return
	if _should_queue_update_sync_for_verification(target):
		_prepare_pending_update_sync(target)
		_refresh_dock()
		_ensure_pending_update_sync_verification()
		return
	_request_update_sync(target, "dock")


func _on_update_switch_requested(kind: String, target_ref: String, target_commit: String = "") -> void:
	_ensure_runtime_state()
	var normalized_ref := target_ref.strip_edges()
	if normalized_ref.is_empty():
		if _state != null:
			_state.update_sync_state = "error"
			_state.update_sync_error = _get_update_localized_text("settings_update_sync_no_target", "Select a branch or release before syncing.")
			_state.update_sync_status = ""
			_state.update_sync_progress = 0.0
			_refresh_dock()
		return
	var normalized_kind := "tag" if kind == "tag" else "branch"
	_cancel_pending_update_sync("Update sync target changed before verification completed.")
	if normalized_kind == "tag":
		_state.settings["update_source"] = "latest_release"
		_state.settings["update_release_tag"] = normalized_ref
	else:
		_state.settings["update_source"] = "custom_branch"
		_state.settings["update_custom_branch"] = normalized_ref
	_save_settings()
	_clear_update_selection_refresh_pending()
	_reset_update_compare_state()
	var resolved_commit := target_commit.strip_edges()
	if resolved_commit.is_empty():
		resolved_commit = str((_state.update_ref_commits as Dictionary).get(normalized_ref, "")).strip_edges()
	var target := {
		"kind": normalized_kind,
		"ref": normalized_ref,
		"commit": resolved_commit
	}
	_state.update_selected_target_kind = normalized_kind
	_state.update_selected_target_ref = normalized_ref
	_state.update_selected_target_commit = resolved_commit
	if _is_update_selected_branch_head(normalized_kind, normalized_ref, _state.update_selected_target_commit):
		_state.update_selected_target_commit = ""
	_request_update_sync(target, "manual_switch")


func _request_update_sync(target: Dictionary, source: String = "unknown") -> bool:
	if _state == null:
		return false
	var target_ref := str(target.get("ref", "")).strip_edges()
	if target_ref.is_empty():
		return false
	var continuing_pending_sync := ["refs_discovery", "manual_sync"].has(source) and str(_state.update_sync_state) == "loading" and str(_state.update_sync_target_ref).strip_edges() == target_ref
	if str(_state.update_sync_state) == "loading" and not continuing_pending_sync:
		_refresh_dock()
		return false
	var manual_switch := source == "manual_switch"
	var should_queue_verification := false if manual_switch else (_should_queue_update_sync_for_verification(target) if source != "refs_discovery" else not _is_update_sync_target_verified(target, true))
	if should_queue_verification:
		_prepare_pending_update_sync(target, manual_switch)
		_refresh_dock()
		_ensure_pending_update_sync_verification()
		return false
	_clear_pending_update_sync()
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
	var planned: Dictionary = _ensure_plugin_update_request_planning_service().resolve_sync_target(_state.settings, _build_update_refs_planning_context())
	if _state == null:
		return planned
	var selected_ref := str(_state.update_selected_target_ref).strip_edges()
	if selected_ref.is_empty():
		return planned
	var selected_commit := str(_state.update_selected_target_commit).strip_edges()
	if selected_commit.is_empty():
		selected_commit = str((_state.update_ref_commits as Dictionary).get(selected_ref, "")).strip_edges()
	return {
		"kind": "tag" if str(_state.update_selected_target_kind) == "tag" else "branch",
		"ref": selected_ref,
		"commit": selected_commit
	}


func _reconcile_update_selected_target_with_refs() -> void:
	if _state == null:
		return
	var selected_ref := str(_state.update_selected_target_ref).strip_edges()
	if selected_ref.is_empty():
		return
	var selected_kind := "tag" if str(_state.update_selected_target_kind) == "tag" else "branch"
	var selected_commit := str(_state.update_selected_target_commit).strip_edges()
	var visible := false
	var source_rows = _state.update_ref_release_rows if selected_kind == "tag" else (_state.update_ref_branch_commit_rows as Dictionary).get(selected_ref, [])
	if source_rows is Array:
		for raw_row in source_rows as Array:
			if not (raw_row is Dictionary):
				continue
			var row := raw_row as Dictionary
			if str(row.get("ref", "")).strip_edges() != selected_ref:
				continue
			var row_commit := str(row.get("commit", "")).strip_edges()
			if selected_commit.is_empty() or row_commit == selected_commit:
				visible = true
				break
	if not visible:
		_clear_update_target_selection()


func _is_update_selected_branch_head(kind: String, target_ref: String, target_commit: String) -> bool:
	if _state == null or kind != "branch" or target_ref.is_empty() or target_commit.is_empty():
		return false
	var branch_head := str((_state.update_ref_commits as Dictionary).get(target_ref, "")).strip_edges()
	return not branch_head.is_empty() and target_commit == branch_head


func _start_update_refs_request(kind: String, url: String, serial: int) -> void:
	if _state == null or serial != _update_refs_request_serial:
		return
	var request_parent := _get_update_request_parent()
	if request_parent == null:
		_mark_update_refs_request_failed(kind, "No active update refs request host.", serial)
		return
	var request_name := "UpdateRefs%sRequest" % kind.capitalize()
	var page_key := "%s_pages" % kind
	var page_count := int(_update_refs_pending.get(page_key, 1))
	var timeout_msec := int(ceil((_ensure_plugin_update_endpoint_config_service().get_refs_http_timeout() + UPDATE_REFS_STALE_REQUEST_GRACE_SEC) * 1000.0))
	_update_refs_pending = _ensure_plugin_update_refs_discovery_service().record_active_request(
		_update_refs_pending,
		kind,
		url,
		serial,
		Time.get_ticks_msec(),
		timeout_msec,
		request_name,
		page_count
	)
	var start_result: Dictionary = _ensure_plugin_update_http_request_service().start_refs_request(
		request_parent,
		request_name,
		url,
		_get_update_refs_headers(),
		Callable(self, "_on_update_refs_request_completed").bind(kind, serial),
		_ensure_plugin_update_endpoint_config_service()
	)
	if not bool(start_result.get("success", false)):
		_update_refs_pending = _ensure_plugin_update_refs_discovery_service().clear_active_request(_update_refs_pending, kind)
		_mark_update_refs_request_failed(kind, "Failed to start %s request: %s" % [kind, int(start_result.get("error", FAILED))], serial)


func _get_pending_update_history_heads() -> Array[String]:
	if _update_refs_pending.is_empty():
		return []
	var heads: Array[String] = []
	for raw_head in _duplicate_update_commit_histories(_update_refs_pending.get("commit_histories", {})).keys():
		var head_commit := str(raw_head).strip_edges()
		if not head_commit.is_empty() and not _ensure_plugin_update_refs_discovery_service().is_kind_done(_update_refs_pending, "commit_history:%s" % head_commit):
			heads.append(head_commit)
	return heads


func _get_update_commit_history_url(head_commit: String) -> String:
	var template: String = _ensure_plugin_update_endpoint_config_service().get_branch_commits_url_template()
	return template % head_commit.strip_edges().uri_encode()


func _start_update_commit_history_request(head_commit: String, url: String, serial: int) -> void:
	var normalized_head := head_commit.strip_edges()
	if _state == null or serial != _update_refs_request_serial or normalized_head.is_empty():
		return
	var kind := "commit_history:%s" % normalized_head
	if _ensure_plugin_update_refs_discovery_service().is_kind_done(_update_refs_pending, kind):
		return
	var request_parent := _get_update_request_parent()
	if request_parent == null:
		_mark_update_refs_request_failed(kind, "No active update refs request host.", serial)
		return
	var page_count: int = _ensure_plugin_update_refs_discovery_service().get_commit_history_pages(_update_refs_pending, normalized_head)
	var timeout_msec := int(ceil((_ensure_plugin_update_endpoint_config_service().get_refs_http_timeout() + UPDATE_REFS_STALE_REQUEST_GRACE_SEC) * 1000.0))
	_update_refs_pending = _ensure_plugin_update_refs_discovery_service().record_active_request(
		_update_refs_pending,
		kind,
		url,
		serial,
		Time.get_ticks_msec(),
		timeout_msec,
		"UpdateCommitHistoryRequest",
		page_count
	)
	var start_result: Dictionary = _ensure_plugin_update_http_request_service().start_refs_request(
		request_parent,
		"UpdateCommitHistoryRequest",
		url,
		_get_update_refs_headers(),
		Callable(self, "_on_update_commit_history_request_completed").bind(normalized_head, serial),
		_ensure_plugin_update_endpoint_config_service()
	)
	if not bool(start_result.get("success", false)):
		_update_refs_pending = _ensure_plugin_update_refs_discovery_service().clear_active_request(_update_refs_pending, kind)
		_mark_update_refs_request_failed(kind, "Failed to start commit history request: %s" % int(start_result.get("error", FAILED)), serial)


func _on_update_commit_history_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, head_commit: String, serial: int) -> void:
	var kind := "commit_history:%s" % head_commit
	if _state == null or serial != _update_refs_request_serial or _ensure_plugin_update_refs_discovery_service().is_kind_done(_update_refs_pending, kind):
		return
	_update_refs_pending = _ensure_plugin_update_refs_discovery_service().clear_active_request(_update_refs_pending, kind)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_handle_update_refs_http_failure(kind, result, response_code, headers, serial)
		return
	_record_update_refs_http_status(kind, result, response_code, headers, "")
	var parse_result := _parse_update_refs_json_array(body)
	if not bool(parse_result.get("success", false)):
		_handle_update_refs_parse_failure(kind, str(parse_result.get("error", "Invalid JSON response")), serial)
		return
	_update_refs_pending = _ensure_plugin_update_refs_discovery_service().append_commit_history(_update_refs_pending, head_commit, parse_result.get("items", []))
	var next_url := _extract_update_refs_next_url(headers)
	var pages: int = _ensure_plugin_update_refs_discovery_service().get_commit_history_pages(_update_refs_pending, head_commit)
	if not next_url.is_empty() and pages < _ensure_plugin_update_endpoint_config_service().get_refs_max_pages():
		_update_refs_pending = _ensure_plugin_update_refs_discovery_service().increment_commit_history_page(_update_refs_pending, head_commit)
		_start_update_commit_history_request(head_commit, next_url, serial)
		return
	var complete := next_url.is_empty()
	_update_refs_pending = _ensure_plugin_update_refs_discovery_service().finish_commit_history(_update_refs_pending, head_commit, complete)
	if not complete:
		_append_update_refs_error(_get_update_localized_text("settings_update_compare_required", "Update target could not be verified; use Switch for an explicit manual change."))
	_finalize_update_refs_discovery_if_ready(serial)


func _append_update_refs_error(message: String) -> void:
	var errors: Array = _update_refs_pending.get("errors", [])
	if not message.is_empty() and not errors.has(message):
		errors.append(message)
	_update_refs_pending["errors"] = errors


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
	return _ensure_plugin_update_request_planning_service().should_resolve_branch_commit_before_archive(target)


func _start_update_archive_branch_ref_request(target: Dictionary, serial: int) -> void:
	var request_parent := _get_update_request_parent()
	if request_parent == null:
		_mark_update_sync_failed("No active update sync request host.", serial)
		return
	var target_ref := str(target.get("ref", "")).strip_edges()
	var start_result: Dictionary = _ensure_plugin_update_http_request_service().start_small_refs_request(
		request_parent,
		"UpdateArchiveBranchRefRequest",
		_get_update_branch_ref_url(target_ref),
		_get_update_refs_headers(),
		Callable(self, "_on_update_archive_branch_ref_request_completed").bind(target, serial),
		_ensure_plugin_update_endpoint_config_service()
	)
	if not bool(start_result.get("success", false)):
		_start_update_archive_sync_request_attempt(target, serial, _build_update_archive_request_attempts(target), 0, ["branch ref request start failed: %s" % int(start_result.get("error", FAILED))])


func _get_update_branch_ref_url(target_ref: String) -> String:
	return _ensure_plugin_update_request_planning_service().get_branch_ref_url(target_ref, _ensure_plugin_update_endpoint_config_service().get_branch_ref_url_template())


func _on_update_archive_branch_ref_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, target: Dictionary, serial: int) -> void:
	if _state == null or serial != _update_sync_request_serial:
		return
	var failures: Array[String] = []
	var resolved_target := target.duplicate(true)
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		var parse_result: Dictionary = _ensure_plugin_update_request_planning_service().parse_branch_ref_response(body)
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

func _build_update_archive_request_attempts(target: Dictionary) -> Array:
	return _ensure_plugin_update_request_planning_service().build_archive_request_attempts(target, _build_update_archive_url_prefixes())


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
	var archive_path: String = _ensure_plugin_update_endpoint_config_service().get_sync_archive_path()
	if FileAccess.file_exists(archive_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(archive_path))
	var start_result: Dictionary = _ensure_plugin_update_http_request_service().start_sync_archive_request(
		request_parent,
		"UpdateArchiveSyncRequest",
		str(attempt.get("url", "")),
		_get_update_archive_headers(),
		Callable(self, "_on_update_archive_sync_request_attempt_completed").bind(target, serial, attempts, attempt_index, failures),
		_ensure_plugin_update_endpoint_config_service(),
		archive_path
	)
	if not bool(start_result.get("success", false)):
		var next_failures := failures.duplicate()
		next_failures.append("%s start failed: %s" % [str(attempt.get("label", "archive request")), int(start_result.get("error", FAILED))])
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
	var url := _build_update_target_version_url(normalized_ref, target_kind)
	var start_result: Dictionary = _ensure_plugin_update_http_request_service().start_small_refs_request(
		request_parent,
		"UpdateRefVersionRequest",
		url,
		_get_update_refs_headers(),
		Callable(self, "_on_update_ref_version_request_completed").bind(normalized_ref, serial),
		_ensure_plugin_update_endpoint_config_service()
	)
	if not bool(start_result.get("success", false)):
		_update_ref_version_requests_in_flight.erase(normalized_ref)


func _build_update_target_version_url(target_ref: String, target_kind: String) -> String:
	return _ensure_plugin_update_compare_service().build_target_version_url(
		target_ref,
		target_kind,
		_ensure_plugin_update_endpoint_config_service().get_target_plugin_cfg_branch_url_template(),
		_ensure_plugin_update_endpoint_config_service().get_target_plugin_cfg_tag_url_template()
	)


func _on_update_ref_version_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, target_ref: String, serial: int) -> void:
	_update_ref_version_requests_in_flight.erase(target_ref)
	if _state == null or serial != _update_ref_version_request_serial:
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var version := _parse_update_target_plugin_cfg_version(body.get_string_from_utf8())
	if version.is_empty():
		return
	_state.update_ref_versions[target_ref] = version
	_save_update_refs_cache()
	_refresh_dock()


func _parse_update_target_plugin_cfg_version(content: String) -> String:
	return _ensure_plugin_update_compare_service().parse_plugin_cfg_version(content)


func _on_update_refs_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, kind: String, serial: int) -> void:
	if _state == null or serial != _update_refs_request_serial:
		return
	if _ensure_plugin_update_refs_discovery_service().is_kind_done(_update_refs_pending, kind):
		return
	_update_refs_pending = _ensure_plugin_update_refs_discovery_service().clear_active_request(_update_refs_pending, kind)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_handle_update_refs_http_failure(kind, result, response_code, headers, serial)
		return
	_record_update_refs_http_status(kind, result, response_code, headers, "")
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
			if not bool(_update_refs_pending.get("background", false)):
				_state.update_ref_branches = _to_string_array(_update_refs_pending.get("branches", []))
				_state.update_ref_commits = _duplicate_update_ref_commits(_update_refs_pending.get("commits", {}))
			_mark_update_refs_kind_success(kind)
			_update_refs_pending["branch_done"] = true
			_queue_pending_update_target_history(serial)
		"releases":
			_append_update_refs_pending_names("releases", _extract_update_ref_names(items, "tag_name"))
			_append_update_refs_pending_names("stable_releases", _extract_update_stable_release_names(items))
			_append_update_refs_pending_release_rows(items)
			if _request_next_update_refs_page_if_available(kind, headers, serial):
				return
			_mark_update_refs_kind_success(kind)
			_update_refs_pending["release_done"] = true
		"tags":
			_append_update_refs_pending_names("tags", _extract_update_ref_names(items, "name"))
			_append_update_refs_pending_commits(items, "name")
			_append_update_refs_pending_tag_rows(items)
			if _request_next_update_refs_page_if_available(kind, headers, serial):
				return
			_mark_update_refs_kind_success(kind)
			_update_refs_pending["tag_done"] = true
			_queue_pending_update_target_history(serial)
		"branch_commits":
			_append_update_refs_pending_branch_commit_rows(_get_pending_update_branch_commits_branch(), items)
			_mark_update_refs_kind_success(kind)
			_update_refs_pending["branch_commits_done"] = true
	_finalize_update_refs_discovery_if_ready(serial)


func _mark_update_refs_kind_success(kind: String) -> void:
	var successful_kinds: Array[String] = _to_string_array(_update_refs_pending.get("successful_kinds", []))
	if not successful_kinds.has(kind):
		successful_kinds.append(kind)
	_update_refs_pending["successful_kinds"] = successful_kinds


func _request_next_update_refs_page_if_available(kind: String, headers: PackedStringArray, serial: int) -> bool:
	var next_url := _extract_update_refs_next_url(headers)
	if next_url.is_empty():
		return false
	var page_key := "%s_pages" % kind
	var page_count := int(_update_refs_pending.get(page_key, 1))
	if page_count >= _ensure_plugin_update_endpoint_config_service().get_refs_max_pages():
		return false
	_update_refs_pending[page_key] = page_count + 1
	_start_update_refs_request(kind, next_url, serial)
	return true


func _extract_update_refs_next_url(headers: PackedStringArray) -> String:
	return _ensure_plugin_update_refs_discovery_service().extract_next_url(headers)


func _append_update_refs_pending_names(key: String, names: Array[String]) -> void:
	_update_refs_pending = _ensure_plugin_update_refs_discovery_service().append_names(_update_refs_pending, key, names)


func _append_update_refs_pending_commits(items: Array, name_key: String) -> void:
	_update_refs_pending = _ensure_plugin_update_refs_discovery_service().append_commits(_update_refs_pending, items, name_key)


func _append_update_refs_pending_release_rows(items: Array) -> void:
	_update_refs_pending = _ensure_plugin_update_refs_discovery_service().append_release_rows(_update_refs_pending, items)


func _append_update_refs_pending_tag_rows(items: Array) -> void:
	_update_refs_pending = _ensure_plugin_update_refs_discovery_service().append_tag_rows(_update_refs_pending, items)


func _append_update_refs_pending_branch_commit_rows(branch: String, items: Array) -> void:
	_update_refs_pending = _ensure_plugin_update_refs_discovery_service().append_branch_commit_rows(_update_refs_pending, branch, items)


func _queue_pending_update_target_history(serial: int) -> bool:
	if _state == null or serial != _update_refs_request_serial:
		return false
	var target := _resolve_pending_update_sync_target()
	var target_commit := str(target.get("commit", "")).strip_edges()
	if target_commit.is_empty():
		return false
	var histories := _duplicate_update_commit_histories(_update_refs_pending.get("commit_histories", {}))
	if histories.has(target_commit):
		return false
	_update_refs_pending = _ensure_plugin_update_refs_discovery_service().begin_commit_history(_update_refs_pending, target_commit, true)
	_start_update_commit_history_request(target_commit, _get_update_commit_history_url(target_commit), serial)
	return true


func _resolve_pending_update_sync_target() -> Dictionary:
	if _state == null:
		return {}
	var planned: Dictionary = _ensure_plugin_update_request_planning_service().resolve_sync_target(
		_state.settings,
		_build_pending_update_refs_planning_context()
	)
	var selected_ref := str(_state.update_selected_target_ref).strip_edges()
	if selected_ref.is_empty():
		return planned
	return {
		"kind": "tag" if str(_state.update_selected_target_kind) == "tag" else "branch",
		"ref": selected_ref,
		"commit": str(_state.update_selected_target_commit).strip_edges() if not str(_state.update_selected_target_commit).strip_edges().is_empty() else str(_update_refs_pending.get("commits", {}).get(selected_ref, "")).strip_edges()
	}


func _build_pending_update_refs_planning_context() -> Dictionary:
	var stable_releases := _to_string_array(_update_refs_pending.get("stable_releases", []))
	var releases := _to_string_array(_update_refs_pending.get("releases", []))
	return {
		"latest_stable_release": stable_releases[0] if not stable_releases.is_empty() else "",
		"latest_release": releases[0] if not releases.is_empty() else "",
		"commits": _update_refs_pending.get("commits", {})
	}


func _get_pending_update_branch_commits_branch() -> String:
	var branch := str(_update_refs_pending.get("branch_commits_branch", "")).strip_edges()
	return branch if not branch.is_empty() else _get_selected_update_branch()


func _extract_update_ref_commit(item: Dictionary) -> String:
	return _ensure_plugin_update_refs_discovery_service().extract_commit(item)


func _to_string_array(values) -> Array[String]:
	return _ensure_plugin_update_refs_discovery_service().to_string_array(values)


func _handle_update_refs_http_failure(kind: String, result: int, response_code: int, headers: PackedStringArray, serial: int) -> void:
	var message := _format_update_http_failure(kind, result, response_code, headers)
	_record_update_refs_http_status(kind, result, response_code, headers, message)
	_mark_update_refs_request_failed(kind, message, serial)


func _handle_update_refs_parse_failure(kind: String, error: String, serial: int) -> void:
	var message := _get_update_localized_text("settings_update_parse_failure", "%s response parse failed: %s") % [kind.capitalize(), error]
	_record_update_refs_audit(str(_state.update_refs_last_trigger), kind, int(_state.update_refs_last_http_status), message, {})
	_mark_update_refs_request_failed(kind, message, serial)


func _format_update_http_failure(kind: String, result: int, response_code: int, headers: PackedStringArray) -> String:
	var rate_limit := _parse_update_rate_limit_headers(headers)
	if response_code == 403 and str(rate_limit.get("remaining", "")).strip_edges() == "0":
		var reset_unix := int(rate_limit.get("reset_unix", 0))
		var reset_text := Time.get_datetime_string_from_unix_time(reset_unix, true) if reset_unix > 0 else "unknown"
		return _get_update_localized_text("settings_update_rate_limit_failure", "%s request failed: GitHub API rate limit reached; resets at %s UTC.") % [kind.capitalize(), reset_text]
	return _get_update_localized_text("settings_update_http_failure", "%s request failed with result %s and HTTP %s") % [kind.capitalize(), result, response_code]


func _record_update_refs_http_status(kind: String, result: int, response_code: int, headers: PackedStringArray, message: String) -> void:
	var rate_limit := _parse_update_rate_limit_headers(headers)
	_record_update_refs_audit(str(_state.update_refs_last_trigger), kind, response_code, message, rate_limit)
	if response_code >= 200 and response_code < 300:
		MCPDebugBuffer.record("debug", "plugin", "Plugin update %s request completed with HTTP %s (result %s)" % [kind, response_code, result])


func _record_update_refs_audit(trigger_source: String, request_kind: String, http_status: int, message: String, rate_limit: Dictionary) -> void:
	if _state == null:
		return
	var now_unix := int(Time.get_unix_time_from_system())
	_state.update_refs_last_trigger = trigger_source
	_state.update_refs_last_requested_unix = now_unix
	_state.update_refs_last_http_status = http_status
	_state.update_refs_rate_limit_remaining = str(rate_limit.get("remaining", _state.update_refs_rate_limit_remaining))
	_state.update_refs_rate_limit_reset_unix = int(rate_limit.get("reset_unix", _state.update_refs_rate_limit_reset_unix))
	_state.update_refs_rate_limit_retry_after = int(rate_limit.get("retry_after", _state.update_refs_rate_limit_retry_after))
	_state.update_refs_audit = {
		"trigger": trigger_source,
		"kind": request_kind,
		"requested_unix": now_unix,
		"http_status": http_status,
		"message": message,
		"rate_limit_remaining": _state.update_refs_rate_limit_remaining,
		"rate_limit_reset_unix": _state.update_refs_rate_limit_reset_unix,
		"rate_limit_retry_after": _state.update_refs_rate_limit_retry_after
	}


func _is_update_refs_rate_limited() -> bool:
	if _state == null:
		return false
	return str(_state.update_refs_rate_limit_remaining).strip_edges() == "0" \
		and int(_state.update_refs_rate_limit_reset_unix) > int(Time.get_unix_time_from_system())


func _build_update_refs_rate_limit_cooldown_message() -> String:
	var reset_unix := int(_state.update_refs_rate_limit_reset_unix) if _state != null else 0
	var reset_text := Time.get_datetime_string_from_unix_time(reset_unix, true) if reset_unix > 0 else "unknown"
	return _get_update_localized_text("settings_update_rate_limit_cooldown", "GitHub API rate limit is active until %s UTC.") % reset_text


func _parse_update_rate_limit_headers(headers: PackedStringArray) -> Dictionary:
	var parsed := {}
	for header in headers:
		var header_text := str(header)
		var separator := header_text.find(":")
		if separator <= 0:
			continue
		var key := header_text.substr(0, separator).strip_edges().to_lower()
		var value := header_text.substr(separator + 1).strip_edges()
		match key:
			"x-ratelimit-remaining":
				parsed["remaining"] = value
			"x-ratelimit-reset":
				parsed["reset_unix"] = int(value)
			"retry-after":
				parsed["retry_after"] = int(value)
	return parsed


func _mark_update_refs_request_failed(kind: String, message: String, serial: int) -> void:
	if _state == null or serial != _update_refs_request_serial:
		return
	if _ensure_plugin_update_refs_discovery_service().is_kind_done(_update_refs_pending, kind):
		return
	_update_refs_pending = _ensure_plugin_update_refs_discovery_service().clear_active_request(_update_refs_pending, kind)
	_append_update_refs_error(message)
	if kind == "branches":
		_update_refs_pending["branch_done"] = true
	elif kind == "tags":
		_update_refs_pending["tag_done"] = true
	elif kind == "branch_commits":
		_update_refs_pending["branch_commits_done"] = true
	elif kind.begins_with("commit_history:"):
		var head_commit := kind.trim_prefix("commit_history:").strip_edges()
		_update_refs_pending = _ensure_plugin_update_refs_discovery_service().mark_commit_history_failed(_update_refs_pending, head_commit)
	else:
		_update_refs_pending["release_done"] = true
	_finalize_update_refs_discovery_if_ready(serial)


func _sweep_stale_update_refs_requests() -> bool:
	if _state == null or _update_refs_pending.is_empty():
		return false
	var serial := int(_update_refs_pending.get("serial", 0))
	if serial != _update_refs_request_serial:
		return false
	var stale_requests: Array[Dictionary] = _ensure_plugin_update_refs_discovery_service().find_stale_active_requests(
		_update_refs_pending,
		Time.get_ticks_msec()
	)
	if stale_requests.is_empty():
		return false
	for request in stale_requests:
		var kind := str(request.get("kind", ""))
		if kind.is_empty():
			continue
		_mark_update_refs_request_failed(kind, _format_stale_update_refs_request_error(request), serial)
	return true


func _format_stale_update_refs_request_error(request: Dictionary) -> String:
	var template := _get_localized_text("settings_update_refs_request_timeout")
	if template.is_empty() or template == "settings_update_refs_request_timeout":
		template = "%s request timed out after %.1fs without completion (page %s)."
	return template % [
		str(request.get("kind", "refs")).capitalize(),
		float(int(request.get("timeout_msec", 0))) / 1000.0,
		int(request.get("page", 1))
	]


func _fail_pending_update_sync_after_refs_discovery(message: String) -> void:
	if not _update_sync_after_refs_discovery_pending or _state == null:
		return
	_apply_update_state_patch(_ensure_plugin_update_state_transition_service().build_pending_sync_failure(message))
	_clear_pending_update_sync()


func _mark_update_sync_failed(message: String, serial: int) -> void:
	if _state == null or serial != _update_sync_request_serial:
		return
	_apply_update_state_patch(_ensure_plugin_update_state_transition_service().build_sync_failure(message))
	_refresh_dock()


func _format_update_sync_failure(sync_result: Dictionary) -> String:
	var message := str(sync_result.get("error", "Update sync failed."))
	if sync_result.has("dirty") and bool(sync_result.get("dirty", false)):
		message += " Addon tree may be partially updated."
	if sync_result.has("recovered") and not bool(sync_result.get("recovered", true)):
		message += " Rollback did not fully recover the previous files."
	var rollback_error := str(sync_result.get("rollback_error", "")).strip_edges()
	if not rollback_error.is_empty():
		message += " Rollback error: %s" % rollback_error
	return message


func _on_update_archive_sync_request_attempt_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray, target: Dictionary, serial: int, attempts: Array, attempt_index: int, failures: Array) -> void:
	if _state == null or serial != _update_sync_request_serial:
		return
	var attempt: Dictionary = attempts[attempt_index] if attempt_index >= 0 and attempt_index < attempts.size() else {}
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		var next_failures := failures.duplicate()
		next_failures.append("%s failed with result %s and HTTP %s" % [str(attempt.get("label", "archive request")), result, response_code])
		_start_update_archive_sync_request_attempt(target, serial, attempts, attempt_index + 1, next_failures)
		return
	await _complete_update_archive_sync_download(target, serial, attempts, attempt_index, failures)


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
	var sync_result := _sync_update_archive_to_addon(_ensure_plugin_update_endpoint_config_service().get_sync_archive_path())
	if not bool(sync_result.get("success", false)):
		if _should_try_next_update_archive_attempt(str(sync_result.get("error", "")), attempts, attempt_index):
			var next_failures := failures.duplicate()
			var attempt: Dictionary = attempts[attempt_index] if attempt_index >= 0 and attempt_index < attempts.size() else {}
			next_failures.append("%s downloaded an unusable archive: %s" % [str(attempt.get("label", "archive request")), str(sync_result.get("error", "archive sync failed"))])
			_start_update_archive_sync_request_attempt(target, serial, attempts, attempt_index + 1, next_failures)
			return
		_mark_update_sync_failed(_format_update_sync_failure(sync_result), serial)
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
	return _ensure_plugin_update_request_planning_service().should_try_next_archive_attempt(error, attempts, attempt_index)


func _format_update_archive_failures(failures: Array) -> String:
	return _ensure_plugin_update_request_planning_service().format_archive_failures(failures)


func _complete_update_sync_after_editor_refresh(target_ref: String, sync_result: Dictionary, serial: int) -> void:
	var refresh_result: Dictionary = await _request_update_sync_editor_refresh(serial)
	if _state == null or serial != _update_sync_request_serial:
		return
	if not bool(refresh_result.get("success", false)):
		_mark_update_sync_failed(_get_localized_text("settings_update_sync_refresh_timeout"), serial)
		return
	_apply_update_state_patch(_ensure_plugin_update_state_transition_service().build_sync_success(
		target_ref,
		int(sync_result.get("written", 0)),
		_get_localized_text("settings_update_sync_success")
	))
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
			var deadline_msec: int = Time.get_ticks_msec() + _ensure_plugin_update_endpoint_config_service().get_sync_editor_refresh_timeout_ms()
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
	var marker_context: Dictionary = _ensure_plugin_update_endpoint_config_service().build_sync_marker_context()
	marker_context["unix_time"] = int(Time.get_unix_time_from_system())
	var marker: Dictionary = _ensure_plugin_update_request_planning_service().build_sync_marker(target, written, marker_context)
	var file := FileAccess.open(_ensure_plugin_update_endpoint_config_service().get_sync_marker_path(), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(marker, "	"))
	file.close()
	return OK


func _build_update_refs_planning_context() -> Dictionary:
	return {
		"latest_stable_release": str(_state.update_ref_latest_stable_release),
		"latest_release": str(_state.update_ref_latest_release),
		"commits": _state.update_ref_commits
	}


func _build_update_archive_url_prefixes() -> Dictionary:
	return _ensure_plugin_update_endpoint_config_service().get_archive_url_prefixes()


func _sync_update_archive_to_addon(archive_path: String) -> Dictionary:
	return _plugin_update_sync_mirror_service.sync_archive_to_addon(archive_path, _get_update_sync_addon_root())


func _get_update_sync_addon_root() -> String:
	return _ensure_plugin_update_endpoint_config_service().get_sync_addon_root()


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
	if not bool(_update_refs_pending.get("branch_done", false)) or not bool(_update_refs_pending.get("release_done", false)) or not bool(_update_refs_pending.get("tag_done", false)) or not bool(_update_refs_pending.get("branch_commits_done", false)):
		_refresh_dock()
		return
	if _queue_pending_update_target_history(serial):
		_refresh_dock()
		return
	if not _ensure_plugin_update_refs_discovery_service().are_commit_histories_done(_update_refs_pending):
		_refresh_dock()
		return
	var snapshot: Dictionary = _ensure_plugin_update_refs_discovery_service().build_final_snapshot(_update_refs_pending)
	var errors: Array = snapshot.get("errors", [])
	var background_refresh := bool(_update_refs_pending.get("background", false))
	var successful_kinds := _to_string_array(_update_refs_pending.get("successful_kinds", []))
	if errors.is_empty() or not successful_kinds.is_empty():
		_apply_successful_update_refs_snapshot(snapshot, successful_kinds, errors.is_empty())
		_reconcile_update_selected_target_with_refs()
		_state.update_refs_last_checked_unix = int(Time.get_unix_time_from_system())
		if background_refresh:
			_apply_update_state_patch(_ensure_plugin_update_state_transition_service().build_refs_success(
				_localization.get_text("settings_update_refs_success") if _localization != null else "Update refs loaded."
			))
			_state.update_refs_refresh_state = "success"
			_state.update_refs_refresh_error = ""
			_state.update_refs_refresh_serial = serial
			_update_refs_discovery_loaded = true
		else:
			_apply_update_state_patch(_ensure_plugin_update_state_transition_service().build_refs_success(
				_localization.get_text("settings_update_refs_success") if _localization != null else "Update refs loaded."
			))
		if not errors.is_empty():
			_state.update_refs_refresh_state = "error"
			_state.update_refs_refresh_error = "; ".join(errors)
		_save_update_refs_cache()
		_refresh_update_compare_for_current_target()
	else:
		if background_refresh:
			_state.update_refs_refresh_state = "error"
			_state.update_refs_refresh_error = "; ".join(errors)
			_state.update_refs_refresh_serial = serial
			_fail_pending_update_sync_after_refs_discovery("Update target discovery failed before sync: %s" % _state.update_refs_refresh_error)
		else:
			_apply_update_state_patch(_ensure_plugin_update_state_transition_service().build_refs_failure(errors))
			_reset_update_compare_state()
			_fail_pending_update_sync_after_refs_discovery("Update target discovery failed before sync: %s" % _state.update_refs_error)
	_update_refs_background_serials.erase(serial)
	var continued_sync := _continue_pending_update_sync_after_refs_discovery()
	if continued_sync:
		return
	_refresh_dock()


func _apply_successful_update_refs_snapshot(snapshot: Dictionary, successful_kinds: Array[String], all_requests_succeeded: bool) -> void:
	if _state == null:
		return
	var completed_kinds := successful_kinds.duplicate()
	if all_requests_succeeded:
		var required_kinds := _to_string_array(_update_refs_pending.get("required_kinds", []))
		if required_kinds.is_empty():
			if _normalize_update_source(str(_state.settings.get("update_source", "latest_stable"))) == "custom_branch":
				required_kinds.append("branches")
				required_kinds.append("branch_commits")
			else:
				required_kinds.append("releases")
				required_kinds.append("tags")
		for kind in required_kinds:
			if not completed_kinds.has(kind):
				completed_kinds.append(kind)
	var branches_succeeded := completed_kinds.has("branches")
	var branch_commits_succeeded := completed_kinds.has("branch_commits")
	var releases_succeeded := completed_kinds.has("releases")
	var tags_succeeded := completed_kinds.has("tags")
	if branches_succeeded:
		_state.update_ref_branches = snapshot.get("branches", [])
		_state.update_ref_commits = snapshot.get("commits", {})
	if branch_commits_succeeded:
		var branch := str(_update_refs_pending.get("branch_commits_branch", "")).strip_edges()
		var current_rows := _duplicate_update_branch_commit_rows(_state.update_ref_branch_commit_rows)
		var refreshed_branch_rows: Dictionary = snapshot.get("branch_commit_rows", {})
		var branch_rows: Array = _duplicate_update_ref_rows(refreshed_branch_rows.get(branch, [])) if refreshed_branch_rows.has(branch) else []
		if not branch_rows.is_empty():
			current_rows[branch] = branch_rows
		elif not branch.is_empty():
			current_rows.erase(branch)
		_state.update_ref_branch_commit_rows = current_rows
		if not branch.is_empty():
			var current_commits := _duplicate_update_ref_commits(_state.update_ref_commits)
			if not branch_rows.is_empty():
				var first_row = branch_rows[0]
				var refreshed_head := str((first_row as Dictionary).get("commit", "")).strip_edges() if first_row is Dictionary else ""
				if not refreshed_head.is_empty():
					current_commits[branch] = refreshed_head
				else:
					current_commits.erase(branch)
			else:
				current_commits.erase(branch)
			_state.update_ref_commits = current_commits
	if releases_succeeded or tags_succeeded:
		var refreshed_releases := _to_string_array(snapshot.get("releases", []))
		var refreshed_release_rows := _duplicate_update_ref_rows(snapshot.get("release_rows", []))
		if releases_succeeded and tags_succeeded:
			_state.update_ref_releases = refreshed_releases
			_state.update_ref_release_rows = refreshed_release_rows
		else:
			_state.update_ref_releases = _merge_update_ref_values(refreshed_releases, _to_string_array(_state.update_ref_releases))
			_state.update_ref_release_rows = _merge_update_ref_rows(refreshed_release_rows, _duplicate_update_ref_rows(_state.update_ref_release_rows))
		if tags_succeeded:
			_state.update_ref_commits = snapshot.get("commits", {})
		if releases_succeeded:
			_state.update_ref_latest_release = str(snapshot.get("latest_release", ""))
			_state.update_ref_latest_stable_release = str(snapshot.get("latest_stable_release", ""))
		_state.update_refs_release_source = str(snapshot.get("release_source", ""))
	_set_update_commit_histories(snapshot.get("commit_histories", {}))


func _merge_update_ref_values(primary: Array[String], fallback: Array[String]) -> Array[String]:
	var merged: Array[String] = []
	for values in [primary, fallback]:
		for value in values:
			var normalized: String = str(value).strip_edges()
			if not normalized.is_empty() and not merged.has(normalized):
				merged.append(normalized)
	return merged


func _merge_update_ref_rows(primary: Array, fallback: Array) -> Array:
	var merged: Array = []
	var seen_refs: Array[String] = []
	for rows in [primary, fallback]:
		for raw_row in rows:
			if not (raw_row is Dictionary):
				continue
			var row := raw_row as Dictionary
			var target_ref := str(row.get("ref", "")).strip_edges()
			if target_ref.is_empty() or seen_refs.has(target_ref):
				continue
			merged.append(row.duplicate(true))
			seen_refs.append(target_ref)
	return merged


func _continue_pending_update_sync_after_refs_discovery() -> bool:
	if not _update_sync_after_refs_discovery_pending or _state == null:
		return false
	if str(_state.update_refs_state) != "success":
		return false
	var target := _resolve_update_sync_target()
	var target_ref := str(target.get("ref", "")).strip_edges()
	if target_ref.is_empty():
		_clear_pending_update_sync()
		_apply_update_state_patch(_ensure_plugin_update_state_transition_service().build_pending_sync_failure(
			_localization.get_text("settings_update_sync_no_target") if _localization != null else "Select an update target before syncing."
		))
		return false
	if not _is_update_sync_target_verified(target, true):
		_ensure_pending_update_sync_verification()
		return true
	if not _update_sync_pending_manual_switch:
		var guard_message := _get_one_click_update_guard_message()
		if not guard_message.is_empty():
			_fail_pending_update_sync_after_refs_discovery(guard_message)
			_refresh_dock()
			return false
	_clear_pending_update_sync()
	return _request_update_sync(target, "refs_discovery")


func _get_one_click_cached_target_guard_message(target: Dictionary) -> String:
	if _state == null:
		return _get_update_localized_text("settings_update_verify_unavailable", "Update target could not be verified.")
	if str(_state.update_refs_state) != "success" or not _update_refs_discovery_loaded:
		return _get_update_localized_text("settings_update_refresh_required", "Refresh the version list before using one-click update.")
	var target_kind := str(target.get("kind", "branch"))
	var target_ref := str(target.get("ref", "")).strip_edges()
	if target_ref.is_empty():
		return _get_update_localized_text("settings_update_sync_no_target", "Select a branch or release before syncing.")
	if target_kind == "branch" and str(target.get("commit", "")).strip_edges().is_empty():
		return _get_update_localized_text("settings_update_branch_commit_required", "Refresh the version list for this branch before using one-click update.")
	return ""


func _get_one_click_update_guard_message() -> String:
	if _state == null:
		return _get_update_localized_text("settings_update_verify_unavailable", "Update target could not be verified.")
	if str(_state.update_compare_state) != "success":
		return _get_update_localized_text("settings_update_compare_required", "Update target could not be verified; use Switch for an explicit manual change.")
	var target_ahead := int(_state.update_compare_ahead_by)
	var current_ahead := int(_state.update_compare_behind_by)
	if target_ahead == 0 and current_ahead == 0:
		return _get_update_localized_text("settings_update_already_latest", "Already on the latest selected version.")
	if target_ahead > 0 and current_ahead == 0:
		return ""
	if current_ahead > 0 and target_ahead == 0:
		return _get_update_localized_text("settings_update_refuses_rollback", "One-click update would roll back commits; use Switch on a specific row to confirm manually.")
	return _get_update_localized_text("settings_update_refuses_divergent", "One-click update would switch to a divergent history; use Switch on a specific row to confirm manually.")


func _get_update_localized_text(key: String, fallback: String) -> String:
	var text := _get_localized_text(key)
	if text.is_empty() or text == key:
		return fallback
	return text


func _set_update_sync_guard_error(message: String) -> void:
	if _state == null:
		return
	_apply_update_state_patch(_ensure_plugin_update_state_transition_service().build_sync_failure(message))
	_refresh_dock()


func _refresh_update_compare_for_current_target() -> bool:
	if _state == null or str(_state.update_refs_state) != "success":
		return false
	var target := _resolve_update_sync_target()
	var compare_snapshot: Dictionary = _ensure_plugin_update_compare_service().build_local_compare_snapshot(
		_resolve_current_update_commit(),
		target,
		_get_update_commit_histories()
	)
	_state.update_compare_base_commit = str(compare_snapshot.get("base_commit", ""))
	_state.update_compare_target_ref = str(compare_snapshot.get("target_ref", ""))
	_state.update_compare_target_commit = str(compare_snapshot.get("target_commit", ""))
	_state.update_compare_ahead_by = int(compare_snapshot.get("ahead_by", -1))
	_state.update_compare_behind_by = int(compare_snapshot.get("behind_by", -1))
	var compare_error := str(compare_snapshot.get("error", ""))
	_state.update_compare_error = _get_update_localized_text("settings_update_compare_required", "Update target could not be verified; use Switch for an explicit manual change.") if not compare_error.is_empty() else ""
	_state.update_compare_state = str(compare_snapshot.get("state", "unavailable"))
	_state.update_compare_refresh_state = "idle"
	_state.update_compare_refresh_error = ""
	_state.update_compare_last_checked_unix = int(Time.get_unix_time_from_system())
	if str(_state.update_compare_state) == "success" and bool(_state.update_selection_refresh_pending) and str(_state.update_selection_refresh_pending_ref).strip_edges() == str(_state.update_compare_target_ref).strip_edges():
		_clear_update_selection_refresh_pending()
	return true


func _resolve_current_update_commit() -> String:
	return _ensure_plugin_update_compare_service().resolve_current_commit(PluginInstanceFreshness.get_freshness_snapshot())


func _reset_update_compare_state() -> void:
	if _state == null:
		return
	_state.update_compare_refresh_state = "idle"
	_state.update_compare_refresh_error = ""
	_state.update_compare_refresh_serial += 1
	_apply_update_state_patch(_ensure_plugin_update_state_transition_service().build_compare_reset())


func _get_update_commit_histories() -> Dictionary:
	if _state == null:
		return _update_commit_histories_fallback
	var value = _state.get("update_commit_histories")
	if value is Dictionary:
		var histories := value as Dictionary
		if not histories.is_empty():
			return histories
	return _update_commit_histories_fallback


func _set_update_commit_histories(raw_histories) -> void:
	var normalized := _duplicate_update_commit_histories(raw_histories)
	_update_commit_histories_fallback = normalized
	if _state != null and _state.get("update_commit_histories") is Dictionary:
		_state.update_commit_histories = normalized


func _parse_update_refs_json_array(body: PackedByteArray) -> Dictionary:
	return _ensure_plugin_update_refs_discovery_service().parse_refs_json_array(body)


func _extract_update_ref_names(items: Array, key: String) -> Array[String]:
	return _ensure_plugin_update_refs_discovery_service().collect_names(items, key)


func _extract_update_stable_release_names(items: Array) -> Array[String]:
	return _ensure_plugin_update_refs_discovery_service().collect_stable_release_names(items)


func _duplicate_update_ref_commits(raw_commits) -> Dictionary:
	return _ensure_plugin_update_refs_discovery_service().duplicate_commits(raw_commits)


func _duplicate_update_ref_rows(raw_rows) -> Array:
	return _ensure_plugin_update_refs_discovery_service().duplicate_rows(raw_rows)


func _duplicate_update_branch_commit_rows(raw_rows) -> Dictionary:
	return _ensure_plugin_update_refs_discovery_service().duplicate_branch_commit_rows(raw_rows)


func _duplicate_update_commit_histories(raw_histories) -> Dictionary:
	return _ensure_plugin_update_refs_discovery_service().duplicate_commit_histories(raw_histories)


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
		_clear_update_selection_refresh_pending()
		_reset_update_compare_state()
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
	var accepted := _ensure_update_refs_discovery_requested(force_refresh, "mcp_tool")
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
	var cached_guard_message := _get_one_click_cached_target_guard_message(target)
	if not cached_guard_message.is_empty():
		_set_update_sync_guard_error(cached_guard_message)
		var cached_guard_data := _build_plugin_update_status_snapshot()
		cached_guard_data["accepted"] = false
		cached_guard_data["action_status"] = str(_state.update_sync_state)
		return _build_plugin_update_tool_response({
			"success": true,
			"accepted": false,
			"loading": false,
			"status": str(_state.update_sync_state),
			"data": cached_guard_data,
			"message": cached_guard_message
		})
	if _is_update_sync_target_verified(target, true):
		var update_guard_message := _get_one_click_update_guard_message()
		if not update_guard_message.is_empty():
			_set_update_sync_guard_error(update_guard_message)
			var update_guard_data := _build_plugin_update_status_snapshot()
			update_guard_data["accepted"] = false
			update_guard_data["action_status"] = str(_state.update_sync_state)
			return _build_plugin_update_tool_response({
				"success": true,
				"accepted": false,
				"loading": false,
				"status": str(_state.update_sync_state),
				"data": update_guard_data,
				"message": update_guard_message
			})
	if _should_queue_update_sync_for_verification(target):
		_prepare_pending_update_sync(target)
		_ensure_pending_update_sync_verification()
	else:
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


func _ensure_plugin_update_request_planning_service():
	if _plugin_update_request_planning_service == null:
		_plugin_update_request_planning_service = PluginUpdateRequestPlanningServiceScript.new()
	return _plugin_update_request_planning_service


func _ensure_plugin_update_refs_discovery_service():
	if _plugin_update_refs_discovery_service == null:
		_plugin_update_refs_discovery_service = PluginUpdateRefsDiscoveryServiceScript.new()
	return _plugin_update_refs_discovery_service


func _ensure_plugin_update_compare_service():
	if _plugin_update_compare_service == null:
		_plugin_update_compare_service = PluginUpdateCompareServiceScript.new()
	return _plugin_update_compare_service


func _ensure_plugin_update_state_transition_service():
	if _plugin_update_state_transition_service == null:
		_plugin_update_state_transition_service = PluginUpdateStateTransitionServiceScript.new()
	return _plugin_update_state_transition_service


func _ensure_plugin_update_endpoint_config_service():
	if _plugin_update_endpoint_config_service == null:
		_plugin_update_endpoint_config_service = PluginUpdateEndpointConfigServiceScript.new()
	return _plugin_update_endpoint_config_service


func _ensure_plugin_update_http_request_service():
	if _plugin_update_http_request_service == null:
		_plugin_update_http_request_service = PluginUpdateHttpRequestServiceScript.new()
	return _plugin_update_http_request_service


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
		"pending_sync_target_ref": str(_update_sync_pending_target_ref),
		"pending_sync_target_kind": str(_update_sync_pending_target_kind),
		"refs_state": str(_state.update_refs_state),
		"refs_status": str(_state.update_refs_status),
		"refs_error": str(_state.update_refs_error),
		"refs_refresh_state": str(_state.update_refs_refresh_state),
		"refs_refresh_error": str(_state.update_refs_refresh_error),
		"refs_last_checked_unix": int(_state.update_refs_last_checked_unix),
		"refs_refresh_serial": int(_state.update_refs_refresh_serial),
		"refs_pending": _build_update_refs_pending_status(),
		"branches": _state.update_ref_branches,
		"releases": _state.update_ref_releases,
		"latest_stable_release": str(_state.update_ref_latest_stable_release),
		"latest_release": str(_state.update_ref_latest_release),
		"release_source": str(_state.update_refs_release_source),
		"commits": _state.update_ref_commits,
		"versions": _state.update_ref_versions,
		"release_rows": _state.update_ref_release_rows,
		"branch_commit_rows": _state.update_ref_branch_commit_rows,
		"refs_last_trigger": str(_state.update_refs_last_trigger),
		"refs_last_requested_unix": int(_state.update_refs_last_requested_unix),
		"refs_last_http_status": int(_state.update_refs_last_http_status),
		"refs_rate_limit_remaining": str(_state.update_refs_rate_limit_remaining),
		"refs_rate_limit_reset_unix": int(_state.update_refs_rate_limit_reset_unix),
		"refs_rate_limit_retry_after": int(_state.update_refs_rate_limit_retry_after),
		"refs_audit": _state.update_refs_audit,
		"compare_state": str(_state.update_compare_state),
		"compare_error": str(_state.update_compare_error),
		"compare_refresh_state": str(_state.update_compare_refresh_state),
		"compare_refresh_error": str(_state.update_compare_refresh_error),
		"compare_last_checked_unix": int(_state.update_compare_last_checked_unix),
		"compare_refresh_serial": int(_state.update_compare_refresh_serial),
		"compare_base_commit": str(_state.update_compare_base_commit),
		"compare_target_ref": str(_state.update_compare_target_ref),
		"compare_target_commit": str(_state.update_compare_target_commit),
		"compare_ahead_by": int(_state.update_compare_ahead_by),
		"compare_behind_by": int(_state.update_compare_behind_by),
		"selected_target_kind": str(_state.update_selected_target_kind),
		"selected_target_ref": str(_state.update_selected_target_ref),
		"selected_target_commit": str(_state.update_selected_target_commit),
		"selection_refresh_pending": _is_update_selection_refresh_pending(target),
		"selection_refresh_pending_ref": str(_state.update_selection_refresh_pending_ref),
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


func _build_update_refs_pending_status() -> Dictionary:
	if _update_refs_pending.is_empty():
		return {}
	return _ensure_plugin_update_refs_discovery_service().build_pending_status(_update_refs_pending, Time.get_ticks_msec())


func _build_plugin_update_compare_status() -> Dictionary:
	return _ensure_plugin_update_tool_facade().build_compare_status(_build_plugin_update_tool_context())


func _build_plugin_update_sync_status() -> Dictionary:
	return _ensure_plugin_update_tool_facade().build_sync_status(_build_plugin_update_tool_context())


func _apply_update_state_patch(patch: Dictionary) -> void:
	if _state == null:
		return
	for key in patch.keys():
		match str(key):
			"pending_sync_after_refs_discovery":
				_update_sync_after_refs_discovery_pending = bool(patch[key])
			"refs_discovery_loaded":
				_update_refs_discovery_loaded = bool(patch[key])
			"refs_state":
				_state.update_refs_state = str(patch[key])
			"refs_error":
				_state.update_refs_error = str(patch[key])
			"refs_status":
				_state.update_refs_status = str(patch[key])
			"sync_state":
				_state.update_sync_state = str(patch[key])
			"sync_error":
				_state.update_sync_error = str(patch[key])
			"sync_status":
				_state.update_sync_status = str(patch[key])
			"sync_progress":
				_state.update_sync_progress = float(patch[key])
			"compare_state":
				_state.update_compare_state = str(patch[key])
			"compare_error":
				_state.update_compare_error = str(patch[key])
			"compare_base_commit":
				_state.update_compare_base_commit = str(patch[key])
			"compare_target_ref":
				_state.update_compare_target_ref = str(patch[key])
			"compare_target_commit":
				_state.update_compare_target_commit = str(patch[key])
			"compare_ahead_by":
				_state.update_compare_ahead_by = int(patch[key])
			"compare_behind_by":
				_state.update_compare_behind_by = int(patch[key])


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
	var success: bool = bool(_ensure_runtime_reload_completion_service().complete_server_restart(_build_runtime_reload_completion_context()))
	_pending_runtime_reload_action = ""
	_finish_self_operation(
		{"operation_id": operation_id},
		success,
		"plugin",
		"runtime_restart_server"
	)


func _complete_runtime_soft_reload(operation_id: String, was_running: bool, focus_snapshot: Dictionary = {}) -> void:
	var success: bool = bool(_ensure_runtime_reload_completion_service().complete_soft_reload(_build_runtime_reload_completion_context(), was_running, focus_snapshot))
	_pending_runtime_reload_action = ""
	_finish_self_operation(
		{"operation_id": operation_id},
		success,
		"plugin",
		"runtime_soft_reload"
	)


func _complete_runtime_full_reload(operation_id: String, was_running: bool, focus_snapshot: Dictionary = {}) -> void:
	var success: bool = bool(_ensure_runtime_reload_completion_service().complete_full_reload(_build_runtime_reload_completion_context(), was_running, focus_snapshot))
	_pending_runtime_reload_action = ""
	_finish_self_operation(
		{"operation_id": operation_id},
		success,
		"plugin",
		"runtime_full_reload"
	)


func _capture_dock_focus_snapshot() -> Dictionary:
	return _ensure_runtime_reload_completion_service().capture_dock_focus_snapshot(_dock, _state)


func _restore_runtime_dock_focus_snapshot(snapshot: Dictionary) -> void:
	_ensure_runtime_reload_completion_service().restore_dock_focus_snapshot(_build_runtime_reload_completion_context(), snapshot)


func _build_runtime_reload_completion_context() -> Dictionary:
	return {
		"state": _state,
		"dock": _dock,
		"get_dock": Callable(self, "_get_dock"),
		"server_controller": _server_controller,
		"get_server_controller": Callable(self, "_get_server_controller"),
		"refresh_service_instances": Callable(self, "_refresh_service_instances"),
		"recreate_server_controller": Callable(self, "_recreate_server_controller"),
		"reset_localization": Callable(self, "_reset_runtime_reload_localization"),
		"recreate_dock": Callable(self, "_recreate_dock"),
		"refresh_dock": Callable(self, "_refresh_dock"),
		"ensure_update_refs_discovery_requested": Callable(self, "_ensure_update_refs_discovery_requested")
	}


func _get_server_controller():
	return _server_controller


func _get_dock():
	return _dock


func _reset_runtime_reload_localization() -> void:
	LocalizationService.reset_instance()
	_localization = LocalizationService.get_instance()
	if _state != null:
		_localization.set_language(str(_state.settings.get("language", "")))
		MCPDebugBuffer.set_minimum_level(str(_state.settings.get("log_level", "info")))


func _ensure_runtime_reload_completion_service():
	if _runtime_reload_completion_service == null:
		_runtime_reload_completion_service = PluginRuntimeReloadCompletionServiceScript.new()
	return _runtime_reload_completion_service


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
	var scene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	return scene as PackedScene


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
	if _plugin_client_config_state_service != null:
		_plugin_client_config_state_service.dispose()
	_plugin_client_config_state_service = PluginClientConfigStateServiceScript.new()
	_user_tool_service = UserToolServiceScript.new()


func _ensure_runtime_state() -> void:
	if _state == null:
		_state = PluginRuntimeStateScript.new()
