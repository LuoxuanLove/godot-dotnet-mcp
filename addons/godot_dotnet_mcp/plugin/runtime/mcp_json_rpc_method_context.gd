@tool
extends RefCounted
class_name MCPJsonRpcMethodContext

var tool_rpc_router = null
var resources_service = null
var prompts_service = null
var response_service = null
var log := Callable()


func dispose() -> void:
	tool_rpc_router = null
	resources_service = null
	prompts_service = null
	response_service = null
	log = Callable()
