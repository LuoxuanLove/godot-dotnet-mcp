extends RefCounted

# {"name": "stdio_tool_error_parity_contracts"}

const StdioServerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_stdio_server.gd")
const ToolRpcRouterScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_rpc_router.gd")
const ToolRpcRouterContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_rpc_router_context.gd")

const MAX_STDIN_CONTENT_BYTES := 1024 * 1024
const MAX_STDIN_HEADER_BYTES := 64 * 1024
const MAX_STDIN_PENDING_BYTES := MAX_STDIN_CONTENT_BYTES + MAX_STDIN_HEADER_BYTES


class FakeToolLoader:
	extends RefCounted

	var disabled_tools: Dictionary = {}
	var hidden_tools: Dictionary = {}
	var executed_count := 0

	func get_tool_definitions() -> Array:
		return [{
			"name": "system_project_lifecycle",
			"category": "system",
			"inputSchema": {"type": "object", "properties": {}}
		}]

	func get_exposed_tool_definitions() -> Array:
		if is_tool_exposed("system_project_lifecycle"):
			return get_tool_definitions()
		return []

	func get_domain_states() -> Array:
		return [{"category": "system", "status": "ready"}]

	func is_tool_enabled(tool_name: String) -> bool:
		return not disabled_tools.has(tool_name)

	func is_tool_exposed(tool_name: String) -> bool:
		return is_tool_enabled(tool_name) and not hidden_tools.has(tool_name) and tool_name == "system_project_lifecycle"

	func execute_tool_async(_category: String, _tool_name: String, _arguments: Dictionary) -> Dictionary:
		executed_count += 1
		return {"success": true, "data": {}, "message": "ok"}


class RouterCallbacks:
	extends RefCounted

	var loader: FakeToolLoader

	func _init(source_loader: FakeToolLoader) -> void:
		loader = source_loader

	func get_tool_loader():
		return loader

	func is_tool_enabled(tool_name: String) -> bool:
		return loader.is_tool_enabled(tool_name)

	func is_tool_exposed(tool_name: String) -> bool:
		return loader.is_tool_exposed(tool_name)

	func log(_message: String, _level: String) -> void:
		pass

	func sanitize_for_json(value):
		return value


func run_case(_tree: SceneTree) -> Dictionary:
	var loader = FakeToolLoader.new()
	var stdio_server = StdioServerScript.new()
	stdio_server.initialize(loader, false)

	var router = ToolRpcRouterScript.new()
	var callbacks = RouterCallbacks.new(loader)
	var context = ToolRpcRouterContextScript.new()
	context.get_tool_loader = Callable(callbacks, "get_tool_loader")
	context.is_tool_enabled = Callable(callbacks, "is_tool_enabled")
	context.is_tool_exposed = Callable(callbacks, "is_tool_exposed")
	context.log = Callable(callbacks, "log")
	context.sanitize_for_json = Callable(callbacks, "sanitize_for_json")
	router.configure(context)

	loader.disabled_tools["system_project_lifecycle"] = true
	var disabled_params := {"name": "system_project_lifecycle", "arguments": {}}
	var router_disabled: Dictionary = await router.build_tool_call_result_async(disabled_params)
	var stdio_disabled_response: Dictionary = await stdio_server.call("_handle_tools_call", disabled_params, 10)
	var disabled_check := _assert_matching_tool_error(router_disabled, stdio_disabled_response.get("result", {}), "disabled")
	if not bool(disabled_check.get("success", false)):
		return disabled_check
	if loader.executed_count != 0:
		return _failure("Disabled stdio/router parity case should not execute the loader.")

	loader.disabled_tools.clear()
	loader.hidden_tools["system_project_lifecycle"] = true
	var hidden_params := {"name": "system_project_lifecycle", "arguments": {}}
	var router_hidden: Dictionary = await router.build_tool_call_result_async(hidden_params)
	var stdio_hidden_response: Dictionary = await stdio_server.call("_handle_tools_call", hidden_params, 11)
	var hidden_check := _assert_matching_tool_error(router_hidden, stdio_hidden_response.get("result", {}), "not exposed")
	if not bool(hidden_check.get("success", false)):
		return hidden_check
	if loader.executed_count != 0:
		return _failure("Hidden stdio/router parity case should not execute the loader.")

	loader.hidden_tools.clear()
	stdio_server.set_disabled_tools(["system_project_lifecycle"])
	var stdio_local_disabled_response: Dictionary = await stdio_server.call("_handle_tools_call", hidden_params, 12)
	var stdio_local_disabled_check := _assert_stable_stdio_tool_error(
		stdio_local_disabled_response.get("result", {}),
		"disabled",
		"stdio-local disabled"
	)
	if not bool(stdio_local_disabled_check.get("success", false)):
		return stdio_local_disabled_check
	if loader.executed_count != 0:
		return _failure("Stdio-local disabled case should not execute the loader.")
	stdio_server.set_disabled_tools([])

	for malformed_name in [1, null]:
		var malformed_params := {"name": malformed_name, "arguments": {}}
		var malformed_response: Dictionary = await stdio_server.call("_handle_tools_call", malformed_params, 13)
		var malformed_check := _assert_stable_stdio_tool_error(
			malformed_response.get("result", {}),
			"Tool name must be a string",
			"malformed name"
		)
		if not bool(malformed_check.get("success", false)):
			return malformed_check
	if loader.executed_count != 0:
		return _failure("Malformed-name stdio cases should not execute the loader.")

	var framing_check: Dictionary = await _assert_stdio_framing_guards(stdio_server)
	if not bool(framing_check.get("success", false)):
		return framing_check

	stdio_server.free()
	return {
		"name": "stdio_tool_error_parity_contracts",
		"success": true,
		"error": "",
		"details": {
			"checked_errors": ["disabled", "not exposed", "stdio-local disabled", "malformed name", "framing"]
		}
	}


func _assert_matching_tool_error(router_result: Dictionary, stdio_result, expected_text: String) -> Dictionary:
	if not (stdio_result is Dictionary):
		return _failure("Stdio tools/call should return a tool result for %s errors." % expected_text)
	var stdio_result_dict: Dictionary = stdio_result
	if not bool(router_result.get("isError", false)):
		return _failure("Shared router should mark %s case as an error." % expected_text)
	if not bool(stdio_result_dict.get("isError", false)):
		return _failure("Stdio should mark %s case as an error." % expected_text)
	var router_structured = router_result.get("structuredContent", {})
	var stdio_structured = stdio_result_dict.get("structuredContent", {})
	if not (router_structured is Dictionary) or not (stdio_structured is Dictionary):
		return _failure("Both router and stdio should expose structuredContent for %s errors." % expected_text)
	var router_error := str((router_structured as Dictionary).get("error", ""))
	var stdio_error := str((stdio_structured as Dictionary).get("error", ""))
	if router_error != stdio_error:
		return _failure("Stdio %s error should match shared router error. router=%s stdio=%s" % [expected_text, router_error, stdio_error])
	if stdio_error.find(expected_text) == -1:
		return _failure("Stdio %s error should preserve the expected text." % expected_text)
	if bool((stdio_structured as Dictionary).get("success", true)):
		return _failure("Stdio %s structuredContent should report success=false." % expected_text)
	return {"success": true, "error": ""}


func _assert_stable_stdio_tool_error(stdio_result, expected_text: String, label: String) -> Dictionary:
	if not (stdio_result is Dictionary):
		return _failure("Stdio tools/call should return a tool result for %s errors." % label)
	var stdio_result_dict: Dictionary = stdio_result
	if not bool(stdio_result_dict.get("isError", false)):
		return _failure("Stdio should mark %s as an error." % label)
	var stdio_structured = stdio_result_dict.get("structuredContent", {})
	if not (stdio_structured is Dictionary):
		return _failure("Stdio should expose structuredContent for %s errors." % label)
	var stdio_error := str((stdio_structured as Dictionary).get("error", ""))
	if stdio_error.find(expected_text) == -1:
		return _failure("Stdio %s error should preserve '%s'. actual=%s" % [label, expected_text, stdio_error])
	if bool((stdio_structured as Dictionary).get("success", true)):
		return _failure("Stdio %s structuredContent should report success=false." % label)
	return {"success": true, "error": ""}


func _assert_stdio_framing_guards(stdio_server) -> Dictionary:
	stdio_server.start()

	if str(stdio_server.call("get_framing_mode")) != "newline":
		stdio_server.stop()
		return _failure("Stdio should default to newline-delimited JSON-RPC framing.")

	var newline_check := await _assert_newline_stdio_frames(stdio_server)
	if not bool(newline_check.get("success", false)):
		stdio_server.stop()
		return newline_check

	stdio_server.set("_buffer", "Content-Length: 2\r\n\r\n{}".to_utf8_buffer())
	stdio_server.set("_last_written_response", {})
	var legacy_default_parsed: bool = bool(await stdio_server.call("_try_parse_frame", int(stdio_server.get("_transport_generation"))))
	if bool(legacy_default_parsed):
		stdio_server.stop()
		return _failure("Default newline stdio mode should not parse legacy Content-Length frames.")
	var legacy_default_error: Dictionary = (stdio_server.get("_last_written_response") as Dictionary).get("error", {})
	if not str(legacy_default_error.get("message", "")).contains("stdio_legacy_content_length_requires_compat"):
		stdio_server.stop()
		return _failure("Default newline stdio mode should direct legacy Content-Length users to compatibility mode.")

	stdio_server.call("set_framing_mode", "legacy_content_length")
	if str(stdio_server.call("get_framing_mode")) != "legacy_content_length":
		stdio_server.stop()
		return _failure("Stdio should allow explicit legacy Content-Length compatibility mode.")

	var non_numeric_check := await _assert_rejected_stdio_frame(
		stdio_server,
		"Content-Length: nope\r\n\r\n{}",
		"stdio_bad_content_length",
		"non-numeric"
	)
	if not bool(non_numeric_check.get("success", false)):
		return non_numeric_check

	var negative_check := await _assert_rejected_stdio_frame(
		stdio_server,
		"Content-Length: -1\r\n\r\n{}",
		"stdio_bad_content_length",
		"negative"
	)
	if not bool(negative_check.get("success", false)):
		return negative_check

	var zero_check := await _assert_rejected_stdio_frame(
		stdio_server,
		"Content-Length: 0\r\n\r\n",
		"stdio_bad_content_length",
		"zero"
	)
	if not bool(zero_check.get("success", false)):
		return zero_check

	var duplicate_check := await _assert_rejected_stdio_frame(
		stdio_server,
		"Content-Length: 2\r\nContent-Length: 2\r\n\r\n{}",
		"stdio_duplicate_content_length",
		"duplicate"
	)
	if not bool(duplicate_check.get("success", false)):
		return duplicate_check

	var oversized_check := await _assert_rejected_stdio_frame(
		stdio_server,
		"Content-Length: 1048577\r\n\r\n{}",
		"stdio_frame_too_large",
		"oversized"
	)
	if not bool(oversized_check.get("success", false)):
		return oversized_check

	var max_content_check := await _assert_max_content_length_stdio_frame(stdio_server)
	if not bool(max_content_check.get("success", false)):
		return max_content_check

	var envelope_check := await _assert_stdio_envelope_guards(stdio_server)
	if not bool(envelope_check.get("success", false)):
		return envelope_check
	var shared_dispatch_check := await _assert_stdio_shared_json_rpc_dispatch(stdio_server)
	if not bool(shared_dispatch_check.get("success", false)):
		return shared_dispatch_check

	var pending_overflow := PackedByteArray()
	pending_overflow.resize(MAX_STDIN_PENDING_BYTES + 1)
	pending_overflow.fill(65)
	stdio_server.set("_buffer", pending_overflow)
	stdio_server.set("_last_written_response", {})
	var rejected_pending_overflow: bool = bool(await stdio_server.call("_try_parse_frame", int(stdio_server.get("_transport_generation"))))
	if bool(rejected_pending_overflow):
		stdio_server.stop()
		return _failure("Oversized stdio pending buffer should not parse successfully.")
	if not (stdio_server.get("_buffer") as PackedByteArray).is_empty():
		stdio_server.stop()
		return _failure("Oversized stdio pending buffer should be cleared.")
	var pending_overflow_response: Dictionary = stdio_server.get("_last_written_response")
	var pending_overflow_error: Dictionary = pending_overflow_response.get("error", {})
	if not str(pending_overflow_error.get("message", "")).contains("stdio_pending_buffer_exceeded"):
		stdio_server.stop()
		return _failure("Oversized stdio pending buffer should report stdio_pending_buffer_exceeded.")

	var first_body := JSON.stringify({"jsonrpc": "2.0", "id": 21, "method": "ping", "params": {}})
	var second_body := JSON.stringify({"jsonrpc": "2.0", "id": 22, "method": "ping", "params": {}})
	var first_frame := "Content-Length: %d\r\n\r\n%s" % [first_body.to_utf8_buffer().size(), first_body]
	var second_frame := "Content-Length: %d\r\n\r\n%s" % [second_body.to_utf8_buffer().size(), second_body]
	stdio_server.set("_buffer", (first_frame + second_frame).to_utf8_buffer())
	stdio_server.set("_last_written_response", {})
	var generation := int(stdio_server.get("_transport_generation"))
	var parsed_first: bool = bool(await stdio_server.call("_try_parse_frame", generation))
	if not bool(parsed_first):
		stdio_server.stop()
		return _failure("Stdio should parse the first valid pipelined frame.")
	if int((stdio_server.get("_last_written_response") as Dictionary).get("id", 0)) != 21:
		stdio_server.stop()
		return _failure("Stdio first pipelined frame should preserve response id.")
	if (stdio_server.get("_buffer") as PackedByteArray).is_empty():
		stdio_server.stop()
		return _failure("Stdio parser should preserve the second pipelined frame after the first parse.")
	var parsed_second: bool = bool(await stdio_server.call("_try_parse_frame", generation))
	if not bool(parsed_second):
		stdio_server.stop()
		return _failure("Stdio should parse the second valid pipelined frame.")
	if int((stdio_server.get("_last_written_response") as Dictionary).get("id", 0)) != 22:
		stdio_server.stop()
		return _failure("Stdio second pipelined frame should preserve response id.")
	if not (stdio_server.get("_buffer") as PackedByteArray).is_empty():
		stdio_server.stop()
		return _failure("Stdio parser should drain valid pipelined frames exactly.")

	stdio_server.stop()
	return {"success": true, "error": ""}


func _assert_stdio_shared_json_rpc_dispatch(stdio_server) -> Dictionary:
	var tools_list_body := JSON.stringify({"jsonrpc": "2.0", "id": 71, "method": "tools/list", "params": {}})
	stdio_server.set("_buffer", ("Content-Length: %d\r\n\r\n%s" % [tools_list_body.to_utf8_buffer().size(), tools_list_body]).to_utf8_buffer())
	stdio_server.set("_last_written_response", {})
	var parsed_tools_list: bool = bool(await stdio_server.call("_try_parse_frame", int(stdio_server.get("_transport_generation"))))
	if not bool(parsed_tools_list):
		return _failure("Stdio shared JSON-RPC dispatch should consume tools/list frames.")
	var tools_list_response: Dictionary = stdio_server.get("_last_written_response")
	var tools_list_result = tools_list_response.get("result", {})
	if int(tools_list_response.get("id", 0)) != 71 or not (tools_list_result is Dictionary) or not ((tools_list_result as Dictionary).get("tools", []) is Array):
		return _failure("Stdio tools/list should route through the shared JSON-RPC router and return a tool list result.")

	var invalid_params_body := JSON.stringify({"jsonrpc": "2.0", "id": 72, "method": "resources/read", "params": []})
	stdio_server.set("_buffer", ("Content-Length: %d\r\n\r\n%s" % [invalid_params_body.to_utf8_buffer().size(), invalid_params_body]).to_utf8_buffer())
	stdio_server.set("_last_written_response", {})
	var parsed_invalid_params: bool = bool(await stdio_server.call("_try_parse_frame", int(stdio_server.get("_transport_generation"))))
	if not bool(parsed_invalid_params):
		return _failure("Stdio shared JSON-RPC dispatch should consume invalid resources/read params frames.")
	var invalid_params_response: Dictionary = stdio_server.get("_last_written_response")
	var invalid_params_error: Dictionary = invalid_params_response.get("error", {})
	if int(invalid_params_error.get("code", 0)) != -32602 or str(invalid_params_error.get("message", "")).find("Invalid params") == -1:
		return _failure("Stdio resources/read non-object params should use the shared JSON-RPC request service -32602 error.")

	var response_envelope_body := JSON.stringify({"jsonrpc": "2.0", "id": 73, "result": {"ignored": true}})
	stdio_server.set("_buffer", ("Content-Length: %d\r\n\r\n%s" % [response_envelope_body.to_utf8_buffer().size(), response_envelope_body]).to_utf8_buffer())
	stdio_server.set("_last_written_response", {})
	var parsed_response_envelope: bool = bool(await stdio_server.call("_try_parse_frame", int(stdio_server.get("_transport_generation"))))
	if not bool(parsed_response_envelope):
		return _failure("Stdio shared JSON-RPC dispatch should consume response envelopes.")
	if not (stdio_server.get("_last_written_response") as Dictionary).is_empty():
		return _failure("Stdio shared JSON-RPC dispatch should ignore response envelopes without emitting a reply.")
	return {"success": true, "error": ""}


func _assert_stdio_envelope_guards(stdio_server) -> Dictionary:
	var invalid_cases: Array[Dictionary] = [
		{
			"label": "no-id object method",
			"request": {"jsonrpc": "2.0", "method": [], "params": {}},
			"expected_id": null
		},
		{
			"label": "wrong jsonrpc",
			"request": {"jsonrpc": "1.0", "id": 31, "method": "ping", "params": {}},
			"expected_id": 31
		},
		{
			"label": "missing method",
			"request": {"jsonrpc": "2.0", "id": 32, "params": {}},
			"expected_id": 32
		},
		{
			"label": "object method",
			"request": {"jsonrpc": "2.0", "id": 33, "method": {}, "params": {}},
			"expected_id": 33
		},
		{
			"label": "object id",
			"request": {"jsonrpc": "2.0", "id": {}, "method": "ping", "params": {}},
			"expected_id": null
		},
		{
			"label": "wrong jsonrpc with object id",
			"request": {"jsonrpc": "1.0", "id": {}, "method": [], "params": {}},
			"expected_id": null
		}
	]
	for invalid_case in invalid_cases:
		var body := JSON.stringify(invalid_case.get("request", {}))
		stdio_server.set("_buffer", ("Content-Length: %d\r\n\r\n%s" % [body.to_utf8_buffer().size(), body]).to_utf8_buffer())
		stdio_server.set("_last_written_response", {})
		var parsed: bool = bool(await stdio_server.call("_try_parse_frame", int(stdio_server.get("_transport_generation"))))
		if not bool(parsed):
			return _failure("Invalid %s stdio envelope should still consume its frame." % str(invalid_case.get("label", "")))
		var response: Dictionary = stdio_server.get("_last_written_response")
		var error: Dictionary = response.get("error", {})
		if int(error.get("code", 0)) != -32600:
			return _failure("Invalid %s stdio envelope should emit -32600. actual=%s" % [str(invalid_case.get("label", "")), str(error.get("code", ""))])
		if response.get("id") != invalid_case.get("expected_id"):
			return _failure("Invalid %s stdio envelope should preserve only valid ids." % str(invalid_case.get("label", "")))

	var notification_body := JSON.stringify({"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}})
	stdio_server.set("_buffer", ("Content-Length: %d\r\n\r\n%s" % [notification_body.to_utf8_buffer().size(), notification_body]).to_utf8_buffer())
	stdio_server.set("_last_written_response", {})
	var parsed_notification: bool = bool(await stdio_server.call("_try_parse_frame", int(stdio_server.get("_transport_generation"))))
	if not bool(parsed_notification):
		return _failure("Valid stdio notification envelope should consume its frame.")
	if not (stdio_server.get("_last_written_response") as Dictionary).is_empty():
		return _failure("Valid stdio notification envelope should not emit a response.")
	var response_body := JSON.stringify({"jsonrpc": "2.0", "id": 40, "result": {"ok": true}})
	stdio_server.set("_buffer", ("Content-Length: %d\r\n\r\n%s" % [response_body.to_utf8_buffer().size(), response_body]).to_utf8_buffer())
	stdio_server.set("_last_written_response", {})
	var parsed_response_envelope: bool = bool(await stdio_server.call("_try_parse_frame", int(stdio_server.get("_transport_generation"))))
	if not bool(parsed_response_envelope):
		return _failure("Stdio JSON-RPC response envelope should consume its frame.")
	if not (stdio_server.get("_last_written_response") as Dictionary).is_empty():
		return _failure("Stdio JSON-RPC response envelope should be ignored instead of treated as an invalid request.")
	return {"success": true, "error": ""}


func _assert_newline_stdio_frames(stdio_server) -> Dictionary:
	var first_body := JSON.stringify({"jsonrpc": "2.0", "id": 31, "method": "ping", "params": {}})
	var second_body := JSON.stringify({"jsonrpc": "2.0", "id": 32, "method": "ping", "params": {}})
	stdio_server.set("_buffer", ("%s\n%s\r\n" % [first_body, second_body]).to_utf8_buffer())
	stdio_server.set("_last_written_response", {})
	var generation := int(stdio_server.get("_transport_generation"))
	var parsed_first: bool = bool(await stdio_server.call("_try_parse_frame", generation))
	if not bool(parsed_first):
		return _failure("Default stdio should parse the first newline-delimited JSON-RPC frame.")
	if int((stdio_server.get("_last_written_response") as Dictionary).get("id", 0)) != 31:
		return _failure("Default stdio first newline frame should preserve response id.")
	var first_written_frame := str(stdio_server.get("_last_written_frame"))
	if first_written_frame.begins_with("Content-Length:"):
		return _failure("Default stdio should write newline-delimited JSON-RPC responses, not Content-Length frames.")
	if first_written_frame.find("\r\n\r\n") != -1:
		return _failure("Default stdio newline response should not include legacy Content-Length separators.")
	var parsed_first_response = JSON.parse_string(first_written_frame)
	if not (parsed_first_response is Dictionary):
		return _failure("Default stdio newline response should be a JSON object string.")
	if (stdio_server.get("_buffer") as PackedByteArray).is_empty():
		return _failure("Default stdio parser should preserve the second newline frame after the first parse.")
	var parsed_second: bool = bool(await stdio_server.call("_try_parse_frame", generation))
	if not bool(parsed_second):
		return _failure("Default stdio should parse the second newline-delimited JSON-RPC frame.")
	if int((stdio_server.get("_last_written_response") as Dictionary).get("id", 0)) != 32:
		return _failure("Default stdio second newline frame should preserve response id.")
	if not (stdio_server.get("_buffer") as PackedByteArray).is_empty():
		return _failure("Default stdio parser should drain newline-delimited frames exactly.")
	return {"success": true, "error": ""}


func _assert_max_content_length_stdio_frame(stdio_server) -> Dictionary:
	var body_prefix := "{\"jsonrpc\":\"2.0\",\"id\":23,\"method\":\"ping\",\"params\":{\"padding\":\""
	var body_suffix := "\"}}"
	var padding_bytes := MAX_STDIN_CONTENT_BYTES - body_prefix.to_utf8_buffer().size() - body_suffix.to_utf8_buffer().size()
	if padding_bytes < 0:
		return _failure("Maximum stdio Content-Length fixture overhead exceeds the content limit.")
	var body := body_prefix + "A".repeat(padding_bytes) + body_suffix
	if body.to_utf8_buffer().size() != MAX_STDIN_CONTENT_BYTES:
		return _failure("Maximum stdio Content-Length fixture must be exactly %d bytes." % MAX_STDIN_CONTENT_BYTES)
	var frame := "Content-Length: %d\r\n\r\n%s" % [body.to_utf8_buffer().size(), body]
	if frame.to_utf8_buffer().size() > MAX_STDIN_PENDING_BYTES:
		return _failure("Maximum stdio Content-Length fixture must fit inside the pending buffer allowance.")

	stdio_server.set("_buffer", frame.to_utf8_buffer())
	stdio_server.set("_last_written_response", {})
	var parsed: bool = bool(await stdio_server.call("_try_parse_frame", int(stdio_server.get("_transport_generation"))))
	if not bool(parsed):
		return _failure("Maximum stdio Content-Length should parse successfully.")
	if not (stdio_server.get("_buffer") as PackedByteArray).is_empty():
		return _failure("Maximum stdio Content-Length should drain the pending buffer.")
	var response: Dictionary = stdio_server.get("_last_written_response")
	if int(response.get("id", 0)) != 23:
		return _failure("Maximum stdio Content-Length should preserve the response id.")
	if response.has("error"):
		return _failure("Maximum stdio Content-Length should not emit a framing error.")
	return {"success": true, "error": ""}


func _assert_rejected_stdio_frame(stdio_server, frame: String, expected_type: String, label: String) -> Dictionary:
	stdio_server.set("_buffer", frame.to_utf8_buffer())
	stdio_server.set("_last_written_response", {})
	var parsed: bool = bool(await stdio_server.call("_try_parse_frame", int(stdio_server.get("_transport_generation"))))
	if bool(parsed):
		return _failure("Invalid %s stdio frame should not parse successfully." % label)
	if not (stdio_server.get("_buffer") as PackedByteArray).is_empty():
		return _failure("Invalid %s stdio frame should clear the pending buffer." % label)
	var response: Dictionary = stdio_server.get("_last_written_response")
	var error: Dictionary = response.get("error", {})
	if int(error.get("code", 0)) != -32700:
		return _failure("Invalid %s stdio frame should emit a JSON-RPC parse/framing error." % label)
	if not str(error.get("message", "")).contains(expected_type):
		return _failure("Invalid %s stdio frame should include %s. actual=%s" % [label, expected_type, str(error.get("message", ""))])
	return {"success": true, "error": ""}


func _failure(message: String) -> Dictionary:
	return {
		"name": "stdio_tool_error_parity_contracts",
		"success": false,
		"error": message,
		"details": {}
	}
