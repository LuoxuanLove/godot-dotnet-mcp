@tool
extends RefCounted
class_name MCPJsonRpcMethodContext

var tool_rpc_router = null
var response_service = null
var log := Callable()


func dispose() -> void:
	tool_rpc_router = null
	response_service = null
	log = Callable()
