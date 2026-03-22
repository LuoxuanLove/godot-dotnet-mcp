@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

var _runtime_context: Dictionary = {}


func configure_runtime(context: Dictionary) -> void:
	_runtime_context = context.duplicate()


func get_registration() -> Dictionary:
	return {
		"category": "plugin",
		"domain_key": "plugin",
		"hot_reloadable": false,
		"compatibility_alias": true
	}


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "runtime",
			"compatibility_alias": true,
			"description": """PLUGIN RUNTIME: Inspect tool loader state and trigger domain reloads.

ACTIONS:
- list_loaded_domains: Return runtime state for every registered domain
- reload_domain: Reload a single domain/category without restarting the MCP server
- reload_all_domains: Reload all hot-reloadable domains and rescan custom tools
- get_reload_status: Return the latest reload result and performance summary

EXAMPLES:
- List loaded domains: {"action": "list_loaded_domains"}
- Reload a single domain: {"action": "reload_domain", "domain": "scene"}
- Reload all domains: {"action": "reload_all_domains"}
- Get reload status: {"action": "get_reload_status"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["list_loaded_domains", "reload_domain", "reload_all_domains", "get_reload_status", "restart_server", "soft_reload_plugin", "full_reload_plugin", "set_tool_enabled", "set_category_enabled", "set_domain_enabled"],
						"description": "Plugin runtime action"
					},
					"domain": {
						"type": "string",
						"description": "Tool domain/category to reload"
					},
					"tool_name": {
						"type": "string",
						"description": "Full tool name, for example user_echo"
					},
					"category": {
						"type": "string",
						"description": "Category name to enable or disable"
					},
					"enabled": {
						"type": "boolean",
						"description": "Desired enabled state"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "evolution",
			"compatibility_alias": true,
			"description": """PLUGIN EVOLUTION: Manage User-category tools through MCP with explicit authorization.

ACTIONS:
- list_user_tools: List scripts and tool names under the User category
- create_user_tool: Preview or create a user tool scaffold in custom_tools/
- delete_user_tool: Preview or delete a user tool script
- get_audit_log: Read recent user-tool audit entries

NOTES:
- Any write action requires authorized=true
- All generated tools are forced into the User root category""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["list_user_tools", "create_user_tool", "delete_user_tool", "get_audit_log"]
					},
					"tool_name": {"type": "string"},
					"display_name": {"type": "string"},
					"description": {"type": "string"},
					"script_path": {"type": "string"},
					"authorized": {"type": "boolean"},
					"limit": {"type": "integer"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "developer",
			"compatibility_alias": true,
			"description": """PLUGIN DEVELOPER: Control developer-facing Dock options.

ACTIONS:
- get_settings: Read current developer options relevant to the Dock
- set_log_level: Change the debug buffer minimum log level
- set_show_user_tools: Toggle User category visibility in the Dock
- list_profiles: List builtin and custom tool presets""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["get_settings", "set_log_level", "set_show_user_tools", "list_profiles"]
					},
					"level": {
						"type": "string",
						"enum": ["trace", "debug", "info", "warning", "error"]
					},
					"enabled": {"type": "boolean"}
				},
				"required": ["action"]
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"runtime":
			return _execute_runtime(args)
		"evolution":
			return _execute_evolution(args)
		"developer":
			return _execute_developer(args)
		_:
			return _error("Unknown plugin tool: %s" % tool_name)


func _execute_runtime(args: Dictionary) -> Dictionary:
	var plugin = _get_plugin()
	if plugin == null or not plugin.has_method("execute_plugin_runtime_tool"):
		return _error("Plugin runtime bridge is unavailable")
	return plugin.execute_plugin_runtime_tool("runtime", args)


func _execute_evolution(args: Dictionary) -> Dictionary:
	var plugin = _get_plugin()
	if plugin == null or not plugin.has_method("execute_plugin_evolution_tool"):
		return _error("Plugin evolution bridge is unavailable")
	return plugin.execute_plugin_evolution_tool("evolution", args)


func _execute_developer(args: Dictionary) -> Dictionary:
	var plugin = _get_plugin()
	if plugin == null or not plugin.has_method("execute_plugin_developer_tool"):
		return _error("Plugin developer bridge is unavailable")
	return plugin.execute_plugin_developer_tool("developer", args)


func _get_plugin():
	var server = _runtime_context.get("server", null)
	if server == null:
		return null
	return server.get_parent()
