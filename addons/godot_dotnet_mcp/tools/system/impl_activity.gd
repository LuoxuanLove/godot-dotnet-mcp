@tool
extends RefCounted

## System implementation: tool_activity

var bridge
var _runtime_context: Dictionary = {}

const REPLACEMENT_RESOURCES := [
	"godot-dotnet-mcp://activity/status",
	"godot-dotnet-mcp://activity/recent",
	"godot-dotnet-mcp://activity/call/{id}",
	"godot-dotnet-mcp://guides/capabilities"
]

const HANDLED_TOOLS := ["tool_activity"]


func handles(tool_name: String) -> bool:
	return tool_name in HANDLED_TOOLS


func configure_runtime(context: Dictionary) -> void:
	_runtime_context = context.duplicate()


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "tool_activity",
			"description": "TOOL ACTIVITY: Inspect current and recent MCP tool calls. ACTIONS: status, recent, get. Reports running calls, recent completions, execution order, query filters, slow-call and failure diagnostics, lightweight scheduling state, and optional self-reported agent context supplied through _mcp_context.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["status", "recent", "get"],
						"description": "Tool activity action."
					},
					"call_id": {
						"type": "string",
						"description": "Call id to inspect for action=get."
					},
					"limit": {
						"type": "integer",
						"description": "Maximum recent calls to return for action=recent."
					},
					"state": {
						"type": "string",
						"enum": ["running", "completed", "failed"],
						"description": "Optional state filter for action=status or action=recent."
					},
					"tool": {
						"type": "string",
						"description": "Optional case-insensitive tool, category, action, or tool_name filter for action=status or action=recent."
					},
					"threshold_ms": {
						"type": "number",
						"description": "Optional slow-call threshold in milliseconds for action=status or action=recent diagnostics."
					},
					"failure_limit": {
						"type": "integer",
						"description": "Maximum recent failed calls to include in action=status or action=recent diagnostics."
					}
				}
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name not in HANDLED_TOOLS:
		return _error("invalid_argument", "Unknown tool: %s" % tool_name)
	return _removed_public_tool()


func _error(error_code: String, message: String, data: Dictionary = {}) -> Dictionary:
	var out := {
		"success": false,
		"error": error_code,
		"message": message
	}
	if not data.is_empty():
		out["data"] = data.duplicate(true)
	return out


func _removed_public_tool() -> Dictionary:
	var message := "system_tool_activity has been removed from the public tool surface. Read the activity resources instead."
	return {
		"success": false,
		"error": message,
		"data": {
			"error_type": "removed_public_tool",
			"removed_tool": "system_tool_activity",
			"replacement_methods": ["resources/read", "resources/list", "resources/templates/list"],
			"replacement_resources": REPLACEMENT_RESOURCES.duplicate()
		}
	}
