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
			"name": "usage_guide",
			"description": "PLUGIN EVOLUTION USAGE GUIDE: Return the recommended authorization and User-tool workflow for this plugin.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"list_user_tools":
			var plugin = _get_plugin()
			if plugin == null or not plugin.has_method("get_user_tool_summaries"):
				return _error("Plugin evolution bridge is unavailable")
			return _success({"user_tools": plugin.get_user_tool_summaries()}, "User tools listed")
		"scaffold_user_tool":
			return _call_plugin_method("create_user_tool_from_tools", [args], "Plugin evolution bridge is unavailable")
		"delete_user_tool":
			return _call_plugin_method(
				"delete_user_tool_from_tools",
				[str(args.get("script_path", "")), bool(args.get("authorized", false)), str(args.get("agent_hint", ""))],
				"Plugin evolution bridge is unavailable"
			)
		"user_tool_audit":
			var plugin = _get_plugin()
			if plugin == null or not plugin.has_method("get_user_tool_audit"):
				return _error("Plugin evolution bridge is unavailable")
			return _success({
				"entries": plugin.get_user_tool_audit(
					int(args.get("limit", 20)),
					str(args.get("filter_action", "")),
					str(args.get("filter_session", ""))
				)
			}, "User tool audit fetched")
		"usage_guide":
			return _call_plugin_method("get_evolution_usage_guide_from_tools", [], "Plugin evolution guide bridge is unavailable")
		_:
			return _error("Unknown plugin evolution tool: %s" % tool_name)
