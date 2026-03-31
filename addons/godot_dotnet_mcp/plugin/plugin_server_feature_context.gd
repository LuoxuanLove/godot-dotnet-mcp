@tool
extends RefCounted
class_name PluginServerFeatureContext

var process_service = null
var attach_service = null
var localization = null
var dock_presenter = null
var show_message := Callable()
var show_confirmation := Callable()
var refresh_dock := Callable()


func dispose() -> void:
	process_service = null
	attach_service = null
	localization = null
	dock_presenter = null
	show_message = Callable()
	show_confirmation = Callable()
	refresh_dock = Callable()
