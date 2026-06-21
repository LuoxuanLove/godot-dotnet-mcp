@tool
extends RefCounted
class_name DockModelService

const ToolProfileCatalog = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_profile_catalog.gd")
const MCPToolManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_manifest.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const PluginInstanceFreshness = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_instance_freshness.gd")
const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const DockPresenterScript = preload("res://addons/godot_dotnet_mcp/plugin/presenters/dock_presenter.gd")
const ToolCatalogSnapshotService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_catalog_snapshot_service.gd")
const DockMcpCatalogProjectionServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/presenters/dock_mcp_catalog_projection_service.gd")

var _state
var _localization
var _server_controller
var _tool_catalog
var _config_service
var _dock_presenter = DockPresenterScript.new()
var _mcp_catalog_projection_service = DockMcpCatalogProjectionServiceScript.new()
var _user_tool_service
var _client_install_detection_service
var _user_tool_watch_service
var _tool_access_feature
var _self_diagnostic_feature
var _get_editor_scale := Callable()
var _plugin_version_cache := ""
var _plugin_version_loaded := false
var _last_catalog_signature := ""
var _last_catalog_snapshot: Dictionary = {}
var _last_tool_catalog_model_signature := ""
var _last_tool_catalog_model: Dictionary = {}
var _last_mcp_projection_signature := ""
var _last_mcp_catalog_projection: Dictionary = {}


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
	if _mcp_catalog_projection_service == null:
		_mcp_catalog_projection_service = DockMcpCatalogProjectionServiceScript.new()
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
		_configure_mcp_catalog_projection_service()
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
	_configure_mcp_catalog_projection_service()


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
	if _mcp_catalog_projection_service != null and _mcp_catalog_projection_service.has_method("dispose"):
		_mcp_catalog_projection_service.dispose()
	_state = null
	_localization = null
	_server_controller = null
	_tool_catalog = null
	_config_service = null
	_dock_presenter = null
	_mcp_catalog_projection_service = null
	_user_tool_service = null
	_client_install_detection_service = null
	_user_tool_watch_service = null
	_tool_access_feature = null
	_self_diagnostic_feature = null
	_get_editor_scale = Callable()
	_plugin_version_cache = ""
	_plugin_version_loaded = false
	_last_catalog_signature = ""
	_last_catalog_snapshot = {}
	_last_tool_catalog_model_signature = ""
	_last_tool_catalog_model = {}
	_last_mcp_projection_signature = ""
	_last_mcp_catalog_projection = {}


func build_model() -> Dictionary:
	if _state == null or _localization == null or _server_controller == null or _tool_catalog == null or _dock_presenter == null:
		return {}

	var settings = _get_settings()
	var current_tab := int(_state.current_tab)
	var needs_tool_catalog := _tab_needs_tool_catalog(current_tab)
	var needs_mcp_catalog := _tab_needs_mcp_catalog(current_tab)
	var needs_runtime_diagnostics := _tab_needs_runtime_diagnostics(current_tab)
	var all_tools_by_category := {}
	var tools_by_category := {}
	var catalog_snapshot := {}
	var tool_presentation := {}
	if needs_tool_catalog:
		var tool_catalog_model := _build_tool_catalog_model(settings, _resolve_tool_presentation_views())
		all_tools_by_category = tool_catalog_model.get("all_tools_by_category", {})
		tools_by_category = tool_catalog_model.get("tools_by_category", {})
		catalog_snapshot = tool_catalog_model.get("catalog_snapshot", {})
		tool_presentation = catalog_snapshot.get("presentation", {})
	var server_status := _build_server_status_snapshot(needs_runtime_diagnostics)
	var self_diagnostics = _build_self_diagnostic_health_snapshot(needs_runtime_diagnostics)
	var client_install_statuses := {}
	var plugin_freshness := {}
	var plugin_version := ""
	var mcp_catalog_projection := _build_mcp_catalog_projection() if needs_mcp_catalog else {}

	if current_tab == 4:
		client_install_statuses = _get_client_install_statuses(settings)
	if current_tab == 5:
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
		"is_running": bool(server_status.get("is_running", false)),
		"stats": server_status.get("stats", {}),
		"domain_states": server_status.get("domain_states", []),
		"reload_status": server_status.get("reload_status", {}),
		"performance": server_status.get("performance", {}),
		"tool_load_errors": server_status.get("tool_load_errors", []),
		"all_tools_by_category": all_tools_by_category,
		"tools_by_category": tools_by_category,
		"self_diagnostics": self_diagnostics,
		"self_diagnostic_copy_text": PluginSelfDiagnosticStore.build_copy_text(self_diagnostics),
		"user_tool_watch": _get_user_tool_watch_status(),
		"editor_scale": _resolve_editor_scale(),
		"log_levels": MCPDebugBuffer.get_available_levels(),
		"current_log_level": _normalize_log_level(str(settings.get("log_level", MCPDebugBuffer.get_minimum_level()))),
		"current_tools_view": str(_get_state_value("current_tools_view", "agent_tools")),
		"builtin_profiles": ToolProfileCatalog.get_builtin_profiles(),
		"custom_profiles": _state.custom_tool_profiles,
		"domain_defs": _get_domain_defs(catalog_snapshot),
		"tool_presentation": tool_presentation,
		"agent_tool_presentation": catalog_snapshot.get("agent_tool_presentation", {}),
		"internal_executor_presentation": catalog_snapshot.get("internal_executor_presentation", {}),
		"tool_diagnostics_presentation": catalog_snapshot.get("tool_diagnostics_presentation", {}),
		"mcp_resources": mcp_catalog_projection.get("mcp_resources", []),
		"mcp_resource_templates": mcp_catalog_projection.get("mcp_resource_templates", []),
		"mcp_prompts": mcp_catalog_projection.get("mcp_prompts", []),
		"mcp_resource_presentation": mcp_catalog_projection.get("mcp_resource_presentation", {}),
		"mcp_prompt_presentation": mcp_catalog_projection.get("mcp_prompt_presentation", {}),
		"mcp_catalog_counts": mcp_catalog_projection.get("mcp_catalog_counts", {}),
		"mcp_catalog_preview": _get_state_value("mcp_catalog_preview", {}),
		"client_install_statuses": client_install_statuses,
		"plugin_freshness": plugin_freshness,
		"plugin_version": plugin_version,
		"update_refs_state": str(_get_state_value("update_refs_state", "idle")),
		"update_refs_status": str(_get_state_value("update_refs_status", "")),
		"update_refs_error": str(_get_state_value("update_refs_error", "")),
		"update_refs_refresh_state": str(_get_state_value("update_refs_refresh_state", "idle")),
		"update_refs_refresh_error": str(_get_state_value("update_refs_refresh_error", "")),
		"update_refs_last_checked_unix": int(_get_state_value("update_refs_last_checked_unix", 0)),
		"update_refs_refresh_serial": int(_get_state_value("update_refs_refresh_serial", 0)),
		"update_refs_branches": _duplicate_string_array(_get_state_value("update_ref_branches", [])),
		"update_refs_releases": _duplicate_string_array(_get_state_value("update_ref_releases", [])),
		"update_refs_latest_stable_release": str(_get_state_value("update_ref_latest_stable_release", "")),
		"update_refs_latest_release": str(_get_state_value("update_ref_latest_release", "")),
		"update_refs_release_source": str(_get_state_value("update_refs_release_source", "")),
		"update_refs_commits": _duplicate_string_dictionary(_get_state_value("update_ref_commits", {})),
		"update_refs_versions": _duplicate_string_dictionary(_get_state_value("update_ref_versions", {})),
		"update_compare_state": str(_get_state_value("update_compare_state", "idle")),
		"update_compare_error": str(_get_state_value("update_compare_error", "")),
		"update_compare_refresh_state": str(_get_state_value("update_compare_refresh_state", "idle")),
		"update_compare_refresh_error": str(_get_state_value("update_compare_refresh_error", "")),
		"update_compare_last_checked_unix": int(_get_state_value("update_compare_last_checked_unix", 0)),
		"update_compare_refresh_serial": int(_get_state_value("update_compare_refresh_serial", 0)),
		"update_compare_base_commit": str(_get_state_value("update_compare_base_commit", "")),
		"update_compare_target_ref": str(_get_state_value("update_compare_target_ref", "")),
		"update_compare_target_commit": str(_get_state_value("update_compare_target_commit", "")),
		"update_compare_ahead_by": int(_get_state_value("update_compare_ahead_by", -1)),
		"update_compare_behind_by": int(_get_state_value("update_compare_behind_by", -1)),
		"update_selection_refresh_pending": bool(_get_state_value("update_selection_refresh_pending", false)),
		"update_selection_refresh_pending_ref": str(_get_state_value("update_selection_refresh_pending_ref", "")),
		"update_sync_state": str(_get_state_value("update_sync_state", "idle")),
		"update_sync_status": str(_get_state_value("update_sync_status", "")),
		"update_sync_error": str(_get_state_value("update_sync_error", "")),
		"update_sync_target_ref": str(_get_state_value("update_sync_target_ref", "")),
		"update_sync_target_kind": str(_get_state_value("update_sync_target_kind", "")),
		"update_sync_progress": float(_get_state_value("update_sync_progress", 0.0)),
		"client_action_state": str(_get_state_value("client_action_state", "idle")),
		"client_action_client_id": str(_get_state_value("client_action_client_id", "")),
		"client_action_status": str(_get_state_value("client_action_status", ""))
	})
	model["update_refs_state"] = str(_get_state_value("update_refs_state", "idle"))
	model["update_refs_status"] = str(_get_state_value("update_refs_status", ""))
	model["update_refs_error"] = str(_get_state_value("update_refs_error", ""))
	model["update_refs_refresh_state"] = str(_get_state_value("update_refs_refresh_state", "idle"))
	model["update_refs_refresh_error"] = str(_get_state_value("update_refs_refresh_error", ""))
	model["update_refs_last_checked_unix"] = int(_get_state_value("update_refs_last_checked_unix", 0))
	model["update_refs_refresh_serial"] = int(_get_state_value("update_refs_refresh_serial", 0))
	model["update_refs_branches"] = _duplicate_string_array(_get_state_value("update_ref_branches", []))
	model["update_refs_releases"] = _duplicate_string_array(_get_state_value("update_ref_releases", []))
	model["update_refs_latest_stable_release"] = str(_get_state_value("update_ref_latest_stable_release", ""))
	model["update_refs_latest_release"] = str(_get_state_value("update_ref_latest_release", ""))
	model["update_refs_release_source"] = str(_get_state_value("update_refs_release_source", ""))
	model["update_refs_commits"] = _duplicate_string_dictionary(_get_state_value("update_ref_commits", {}))
	model["update_refs_versions"] = _duplicate_string_dictionary(_get_state_value("update_ref_versions", {}))
	model["update_compare_state"] = str(_get_state_value("update_compare_state", "idle"))
	model["update_compare_error"] = str(_get_state_value("update_compare_error", ""))
	model["update_compare_refresh_state"] = str(_get_state_value("update_compare_refresh_state", "idle"))
	model["update_compare_refresh_error"] = str(_get_state_value("update_compare_refresh_error", ""))
	model["update_compare_last_checked_unix"] = int(_get_state_value("update_compare_last_checked_unix", 0))
	model["update_compare_refresh_serial"] = int(_get_state_value("update_compare_refresh_serial", 0))
	model["update_compare_base_commit"] = str(_get_state_value("update_compare_base_commit", ""))
	model["update_compare_target_ref"] = str(_get_state_value("update_compare_target_ref", ""))
	model["update_compare_target_commit"] = str(_get_state_value("update_compare_target_commit", ""))
	model["update_compare_ahead_by"] = int(_get_state_value("update_compare_ahead_by", -1))
	model["update_compare_behind_by"] = int(_get_state_value("update_compare_behind_by", -1))
	model["update_selection_refresh_pending"] = bool(_get_state_value("update_selection_refresh_pending", false))
	model["update_selection_refresh_pending_ref"] = str(_get_state_value("update_selection_refresh_pending_ref", ""))
	model["update_sync_state"] = str(_get_state_value("update_sync_state", "idle"))
	model["update_sync_status"] = str(_get_state_value("update_sync_status", ""))
	model["update_sync_error"] = str(_get_state_value("update_sync_error", ""))
	model["update_sync_target_ref"] = str(_get_state_value("update_sync_target_ref", ""))
	model["update_sync_target_kind"] = str(_get_state_value("update_sync_target_kind", ""))
	model["update_sync_progress"] = float(_get_state_value("update_sync_progress", 0.0))
	model["client_action_state"] = str(_get_state_value("client_action_state", "idle"))
	model["client_action_client_id"] = str(_get_state_value("client_action_client_id", ""))
	model["client_action_status"] = str(_get_state_value("client_action_status", ""))
	model["all_tools_by_category"] = all_tools_by_category
	return model


func _build_exposed_tool_definitions(all_tools_by_category: Dictionary) -> Array[Dictionary]:
	var exposed: Array[Dictionary] = []
	for category_value in all_tools_by_category.keys():
		var category := str(category_value)
		for tool_def in all_tools_by_category.get(category, []):
			if not (tool_def is Dictionary):
				continue
			var tool := (tool_def as Dictionary).duplicate(true)
			if bool(tool.get("compatibility_alias", false)):
				continue
			tool["name"] = _get_exposed_tool_full_name(category, tool)
			tool["category"] = category
			exposed.append(tool)
	return exposed


func _build_tool_catalog_snapshot(tools_by_category: Dictionary, settings: Dictionary, presentation_views: Array[String]) -> Dictionary:
	var loader = _get_tool_loader()
	if loader == null:
		return {}
	var view_parts := PackedStringArray()
	for view in presentation_views:
		view_parts.append(view)
	var signature := "%s\nviews:%s" % [_build_tool_catalog_signature(loader, tools_by_category, settings), ",".join(view_parts)]
	if signature == _last_catalog_signature:
		return _last_catalog_snapshot.duplicate(true)
	var snapshot: Dictionary = ToolCatalogSnapshotService.build_snapshot(loader, {
		"all_tools_by_category": tools_by_category,
		"exposed_tools": _build_exposed_tool_definitions(tools_by_category),
		"disabled_tools": settings.get("disabled_tools", []),
		"presentation_views": presentation_views
	})
	if bool(snapshot.get("success", false)):
		_last_catalog_signature = signature
		_last_catalog_snapshot = snapshot.duplicate(true)
		return snapshot
	return {}


func _build_tool_catalog_model(settings: Dictionary, presentation_views: Array[String]) -> Dictionary:
	var signature := _build_tool_catalog_model_signature(settings, presentation_views)
	if not signature.is_empty() and signature == _last_tool_catalog_model_signature and not _last_tool_catalog_model.is_empty():
		return _last_tool_catalog_model
	var all_tools_by_category := _get_all_tools_by_category()
	var tools_by_category := _filter_visible_tools_by_category(all_tools_by_category)
	var catalog_snapshot := _build_tool_catalog_snapshot(tools_by_category, settings, presentation_views)
	var model := {
		"all_tools_by_category": all_tools_by_category,
		"tools_by_category": tools_by_category,
		"catalog_snapshot": catalog_snapshot
	}
	if signature.is_empty():
		_last_tool_catalog_model_signature = ""
		_last_tool_catalog_model = {}
	else:
		_last_tool_catalog_model_signature = signature
		_last_tool_catalog_model = model
	return model


func _build_tool_catalog_model_signature(settings: Dictionary, presentation_views: Array[String]) -> String:
	var loader_status := _get_light_tool_loader_status()
	if not loader_status.has("catalog_revision"):
		return ""
	var disabled_tools: Array[String] = []
	for tool_name in settings.get("disabled_tools", []):
		disabled_tools.append(str(tool_name))
	disabled_tools.sort()
	var views: Array[String] = []
	for view in presentation_views:
		views.append(view)
	views.sort()
	return _signature_join([
		"catalog_revision", int(loader_status.get("catalog_revision", 0)),
		"initialized", bool(loader_status.get("initialized", false)),
		"status", str(loader_status.get("status", "")),
		"tool_count", int(loader_status.get("tool_count", 0)),
		"exposed_tool_count", int(loader_status.get("exposed_tool_count", 0)),
		"category_count", int(loader_status.get("category_count", 0)),
		"tool_load_error_count", int(loader_status.get("tool_load_error_count", 0)),
		"disabled_tools", disabled_tools,
		"presentation_views", views,
		"show_user_tools", bool(settings.get("show_user_tools", true))
	])


func _resolve_tool_presentation_views() -> Array[String]:
	var view := str(_get_state_value("current_tools_view", "agent_tools"))
	match view:
		"internal_executors":
			return ["internal_executors"]
		"tool_diagnostics":
			return ["tool_diagnostics"]
		_:
			return ["agent_tools"]


func _build_mcp_catalog_projection() -> Dictionary:
	if _mcp_catalog_projection_service == null:
		return {}
	var signature := _build_mcp_projection_signature()
	if signature == _last_mcp_projection_signature:
		return _last_mcp_catalog_projection.duplicate(true)
	var projection = _mcp_catalog_projection_service.build_projection()
	if projection is Dictionary:
		_last_mcp_projection_signature = signature
		_last_mcp_catalog_projection = (projection as Dictionary).duplicate(true)
		return projection
	return {}


func _configure_mcp_catalog_projection_service() -> void:
	if _mcp_catalog_projection_service == null:
		return
	_mcp_catalog_projection_service.configure({
		"sanitize_for_json": Callable(self, "_sanitize_for_mcp_catalog")
	})


func _get_tool_loader():
	if _server_controller != null and _server_controller.has_method("get_tool_loader"):
		return _server_controller.get_tool_loader()
	return _server_controller


func _sanitize_for_mcp_catalog(value):
	match typeof(value):
		TYPE_DICTIONARY:
			var result := {}
			for key in value:
				result[str(key)] = _sanitize_for_mcp_catalog(value[key])
			return result
		TYPE_ARRAY:
			var result := []
			for item in value:
				result.append(_sanitize_for_mcp_catalog(item))
			return result
		TYPE_OBJECT:
			return str(value)
		_:
			return value


func _get_exposed_tool_full_name(category: String, tool: Dictionary) -> String:
	var full_name := str(tool.get("full_name", ""))
	if not full_name.is_empty():
		return full_name
	var name := str(tool.get("name", ""))
	if name.begins_with("%s_" % category):
		return name
	return "%s_%s" % [category, name]


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


func _get_light_tool_loader_status() -> Dictionary:
	if _server_controller == null:
		return {}
	if _server_controller.has_method("peek_light_tool_loader_status"):
		var light_status = _server_controller.peek_light_tool_loader_status()
		if light_status is Dictionary:
			return (light_status as Dictionary).duplicate(true)
	if _server_controller.has_method("peek_tool_loader_status"):
		var peek_status = _server_controller.peek_tool_loader_status()
		if peek_status is Dictionary:
			return (peek_status as Dictionary).duplicate(true)
	if _server_controller.has_method("get_tool_loader_status"):
		var status = _server_controller.get_tool_loader_status()
		if status is Dictionary:
			return (status as Dictionary).duplicate(true)
	return {}


func _tab_needs_tool_catalog(current_tab: int) -> bool:
	return current_tab == 1


func _tab_needs_mcp_catalog(current_tab: int) -> bool:
	return current_tab == 2 or current_tab == 3


func _tab_needs_runtime_diagnostics(current_tab: int) -> bool:
	return current_tab == 1 or current_tab == 5


func _get_domain_defs(catalog_snapshot: Dictionary) -> Array:
	var manifest = catalog_snapshot.get("catalog_manifest", {})
	if manifest is Dictionary:
		var defs = (manifest as Dictionary).get("domain_defs", [])
		if defs is Array:
			return defs
	return MCPToolManifest.TOOL_DOMAIN_DEFS


func _build_tool_catalog_signature(loader, tools_by_category: Dictionary, settings: Dictionary) -> String:
	var loader_status := {}
	if loader != null and loader.has_method("get_tool_loader_status"):
		var raw_status = loader.get_tool_loader_status()
		if raw_status is Dictionary:
			loader_status = raw_status
	var tool_entries: Array[String] = []
	for category in tools_by_category.keys():
		var tools = tools_by_category.get(category, [])
		if not (tools is Array):
			tool_entries.append(_signature_join([str(category), "invalid"]))
			continue
		for tool in tools:
			tool_entries.append(_build_tool_signature_entry(str(category), tool))
	tool_entries.sort()
	var disabled_tools: Array[String] = []
	for tool_name in settings.get("disabled_tools", []):
		disabled_tools.append(str(tool_name))
	disabled_tools.sort()
	return _signature_join([
		"tools", tool_entries,
		"disabled", disabled_tools,
		"loader_initialized", bool(loader_status.get("initialized", false)),
		"loader_status", str(loader_status.get("status", "")),
		"tool_count", int(loader_status.get("tool_count", 0)),
		"exposed_tool_count", int(loader_status.get("exposed_tool_count", 0)),
		"category_count", int(loader_status.get("category_count", 0)),
		"tool_load_error_count", int(loader_status.get("tool_load_error_count", 0))
	])


func _build_tool_signature_entry(category: String, tool) -> String:
	if not (tool is Dictionary):
		return _signature_join([category, "invalid"])
	var tool_def := tool as Dictionary
	return _signature_join([
		category,
		str(tool_def.get("name", "")),
		str(tool_def.get("full_name", tool_def.get("fullName", ""))),
		str(tool_def.get("description", "")),
		str(tool_def.get("source", "")),
		str(tool_def.get("load_state", tool_def.get("loadState", ""))),
		str(tool_def.get("script_path", tool_def.get("scriptPath", ""))),
		tool_def.get("inputSchema", tool_def.get("parameters", {})),
		tool_def.get("outputSchema", {}),
		tool_def.get("annotations", {}),
		tool_def.get("presentation", {}),
		tool_def.get("icons", [])
	])


func _build_mcp_projection_signature() -> String:
	return _signature_join([
		"protocol_catalog", "resources_prompts_list",
		"language", str(_get_settings().get("language", ""))
	])


func _signature_join(values: Array) -> String:
	var parts: Array[String] = []
	for value in values:
		parts.append(_signature_value(value))
	return "|".join(parts)


func _signature_value(value) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			var dict := value as Dictionary
			var keys: Array[String] = []
			var values_by_key := {}
			for key in dict.keys():
				var key_text := str(key)
				keys.append(key_text)
				values_by_key[key_text] = dict[key]
			keys.sort()
			var entries: Array[String] = []
			for key_text in keys:
				entries.append("%s=%s" % [_signature_scalar(key_text), _signature_value(values_by_key.get(key_text))])
			return "d{%s}" % ",".join(entries)
		TYPE_ARRAY:
			var entries: Array[String] = []
			for item in value as Array:
				entries.append(_signature_value(item))
			return "a[%s]" % ",".join(entries)
		TYPE_BOOL:
			return "b:%s" % ("1" if bool(value) else "0")
		TYPE_INT:
			return "i:%s" % str(int(value))
		TYPE_FLOAT:
			return "f:%s" % str(float(value))
		TYPE_NIL:
			return "n:"
		_:
			return "s:%s" % _signature_scalar(str(value))


func _signature_scalar(value: String) -> String:
	return "%d:%s" % [value.length(), value]


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


func _build_server_status_snapshot(include_runtime_diagnostics: bool = false) -> Dictionary:
	if _server_controller == null:
		return {
			"is_running": false,
			"stats": {},
			"domain_states": [],
			"reload_status": {},
			"performance": {},
			"tool_load_errors": []
		}
	var stats := {}
	if _server_controller.has_method("get_connection_stats"):
		var raw_stats = _server_controller.get_connection_stats()
		if raw_stats is Dictionary:
			stats = (raw_stats as Dictionary).duplicate(true)
	var is_running := false
	if _server_controller.has_method("is_running"):
		is_running = bool(_server_controller.is_running())
	var snapshot := {
		"is_running": is_running,
		"stats": stats,
		"domain_states": [],
		"reload_status": {},
		"performance": {},
		"tool_load_errors": []
	}
	if not include_runtime_diagnostics:
		return snapshot
	if _server_controller.has_method("get_domain_states"):
		var domain_states = _server_controller.get_domain_states()
		if domain_states is Array:
			snapshot["domain_states"] = (domain_states as Array).duplicate(true)
	if _server_controller.has_method("get_reload_status"):
		var reload_status = _server_controller.get_reload_status()
		if reload_status is Dictionary:
			snapshot["reload_status"] = (reload_status as Dictionary).duplicate(true)
	if _server_controller.has_method("get_performance_summary"):
		var performance = _server_controller.get_performance_summary()
		if performance is Dictionary:
			snapshot["performance"] = (performance as Dictionary).duplicate(true)
	if _server_controller.has_method("get_tool_load_errors"):
		var load_errors = _server_controller.get_tool_load_errors()
		if load_errors is Array:
			snapshot["tool_load_errors"] = (load_errors as Array).duplicate(true)
	return snapshot


func _build_self_diagnostic_health_snapshot(include_runtime_diagnostics: bool = false) -> Dictionary:
	if _self_diagnostic_feature != null and _self_diagnostic_feature.has_method("build_self_diagnostic_health_snapshot"):
		if include_runtime_diagnostics:
			return _self_diagnostic_feature.build_self_diagnostic_health_snapshot()
		return PluginSelfDiagnosticStore.get_health_snapshot({})
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
