@tool
extends RefCounted
class_name MCPToolRpcRouterContext

var get_tool_loader := Callable()
var is_tool_enabled := Callable()
var is_tool_exposed := Callable()
var log := Callable()
var sanitize_for_json := Callable()


func dispose() -> void:
	get_tool_loader = Callable()
	is_tool_enabled = Callable()
	is_tool_exposed = Callable()
	log = Callable()
	sanitize_for_json = Callable()
