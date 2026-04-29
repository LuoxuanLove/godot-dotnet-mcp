@tool
extends RefCounted
class_name MCPJsonRpcRequestContext

var route_json_rpc_async := Callable()
var build_json_rpc_error := Callable()
var emit_request_received := Callable()
var log := Callable()


func dispose() -> void:
	route_json_rpc_async = Callable()
	build_json_rpc_error = Callable()
	emit_request_received = Callable()
	log = Callable()
