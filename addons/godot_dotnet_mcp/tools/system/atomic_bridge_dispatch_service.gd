@tool
extends RefCounted

## AtomicBridge call flow service.
## Keeps write guards, name parsing, dispatch, and cache invalidation out of the facade.

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")


func call_atomic(full_name: String, args: Dictionary, support, runtime) -> Dictionary:
	var request := _prepare_request(full_name, args, support, runtime)
	if not bool(request.get("success", false)):
		return _error(str(request.get("error", "")))
	var result: Dictionary = runtime.dispatch(str(request.get("category", "")), str(request.get("tool_name", "")), args)
	if bool(request.get("write_action", false)) and bool(result.get("success", false)):
		runtime.invalidate()
	return result


func call_atomic_async(full_name: String, args: Dictionary, support, runtime) -> Dictionary:
	var request := _prepare_request(full_name, args, support, runtime)
	if not bool(request.get("success", false)):
		return _error(str(request.get("error", "")))
	var result: Dictionary = await runtime.dispatch_async(str(request.get("category", "")), str(request.get("tool_name", "")), args)
	if bool(request.get("write_action", false)) and bool(result.get("success", false)):
		runtime.invalidate()
	return result


func _prepare_request(full_name: String, args: Dictionary, support, runtime) -> Dictionary:
	MCPDebugBuffer.record("debug", "atomic",
		"%s action=%s" % [full_name, str(args.get("action", ""))])
	var write_action: bool = bool(support.is_write_atomic_action(full_name, args))
	if write_action:
		var target_path: String = str(support.find_path_in_args(args))
		if bool(support.is_protected_path(target_path)) and not bool(args.get("allow_plugin_write", false)):
			MCPDebugBuffer.record("warning", "atomic",
				"Write blocked on protected path: %s (tool: %s)" % [target_path, full_name])
			return {"success": false, "error": "Protected path: cannot write to MCP plugin directory via system tools. Use plugin_developer tools with explicit authorization."}
	var parsed := _parse_atomic_name(full_name)
	if not bool(parsed.get("success", false)):
		MCPDebugBuffer.record("debug", "atomic", "Invalid atomic name: %s" % full_name)
		return parsed
	var category := str(parsed.get("category", ""))
	if not runtime.has_category(category):
		return {"success": false, "error": "Unknown atomic category: %s (from %s)" % [category, full_name]}
	parsed["write_action"] = write_action
	return parsed


func _parse_atomic_name(full_name: String) -> Dictionary:
	var parts := full_name.split("_", false, 1)
	if parts.size() < 2:
		return {"success": false, "error": "Invalid atomic tool name: %s" % full_name}
	return {
		"success": true,
		"category": str(parts[0]),
		"tool_name": str(parts[1])
	}


func _error(message: String) -> Dictionary:
	return {"success": false, "error": message}
