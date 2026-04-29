@tool
extends RefCounted
class_name MCPEditorLifecycleActionContext

var build_state := Callable()
var build_state_with_hint := Callable()
var build_success := Callable()
var build_error := Callable()
var schedule_action := Callable()
var get_plugin_host := Callable()
var log := Callable()


func dispose() -> void:
	build_state = Callable()
	build_state_with_hint = Callable()
	build_success = Callable()
	build_error = Callable()
	schedule_action = Callable()
	get_plugin_host = Callable()
	log = Callable()
