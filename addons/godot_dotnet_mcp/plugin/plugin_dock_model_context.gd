@tool
extends RefCounted
class_name PluginDockModelContext

var state = null
var localization = null
var server_controller = null
var tool_catalog = null
var config_service = null
var dock_presenter = null
var user_tool_service = null
var client_install_detection_service = null
var central_server_attach_service = null
var central_server_process_service = null
var user_tool_watch_service = null
var tool_access_feature = null
var self_diagnostic_feature = null
var get_editor_scale := Callable()


func resolve_editor_scale() -> float:
	if get_editor_scale.is_valid():
		return float(get_editor_scale.call())
	return 1.0


func dispose() -> void:
	state = null
	localization = null
	server_controller = null
	tool_catalog = null
	config_service = null
	dock_presenter = null
	user_tool_service = null
	client_install_detection_service = null
	central_server_attach_service = null
	central_server_process_service = null
	user_tool_watch_service = null
	tool_access_feature = null
	self_diagnostic_feature = null
	get_editor_scale = Callable()
