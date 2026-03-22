@tool
extends "res://addons/godot_dotnet_mcp/tools/plugin_shared.gd"


func get_registration() -> Dictionary:
	return {
		"category": "plugin_runtime",
		"domain_key": "plugin",
		"hot_reloadable": false
	}


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "state",
			"description": "PLUGIN RUNTIME STATE: Read loaded domains, usage stats, self diagnostics, the latest reload summary, and detailed GDScript LSP diagnostics status via action=get_lsp_diagnostics_status.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["list_loaded_domains", "get_reload_status", "get_tool_usage_stats", "get_self_health", "get_self_errors", "get_self_timeline", "clear_self_diagnostics", "get_lsp_diagnostics_status"]
					},
					"severity": {
						"type": "string",
						"enum": ["info", "warning", "error"]
					},
					"category": {
						"type": "string"
					},
					"limit": {
						"type": "integer",
						"minimum": 1,
						"maximum": 200
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "reload",
			"description": "PLUGIN RUNTIME RELOAD: Reload tool domains or the plugin lifecycle itself.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["reload_domain", "reload_all_domains", "soft_reload_plugin", "full_reload_plugin"]
					},
					"domain": {
						"type": "string"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "server",
			"description": "PLUGIN SERVER CONTROL: Restart the embedded MCP server without changing tool registration.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		},
		{
			"name": "toggle",
			"description": "PLUGIN TOGGLES: Enable or disable tools, categories or domains.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["set_tool_enabled", "set_category_enabled", "set_domain_enabled"]
					},
					"tool_name": {
						"type": "string"
					},
					"category": {
						"type": "string"
					},
					"domain": {
						"type": "string"
					},
					"enabled": {
						"type": "boolean"
					}
				},
				"required": ["action", "enabled"]
			}
		},
		{
			"name": "usage_guide",
			"description": "PLUGIN RUNTIME USAGE GUIDE: Return the recommended runtime control and reload workflow for this plugin.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	return _call_plugin_method(
		"execute_plugin_runtime_tool",
		[tool_name, args],
		"Plugin runtime bridge is unavailable"
	)
