@tool
extends RefCounted
class_name MCPJsonRpcRouterContext

var handle_initialize := Callable()
var handle_tools_list := Callable()
var handle_tools_call_async := Callable()
var handle_notification := Callable()
var build_json_rpc_response := Callable()
var build_json_rpc_error := Callable()
var log := Callable()


func dispose() -> void:
	handle_initialize = Callable()
	handle_tools_list = Callable()
	handle_tools_call_async = Callable()
	handle_notification = Callable()
	build_json_rpc_response = Callable()
	build_json_rpc_error = Callable()
	log = Callable()
