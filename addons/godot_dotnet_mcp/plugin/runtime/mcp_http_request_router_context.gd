@tool
extends RefCounted
class_name MCPHttpRequestRouterContext

var handle_mcp_request_async := Callable()
var build_health_response := Callable()
var build_tools_list_response := Callable()
var handle_editor_lifecycle_request := Callable()
var handle_editor_lifecycle_post_request := Callable()
var build_cors_response := Callable()
var sse_event_queue = null


func dispose() -> void:
	handle_mcp_request_async = Callable()
	build_health_response = Callable()
	build_tools_list_response = Callable()
	handle_editor_lifecycle_request = Callable()
	handle_editor_lifecycle_post_request = Callable()
	build_cors_response = Callable()
	sse_event_queue = null
