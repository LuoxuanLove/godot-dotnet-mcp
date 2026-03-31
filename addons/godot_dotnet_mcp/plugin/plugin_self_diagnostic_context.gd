@tool
extends RefCounted
class_name PluginSelfDiagnosticContext

var localization = null
var runtime_bridge_autoload_name := ""
var runtime_bridge_autoload_path := ""
var count_dock_instances := Callable()
var has_runtime_bridge_root_instance := Callable()
var is_server_running := Callable()
var get_connection_stats := Callable()
var get_tool_load_errors := Callable()
var get_reload_status := Callable()
var get_performance_summary := Callable()
var get_permission_level := Callable()
var refresh_dock := Callable()
var show_message := Callable()
var is_dock_present := Callable()


func dispose() -> void:
	localization = null
	runtime_bridge_autoload_name = ""
	runtime_bridge_autoload_path = ""
	count_dock_instances = Callable()
	has_runtime_bridge_root_instance = Callable()
	is_server_running = Callable()
	get_connection_stats = Callable()
	get_tool_load_errors = Callable()
	get_reload_status = Callable()
	get_performance_summary = Callable()
	get_permission_level = Callable()
	refresh_dock = Callable()
	show_message = Callable()
	is_dock_present = Callable()
