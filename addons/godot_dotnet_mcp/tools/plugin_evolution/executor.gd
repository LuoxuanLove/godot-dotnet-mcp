@tool
extends "res://addons/godot_dotnet_mcp/tools/plugin_shared.gd"


func get_registration() -> Dictionary:
	return {
		"category": "plugin_evolution",
		"domain_key": "plugin",
		"hot_reloadable": false
	}


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "list_user_tools",
			"description": "PLUGIN EVOLUTION LIST: Return all registered User-category tools.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		},
		{
			"name": "scaffold_user_tool",
			"description": "PLUGIN EVOLUTION SCAFFOLD: Preview or create a User-category tool scaffold through explicit authorization.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"tool_name": {"type": "string"},
					"display_name": {"type": "string"},
					"description": {"type": "string"},
					"authorized": {"type": "boolean"},
					"agent_hint": {"type": "string"}
				},
				"required": ["tool_name"]
			}
		},
		{
			"name": "delete_user_tool",
			"description": "PLUGIN EVOLUTION DELETE: Preview or delete a User-category tool script.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"script_path": {"type": "string"},
					"authorized": {"type": "boolean"},
					"agent_hint": {"type": "string"}
				},
				"required": ["script_path"]
			}
		},
		{
			"name": "restore_user_tool",
			"description": "PLUGIN EVOLUTION RESTORE: Preview or restore the most recently deleted User-category tool script.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"authorized": {"type": "boolean"},
					"agent_hint": {"type": "string"}
				}
			}
		},
		{
			"name": "user_tool_audit",
			"description": "PLUGIN EVOLUTION AUDIT: Read recent user tool audit entries.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"limit": {"type": "integer"},
					"filter_action": {"type": "string"},
					"filter_session": {"type": "string"}
				}
			}
		},
		{
			"name": "check_compatibility",
			"description": "PLUGIN EVOLUTION COMPATIBILITY: Compare existing User tools against the current scaffold version.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		},
		{
			"name": "usage_guide",
			"description": "PLUGIN EVOLUTION USAGE GUIDE: Return the recommended authorization and User-tool workflow for this plugin.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	return _call_plugin_method(
		"execute_plugin_evolution_tool",
		[tool_name, args],
		"Plugin evolution bridge is unavailable"
	)
