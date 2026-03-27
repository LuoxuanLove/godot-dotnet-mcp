@tool
extends "res://addons/godot_dotnet_mcp/tools/debug/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	var message = str(args.get("message", ""))

	match action:
		"print":
			if message.is_empty():
				return _error("Message is required")
			print("[MCP] %s" % message)
			MCPDebugBuffer.record("info", "debug_log", message)
		"warning":
			if message.is_empty():
				return _error("Message is required")
			push_warning("[MCP] %s" % message)
			MCPDebugBuffer.record("warning", "debug_log", message)
		"error":
			if message.is_empty():
				return _error("Message is required")
			push_error("[MCP] %s" % message)
			MCPDebugBuffer.record("error", "debug_log", message)
		"rich":
			if message.is_empty():
				return _error("Message is required")
			print_rich(message)
			MCPDebugBuffer.record("info", "debug_log", message)
		_:
			return _error("Unknown action: %s" % action)

	return _success({
		"action": action,
		"message": message
	}, "Message logged")
