@tool
extends RefCounted
class_name PluginToolAccessContext

var state = null
var localization = null
var tool_catalog = null
var get_all_tools_by_category := Callable()
var set_disabled_tools := Callable()
var save_settings := Callable()
var refresh_dock := Callable()
var show_message := Callable()
var change_language := Callable()


func dispose() -> void:
	state = null
	localization = null
	tool_catalog = null
	get_all_tools_by_category = Callable()
	set_disabled_tools = Callable()
	save_settings = Callable()
	refresh_dock = Callable()
	show_message = Callable()
	change_language = Callable()
