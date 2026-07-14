@tool
extends RefCounted

## System implementation: tool catalog search

var bridge
var _runtime_context: Dictionary = {}

const REPLACEMENT_RESOURCES := [
	"godot-dotnet-mcp://tools/catalog/exposed",
	"godot-dotnet-mcp://tools/catalog/visible",
	"godot-dotnet-mcp://tools/catalog",
	"godot-dotnet-mcp://guides/capabilities"
]

const HANDLED_TOOLS := ["tool_catalog"]
func handles(tool_name: String) -> bool:
	return tool_name in HANDLED_TOOLS


func configure_runtime(context: Dictionary) -> void:
	_runtime_context = context.duplicate(true)


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "tool_catalog",
			"description": "TOOL CATALOG: Search the current tool catalog by query, category, or domain key. ACTIONS: search (default). Returns matching tools with exposed/enabled state, actions, parameters, group path, match reasons, available filter values, filter warnings, and suggested next queries. Use visibility=visible to include non-public visible internal tools.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["search"], "description": "Tool catalog action (default: search)"},
					"query": {"type": "string", "description": "Optional case-insensitive search text matched against tool names, descriptions, actions, parameters, enum values, category, and domain key."},
					"category": {"type": "string", "description": "Optional tool category filter, such as system, project, editor, runtime, script, or user."},
					"domain": {"type": "string", "description": "Optional domain key filter, such as core, plugin, user, or a custom domain key."},
					"visibility": {"type": "string", "enum": ["exposed", "visible"], "description": "Search public exposed MCP tools or visible internal catalog tools (default: exposed)."},
					"limit": {"type": "integer", "description": "Maximum number of matches to return (default 25, max 100)."},
					"include_schema": {"type": "boolean", "description": "Include full input schema for each match (default: false)."}
				}
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name not in HANDLED_TOOLS:
		return _error("Unknown tool: %s" % tool_name)
	return _removed_public_tool()


func _error(message: String) -> Dictionary:
	if bridge != null and bridge.has_method("error"):
		return bridge.error(message)
	return {
		"success": false,
		"error": message,
		"message": message
	}


func _removed_public_tool() -> Dictionary:
	var message := "system_tool_catalog has been removed from the public tool surface. Read the catalog resources instead."
	return {
		"success": false,
		"error": message,
		"data": {
			"error_type": "removed_public_tool",
			"removed_tool": "system_tool_catalog",
			"replacement_methods": ["resources/read", "resources/list"],
			"replacement_resources": REPLACEMENT_RESOURCES.duplicate()
		}
	}
