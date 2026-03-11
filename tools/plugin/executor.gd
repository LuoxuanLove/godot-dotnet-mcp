@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

const PluginRuntimeState = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_state.gd")

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
	var loader = _runtime_context.get("tool_loader", null)
	if loader == null:
		return _error("Tool loader is unavailable")
	var plugin = _get_plugin()

	match str(args.get("action", "")):
		"list_loaded_domains":
			return _success({
				"domains": loader.get_domain_states(),
				"performance": loader.get_performance_summary()
			}, "Loaded domains listed")
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
			return {
				"success": false,
				"error": "Failed to reload domain: %s" % domain,
				"data": status
			}
		"reload_all_domains":
			var status = loader.reload_all_domains()
			if status.get("failed_domains", []).is_empty():
				return _success(status, "Reloaded all domains")
			return {
				"success": false,
				"error": "Some domains failed to reload",
				"data": status
			}
		"get_reload_status":
			return _success(loader.get_reload_status(), "Reload status fetched")
		"restart_server":
			if plugin == null or not plugin.has_method("runtime_restart_server"):
				return _error("Plugin runtime bridge is unavailable")
			return plugin.runtime_restart_server()
		"soft_reload_plugin":
			if plugin == null or not plugin.has_method("runtime_soft_reload"):
				return _error("Plugin soft reload bridge is unavailable")
			return plugin.runtime_soft_reload()
		"full_reload_plugin":
			if plugin == null or not plugin.has_method("runtime_full_reload"):
				return _error("Plugin full reload bridge is unavailable")
			return plugin.runtime_full_reload()
		"set_tool_enabled":
			if plugin == null or not plugin.has_method("set_tool_enabled_from_tools"):
				return _error("Plugin tool toggle bridge is unavailable")
			return plugin.set_tool_enabled_from_tools(str(args.get("tool_name", "")), bool(args.get("enabled", false)))
		"set_category_enabled":
			if plugin == null or not plugin.has_method("set_category_enabled_from_tools"):
				return _error("Plugin category toggle bridge is unavailable")
			return plugin.set_category_enabled_from_tools(str(args.get("category", "")), bool(args.get("enabled", false)))
		"set_domain_enabled":
			if plugin == null or not plugin.has_method("set_domain_enabled_from_tools"):
				return _error("Plugin domain toggle bridge is unavailable")
			return plugin.set_domain_enabled_from_tools(str(args.get("domain", "")), bool(args.get("enabled", false)))
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _execute_evolution(args: Dictionary) -> Dictionary:
	var plugin = _get_plugin()
	if plugin == null:
		return _error("Plugin evolution bridge is unavailable")

	match str(args.get("action", "")):
		"list_user_tools":
			return _success({"user_tools": plugin.get_user_tool_summaries()}, "User tools listed")
		"create_user_tool":
			return plugin.create_user_tool_from_tools(args)
		"delete_user_tool":
			return plugin.delete_user_tool_from_tools(str(args.get("script_path", "")), bool(args.get("authorized", false)))
		"get_audit_log":
			return _success({"entries": plugin.get_user_tool_audit(int(args.get("limit", 20)))}, "User tool audit fetched")
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _execute_developer(args: Dictionary) -> Dictionary:
	var plugin = _get_plugin()
	if plugin == null:
		return _error("Plugin developer bridge is unavailable")

	match str(args.get("action", "")):
		"get_settings":
			return _success({
				"log_level": plugin.get_log_level_for_tools(),
				"show_user_tools": bool(plugin._state.settings.get("show_user_tools", false))
			}, "Developer settings fetched")
		"set_log_level":
			return plugin.set_log_level_for_tools(str(args.get("level", "info")))
		"set_show_user_tools":
			return plugin.set_show_user_tools_from_tools(bool(args.get("enabled", false)))
		"list_profiles":
			return _success({
				"builtin_profiles": PluginRuntimeState.BUILTIN_TOOL_PROFILES,
				"custom_profiles": plugin._state.custom_tool_profiles if plugin._state != null else {}
			}, "Profiles listed")
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _get_plugin():
	var server = _runtime_context.get("server", null)
	if server == null:
		return null
	return server.get_parent()
