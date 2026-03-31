@tool
extends RefCounted
class_name MCPEditorLifecycleEndpointContext

var build_state := Callable()
var execute_close := Callable()
var execute_restart := Callable()
var build_success := Callable()
var build_error := Callable()


func dispose() -> void:
	build_state = Callable()
	execute_close = Callable()
	execute_restart = Callable()
	build_success = Callable()
	build_error = Callable()
