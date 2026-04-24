@tool
extends RefCounted
class_name MCPJsonRpcRequestService

const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")

var _route_json_rpc_async := Callable()
var _build_json_rpc_error := Callable()
var _emit_request_received := Callable()
var _log := Callable()


func configure(context = null) -> void:
	if context == null:
		dispose()
		return
	_route_json_rpc_async = context.route_json_rpc_async
	_build_json_rpc_error = context.build_json_rpc_error
	_emit_request_received = context.emit_request_received
	_log = context.log


func dispose() -> void:
	_route_json_rpc_async = Callable()
	_build_json_rpc_error = Callable()
	_emit_request_received = Callable()
	_log = Callable()


func handle_request_async(body: String) -> Dictionary:
	_log_message("Parsing request body (%d bytes)" % body.length(), "debug")
	var json = JSON.new()
	var error = json.parse(body)

	if error != OK:
		_record_parse_error(json.get_error_message(), body.length())
		return _build_error(-32700, "Parse error: %s" % json.get_error_message(), null)

	var request = json.get_data()
	if not (request is Dictionary):
		return _build_error(-32600, "Invalid Request", null)

	var request_dict: Dictionary = request
	var method = str(request_dict.get("method", ""))
	var params = request_dict.get("params", {})
	if not (params is Dictionary):
		params = {}
	var has_id = request_dict.has("id")
	var id = request_dict.get("id")

	_log_message("Method: %s, ID: %s" % [method, id], "debug")
	if _emit_request_received.is_valid():
		_emit_request_received.call(method, params)

	if _route_json_rpc_async.is_valid():
		return await _route_json_rpc_async.call(method, params, id, has_id)
	return _build_error(-32603, "JSON-RPC router is unavailable", id)


func _build_error(code: int, message: String, id) -> Dictionary:
	if _build_json_rpc_error.is_valid():
		var response = _build_json_rpc_error.call(code, message, id)
		if response is Dictionary:
			return (response as Dictionary).duplicate(true)
	return {
		"jsonrpc": "2.0",
		"error": {
			"code": code,
			"message": message
		},
		"id": id
	}


func _record_parse_error(error_message: String, body_length: int) -> void:
	_log_message("JSON parse error: %s" % error_message, "warning")
	PluginSelfDiagnosticStore.record_incident(
		"warning",
		"server_error",
		"json_parse_error",
		"MCP request JSON parsing failed",
		"mcp_json_rpc_request_service",
		"handle_request",
		"",
		"",
		"",
		true,
		"Inspect the malformed request body sent to /mcp.",
		{
			"error_message": error_message,
			"body_length": body_length
		}
	)


func _log_message(message: String, level: String) -> void:
	if _log.is_valid():
		_log.call(message, level)
