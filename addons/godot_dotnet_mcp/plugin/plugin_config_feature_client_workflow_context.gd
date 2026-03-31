@tool
extends RefCounted
class_name PluginConfigFeatureClientWorkflowContext

var settings: Dictionary = {}
var localization = null
var config_service = null
var dock_presenter = null
var central_server_process_service = null
var client_install_detection_service = null
var show_message := Callable()
var refresh_dock := Callable()
var save_settings := Callable()
var ensure_client_executable_dialog := Callable()
var get_client_executable_dialog := Callable()


func dispose() -> void:
	settings = {}
	localization = null
	config_service = null
	dock_presenter = null
	central_server_process_service = null
	client_install_detection_service = null
	show_message = Callable()
	refresh_dock = Callable()
	save_settings = Callable()
	ensure_client_executable_dialog = Callable()
	get_client_executable_dialog = Callable()
