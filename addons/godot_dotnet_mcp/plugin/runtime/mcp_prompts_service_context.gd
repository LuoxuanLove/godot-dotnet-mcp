@tool
extends RefCounted
class_name MCPPromptsServiceContext

var get_tool_loader_status := Callable()


func dispose() -> void:
	get_tool_loader_status = Callable()
