extends RefCounted

const JsonRpcRequestServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_json_rpc_request_service.gd")
const JsonRpcRequestContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_json_rpc_request_context.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")


class FakeCallbacks:
	extends RefCounted

	var received: Array[Dictionary] = []
	var last_log: Dictionary = {}
	var delayed_route_entered := false
	var release_delayed_route := false

	func route_json_rpc_async(method: String, params: Dictionary, id, has_id: bool) -> Dictionary:
		if method == "contract/delayed":
			delayed_route_entered = true
			while not release_delayed_route:
				await Engine.get_main_loop().process_frame
		return {
			"jsonrpc": "2.0",
			"result": {
				"method": method,
				"params": params.duplicate(true),
				"hasId": has_id
			},
			"id": id
		}

	func build_json_rpc_error(code: int, message: String, id) -> Dictionary:
		return {
			"jsonrpc": "2.0",
			"error": {
				"code": code,
				"message": message
			},
			"id": id
		}

	func emit_request_received(method: String, params: Dictionary) -> void:
		received.append({
			"method": method,
			"params": params.duplicate(true)
		})

	func log(message: String, level: String) -> void:
		last_log = {
			"message": message,
			"level": level
		}


func run_case(_tree: SceneTree) -> Dictionary:
	PluginSelfDiagnosticStore.clear()
	var service = JsonRpcRequestServiceScript.new()
	var callbacks = FakeCallbacks.new()
	var context = JsonRpcRequestContextScript.new()
	context.route_json_rpc_async = Callable(callbacks, "route_json_rpc_async")
	context.build_json_rpc_error = Callable(callbacks, "build_json_rpc_error")
	context.emit_request_received = Callable(callbacks, "emit_request_received")
	context.log = Callable(callbacks, "log")
	service.configure(context)

	var invalid_json: Dictionary = await service.handle_request_async("{")
	var invalid_json_error = invalid_json.get("error", {})
	if not (invalid_json_error is Dictionary) or int((invalid_json_error as Dictionary).get("code", 0)) != -32700:
		return _failure("JSON-RPC request service did not preserve the parse-error contract.")

	var invalid_request: Dictionary = await service.handle_request_async(JSON.stringify([]))
	var invalid_request_error = invalid_request.get("error", {})
	if not (invalid_request_error is Dictionary) or int((invalid_request_error as Dictionary).get("code", 0)) != -32600:
		return _failure("JSON-RPC request service did not reject a non-object request body.")

	var wrong_jsonrpc: Dictionary = await service.handle_request_async(JSON.stringify({
		"jsonrpc": "1.0",
		"id": 2,
		"method": "tools/list",
		"params": {}
	}))
	var wrong_jsonrpc_error = wrong_jsonrpc.get("error", {})
	if not (wrong_jsonrpc_error is Dictionary) or int((wrong_jsonrpc_error as Dictionary).get("code", 0)) != -32600:
		return _failure("JSON-RPC request service should reject non-2.0 envelopes with -32600.")
	if int(wrong_jsonrpc.get("id", 0)) != 2:
		return _failure("JSON-RPC request service should preserve valid ids on invalid envelope errors.")
	if callbacks.received.size() != 0:
		return _failure("JSON-RPC request service should not emit request_received for invalid jsonrpc envelopes.")

	var wrong_jsonrpc_invalid_id: Dictionary = await service.handle_request_async(JSON.stringify({
		"jsonrpc": "1.0",
		"id": {},
		"method": [],
		"params": {}
	}))
	var wrong_jsonrpc_invalid_id_error = wrong_jsonrpc_invalid_id.get("error", {})
	if not (wrong_jsonrpc_invalid_id_error is Dictionary) or int((wrong_jsonrpc_invalid_id_error as Dictionary).get("code", 0)) != -32600:
		return _failure("JSON-RPC request service should reject combined invalid jsonrpc/id envelopes with -32600.")
	if wrong_jsonrpc_invalid_id.get("id") != null:
		return _failure("JSON-RPC request service should not echo invalid ids from combined malformed envelopes.")

	var missing_method: Dictionary = await service.handle_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 3,
		"params": {}
	}))
	var missing_method_error = missing_method.get("error", {})
	if not (missing_method_error is Dictionary) or int((missing_method_error as Dictionary).get("code", 0)) != -32600:
		return _failure("JSON-RPC request service should reject missing method envelopes with -32600.")

	var non_string_method: Dictionary = await service.handle_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 4,
		"method": {},
		"params": {}
	}))
	var non_string_method_error = non_string_method.get("error", {})
	if not (non_string_method_error is Dictionary) or int((non_string_method_error as Dictionary).get("code", 0)) != -32600:
		return _failure("JSON-RPC request service should reject non-string method envelopes with -32600.")

	var invalid_id: Dictionary = await service.handle_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": {},
		"method": "tools/list",
		"params": {}
	}))
	var invalid_id_error = invalid_id.get("error", {})
	if not (invalid_id_error is Dictionary) or int((invalid_id_error as Dictionary).get("code", 0)) != -32600:
		return _failure("JSON-RPC request service should reject object ids with -32600.")
	if invalid_id.get("id") != null:
		return _failure("JSON-RPC request service should use id=null when the request id type is invalid.")

	var invalid_notification_method: Dictionary = await service.handle_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"method": [],
		"params": {}
	}))
	var invalid_notification_method_error = invalid_notification_method.get("error", {})
	if not (invalid_notification_method_error is Dictionary) or int((invalid_notification_method_error as Dictionary).get("code", 0)) != -32600:
		return _failure("JSON-RPC request service should reject invalid no-id envelopes with -32600 and id=null.")
	if invalid_notification_method.get("id") != null:
		return _failure("JSON-RPC request service should use id=null for invalid no-id envelopes.")
	if callbacks.received.size() != 0:
		return _failure("JSON-RPC request service should not emit request_received for invalid notification envelopes.")

	var json_rpc_result_response: Dictionary = await service.handle_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 22,
		"result": {"ack": true}
	}))
	if int(json_rpc_result_response.get("status", 0)) != 202 or not bool(json_rpc_result_response.get("_no_body", false)):
		return _failure("JSON-RPC request service should accept response envelopes with 202 and no body.")
	if callbacks.received.size() != 0:
		return _failure("JSON-RPC request service should not emit request_received for response envelopes.")

	var json_rpc_error_response: Dictionary = await service.handle_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 23,
		"error": {"code": -32800, "message": "Cancelled"}
	}))
	if int(json_rpc_error_response.get("status", 0)) != 202 or not bool(json_rpc_error_response.get("_no_body", false)):
		return _failure("JSON-RPC request service should accept error response envelopes with 202 and no body.")

	var missing_id_response_like_body: Dictionary = await service.handle_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"result": {"ok": true}
	}))
	var missing_id_response_like_error = missing_id_response_like_body.get("error", {})
	if not (missing_id_response_like_error is Dictionary) or int((missing_id_response_like_error as Dictionary).get("code", 0)) != -32600:
		return _failure("JSON-RPC request service should not accept result envelopes without response ids.")

	var invalid_params: Dictionary = await service.handle_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 8,
		"method": "tools/list",
		"params": []
	}))
	var invalid_params_error = invalid_params.get("error", {})
	if not (invalid_params_error is Dictionary) or int((invalid_params_error as Dictionary).get("code", 0)) != -32602:
		return _failure("JSON-RPC request service should reject non-object params with -32602.")
	if callbacks.received.size() != 0:
		return _failure("JSON-RPC request service should not emit request_received for invalid params.")

	var invalid_notification_params: Dictionary = await service.handle_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"method": "tools/list",
		"params": []
	}))
	if not bool(invalid_notification_params.get("_no_body", false)):
		return _failure("JSON-RPC request service should not respond to notifications with invalid params.")
	if callbacks.received.size() != 0:
		return _failure("JSON-RPC request service should not emit request_received for invalid notification params.")

	var response: Dictionary = await service.handle_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 7,
		"method": "tools/list",
		"params": {
			"limit": 1
		}
	}))
	var result = response.get("result", {})
	if not (result is Dictionary) or str((result as Dictionary).get("method", "")) != "tools/list":
		return _failure("JSON-RPC request service did not forward valid requests to the routed handler.")
	if callbacks.received.is_empty():
		return _failure("JSON-RPC request service did not emit the request_received callback.")
	var first_received = callbacks.received[0]
	if str(first_received.get("method", "")) != "tools/list":
		return _failure("JSON-RPC request service did not preserve the emitted method name.")

	var delayed_state := {"done": false, "response": {}}
	_run_delayed_request(service, delayed_state)
	var wait_frames := 0
	while not callbacks.delayed_route_entered and wait_frames < 30:
		await _tree.process_frame
		wait_frames += 1
	if not callbacks.delayed_route_entered:
		return _failure("JSON-RPC request service cancellation contract did not enter a pending request.")
	var cancelled_response: Dictionary = await service.handle_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"method": "notifications/cancelled",
		"params": {
			"requestId": 77,
			"reason": "contract\n%s" % "S".repeat(200)
		}
	}))
	if int(cancelled_response.get("status", 0)) != 202 or not bool(cancelled_response.get("_no_body", false)):
		return _failure("JSON-RPC request service should accept cancellation notifications with 202 and no body.")
	var cancellation_log := str(callbacks.last_log.get("message", ""))
	if cancellation_log.find("\n") != -1 or cancellation_log.find("\r") != -1:
		return _failure("JSON-RPC request service should strip newlines from cancellation reason logs.")
	if cancellation_log.length() > 220 or cancellation_log.find("S".repeat(160)) != -1:
		return _failure("JSON-RPC request service should truncate client-supplied cancellation reasons before logging.")
	callbacks.release_delayed_route = true
	wait_frames = 0
	while not bool(delayed_state.get("done", false)) and wait_frames < 30:
		await _tree.process_frame
		wait_frames += 1
	var delayed_response = delayed_state.get("response", {})
	if not (delayed_response is Dictionary):
		return _failure("JSON-RPC request service cancellation contract did not complete the pending response.")
	var delayed_error = (delayed_response as Dictionary).get("error", {})
	if not (delayed_error is Dictionary) or int((delayed_error as Dictionary).get("code", 0)) != -32800:
		return _failure("JSON-RPC request service should complete cancelled pending requests with JSON-RPC -32800.")
	if int((delayed_response as Dictionary).get("id", 0)) != 77:
		return _failure("JSON-RPC request service should preserve the original cancelled request id.")

	return {
		"name": "json_rpc_request_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"received_count": callbacks.received.size(),
			"last_log_level": str(callbacks.last_log.get("level", "")),
			"result_method": str((result as Dictionary).get("method", ""))
		}
	}


func _run_delayed_request(service, state: Dictionary) -> void:
	state["response"] = await service.handle_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 77,
		"method": "contract/delayed",
		"params": {}
	}))
	state["done"] = true


func cleanup_case(_tree: SceneTree) -> void:
	PluginSelfDiagnosticStore.clear()


func _failure(message: String) -> Dictionary:
	return {
		"name": "json_rpc_request_service_contracts",
		"success": false,
		"error": message
	}
