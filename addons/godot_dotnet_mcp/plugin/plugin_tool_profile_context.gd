@tool
extends RefCounted
class_name PluginToolProfileContext

var state = null
var localization = null
var settings_store = null
var tool_catalog = null
var get_all_tools_by_category := Callable()
var set_disabled_tools := Callable()
var cleanup_disabled_tools := Callable()
var save_settings := Callable()
var refresh_dock := Callable()


func dispose() -> void:
	state = null
	localization = null
	settings_store = null
	tool_catalog = null
	get_all_tools_by_category = Callable()
	set_disabled_tools = Callable()
	cleanup_disabled_tools = Callable()
	save_settings = Callable()
	refresh_dock = Callable()
