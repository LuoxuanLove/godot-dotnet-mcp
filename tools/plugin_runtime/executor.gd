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
			"description": "PLUGIN RUNTIME STATE: Read loaded domains, usage stats and the latest reload summary.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["list_loaded_domains", "get_reload_status", "get_tool_usage_stats"]
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
	var loader = _get_loader()

	match tool_name:
		"state":
			if loader == null:
				return _error("Tool loader is unavailable")
			match str(args.get("action", "")):
				"list_loaded_domains":
					return _success({
						"domains": loader.get_domain_states(),
						"performance": loader.get_performance_summary()
					}, "Loaded domains listed")
				"get_reload_status":
					return _success(loader.get_reload_status(), "Reload status fetched")
				"get_tool_usage_stats":
					var stats = loader.get_tool_usage_stats()
					return _success({
						"count": stats.size(),
						"tool_usage_stats": stats
					}, "Tool usage stats fetched")
				_:
					return _error("Unknown action: %s" % str(args.get("action", "")))
		"reload":
			if loader == null:
				return _error("Tool loader is unavailable")
			match str(args.get("action", "")):
				"reload_domain":
					var domain = str(args.get("domain", ""))
					if domain.is_empty():
						return _error("Missing domain")
					var status = loader.reload_domain(domain)
					if status.get("failed_domains", []).is_empty() and status.get("skipped_domains", []).has(domain):
						return _success(status, "Domain skipped: %s" % domain)
					var success = status.get("failed_domains", []).is_empty() and status.get("reloaded_domains", []).has(domain)
					if success:
						return _success(status, "Domain reloaded: %s" % domain)
					return {"success": false, "error": "Failed to reload domain: %s" % domain, "data": status}
				"reload_all_domains":
					var status = loader.reload_all_domains()
					if status.get("failed_domains", []).is_empty():
						return _success(status, "Reloaded all domains")
					return {"success": false, "error": "Some domains failed to reload", "data": status}
				"soft_reload_plugin":
					return _call_plugin_method("runtime_soft_reload", [], "Plugin soft reload bridge is unavailable")
				"full_reload_plugin":
					return _call_plugin_method("runtime_full_reload", [], "Plugin full reload bridge is unavailable")
				_:
					return _error("Unknown action: %s" % str(args.get("action", "")))
		"server":
			return _call_plugin_method("runtime_restart_server", [], "Plugin runtime bridge is unavailable")
		"toggle":
			match str(args.get("action", "")):
				"set_tool_enabled":
					return _call_plugin_method(
						"set_tool_enabled_from_tools",
						[str(args.get("tool_name", "")), bool(args.get("enabled", false))],
						"Plugin tool toggle bridge is unavailable"
					)
				"set_category_enabled":
					return _call_plugin_method(
						"set_category_enabled_from_tools",
						[str(args.get("category", "")), bool(args.get("enabled", false))],
						"Plugin category toggle bridge is unavailable"
					)
				"set_domain_enabled":
					return _call_plugin_method(
						"set_domain_enabled_from_tools",
						[str(args.get("domain", "")), bool(args.get("enabled", false))],
						"Plugin domain toggle bridge is unavailable"
					)
				_:
					return _error("Unknown action: %s" % str(args.get("action", "")))
		"usage_guide":
			return _call_plugin_method("get_runtime_usage_guide_from_tools", [], "Plugin runtime guide bridge is unavailable")
		_:
			return _error("Unknown plugin runtime tool: %s" % tool_name)
