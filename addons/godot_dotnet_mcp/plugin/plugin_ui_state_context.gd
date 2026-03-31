@tool
extends RefCounted
class_name PluginUiStateContext

var state = null
var localization = null
var client_install_detection_service = null
var save_settings := Callable()
var refresh_dock := Callable()
var show_message := Callable()
var capture_dock_focus_snapshot := Callable()
var restore_dock_focus_snapshot := Callable()


func dispose() -> void:
	state = null
	localization = null
	client_install_detection_service = null
	save_settings = Callable()
	refresh_dock = Callable()
	show_message = Callable()
	capture_dock_focus_snapshot = Callable()
	restore_dock_focus_snapshot = Callable()
