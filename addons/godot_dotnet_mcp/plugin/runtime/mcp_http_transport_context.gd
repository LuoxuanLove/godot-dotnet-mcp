@tool
extends RefCounted
class_name MCPHttpTransportContext

var log := Callable()
var emit_client_connected := Callable()
var emit_client_disconnected := Callable()
var route_request_async := Callable()
var write_http_response := Callable()
var tick_loader := Callable()


func dispose() -> void:
	log = Callable()
	emit_client_connected = Callable()
	emit_client_disconnected = Callable()
	route_request_async = Callable()
	write_http_response = Callable()
	tick_loader = Callable()
