@tool
extends RefCounted
class_name MCPHttpResponseContext

var get_tool_loader := Callable()
var get_tool_loader_status := Callable()
var get_server_stats := Callable()
var get_editor_session_identity := Callable()
var get_freshness_snapshot := Callable()
var log := Callable()
var server_name := ""
var server_version := ""
var protocol_version := ""
var tool_schema_version := ""


func dispose() -> void:
	get_tool_loader = Callable()
	get_tool_loader_status = Callable()
	get_server_stats = Callable()
	get_editor_session_identity = Callable()
	get_freshness_snapshot = Callable()
	log = Callable()
	server_name = ""
	server_version = ""
	protocol_version = ""
	tool_schema_version = ""
