@tool
extends RefCounted
class_name DockModelService

const ToolPermissionPolicy = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_permission_policy.gd")
const ToolProfileCatalog = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_profile_catalog.gd")
const MCPToolManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_manifest.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")

var _state
var _localization
var _server_controller
var _tool_catalog
var _config_service
var _dock_presenter
var _user_tool_service
var _client_install_detection_service
var _central_server_attach_service
var _central_server_process_service
var _user_tool_watch_service
var _tool_access_feature
var _self_diagnostic_feature
var _get_editor_scale := Callable()


func configure(
	state,
	localization,
	server_controller,
	tool_catalog,
	config_service,
	dock_presenter,
	user_tool_service,
	client_install_detection_service,
	central_server_attach_service,
	central_server_process_service,
	user_tool_watch_service,
	tool_access_feature,
	self_diagnostic_feature,
	callbacks: Dictionary = {}
) -> void:
	_state = state
	_localization = localization
	_server_controller = server_controller
	_tool_catalog = tool_catalog
	_config_service = config_service
	_dock_presenter = dock_presenter
	_user_tool_service = user_tool_service
	_client_install_detection_service = client_install_detection_service
	_central_server_attach_service = central_server_attach_service
	_central_server_process_service = central_server_process_service
	_user_tool_watch_service = user_tool_watch_service
	_tool_access_feature = tool_access_feature
	_self_diagnostic_feature = self_diagnostic_feature
	_get_editor_scale = callbacks.get("get_editor_scale", Callable())


func build_model() -> Dictionary:
	if _state == null or _localization == null or _server_controller == null or _tool_catalog == null or _dock_presenter == null:
		return {}

	var settings = _get_settings()
	var all_tools_by_category = _get_all_tools_by_category()
	var tools_by_category = _filter_visible_tools_by_category(all_tools_by_category)
	var self_diagnostics = _build_self_diagnostic_health_snapshot()
	var client_install_statuses := {}

	if int(_state.current_tab) == 2:
		client_install_statuses = _get_client_install_statuses(settings)

	return _dock_presenter.build_model({
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
		"central_server_attach": _get_central_server_attach_status(),
		"central_server_process": _get_central_server_process_status(),
		"user_tool_watch": _get_user_tool_watch_status(),
		"editor_scale": _resolve_editor_scale(),
		"permission_levels": ToolPermissionPolicy.PERMISSION_LEVELS,
		"current_permission_level": _get_permission_level(),
		"log_levels": MCPDebugBuffer.get_available_levels(),
		"current_log_level": str(settings.get("log_level", MCPDebugBuffer.get_minimum_level())),
		"builtin_profiles": ToolProfileCatalog.get_builtin_profiles(),
		"custom_profiles": _state.custom_tool_profiles,
		"domain_defs": MCPToolManifest.TOOL_DOMAIN_DEFS,
		"client_install_statuses": client_install_statuses
	})


func _get_settings() -> Dictionary:
	if _state == null or not (_state.settings is Dictionary):
		return {}
	return _state.settings


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
		if not _is_tool_category_visible_for_permission(str(category)):
			filtered.erase(category)
	return filtered


func _is_tool_category_visible_for_permission(category: String) -> bool:
	if _tool_access_feature != null and _tool_access_feature.has_method("is_tool_category_visible_for_permission"):
		return _tool_access_feature.is_tool_category_visible_for_permission(category)
	if category == "user":
		return bool(_get_settings().get("show_user_tools", true))
	if category == "plugin":
		return _get_permission_level() == ToolPermissionPolicy.PERMISSION_DEVELOPER
	return ToolPermissionPolicy.permission_allows_category(_get_permission_level(), category)


func _get_permission_level() -> String:
	if _tool_access_feature != null and _tool_access_feature.has_method("get_permission_level"):
		return str(_tool_access_feature.get_permission_level())
	return ToolPermissionPolicy.normalize_permission_level(
		str(_get_settings().get("permission_level", ToolPermissionPolicy.PERMISSION_EVOLUTION))
	)


func _build_self_diagnostic_health_snapshot() -> Dictionary:
	if _self_diagnostic_feature != null and _self_diagnostic_feature.has_method("build_self_diagnostic_health_snapshot"):
		return _self_diagnostic_feature.build_self_diagnostic_health_snapshot()
	return PluginSelfDiagnosticStore.get_health_snapshot({})


func _get_central_server_attach_status() -> Dictionary:
	if _central_server_attach_service == null:
		return {}
	var status = _central_server_attach_service.get_status()
	if _dock_presenter != null and _dock_presenter.has_method("localize_central_server_attach_status"):
		return _dock_presenter.localize_central_server_attach_status(status, _localization)
	return status


func _get_central_server_process_status() -> Dictionary:
	if _central_server_process_service == null:
		return {}
	return _central_server_process_service.get_status()


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
