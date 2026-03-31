@tool
extends RefCounted
class_name PluginConfigFeatureConfigWorkflowContext

var localization = null
var config_service = null
var get_statuses := Callable()
var show_message := Callable()
var show_confirmation := Callable()
var refresh_dock := Callable()
var invalidate_client_install_status_cache := Callable()


func dispose() -> void:
	localization = null
	config_service = null
	get_statuses = Callable()
	show_message = Callable()
	show_confirmation = Callable()
	refresh_dock = Callable()
	invalidate_client_install_status_cache = Callable()
