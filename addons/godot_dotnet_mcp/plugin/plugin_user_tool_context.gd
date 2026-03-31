@tool
extends RefCounted
class_name PluginUserToolContext

var user_tool_service = null
var show_message := Callable()
var refresh_dock := Callable()
var save_settings := Callable()
var cleanup_disabled_tools := Callable()
var create_reload_coordinator := Callable()
var reload_all_domains := Callable()


func dispose() -> void:
	user_tool_service = null
	show_message = Callable()
	refresh_dock = Callable()
	save_settings = Callable()
	cleanup_disabled_tools = Callable()
	create_reload_coordinator = Callable()
	reload_all_domains = Callable()
