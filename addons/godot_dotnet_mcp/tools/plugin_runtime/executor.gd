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
				"get_lsp_diagnostics_status":
					var snapshot := _build_lsp_diagnostics_snapshot(loader)
					var service_summary_raw = snapshot.get("service", {})
					var service_summary: Dictionary = service_summary_raw if service_summary_raw is Dictionary else {}
					if bool(service_summary.get("available", false)):
						return _success(snapshot, "LSP diagnostics status fetched")
					return _error(str(snapshot.get("error", "LSP diagnostics status is unavailable")), snapshot)
				"get_self_health":
					return _call_plugin_method("get_self_diagnostic_health_from_tools", [], "Plugin self diagnostics bridge is unavailable")
				"get_self_errors":
					return _call_plugin_method(
						"get_self_diagnostic_errors_from_tools",
						[
							str(args.get("severity", "")),
							str(args.get("category", "")),
							int(args.get("limit", 20))
						],
						"Plugin self diagnostics bridge is unavailable"
					)
				"get_self_timeline":
					return _call_plugin_method(
						"get_self_diagnostic_timeline_from_tools",
						[int(args.get("limit", 20))],
						"Plugin self diagnostics bridge is unavailable"
					)
				"clear_self_diagnostics":
					return _call_plugin_method("clear_self_diagnostics_from_tools", [], "Plugin self diagnostics bridge is unavailable")
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


func _build_lsp_diagnostics_snapshot(loader) -> Dictionary:
	var snapshot: Dictionary = {
		"loader": {
			"available": loader != null,
			"has_tool_loader": loader != null,
			"owns_diagnostics_service": false,
			"service_generation": 0,
			"tool_loader_status": {}
		},
		"service": {
			"available": false,
			"request_count": 0,
			"active_key": "",
			"cache_entry_count": 0,
			"last_completed_status": {},
			"status": {},
			"last_error": ""
		},
		"client": {
			"available": false
		},
		"error": "LSP diagnostics status is unavailable"
	}

	if loader == null:
		snapshot["error"] = "Tool loader is unavailable"
		return snapshot

	if loader != null:
		if loader.has_method("get_lsp_diagnostics_debug_snapshot"):
			var loader_snapshot = loader.get_lsp_diagnostics_debug_snapshot()
			if loader_snapshot is Dictionary and not (loader_snapshot as Dictionary).is_empty():
				return _normalize_lsp_diagnostics_snapshot(loader_snapshot as Dictionary)
		if loader.has_method("get_gdscript_lsp_diagnostics_service"):
			var service = loader.get_gdscript_lsp_diagnostics_service()
			if service != null and service.has_method("get_debug_snapshot"):
				return _normalize_lsp_diagnostics_snapshot({
					"has_tool_loader": true,
					"service_available": true,
					"service": service.get_debug_snapshot()
				})
	snapshot["error"] = "Tool loader does not expose LSP diagnostics state"
	return snapshot


func _normalize_lsp_diagnostics_snapshot(raw_snapshot: Dictionary) -> Dictionary:
	var snapshot: Dictionary = {
		"loader": {
			"available": bool(raw_snapshot.get("has_tool_loader", false)),
			"has_tool_loader": bool(raw_snapshot.get("has_tool_loader", false)),
			"owns_diagnostics_service": bool(raw_snapshot.get("service_available", false)),
			"service_generation": int(raw_snapshot.get("service_generation", 0)),
			"tool_loader_status": raw_snapshot.get("tool_loader_status", {})
		},
		"service": {
			"available": false,
			"request_count": 0,
			"active_key": "",
			"cache_entry_count": 0,
			"last_completed_status": {},
			"status": {},
			"last_error": ""
		},
		"client": {
			"available": false
		},
		"error": "LSP diagnostics status is unavailable"
	}

	var service_raw = raw_snapshot.get("service", {})
	var service_snapshot: Dictionary = {}
	if service_raw is Dictionary:
		service_snapshot = (service_raw as Dictionary).duplicate(true)

	var service_summary_raw = snapshot.get("service", {})
	var service_summary: Dictionary = service_summary_raw if service_summary_raw is Dictionary else {}
	service_summary["available"] = bool(raw_snapshot.get("service_available", false)) and not service_snapshot.is_empty()
	service_summary["request_count"] = int(service_snapshot.get("request_count", 0))
	service_summary["active_key"] = str(service_snapshot.get("active_key", ""))
	service_summary["cache_entry_count"] = int(service_snapshot.get("cache_entry_count", 0))
	service_summary["last_completed_status"] = service_snapshot.get("last_completed_status", {})
	service_summary["status"] = service_snapshot.get("status", {})

	var status_raw = service_summary.get("status", {})
	var status_dict: Dictionary = status_raw if status_raw is Dictionary else {}
	var last_completed_raw = service_summary.get("last_completed_status", {})
	var last_completed: Dictionary = last_completed_raw if last_completed_raw is Dictionary else {}
	var client_raw = service_snapshot.get("client", {})
	if client_raw is Dictionary:
		var client_snapshot := (client_raw as Dictionary).duplicate(true)
		client_snapshot["available"] = not client_snapshot.is_empty()
		snapshot["client"] = client_snapshot

	var last_error := str(status_dict.get("error", ""))
	if last_error.is_empty():
		last_error = str(last_completed.get("error", ""))
	service_summary["last_error"] = last_error
	snapshot["service"] = service_summary

	if bool(service_summary.get("available", false)):
		snapshot.erase("error")
	elif not last_error.is_empty():
		snapshot["error"] = last_error
	return snapshot
