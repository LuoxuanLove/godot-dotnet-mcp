@tool
extends EditorPlugin

const LocalizationService = preload("res://addons/godot_dotnet_mcp/localization/localization_service.gd")
const PluginRuntimeState = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_state.gd")
const SettingsStore = preload("res://addons/godot_dotnet_mcp/plugin/config/settings_store.gd")
const ServerRuntimeController = preload("res://addons/godot_dotnet_mcp/plugin/runtime/server_runtime_controller.gd")
const ToolCatalogService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_catalog_service.gd")
const PluginReloadCoordinator = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_reload_coordinator.gd")
const ClientConfigService = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_service.gd")
const UserToolService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_service.gd")
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
var _user_tool_service := UserToolService.new()
var _localization: LocalizationService
var _dock: Control
var _status_poll_accumulator := 0.0
var _editor_debugger_bridge: EditorDebuggerPlugin


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

	_server_controller.attach(self, _state.settings)
	_server_controller.server_started.connect(_on_server_started)
	_server_controller.server_stopped.connect(_on_server_stopped)
	_server_controller.request_received.connect(_on_request_received)
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
	_finish_self_operation(operation, true, "plugin", "_enter_tree")

	print("[Godot MCP] Plugin loaded")


func _exit_tree() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("plugin_exit_tree", "_exit_tree")
	set_process(false)
	_save_settings()
	_remove_dock()
	_uninstall_editor_debugger_bridge()
	_server_controller.detach()
	LocalizationService.reset_instance()
	_localization = null
	_user_tool_service = null
	_config_service = null
	_tool_catalog = null
	_server_controller = null
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


func _process(delta: float) -> void:
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


func _load_state() -> void:
	var load_result = _settings_store.load_plugin_settings(
		PluginRuntimeState.DEFAULT_SETTINGS,
		PluginRuntimeState.SETTINGS_PATH,
		PluginRuntimeState.ALL_TOOL_CATEGORIES,
		PluginRuntimeState.DEFAULT_COLLAPSED_DOMAINS
	)
	_state.settings = load_result["settings"]
	_state.needs_initial_tool_profile_apply = not bool(load_result["has_settings_file"])
	_state.custom_tool_profiles = _settings_store.load_custom_profiles(PluginRuntimeState.TOOL_PROFILE_DIR)


func _save_settings() -> void:
	_settings_store.save_plugin_settings(PluginRuntimeState.SETTINGS_PATH, _state.settings)


func _ensure_runtime_bridge_autoload() -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("runtime_bridge_autoload", "_ensure_runtime_bridge_autoload")
	if not ResourceLoader.exists(RUNTIME_BRIDGE_AUTOLOAD_PATH):
		MCPRuntimeDebugStore.set_bridge_status(false, RUNTIME_BRIDGE_AUTOLOAD_NAME, RUNTIME_BRIDGE_AUTOLOAD_PATH, "Runtime bridge script missing")
		push_error("[Godot MCP] Runtime bridge autoload script not found: %s" % RUNTIME_BRIDGE_AUTOLOAD_PATH)
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
		_record_self_incident("warning", "autoload_conflict", "autoload_name_occupied", "Runtime bridge autoload name is already occupied", "plugin", "_ensure_runtime_bridge_autoload", current_path, "", str(operation.get("operation_id", "")), true, "Resolve the conflicting autoload entry before enabling the runtime bridge.", {"setting_key": setting_key})
		_finish_self_operation(operation, false, "plugin", "_ensure_runtime_bridge_autoload")
		return
	_clear_runtime_bridge_root_instance()
	add_autoload_singleton(RUNTIME_BRIDGE_AUTOLOAD_NAME, RUNTIME_BRIDGE_AUTOLOAD_PATH)
	ProjectSettings.save()
	MCPRuntimeDebugStore.set_bridge_status(true, RUNTIME_BRIDGE_AUTOLOAD_NAME, RUNTIME_BRIDGE_AUTOLOAD_PATH, "Runtime bridge autoload installed")
	_record_runtime_bridge_stale_instance("_ensure_runtime_bridge_autoload", str(operation.get("operation_id", "")))
	_finish_self_operation(operation, true, "plugin", "_ensure_runtime_bridge_autoload")
	print("[Godot MCP] Runtime bridge autoload added")


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
	print("[Godot MCP] Runtime bridge autoload removed")


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
		remove_control_from_docks(_dock)
		if _dock.get_parent() != null:
			_dock.get_parent().remove_child(_dock)
		_dock.set_script(null)
		_dock.free()
	_dock = null
	if _count_dock_instances() > 0:
		_record_self_incident("warning", "reload_conflict", "instance_cleanup_incomplete", "Dock instances remain after dock removal", "plugin", "_remove_dock", MCP_DOCK_SCRIPT_PATH, "", str(operation.get("operation_id", "")), true, "Inspect dock cleanup and plugin reload ordering.", {"remaining_dock_instances": _count_dock_instances()})
	_finish_self_operation(operation, true, "plugin", "_remove_dock")


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
		remove_control_from_docks(child)
		if child.get_parent() != null:
			child.get_parent().remove_child(child)
		child.set_script(null)
		child.free()
		print("[Godot MCP] Removed stale dock instance: %s path=%s" % [child.get_instance_id(), script_path])
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
	connected = _connect_dock_signal("auto_start_toggled", _on_auto_start_toggled, operation_id) and connected
	connected = _connect_dock_signal("log_level_changed", _on_log_level_changed, operation_id) and connected
	connected = _connect_dock_signal("permission_level_changed", _on_permission_level_changed, operation_id) and connected
	connected = _connect_dock_signal("language_changed", _on_language_changed, operation_id) and connected
	connected = _connect_dock_signal("start_requested", _on_start_requested, operation_id) and connected
	connected = _connect_dock_signal("restart_requested", _on_restart_requested, operation_id) and connected
	connected = _connect_dock_signal("stop_requested", _on_stop_requested, operation_id) and connected
	connected = _connect_dock_signal("full_reload_requested", _on_full_reload_requested, operation_id) and connected
	connected = _connect_dock_signal("profile_selected", _on_profile_selected, operation_id) and connected
	connected = _connect_dock_signal("save_profile_requested", _on_save_profile_requested, operation_id) and connected
	connected = _connect_dock_signal("rename_profile_requested", _on_rename_profile_requested, operation_id) and connected
	connected = _connect_dock_signal("delete_profile_requested", _on_delete_profile_requested, operation_id) and connected
	connected = _connect_dock_signal("show_user_tools_toggled", _on_show_user_tools_toggled, operation_id) and connected
	connected = _connect_dock_signal("delete_user_tool_requested", _on_delete_user_tool_requested, operation_id) and connected
	connected = _connect_dock_signal("tool_toggled", _on_tool_toggled, operation_id) and connected
	connected = _connect_dock_signal("category_toggled", _on_category_toggled, operation_id) and connected
	connected = _connect_dock_signal("domain_toggled", _on_domain_toggled, operation_id) and connected
	connected = _connect_dock_signal("category_collapse_toggled", _on_category_collapse_toggled, operation_id) and connected
	connected = _connect_dock_signal("domain_collapse_toggled", _on_domain_collapse_toggled, operation_id) and connected
	connected = _connect_dock_signal("expand_all_requested", _on_expand_all_requested, operation_id) and connected
	connected = _connect_dock_signal("collapse_all_requested", _on_collapse_all_requested, operation_id) and connected
	connected = _connect_dock_signal("cli_scope_changed", _on_cli_scope_changed, operation_id) and connected
	connected = _connect_dock_signal("config_platform_changed", _on_config_platform_changed, operation_id) and connected
	connected = _connect_dock_signal("config_write_requested", _on_config_write_requested, operation_id) and connected
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

	var desktop_clients = _build_desktop_client_models()
	var cli_clients = _build_cli_client_models()
	var config_platforms = _build_config_platform_models(desktop_clients, cli_clients)
	_state.current_config_platform = _resolve_current_config_platform(config_platforms)

	var self_diagnostics = _build_self_diagnostic_health_snapshot()
	return {
		"localization": _localization,
		"settings": _state.settings,
		"current_language": _state.resolve_active_language(_localization),
		"current_tab": _state.current_tab,
		"permission_levels": PluginRuntimeState.PERMISSION_LEVELS,
		"current_permission_level": _get_permission_level(),
		"show_user_tools": bool(_state.settings.get("show_user_tools", false)),
		"log_levels": MCPDebugBuffer.get_available_levels(),
		"current_log_level": str(_state.settings.get("log_level", MCPDebugBuffer.get_minimum_level())),
		"current_cli_scope": _state.current_cli_scope,
		"current_config_platform": _state.current_config_platform,
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
		"builtin_profiles": PluginRuntimeState.BUILTIN_TOOL_PROFILES,
		"custom_profiles": _state.custom_tool_profiles,
		"domain_defs": PluginRuntimeState.TOOL_DOMAIN_DEFS,
		"profile_description": _get_tool_profile_description(profile_id, tool_names),
		"user_tools": _user_tool_service.list_user_tools(),
		"desktop_clients": desktop_clients,
		"cli_clients": cli_clients,
		"config_platforms": config_platforms
	}


func _refresh_dock() -> void:
	if _dock == null or not is_instance_valid(_dock):
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


func _build_desktop_client_models() -> Array[Dictionary]:
	var host = str(_state.settings.get("host", "127.0.0.1"))
	var port = int(_state.settings.get("port", 3000))
	return [
		{
			"id": "claude_desktop",
			"name_key": "config_client_claude_desktop",
			"summary_key": "config_client_claude_desktop_desc",
			"path": _config_service.get_claude_config_path(),
			"content": _config_service.get_url_config(host, port),
			"writeable": true
		},
		{
			"id": "cursor",
			"name_key": "config_client_cursor",
			"summary_key": "config_client_cursor_desc",
			"path": _config_service.get_cursor_config_path(),
			"content": _config_service.get_url_config(host, port),
			"writeable": true
		},
		{
			"id": "gemini",
			"name_key": "config_client_gemini",
			"summary_key": "config_client_gemini_desc",
			"path": _config_service.get_gemini_config_path(),
			"content": _config_service.get_http_url_config(host, port),
			"writeable": true
		}
	]


func _build_cli_client_models() -> Array[Dictionary]:
	var host = str(_state.settings.get("host", "127.0.0.1"))
	var port = int(_state.settings.get("port", 3000))
	return [
		{
			"id": "claude_code",
			"name_key": "config_client_claude_code",
			"summary_key": "config_client_claude_code_desc",
			"content": _config_service.get_claude_code_command(_state.current_cli_scope, host, port)
		},
		{
			"id": "codex",
			"name_key": "config_client_codex",
			"summary_key": "config_client_codex_desc",
			"content": _config_service.get_codex_command(host, port)
		}
	]


func _build_config_platform_models(desktop_clients: Array[Dictionary], cli_clients: Array[Dictionary]) -> Array[Dictionary]:
	var platforms: Array[Dictionary] = []
	for client in desktop_clients:
		platforms.append({
			"id": str(client.get("id", "")),
			"name_key": str(client.get("name_key", "")),
			"group": "desktop"
		})
	for client in cli_clients:
		platforms.append({
			"id": str(client.get("id", "")),
			"name_key": str(client.get("name_key", "")),
			"group": "cli"
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


func _on_port_changed(value: int) -> void:
	_state.settings["port"] = value
	_save_settings()
	_refresh_dock()


func _on_auto_start_toggled(enabled: bool) -> void:
	_state.settings["auto_start"] = enabled
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


func _on_profile_selected(profile_id: String) -> void:
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


func _on_save_profile_requested(profile_name: String) -> void:
	var result = _save_custom_profile(profile_name)
	if not bool(result.get("success", false)):
		_show_message(str(result.get("error", _localization.get_text("tool_profile_save_failed"))))
		return
	_show_message(str(result.get("message", "")))
	_refresh_dock()


func _on_rename_profile_requested(profile_id: String, profile_name: String) -> void:
	var result = _rename_custom_profile(profile_id, profile_name)
	if not bool(result.get("success", false)):
		_show_message(str(result.get("error", _localization.get_text("tool_profile_rename_failed"))))
		return
	_show_message(str(result.get("message", "")))
	_refresh_dock()


func _on_delete_profile_requested(profile_id: String) -> void:
	var result = _delete_custom_profile(profile_id)
	if not bool(result.get("success", false)):
		_show_message(str(result.get("error", _localization.get_text("tool_profile_delete_failed"))))
		return
	_show_message(str(result.get("message", "")))
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


func _on_show_user_tools_toggled(enabled: bool) -> void:
	_state.settings["show_user_tools"] = enabled
	_save_settings()
	_refresh_dock()


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


func _on_category_collapse_toggled(category: String) -> void:
	_toggle_array_membership(_state.settings["collapsed_categories"], category)
	_save_settings()


func _on_domain_collapse_toggled(domain_key: String) -> void:
	_toggle_array_membership(_state.settings["collapsed_domains"], domain_key)
	_save_settings()


func _on_expand_all_requested() -> void:
	_state.settings["collapsed_categories"] = []
	_state.settings["collapsed_domains"] = []
	_save_settings()
	_refresh_dock()


func _on_collapse_all_requested() -> void:
	var all_categories: Array = []
	for category in _server_controller.get_all_tools_by_category().keys():
		all_categories.append(str(category))

	var all_domains = PluginRuntimeState.DEFAULT_COLLAPSED_DOMAINS.duplicate()
	_state.settings["collapsed_categories"] = all_categories
	_state.settings["collapsed_domains"] = all_domains
	_save_settings()
	_refresh_dock()


func _on_cli_scope_changed(scope: String) -> void:
	_state.current_cli_scope = scope
	_refresh_dock()


func _on_config_platform_changed(platform_id: String) -> void:
	_state.current_config_platform = platform_id
	_refresh_dock()


func _on_config_write_requested(config_type: String, filepath: String, config: String, client_name: String) -> void:
	var result = _config_service.write_config_file(config_type, filepath, config)
	if not result.get("success", false):
		match str(result.get("error", "")):
			"parse_error":
				_show_message(_localization.get_text("msg_parse_error"))
			"dir_error":
				_show_message(_localization.get_text("msg_dir_error") + str(result.get("path", "")))
			_:
				_show_message(_localization.get_text("msg_write_error"))
		return

	_show_message(_localization.get_text("msg_config_success") % client_name)


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


func _toggle_array_membership(items: Array, value: String) -> void:
	if items.has(value):
		items.erase(value)
	else:
		items.append(value)


func _show_message(message: String) -> void:
	print("[Godot MCP] %s" % message)
	if _dock and is_instance_valid(_dock):
		_dock.show_message(_localization.get_text("dialog_title"), message)


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
		_schedule_user_tool_catalog_refresh()
	return result


func delete_user_tool_from_tools(script_path: String, authorized: bool, agent_hint: String = "") -> Dictionary:
	var result = _user_tool_service.delete_tool(script_path, authorized, agent_hint)
	if bool(result.get("success", false)):
		_schedule_user_tool_catalog_refresh()
	return result


func restore_user_tool_from_tools(authorized: bool, agent_hint: String = "") -> Dictionary:
	var result = _user_tool_service.restore_latest_backup(authorized, agent_hint)
	if bool(result.get("success", false)):
		_schedule_user_tool_catalog_refresh()
	return result


func _schedule_user_tool_catalog_refresh() -> void:
	call_deferred("_apply_user_tool_catalog_refresh")


func _apply_user_tool_catalog_refresh() -> void:
	_server_controller.reload_all_domains()
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
	var success = _server_controller.start(_state.settings, "tool_runtime_restart")
	_refresh_dock()
	_finish_self_operation(operation, success, "plugin", "runtime_restart_server")
	return {"success": success, "running": _server_controller.is_running()}


func runtime_soft_reload() -> Dictionary:
	var operation = PluginSelfDiagnosticStore.begin_operation("runtime_soft_reload", "runtime_soft_reload")
	var was_running = _server_controller.is_running()
	_refresh_service_instances()
	LocalizationService.reset_instance()
	_localization = LocalizationService.get_instance()
	_localization.set_language(str(_state.settings.get("language", "")))
	MCPDebugBuffer.set_minimum_level(str(_state.settings.get("log_level", "info")))
	if was_running:
		_server_controller.start(_state.settings, "tool_soft_reload")
	else:
		_server_controller.reinitialize(_state.settings, "tool_soft_reload")
	_recreate_dock()
	_finish_self_operation(operation, true, "plugin", "runtime_soft_reload")
	return {"success": true, "message": "Plugin soft reloaded", "running": _server_controller.is_running()}


func runtime_full_reload() -> Dictionary:
	var operation = PluginSelfDiagnosticStore.begin_operation("runtime_full_reload", "runtime_full_reload")
	_on_full_reload_requested()
	_finish_self_operation(operation, true, "plugin", "runtime_full_reload")
	return {"success": true, "message": "Plugin full reload scheduled"}


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
	_on_show_user_tools_toggled(enabled)
	return {"success": true, "show_user_tools": enabled}


func get_developer_settings_for_tools() -> Dictionary:
	return {
		"success": true,
		"data": {
			"permission_level": _get_permission_level(),
			"log_level": get_log_level_for_tools(),
			"show_user_tools": bool(_state.settings.get("show_user_tools", false)),
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
	var codes: Array = _localization.get_available_languages().keys()
	codes.sort()
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
	_on_profile_selected(profile_id)
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
		return bool(_state.settings.get("show_user_tools", false))
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
	coordinator.configure(PLUGIN_ID, editor_interface)
	base_control.add_child(coordinator)


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
	_user_tool_service = UserToolService.new()
