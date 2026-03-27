@tool
extends "res://addons/godot_dotnet_mcp/tools/debug/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	match str(args.get("action", "")):
		"get_recent":
			return _success({
				"count": MCPDebugBuffer.size(),
				"events": MCPDebugBuffer.get_recent(int(args.get("limit", 50)))
			})
		"get_errors":
			var events := MCPDebugBuffer.get_by_levels(["warning", "error"], int(args.get("limit", 50)))
			return _success({
				"count": events.size(),
				"events": events
			})
		"clear_buffer":
			MCPDebugBuffer.clear()
			return _success({"count": 0}, "Debug buffer cleared")
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))
