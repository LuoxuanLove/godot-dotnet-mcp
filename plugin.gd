@tool
extends EditorPlugin

const LocalizationService = preload("res://addons/godot_dotnet_mcp/localization/localization_service.gd")
const PluginRuntimeState = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_state.gd")
const SettingsStore = preload("res://addons/godot_dotnet_mcp/plugin/config/settings_store.gd")
const ServerRuntimeController = preload("res://addons/godot_dotnet_mcp/plugin/runtime/server_runtime_controller.gd")
const ToolCatalogService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_catalog_service.gd")
const PluginReloadCoordinator = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_reload_coordinator.gd")
const ClientConfigService = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_service.gd")
const MCP_DOCK_SCENE_PATH := "res://addons/godot_dotnet_mcp/ui/mcp_dock.tscn"
const MCP_DOCK_SCRIPT_PATH := "res://addons/godot_dotnet_mcp/ui/mcp_dock.gd"
const PLUGIN_ID := "godot_dotnet_mcp"
const PENDING_FOCUS_SNAPSHOT_KEY := "_pending_focus_snapshot"

var _state := PluginRuntimeState.new()
var _settings_store := SettingsStore.new()
var _server_controller := ServerRuntimeController.new()
var _tool_catalog := ToolCatalogService.new()
var _config_service := ClientConfigService.new()
var _localization: LocalizationService
var _dock: Control
var _status_poll_accumulator := 0.0


func _enter_tree() -> void:
	_load_state()
	LocalizationService.reset_instance()
	_localization = LocalizationService.get_instance()
	_localization.set_language(str(_state.settings.get("language", "")))

	_server_controller.attach(self, _state.settings)
	_server_controller.server_started.connect(_on_server_started)
	_server_controller.server_stopped.connect(_on_server_stopped)
	_server_controller.request_received.connect(_on_request_received)

	_create_dock()
	_apply_initial_tool_profile_if_needed()
	_refresh_dock()
	set_process(true)

	if bool(_state.settings.get("auto_start", true)):
		_server_controller.start(_state.settings, "auto_start")
		_refresh_dock()

	_restore_pending_focus_snapshot_if_needed()

	print("[Godot MCP] Plugin loaded")


func _exit_tree() -> void:
	set_process(false)
	_save_settings()
	_remove_dock()
	_server_controller.detach()


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


func _create_dock() -> void:
	_remove_dock()
	_remove_stale_docks()
	var dock_scene = _load_packed_scene(MCP_DOCK_SCENE_PATH)
	if dock_scene == null:
		push_error("[Godot MCP] Failed to load dock scene: %s" % MCP_DOCK_SCENE_PATH)
		return
	_dock = dock_scene.instantiate()
	_wire_dock_signals()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)


func _remove_dock() -> void:
	if _dock != null and is_instance_valid(_dock):
		remove_control_from_docks(_dock)
		_dock.queue_free()
	_dock = null


func _remove_stale_docks() -> void:
	var editor_interface = get_editor_interface()
	if editor_interface == null:
		return
	var base_control = editor_interface.get_base_control()
	if base_control == null:
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
		child.queue_free()
		print("[Godot MCP] Removed stale dock instance: %s path=%s" % [child.get_instance_id(), script_path])


func _wire_dock_signals() -> void:
	_dock.current_tab_changed.connect(_on_current_tab_changed)
	_dock.port_changed.connect(_on_port_changed)
	_dock.auto_start_toggled.connect(_on_auto_start_toggled)
	_dock.debug_toggled.connect(_on_debug_toggled)
	_dock.language_changed.connect(_on_language_changed)
	_dock.start_requested.connect(_on_start_requested)
	_dock.restart_requested.connect(_on_restart_requested)
	_dock.stop_requested.connect(_on_stop_requested)
	_dock.full_reload_requested.connect(_on_full_reload_requested)
	_dock.profile_selected.connect(_on_profile_selected)
	_dock.save_profile_requested.connect(_on_save_profile_requested)
	_dock.tool_toggled.connect(_on_tool_toggled)
	_dock.category_toggled.connect(_on_category_toggled)
	_dock.domain_toggled.connect(_on_domain_toggled)
	_dock.category_collapse_toggled.connect(_on_category_collapse_toggled)
	_dock.domain_collapse_toggled.connect(_on_domain_collapse_toggled)
	_dock.expand_all_requested.connect(_on_expand_all_requested)
	_dock.collapse_all_requested.connect(_on_collapse_all_requested)
	_dock.cli_scope_changed.connect(_on_cli_scope_changed)
	_dock.config_platform_changed.connect(_on_config_platform_changed)
	_dock.config_write_requested.connect(_on_config_write_requested)
	_dock.copy_requested.connect(_on_copy_requested)


func _build_dock_model() -> Dictionary:
	var tools_by_category = _server_controller.get_tools_by_category()
	var tool_names = _tool_catalog.build_tool_name_index(tools_by_category)
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

	return {
		"localization": _localization,
		"settings": _state.settings,
		"current_language": _state.resolve_active_language(_localization),
		"current_tab": _state.current_tab,
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
		"builtin_profiles": PluginRuntimeState.BUILTIN_TOOL_PROFILES,
		"custom_profiles": _state.custom_tool_profiles,
		"domain_defs": PluginRuntimeState.TOOL_DOMAIN_DEFS,
		"profile_description": _get_tool_profile_description(profile_id, tool_names),
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

	var tool_names = _tool_catalog.build_tool_name_index(_server_controller.get_tools_by_category())
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


func _on_debug_toggled(enabled: bool) -> void:
	_state.settings["debug_mode"] = enabled
	_server_controller.set_debug_mode(enabled)
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


func _on_profile_selected(profile_id: String) -> void:
	var tool_names = _tool_catalog.build_tool_name_index(_server_controller.get_tools_by_category())
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
	if profile_name.is_empty():
		_show_message(_localization.get_text("tool_profile_name_required"))
		return

	var result = _settings_store.save_custom_profile(
		PluginRuntimeState.TOOL_PROFILE_DIR,
		profile_name,
		_state.settings.get("disabled_tools", [])
	)
	if not result.get("success", false):
		_show_message(_localization.get_text("tool_profile_save_failed"))
		return

	_state.custom_tool_profiles = _settings_store.load_custom_profiles(PluginRuntimeState.TOOL_PROFILE_DIR)
	_state.settings["tool_profile_id"] = "custom:%s" % str(result.get("slug", ""))
	_save_settings()
	_show_message(_localization.get_text("tool_profile_saved") % profile_name)
	_refresh_dock()


func _on_tool_toggled(tool_name: String, enabled: bool) -> void:
	_apply_tool_enabled(tool_name, enabled)


func _on_category_toggled(category: String, enabled: bool) -> void:
	for tool_name in _tool_catalog.build_tool_name_index(_server_controller.get_tools_by_category()):
		if str(tool_name).begins_with(category + "_"):
			_set_tool_enabled(str(tool_name), enabled)
	_server_controller.set_disabled_tools(_state.settings["disabled_tools"])
	_save_settings()
	_refresh_dock()


func _on_domain_toggled(domain_key: String, enabled: bool) -> void:
	var target_categories: Array = []
	for domain_def in PluginRuntimeState.TOOL_DOMAIN_DEFS:
		if str(domain_def.get("key", "")) != domain_key:
			continue
		target_categories = domain_def.get("categories", []).duplicate()
		break

	if target_categories.is_empty():
		for category in _server_controller.get_tools_by_category().keys():
			var known_domain = _tool_catalog.find_domain_key_for_category(PluginRuntimeState.TOOL_DOMAIN_DEFS, str(category))
			if known_domain.is_empty():
				target_categories.append(str(category))

	for tool_name in _tool_catalog.build_tool_name_index(_server_controller.get_tools_by_category()):
		var category = str(tool_name).split("_")[0]
		if target_categories.has(category):
			_set_tool_enabled(str(tool_name), enabled)

	_server_controller.set_disabled_tools(_state.settings["disabled_tools"])
	_save_settings()
	_refresh_dock()


func _on_category_collapse_toggled(category: String) -> void:
	_toggle_array_membership(_state.settings["collapsed_categories"], category)
	_save_settings()
	_refresh_dock()


func _on_domain_collapse_toggled(domain_key: String) -> void:
	_toggle_array_membership(_state.settings["collapsed_domains"], domain_key)
	_save_settings()
	_refresh_dock()


func _on_expand_all_requested() -> void:
	_state.settings["collapsed_categories"] = []
	_state.settings["collapsed_domains"] = []
	_save_settings()
	_refresh_dock()


func _on_collapse_all_requested() -> void:
	var all_categories: Array = []
	for category in _server_controller.get_tools_by_category().keys():
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


func _get_editor_scale() -> float:
	var editor_interface = get_editor_interface()
	if editor_interface:
		return float(editor_interface.get_editor_scale())
	return 1.0


func _load_packed_scene(path: String) -> PackedScene:
	var scene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
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
