extends RefCounted

# {"name": "mcp_debug_buffer_contracts"}

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	MCPDebugBuffer.clear()
	MCPDebugBuffer.set_minimum_level("debug")
	var levels := MCPDebugBuffer.get_available_levels()
	if levels != ["debug", "info", "warning", "error"]:
		return _failure("MCPDebugBuffer should expose exactly four public log levels: debug/info/warning/error.")

	MCPDebugBuffer.record("trace", "contract", "legacy trace alias")
	var recent := MCPDebugBuffer.get_recent(1)
	if recent.size() != 1:
		return _failure("Legacy trace input should still be recorded as a debug-level compatibility alias.")
	if str((recent[0] as Dictionary).get("level", "")) != "debug":
		return _failure("Legacy trace input should normalize to debug instead of creating a fifth public level.")

	return {
		"name": "mcp_debug_buffer_contracts",
		"success": true,
		"error": "",
		"details": {
			"level_count": levels.size(),
			"normalized_level": str((recent[0] as Dictionary).get("level", ""))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "mcp_debug_buffer_contracts",
		"success": false,
		"error": message
	}
