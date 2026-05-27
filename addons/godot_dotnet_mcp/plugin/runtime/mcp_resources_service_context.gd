@tool
extends RefCounted
class_name MCPResourcesServiceContext

var get_tool_loader := Callable()
var get_tool_loader_status := Callable()
var sanitize_for_json := Callable()


func dispose() -> void:
	get_tool_loader = Callable()
	get_tool_loader_status = Callable()
	sanitize_for_json = Callable()
