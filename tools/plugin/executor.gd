@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

var _runtime_context: Dictionary = {}


func configure_runtime(context: Dictionary) -> void:
	_runtime_context = context.duplicate()


func get_registration() -> Dictionary:
	return {
		"category": "plugin",
		"domain_key": "core",
		"hot_reloadable": false
	}


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "runtime",
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
						"enum": ["list_loaded_domains", "reload_domain", "reload_all_domains", "get_reload_status"],
						"description": "Plugin runtime action"
					},
					"domain": {
						"type": "string",
						"description": "Tool domain/category to reload"
					}
				},
				"required": ["action"]
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"runtime":
			return _execute_runtime(args)
		_:
			return _error("Unknown plugin tool: %s" % tool_name)


func _execute_runtime(args: Dictionary) -> Dictionary:
	var loader = _runtime_context.get("tool_loader", null)
	if loader == null:
		return _error("Tool loader is unavailable")

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
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))
