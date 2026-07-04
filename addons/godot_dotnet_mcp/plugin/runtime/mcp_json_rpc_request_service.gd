@tool
extends RefCounted
class_name MCPJsonRpcRequestService

const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const MCPJsonRpcEnvelopeValidator = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_json_rpc_envelope_validator.gd")

const MAX_CLIENT_LOG_FIELD_CHARS := 120

var _route_json_rpc_async := Callable()
var _build_json_rpc_error := Callable()
var _emit_request_received := Callable()
var _log := Callable()
var _cancelled_request_ids: Dictionary = {}
var _pending_request_ids: Dictionary = {}


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
	_cancelled_request_ids.clear()
	_pending_request_ids.clear()


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
	if _is_json_rpc_response_envelope(request_dict):
		return {"status": 202, "_no_body": true}

	var envelope_validation := MCPJsonRpcEnvelopeValidator.validate_request_envelope(request_dict)
	var has_id = bool(envelope_validation.get("has_id", false))
	var id = envelope_validation.get("id")
	if not bool(envelope_validation.get("success", false)):
		return _build_error(
			int(envelope_validation.get("code", -32600)),
			str(envelope_validation.get("message", "Invalid Request")),
			id
		)

	var method = str(envelope_validation.get("method", ""))
	var params = request_dict.get("params", {})
	if not (params is Dictionary):
		if not has_id:
			return {"status": 202, "_no_body": true}
		return _build_error(-32602, "Invalid params: expected object", id)

	if not has_id and method == "notifications/cancelled":
		var notification_params := params as Dictionary
		_mark_cancelled_request(notification_params)
		return {"status": 202, "_no_body": true}

	_log_message(
		"Method: %s, ID: %s" % [
			_sanitize_client_log_field(method),
			_sanitize_client_log_field(id)
		],
		"debug"
	)
	if _emit_request_received.is_valid():
		_emit_request_received.call(method, params)

	if _route_json_rpc_async.is_valid():
		if has_id:
			var id_key := _request_id_key(id)
			_pending_request_ids[id_key] = true
			var routed_response: Dictionary = await _route_json_rpc_async.call(method, params, id, has_id)
			_pending_request_ids.erase(id_key)
			if _cancelled_request_ids.has(id_key):
				_cancelled_request_ids.erase(id_key)
				return _build_error(-32800, "Request cancelled", id)
			return routed_response
		return await _route_json_rpc_async.call(method, params, id, has_id)
	return _build_error(-32603, "JSON-RPC router is unavailable", id)


func _is_json_rpc_response_envelope(request: Dictionary) -> bool:
	if str(request.get("jsonrpc", "")) != "2.0":
		return false
	if request.has("method"):
		return false
	if not request.has("id") or not _is_valid_json_rpc_id(request.get("id")):
		return false
	var has_result := request.has("result")
	var has_error := request.has("error")
	if has_result == has_error:
		return false
	if has_error and not (request.get("error") is Dictionary):
		return false
	return true


func _is_valid_json_rpc_id(id) -> bool:
	if id == null:
		return true
	if id is String:
		return true
	if id is int:
		return true
	if id is float:
		return true
	return false


func _mark_cancelled_request(params: Dictionary) -> void:
	if not params.has("requestId"):
		_log_message("Cancellation notification missing requestId.", "debug")
		return
	var id = params.get("requestId")
	if not _is_valid_json_rpc_id(id):
		_log_message("Cancellation notification ignored invalid requestId.", "debug")
		return
	var id_key := _request_id_key(id)
	var id_log_key := _sanitize_client_log_field(id_key)
	var reason := _sanitize_client_log_field(params.get("reason", ""))
	var status := "pending" if _pending_request_ids.has(id_key) else "not_pending"
	if status == "pending":
		_cancelled_request_ids[id_key] = true
	if reason.is_empty():
		_log_message("Request cancelled by client: %s (%s)" % [id_log_key, status], "debug")
	else:
		_log_message("Request cancelled by client: %s (%s): %s" % [id_log_key, status, reason], "debug")


func _sanitize_client_log_field(value) -> String:
	var text := str(value).strip_edges().replace("\r", " ").replace("\n", " ")
	if text.length() <= MAX_CLIENT_LOG_FIELD_CHARS:
		return text
	return "%s..." % text.substr(0, MAX_CLIENT_LOG_FIELD_CHARS)


func _request_id_key(id) -> String:
	if id == null:
		return "null:"
	return "%s:%s" % [type_string(typeof(id)), str(id)]


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
