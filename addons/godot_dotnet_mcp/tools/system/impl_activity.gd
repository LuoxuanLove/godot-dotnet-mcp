@tool
extends RefCounted

## System implementation: tool_activity

var bridge
var _runtime_context: Dictionary = {}

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
	var registry = _get_registry()
	if registry == null:
		return _error("activity_registry_unavailable", "Tool activity registry is unavailable.")
	var action := str(args.get("action", "status")).strip_edges()
	if action.is_empty():
		action = "status"
	match action:
		"status":
			return _success(registry.get_status(_query_options(args)), "Tool activity status fetched")
		"recent":
			var limit := int(args.get("limit", 20))
			return _success(registry.get_recent(limit, _query_options(args)), "Recent tool activity fetched")
		"get":
			var call_id := str(args.get("call_id", "")).strip_edges()
			if call_id.is_empty():
				return _error("invalid_argument", "action=get requires call_id.")
			return _success(registry.get_call(call_id), "Tool activity call fetched")
		_:
			return _error("invalid_argument", "Unknown tool_activity action: %s" % action, {
				"valid_actions": ["status", "recent", "get"]
			})


func _query_options(args: Dictionary) -> Dictionary:
	var options := {}
	for key in ["state", "tool", "threshold_ms", "failure_limit"]:
		if args.has(key):
			options[key] = args[key]
	return options


func _get_registry():
	if _runtime_context.get("tool_activity_registry", null) != null:
		return _runtime_context.get("tool_activity_registry", null)
	var tool_loader = _runtime_context.get("tool_loader", null)
	if tool_loader != null and tool_loader.has_method("get_tool_activity_registry"):
		return tool_loader.get_tool_activity_registry()
	return null


func _success(data: Dictionary, message: String) -> Dictionary:
	return {
		"success": true,
		"data": data,
		"message": message
	}


func _error(error_code: String, message: String, data: Dictionary = {}) -> Dictionary:
	var out := {
		"success": false,
		"error": error_code,
		"message": message
	}
	if not data.is_empty():
		out["data"] = data.duplicate(true)
	return out
