extends RefCounted

const HttpServerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_server.gd")
const StdioServerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_stdio_server.gd")
const ToolLoaderScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader.gd")
const DefaultToolAccessProviderScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/default_tool_access_provider.gd")


class FakeServerContext extends RefCounted:
	var _tool_access_provider

	func _init(tool_access_provider) -> void:
		_tool_access_provider = tool_access_provider

	func get_tool_access_provider():
		return _tool_access_provider


var _http_server = null
var _tool_loader = null
var _stdio_server = null


func run_case(_tree: SceneTree) -> Dictionary:
	_http_server = HttpServerScript.new()
	_http_server.initialize(0, "127.0.0.1", false)
	var http_loader = _http_server.get_tool_loader()
	if http_loader == null:
		return _failure("HTTP server did not initialize its tool loader.")
	var http_service = _http_server.get_gdscript_lsp_diagnostics_service()
	if http_service == null:
		return _failure("HTTP server did not expose the loader-owned GDScript LSP diagnostics service.")
	if http_service != http_loader.get_gdscript_lsp_diagnostics_service():
		return _failure("HTTP server should expose the exact diagnostics service instance owned by the loader adapter.")

	var tool_access_provider = DefaultToolAccessProviderScript.new()
	tool_access_provider.configure({
		"show_user_tools": true
	})
	_tool_loader = ToolLoaderScript.new()
	_tool_loader.configure(FakeServerContext.new(tool_access_provider))
	var summary: Dictionary = _tool_loader.initialize([])
	if int(summary.get("tool_count", 0)) <= 0:
		return _failure("Standalone tool loader did not initialize for stdio access testing.")

	_stdio_server = StdioServerScript.new()
	if _stdio_server.get_gdscript_lsp_diagnostics_service() != null:
		return _failure("Stdio server should not expose a diagnostics service before a tool loader is injected.")
	_stdio_server.initialize(_tool_loader, false)
	var stdio_service = _stdio_server.get_gdscript_lsp_diagnostics_service()
	if stdio_service == null:
		return _failure("Stdio server did not expose the loader-owned GDScript LSP diagnostics service.")
	if stdio_service != _tool_loader.get_gdscript_lsp_diagnostics_service():
		return _failure("Stdio server should expose the exact diagnostics service instance owned by the injected loader.")

	var unavailable_port := _pick_free_port(26706)
	if unavailable_port < 0:
		return _failure("Could not reserve an unavailable DAP port for stdio dispatch testing.")
	var dap_response: Dictionary = await _stdio_server.call("_handle_tools_call", {
		"name": "system_dap_debugger",
		"arguments": {
			"action": "pause",
			"host": "127.0.0.1",
			"port": unavailable_port,
			"thread_id": 1,
			"timeout_ms": 180
		}
	}, 99)
	var dap_check := _expect_stdio_dap_unavailable(dap_response)
	if not bool(dap_check.get("success", false)):
		return dap_check

	return {
		"name": "lsp_service_access_contracts",
		"success": true,
		"error": "",
		"details": {
			"http_loader_has_service": http_service != null,
			"stdio_loader_has_service": stdio_service != null,
			"stdio_dap_port": unavailable_port
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	if _http_server != null:
		if _http_server.has_method("stop"):
			_http_server.stop()
		if _http_server.has_method("dispose"):
			_http_server.dispose()
		_http_server.free()
	_http_server = null
	if _stdio_server != null:
		if _stdio_server.has_method("stop"):
			_stdio_server.stop()
		_stdio_server.free()
	_stdio_server = null
	if _tool_loader != null and _tool_loader.has_method("shutdown"):
		_tool_loader.shutdown()
	_tool_loader = null
	await tree.process_frame


func _failure(message: String) -> Dictionary:
	return {
		"name": "lsp_service_access_contracts",
		"success": false,
		"error": message
	}


func _expect_stdio_dap_unavailable(response: Dictionary) -> Dictionary:
	var result = response.get("result", {})
	if not (result is Dictionary):
		return _failure("Stdio DAP response should include a JSON-RPC result.")
	var content = (result as Dictionary).get("content", [])
	if not (content is Array) or (content as Array).is_empty():
		return _failure("Stdio DAP response should include text content.")
	var payload_text := str(((content as Array)[0] as Dictionary).get("text", ""))
	var parsed = JSON.parse_string(payload_text)
	if not (parsed is Dictionary):
		return _failure("Stdio DAP response text should contain a JSON object.")
	var parsed_dict: Dictionary = parsed
	if bool(parsed_dict.get("success", true)):
		return _failure("Stdio DAP pause should return a structured unavailable result without a listening endpoint.")
	var data = parsed_dict.get("data", {})
	if not (data is Dictionary):
		return _failure("Stdio DAP unavailable result should include structured data.")
	if str((data as Dictionary).get("error_type", "")) == "dap_async_required":
		return _failure("Stdio DAP tools/call should use async tool execution, not return dap_async_required.")
	if str((data as Dictionary).get("error_type", "")) != "dap_unavailable":
		return _failure("Stdio DAP unavailable result should set data.error_type=dap_unavailable: %s" % payload_text)
	return {"success": true}


func _pick_free_port(start_port: int) -> int:
	for port in range(start_port, start_port + 40):
		var probe := TCPServer.new()
		if probe.listen(port, "127.0.0.1") == OK:
			probe.stop()
			return port
	return -1
