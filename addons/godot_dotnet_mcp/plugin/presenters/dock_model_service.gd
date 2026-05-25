@tool
extends RefCounted
class_name DockModelService

const ToolProfileCatalog = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_profile_catalog.gd")
const MCPToolManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_manifest.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const PluginInstanceFreshness = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_instance_freshness.gd")
const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const DockPresenterScript = preload("res://addons/godot_dotnet_mcp/plugin/presenters/dock_presenter.gd")
const ToolPresentationService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_presentation_service.gd")

var _state
var _localization
var _server_controller
var _tool_catalog
var _config_service
var _dock_presenter = DockPresenterScript.new()
var _user_tool_service
var _client_install_detection_service
var _user_tool_watch_service
var _tool_access_feature
var _self_diagnostic_feature
var _get_editor_scale := Callable()
var _plugin_version_cache := ""
var _plugin_version_loaded := false


func configure(
	context_or_state,
	localization = null,
	server_controller = null,
	tool_catalog = null,
	config_service = null,
	dock_presenter = null,
	user_tool_service = null,
	client_install_detection_service = null,
	user_tool_watch_service = null,
	get_editor_scale: Callable = Callable()
) -> void:
	if _dock_presenter == null:
		_dock_presenter = DockPresenterScript.new()
	if localization == null and server_controller == null and tool_catalog == null and config_service == null and user_tool_service == null and client_install_detection_service == null and user_tool_watch_service == null:
		if context_or_state == null:
			dispose()
			return
		_state = _context_get(context_or_state, "state")
		_localization = _context_get(context_or_state, "localization")
		_server_controller = _context_get(context_or_state, "server_controller")
		_tool_catalog = _context_get(context_or_state, "tool_catalog")
		_config_service = _context_get(context_or_state, "config_service")
		var injected_presenter = _context_get(context_or_state, "dock_presenter")
		if injected_presenter != null:
			_dock_presenter = injected_presenter
		_user_tool_service = _context_get(context_or_state, "user_tool_service")
		_client_install_detection_service = _context_get(context_or_state, "client_install_detection_service")
		_user_tool_watch_service = _context_get(context_or_state, "user_tool_watch_service")
		_tool_access_feature = _context_get(context_or_state, "tool_access_feature")
		_self_diagnostic_feature = _context_get(context_or_state, "self_diagnostic_feature")
		var resolved_editor_scale = _context_get(context_or_state, "get_editor_scale", Callable())
		_get_editor_scale = resolved_editor_scale if resolved_editor_scale is Callable else Callable()
		return

	_state = context_or_state
	_localization = localization
	_server_controller = server_controller
	_tool_catalog = tool_catalog
	_config_service = config_service
	if dock_presenter != null:
		_dock_presenter = dock_presenter
	_user_tool_service = user_tool_service
	_client_install_detection_service = client_install_detection_service
	_user_tool_watch_service = user_tool_watch_service
	_tool_access_feature = null
	_self_diagnostic_feature = null
	_get_editor_scale = get_editor_scale


func _context_get(context, key: String, default_value = null):
	if context == null:
		return default_value
	if context is Dictionary:
		return (context as Dictionary).get(key, default_value)
	if context.has_method("get"):
		var value = context.get(key)
		return default_value if value == null else value
	return default_value


func dispose() -> void:
	if _dock_presenter != null and _dock_presenter.has_method("dispose"):
		_dock_presenter.dispose()
	_state = null
	_localization = null
	_server_controller = null
	_tool_catalog = null
	_config_service = null
	_dock_presenter = null
	_user_tool_service = null
	_client_install_detection_service = null
	_user_tool_watch_service = null
	_tool_access_feature = null
	_self_diagnostic_feature = null
	_get_editor_scale = Callable()
	_plugin_version_cache = ""
	_plugin_version_loaded = false


func build_model() -> Dictionary:
	if _state == null or _localization == null or _server_controller == null or _tool_catalog == null or _dock_presenter == null:
		return {}

	var settings = _get_settings()
	var all_tools_by_category = _get_all_tools_by_category()
	var tools_by_category = _filter_visible_tools_by_category(all_tools_by_category)
	var domain_states = _server_controller.get_domain_states()
	var tool_presentation = ToolPresentationService.build_tool_presentation(
		_build_exposed_tool_definitions(tools_by_category),
		tools_by_category,
		domain_states,
		settings.get("disabled_tools", []),
		MCPToolManifest.TOOL_DOMAIN_DEFS
	)
	var self_diagnostics = _build_self_diagnostic_health_snapshot()
	var client_install_statuses := {}
	var plugin_freshness := {}
	var plugin_version := ""

	if int(_state.current_tab) == 2:
		client_install_statuses = _get_client_install_statuses(settings)
	if int(_state.current_tab) == 3:
		plugin_freshness = _get_plugin_freshness_snapshot()
		plugin_version = _read_plugin_version()

	var model = _dock_presenter.build_model({
		"state": _state,
		"settings": settings,
		"localization": _localization,
		"server_controller": _server_controller,
		"tool_catalog": _tool_catalog,
		"user_tool_service": _user_tool_service,
		"config_service": _config_service,
		"all_tools_by_category": all_tools_by_category,
		"tools_by_category": tools_by_category,
		"self_diagnostics": self_diagnostics,
		"self_diagnostic_copy_text": PluginSelfDiagnosticStore.build_copy_text(self_diagnostics),
		"user_tool_watch": _get_user_tool_watch_status(),
		"editor_scale": _resolve_editor_scale(),
		"log_levels": MCPDebugBuffer.get_available_levels(),
		"current_log_level": _normalize_log_level(str(settings.get("log_level", MCPDebugBuffer.get_minimum_level()))),
		"builtin_profiles": ToolProfileCatalog.get_builtin_profiles(),
		"custom_profiles": _state.custom_tool_profiles,
		"domain_defs": MCPToolManifest.TOOL_DOMAIN_DEFS,
		"tool_presentation": tool_presentation,
		"client_install_statuses": client_install_statuses,
		"plugin_freshness": plugin_freshness,
		"plugin_version": plugin_version,
		"update_refs_state": str(_get_state_value("update_refs_state", "idle")),
		"update_refs_status": str(_get_state_value("update_refs_status", "")),
		"update_refs_error": str(_get_state_value("update_refs_error", "")),
		"update_refs_branches": _duplicate_string_array(_get_state_value("update_ref_branches", [])),
		"update_refs_releases": _duplicate_string_array(_get_state_value("update_ref_releases", [])),
		"update_refs_latest_stable_release": str(_get_state_value("update_ref_latest_stable_release", "")),
		"update_refs_latest_release": str(_get_state_value("update_ref_latest_release", "")),
		"update_refs_release_source": str(_get_state_value("update_refs_release_source", "")),
		"update_refs_commits": _duplicate_string_dictionary(_get_state_value("update_ref_commits", {})),
		"update_refs_versions": _duplicate_string_dictionary(_get_state_value("update_ref_versions", {})),
		"update_compare_state": str(_get_state_value("update_compare_state", "idle")),
		"update_compare_error": str(_get_state_value("update_compare_error", "")),
		"update_compare_base_commit": str(_get_state_value("update_compare_base_commit", "")),
		"update_compare_target_ref": str(_get_state_value("update_compare_target_ref", "")),
		"update_compare_target_commit": str(_get_state_value("update_compare_target_commit", "")),
		"update_compare_ahead_by": int(_get_state_value("update_compare_ahead_by", -1)),
		"update_compare_behind_by": int(_get_state_value("update_compare_behind_by", -1)),
		"update_sync_state": str(_get_state_value("update_sync_state", "idle")),
		"update_sync_status": str(_get_state_value("update_sync_status", "")),
		"update_sync_error": str(_get_state_value("update_sync_error", "")),
		"update_sync_target_ref": str(_get_state_value("update_sync_target_ref", "")),
		"update_sync_target_kind": str(_get_state_value("update_sync_target_kind", ""))
	})
	model["update_refs_state"] = str(_get_state_value("update_refs_state", "idle"))
	model["update_refs_status"] = str(_get_state_value("update_refs_status", ""))
	model["update_refs_error"] = str(_get_state_value("update_refs_error", ""))
	model["update_refs_branches"] = _duplicate_string_array(_get_state_value("update_ref_branches", []))
	model["update_refs_releases"] = _duplicate_string_array(_get_state_value("update_ref_releases", []))
	model["update_refs_latest_stable_release"] = str(_get_state_value("update_ref_latest_stable_release", ""))
	model["update_refs_latest_release"] = str(_get_state_value("update_ref_latest_release", ""))
	model["update_refs_release_source"] = str(_get_state_value("update_refs_release_source", ""))
	model["update_refs_commits"] = _duplicate_string_dictionary(_get_state_value("update_ref_commits", {}))
	model["update_refs_versions"] = _duplicate_string_dictionary(_get_state_value("update_ref_versions", {}))
	model["update_compare_state"] = str(_get_state_value("update_compare_state", "idle"))
	model["update_compare_error"] = str(_get_state_value("update_compare_error", ""))
	model["update_compare_base_commit"] = str(_get_state_value("update_compare_base_commit", ""))
	model["update_compare_target_ref"] = str(_get_state_value("update_compare_target_ref", ""))
	model["update_compare_target_commit"] = str(_get_state_value("update_compare_target_commit", ""))
	model["update_compare_ahead_by"] = int(_get_state_value("update_compare_ahead_by", -1))
	model["update_compare_behind_by"] = int(_get_state_value("update_compare_behind_by", -1))
	model["update_sync_state"] = str(_get_state_value("update_sync_state", "idle"))
	model["update_sync_status"] = str(_get_state_value("update_sync_status", ""))
	model["update_sync_error"] = str(_get_state_value("update_sync_error", ""))
	model["update_sync_target_ref"] = str(_get_state_value("update_sync_target_ref", ""))
	model["update_sync_target_kind"] = str(_get_state_value("update_sync_target_kind", ""))
	model["all_tools_by_category"] = all_tools_by_category
	return model


func _build_exposed_tool_definitions(all_tools_by_category: Dictionary) -> Array[Dictionary]:
	var exposed: Array[Dictionary] = []
	for tool_def in all_tools_by_category.get("system", []):
		if not (tool_def is Dictionary):
			continue
		var tool := (tool_def as Dictionary).duplicate(true)
		if bool(tool.get("compatibility_alias", false)):
			continue
		tool["name"] = str(tool.get("full_name", "system_%s" % str(tool.get("name", ""))))
		tool["category"] = "system"
		exposed.append(tool)
	return exposed


func _get_settings() -> Dictionary:
	if _state == null or not (_state.settings is Dictionary):
		return {}
	return _state.settings


func _get_state_value(property_name: String, default_value = null):
	if _state == null:
		return default_value
	var value = _state.get(property_name)
	return default_value if value == null else value


func _normalize_log_level(level: String) -> String:
	var normalized := level.to_lower().strip_edges()
	if normalized == "trace":
		return "debug"
	if not (normalized in MCPDebugBuffer.get_available_levels()):
		return MCPDebugBuffer.get_minimum_level()
	return normalized


func _get_all_tools_by_category() -> Dictionary:
	if _server_controller == null or not _server_controller.has_method("get_all_tools_by_category"):
		return {}
	var tools = _server_controller.get_all_tools_by_category()
	if tools is Dictionary:
		return (tools as Dictionary).duplicate(true)
	return {}


func _filter_visible_tools_by_category(all_tools_by_category: Dictionary) -> Dictionary:
	var filtered = all_tools_by_category.duplicate(true)
	for category in filtered.keys():
		if not _is_tool_category_visible(str(category)):
			filtered.erase(category)
	return filtered


func _is_tool_category_visible(category: String) -> bool:
	if _tool_access_feature != null and _tool_access_feature.has_method("is_tool_category_visible"):
		return _tool_access_feature.is_tool_category_visible(category)
	if category == "user":
		return bool(_get_settings().get("show_user_tools", true))
	return true


func _build_self_diagnostic_health_snapshot() -> Dictionary:
	if _self_diagnostic_feature != null and _self_diagnostic_feature.has_method("build_self_diagnostic_health_snapshot"):
		return _self_diagnostic_feature.build_self_diagnostic_health_snapshot()
	return PluginSelfDiagnosticStore.get_health_snapshot({})


func _get_user_tool_watch_status() -> Dictionary:
	if _user_tool_watch_service == null:
		return {}
	return _user_tool_watch_service.get_status()


func _resolve_editor_scale() -> float:
	if _get_editor_scale.is_valid():
		return float(_get_editor_scale.call())
	return 1.0


func _get_client_install_statuses(settings: Dictionary) -> Dictionary:
	if _client_install_detection_service == null:
		return {}
	_client_install_detection_service.configure(settings)
	return _client_install_detection_service.detect_all()


func _get_plugin_freshness_snapshot() -> Dictionary:
	return PluginInstanceFreshness.get_freshness_snapshot()


func _read_plugin_version() -> String:
	if _plugin_version_loaded:
		return _plugin_version_cache
	_plugin_version_loaded = true
	var config := ConfigFile.new()
	if config.load("res://addons/godot_dotnet_mcp/plugin.cfg") != OK:
		_plugin_version_cache = ""
		return _plugin_version_cache
	_plugin_version_cache = str(config.get_value("plugin", "version", ""))
	return _plugin_version_cache


func _duplicate_string_array(values) -> Array[String]:
	var result: Array[String] = []
	if not (values is Array):
		return result
	for value in values:
		result.append(str(value))
	return result


func _duplicate_string_dictionary(values) -> Dictionary:
	var result := {}
	if not (values is Dictionary):
		return result
	for key in (values as Dictionary).keys():
		var normalized_key := str(key).strip_edges()
		var normalized_value := str((values as Dictionary).get(key, "")).strip_edges()
		if not normalized_key.is_empty() and not normalized_value.is_empty():
			result[normalized_key] = normalized_value
	return result
