extends RefCounted

# {"name": "stdio_tool_error_parity_contracts"}

const StdioServerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_stdio_server.gd")
const ToolRpcRouterScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_rpc_router.gd")
const ToolRpcRouterContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_rpc_router_context.gd")


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

	var pending_overflow := PackedByteArray()
	pending_overflow.resize(1048577)
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
