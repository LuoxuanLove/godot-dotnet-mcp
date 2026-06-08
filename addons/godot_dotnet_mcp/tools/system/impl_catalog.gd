@tool
extends RefCounted

## System implementation: tool catalog search

const ToolCatalogSearchService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_catalog_search_service.gd")

var bridge
var _runtime_context: Dictionary = {}

const HANDLED_TOOLS := ["tool_catalog"]
func handles(tool_name: String) -> bool:
	return tool_name in HANDLED_TOOLS


func configure_runtime(context: Dictionary) -> void:
	_runtime_context = context.duplicate(true)


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "tool_catalog",
			"description": "TOOL CATALOG: Search the current tool catalog by query, category, or domain key. ACTIONS: search (default). Returns matching tools with exposed/enabled state, actions, parameters, group path, and match reasons. Use visibility=visible to include non-public visible internal tools.",
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
	var action := str(args.get("action", "search")).strip_edges()
	if action.is_empty():
		action = "search"
	match action:
		"search":
			return _execute_search(args)
		_:
			return _error("Unknown tool_catalog action: %s" % action)


func _execute_search(args: Dictionary) -> Dictionary:
	var loader = _runtime_context.get("tool_loader", null)
	var result: Dictionary = ToolCatalogSearchService.search(loader, args)
	if not bool(result.get("success", false)) and bridge != null and bridge.has_method("error"):
		return bridge.error(str(result.get("message", result.get("error", "Tool catalog search failed"))))
	return result


func _error(message: String) -> Dictionary:
	if bridge != null and bridge.has_method("error"):
		return bridge.error(message)
	return {
		"success": false,
		"error": message,
		"message": message
	}
