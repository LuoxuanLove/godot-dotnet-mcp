@tool
extends RefCounted
class_name MCPToolsApiServiceContext

var get_tool_loader := Callable()
var get_tool_loader_status := Callable()
var ensure_initialized := Callable()


func dispose() -> void:
	get_tool_loader = Callable()
	get_tool_loader_status = Callable()
	ensure_initialized = Callable()
