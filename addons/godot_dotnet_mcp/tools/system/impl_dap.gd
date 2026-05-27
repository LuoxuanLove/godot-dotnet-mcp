@tool
extends RefCounted

## System implementation: dap_debugger

var bridge

const HANDLED_TOOLS := ["dap_debugger"]


func handles(tool_name: String) -> bool:
	return tool_name in HANDLED_TOOLS


func get_tools() -> Array[Dictionary]:
	var DapExecutorScript = load("res://addons/godot_dotnet_mcp/tools" + "/dap/executor.gd")
	if DapExecutorScript == null:
		return []
	var executor = DapExecutorScript.new()
	var tools: Array[Dictionary] = executor.get_tools()
	if tools.is_empty():
		return []
	var tool := (tools[0] as Dictionary).duplicate(true)
	tool["name"] = "dap_debugger"
	tool["description"] = "GODOT DAP DEBUGGER: High-level Debug Adapter Protocol entry for Godot debugger endpoints. Supports status, breakpoint set/remove/list, pause/continue/step_over, stack_trace, and output. Defaults to 127.0.0.1:6006 and returns structured dap_unavailable when no endpoint is reachable."
	return [tool]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name != "dap_debugger":
		return _unknown_tool_error(tool_name)
	return bridge.call_atomic("dap_debugger", args)


func execute_async(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name != "dap_debugger":
		return _unknown_tool_error(tool_name)
	return await bridge.call_atomic_async("dap_debugger", args)


func _unknown_tool_error(tool_name: String) -> Dictionary:
	return {
		"success": false,
		"error": "Unknown tool: %s" % tool_name,
		"data": {
			"error_type": "invalid_argument",
			"tool_name": tool_name
		}
	}
