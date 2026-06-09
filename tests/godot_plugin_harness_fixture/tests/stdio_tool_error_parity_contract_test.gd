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

	stdio_server.free()
	return {
		"name": "stdio_tool_error_parity_contracts",
		"success": true,
		"error": "",
		"details": {
			"checked_errors": ["disabled", "not exposed"]
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


func _failure(message: String) -> Dictionary:
	return {
		"name": "stdio_tool_error_parity_contracts",
		"success": false,
		"error": message,
		"details": {}
	}
