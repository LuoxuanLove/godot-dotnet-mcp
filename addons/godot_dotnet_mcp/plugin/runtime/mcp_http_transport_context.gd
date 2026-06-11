@tool
extends RefCounted
class_name MCPHttpTransportContext

var log := Callable()
var emit_client_connected := Callable()
var emit_client_disconnected := Callable()
var route_request_async := Callable()
var write_http_response := Callable()
var write_sse_stream_open := Callable()
var write_sse_heartbeat := Callable()
var write_sse_events := Callable()
var get_sse_events_since_index := Callable()
var tick_loader := Callable()
var max_pending_request_bytes := 0


func dispose() -> void:
	log = Callable()
	emit_client_connected = Callable()
	emit_client_disconnected = Callable()
	route_request_async = Callable()
	write_http_response = Callable()
	write_sse_stream_open = Callable()
	write_sse_heartbeat = Callable()
	write_sse_events = Callable()
	get_sse_events_since_index = Callable()
	tick_loader = Callable()
	max_pending_request_bytes = 0
