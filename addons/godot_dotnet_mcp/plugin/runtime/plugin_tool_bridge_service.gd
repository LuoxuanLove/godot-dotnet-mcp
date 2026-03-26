@tool
extends RefCounted
class_name PluginToolBridgeService

var _server_controller
var _reload_feature
var _self_diagnostic_feature
var _tool_access_feature
var _tool_profile_feature
var _user_tool_feature


func configure(server_controller, reload_feature, self_diagnostic_feature, tool_access_feature, tool_profile_feature, user_tool_feature) -> void:
	_server_controller = server_controller
	_reload_feature = reload_feature
	_self_diagnostic_feature = self_diagnostic_feature
	_tool_access_feature = tool_access_feature
	_tool_profile_feature = tool_profile_feature
	_user_tool_feature = user_tool_feature


func execute_runtime_tool(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"state":
			return _execute_runtime_state_action(str(args.get("action", "")), args)
		"reload":
			return _execute_runtime_reload_action(str(args.get("action", "")), args)
		"server":
			return _call_feature_method(_reload_feature, "runtime_restart_server", [], "Plugin runtime bridge is unavailable")
		"toggle":
			return _execute_runtime_toggle_action(str(args.get("action", "")), args)
		"usage_guide":
			return _build_runtime_usage_guide()
		_:
			return _error("Unknown plugin runtime tool: %s" % tool_name)


func execute_developer_tool(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"settings":
			return _call_feature_method(_tool_access_feature, "get_developer_settings_for_tools", [], "Plugin developer bridge is unavailable")
		"log_level":
			return _call_feature_method(_tool_access_feature, "set_log_level_for_tools", [str(args.get("level", "info"))], "Plugin developer bridge is unavailable")
		"user_visibility":
			return _call_feature_method(_tool_access_feature, "set_show_user_tools_from_tools", [bool(args.get("enabled", false))], "Plugin developer bridge is unavailable")
		"list_languages":
			return _call_feature_method(_tool_access_feature, "get_languages_for_tools", [], "Plugin developer bridge is unavailable")
		"set_language":
			return _call_feature_method(_tool_access_feature, "set_language_from_tools", [str(args.get("language", ""))], "Plugin developer bridge is unavailable")
		"list_profiles":
			return _call_feature_method(_tool_profile_feature, "list_profiles_from_tools", [], "Plugin developer bridge is unavailable")
		"apply_profile":
			return _call_feature_method(_tool_profile_feature, "apply_profile_from_tools", [str(args.get("profile_id", ""))], "Plugin developer bridge is unavailable")
		"save_profile":
			return _call_feature_method(_tool_profile_feature, "save_profile_from_tools", [str(args.get("profile_name", ""))], "Plugin developer bridge is unavailable")
		"rename_profile":
			return _call_feature_method(_tool_profile_feature, "rename_profile_from_tools", [str(args.get("profile_id", "")), str(args.get("profile_name", ""))], "Plugin developer bridge is unavailable")
		"delete_profile":
			return _call_feature_method(_tool_profile_feature, "delete_profile_from_tools", [str(args.get("profile_id", ""))], "Plugin developer bridge is unavailable")
		"export_config":
			return _call_feature_method(_tool_profile_feature, "export_config_from_tools", [str(args.get("path", ""))], "Plugin developer bridge is unavailable")
		"import_config":
			return _call_feature_method(_tool_profile_feature, "import_config_from_tools", [str(args.get("path", ""))], "Plugin developer bridge is unavailable")
		"usage_guide":
			return _build_plugin_usage_guide()
		_:
			return _error("Unknown plugin developer tool: %s" % tool_name)


func execute_evolution_tool(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"list_user_tools":
			return _success({"user_tools": _call_user_tool_summaries()}, "User tools listed")
		"scaffold_user_tool":
			return _call_feature_method(_user_tool_feature, "create_user_tool_from_tools", [args], "Plugin evolution bridge is unavailable")
		"delete_user_tool":
			return _call_feature_method(_user_tool_feature, "delete_user_tool_from_tools", [str(args.get("script_path", "")), bool(args.get("authorized", false)), str(args.get("agent_hint", ""))], "Plugin evolution bridge is unavailable")
		"restore_user_tool":
			return _call_feature_method(_user_tool_feature, "restore_user_tool_from_tools", [bool(args.get("authorized", false)), str(args.get("agent_hint", ""))], "Plugin evolution restore bridge is unavailable")
		"user_tool_audit":
			return _success({
				"entries": _call_user_tool_audit(
					int(args.get("limit", 20)),
					str(args.get("filter_action", "")),
					str(args.get("filter_session", ""))
				)
			}, "User tool audit fetched")
		"check_compatibility":
			return _call_feature_method(_user_tool_feature, "get_user_tool_compatibility_from_tools", [], "Plugin evolution compatibility bridge is unavailable")
		"usage_guide":
			return _build_evolution_usage_guide()
		_:
			return _error("Unknown plugin evolution tool: %s" % tool_name)


func _execute_runtime_state_action(action: String, args: Dictionary) -> Dictionary:
	match action:
		"list_loaded_domains":
			return _success({
				"domains": _call_server_array("get_domain_states"),
				"performance": _call_server_dictionary("get_performance_summary")
			}, "Loaded domains listed")
		"get_reload_status":
			return _success(_call_server_dictionary("get_reload_status"), "Reload status fetched")
		"get_tool_usage_stats":
			var stats = _call_server_array("get_tool_usage_stats")
			return _success({
				"count": stats.size(),
				"tool_usage_stats": stats
			}, "Tool usage stats fetched")
		"get_lsp_diagnostics_status":
			var snapshot = _call_server_dictionary("get_lsp_diagnostics_debug_snapshot")
			if snapshot.is_empty():
				snapshot = {"error": "LSP diagnostics status is unavailable"}
			var service_raw = snapshot.get("service", {})
			var service_summary: Dictionary = service_raw if service_raw is Dictionary else {}
			if bool(service_summary.get("available", false)):
				return _success(snapshot, "LSP diagnostics status fetched")
			return _error(str(snapshot.get("error", "LSP diagnostics status is unavailable")), snapshot)
		"get_self_health":
			return _call_feature_method(_self_diagnostic_feature, "get_self_diagnostic_health_from_tools", [], "Plugin self diagnostics bridge is unavailable")
		"get_self_errors":
			return _call_feature_method(_self_diagnostic_feature, "get_self_diagnostic_errors_from_tools", [str(args.get("severity", "")), str(args.get("category", "")), int(args.get("limit", 20))], "Plugin self diagnostics bridge is unavailable")
		"get_self_timeline":
			return _call_feature_method(_self_diagnostic_feature, "get_self_diagnostic_timeline_from_tools", [int(args.get("limit", 20))], "Plugin self diagnostics bridge is unavailable")
		"clear_self_diagnostics":
			return _call_feature_method(_self_diagnostic_feature, "clear_self_diagnostics_from_tools", [], "Plugin self diagnostics bridge is unavailable")
		_:
			return _error("Unknown action: %s" % action)


func _execute_runtime_reload_action(action: String, args: Dictionary) -> Dictionary:
	match action:
		"reload_domain":
			var domain = str(args.get("domain", ""))
			if domain.is_empty():
				return _error("Missing domain")
			var status = _call_server_dictionary("reload_domain", [domain])
			if (status.get("failed_domains", []) as Array).is_empty() and (status.get("skipped_domains", []) as Array).has(domain):
				return _success(status, "Domain skipped: %s" % domain)
			var success = (status.get("failed_domains", []) as Array).is_empty() and (status.get("reloaded_domains", []) as Array).has(domain)
			if success:
				return _success(status, "Domain reloaded: %s" % domain)
			return {"success": false, "error": "Failed to reload domain: %s" % domain, "data": status}
		"reload_all_domains":
			var status = _call_server_dictionary("reload_all_domains")
			if (status.get("failed_domains", []) as Array).is_empty():
				return _success(status, "Reloaded all domains")
			return {"success": false, "error": "Some domains failed to reload", "data": status}
		"soft_reload_plugin":
			return _call_feature_method(_reload_feature, "runtime_soft_reload", [], "Plugin soft reload bridge is unavailable")
		"full_reload_plugin":
			return _call_feature_method(_reload_feature, "runtime_full_reload", [], "Plugin full reload bridge is unavailable")
		_:
			return _error("Unknown action: %s" % action)


func _execute_runtime_toggle_action(action: String, args: Dictionary) -> Dictionary:
	match action:
		"set_tool_enabled":
			return _call_feature_method(_tool_access_feature, "set_tool_enabled_from_tools", [str(args.get("tool_name", "")), bool(args.get("enabled", false))], "Plugin tool toggle bridge is unavailable")
		"set_category_enabled":
			return _call_feature_method(_tool_access_feature, "set_category_enabled_from_tools", [str(args.get("category", "")), bool(args.get("enabled", false))], "Plugin category toggle bridge is unavailable")
		"set_domain_enabled":
			return _call_feature_method(_tool_access_feature, "set_domain_enabled_from_tools", [str(args.get("domain", "")), bool(args.get("enabled", false))], "Plugin domain toggle bridge is unavailable")
		_:
			return _error("Unknown action: %s" % action)


func _build_runtime_usage_guide() -> Dictionary:
	return {
		"success": true,
		"data": {
			"summary": [
				"Start with plugin_runtime_state before changing toggles or reload state.",
				"Prefer reload_domain or reload_all_domains first, then soft_reload_plugin, and keep full_reload_plugin for editor-side lifecycle resets only.",
				"Use debug_runtime_bridge to read the latest project session state and captured lifecycle events, even after the project has stopped.",
				"Use runtime toggles to disable tools freely, but enabling plugin_evolution or plugin_developer targets requires the matching permission level."
			],
			"recommended_flow": [
				{"step": 1, "name": "Inspect state", "tools": ["plugin_runtime_state"], "purpose": "Read loaded domains, reload status and the active permission mode."},
				{"step": 2, "name": "Toggle carefully", "tools": ["plugin_runtime_toggle"], "purpose": "Disable anything when isolating faults; only enable targets allowed by the current permission level."},
				{"step": 3, "name": "Reload safely", "tools": ["plugin_runtime_reload"], "purpose": "Start with domain reloads, then reload all domains, and escalate to soft/full plugin reload only when necessary."},
				{"step": 4, "name": "Read runtime bridge", "tools": ["debug_runtime_bridge"], "purpose": "Inspect the latest debugger session state and recent lifecycle events from the last editor-run project session."},
				{"step": 5, "name": "Recover transport", "tools": ["plugin_runtime_server"], "purpose": "Restart the embedded MCP server if transport state is stale but plugin state is otherwise valid."},
				{"step": 6, "name": "Verify", "tools": ["debug_log_write", "debug_log_buffer", "debug_performance"], "purpose": "Read recent errors and a lightweight runtime health snapshot after each change."}
			],
			"warnings": [
				"Do not disable the godot_dotnet_mcp plugin through its own MCP connection when you still need the current transport.",
				"Enabling plugin_evolution or plugin_developer targets from runtime toggles is permission-gated and cannot bypass the user-selected mode.",
				"debug_runtime_bridge is the MCP tool name; runtime state remains readable after stop, but real-time observation still requires the project to be running.",
				"Full plugin reload should be reserved for Dock wiring or plugin lifecycle recreation, not routine executor edits."
			]
		},
		"message": "Plugin runtime usage guide fetched"
	}


func _build_evolution_usage_guide() -> Dictionary:
	return {
		"success": true,
		"data": {
			"summary": [
				"Self-evolution only manages User-category tools and never writes into builtin categories.",
				"Create, delete and restore actions must pass explicit authorization; otherwise they return preview-only results.",
				"Audit entries should be checked after every authorized change.",
				"Use debug_runtime_bridge if a new User tool is expected to affect the running project and you need to inspect the latest session or lifecycle result."
			],
			"recommended_flow": [
				{"step": 1, "name": "Inspect current User tools", "tools": ["plugin_evolution_list_user_tools"], "purpose": "Read existing User tools before adding or removing scripts."},
				{"step": 2, "name": "Preview scaffold or deletion", "tools": ["plugin_evolution_scaffold_user_tool", "plugin_evolution_delete_user_tool", "plugin_evolution_restore_user_tool"], "purpose": "Run without authorization first to inspect the pending change or the latest restorable backup."},
				{"step": 3, "name": "Authorize and apply", "tools": ["plugin_evolution_scaffold_user_tool", "plugin_evolution_delete_user_tool", "plugin_evolution_restore_user_tool"], "purpose": "Repeat the action with explicit authorization only after user approval."},
				{"step": 4, "name": "Reload and verify", "tools": ["plugin_runtime_reload", "plugin_runtime_state"], "purpose": "Refresh tool domains and verify the updated User tool inventory."},
				{"step": 5, "name": "Audit", "tools": ["plugin_evolution_user_tool_audit"], "purpose": "Confirm that the authorized change has been recorded."}
			],
			"warnings": [
				"Stable mode hides and denies the entire plugin_evolution category.",
				"User tools must stay inside the User category even when generated through MCP.",
				"Deletion and restore requests should be previewed before authorization to avoid mutating the wrong script."
			]
		},
		"message": "Plugin evolution usage guide fetched"
	}


func _build_plugin_usage_guide() -> Dictionary:
	return {
		"success": true,
		"data": {
			"summary": [
				"Use plugin_runtime_* to inspect and reload the live editor-side runtime, then use plugin_developer_* to tune Dock-facing settings and profiles.",
				"Reserve plugin_evolution_* for User-category tool authoring and maintenance; it should not be used to mutate builtin categories.",
				"Prefer tool-level or category-level toggles over full plugin reload when isolating runtime faults.",
				"Developer-only actions remain permission-gated by the plugin's current permission mode."
			],
			"recommended_flow": [
				{"step": 1, "name": "Inspect runtime", "tools": ["plugin_runtime_state", "plugin_runtime_reload"], "purpose": "Read current loader state and reload status before changing anything."},
				{"step": 2, "name": "Tune developer settings", "tools": ["plugin_developer_settings", "plugin_developer_log_level", "plugin_developer_list_profiles"], "purpose": "Adjust Dock-facing settings or load the correct profile for the session."},
				{"step": 3, "name": "Change tool availability", "tools": ["plugin_runtime_toggle", "plugin_developer_apply_profile"], "purpose": "Disable or enable only the domains needed for the current debugging task."},
				{"step": 4, "name": "Evolve User tools when needed", "tools": ["plugin_evolution_list_user_tools", "plugin_evolution_scaffold_user_tool", "plugin_evolution_user_tool_audit"], "purpose": "Create or maintain User-category tools only after the runtime is understood."},
				{"step": 5, "name": "Verify and diagnose", "tools": ["plugin_runtime_state", "debug_runtime_bridge", "debug_log_write"], "purpose": "Confirm the runtime is healthy and collect diagnostics after each change."}
			],
			"warnings": [
				"Full plugin reload is more disruptive than domain reload and should be kept for lifecycle-level issues.",
				"User tool authoring still requires explicit authorization and never writes into builtin tool directories.",
				"Changing Dock-facing developer settings does not bypass permission rules for restricted tool categories."
			]
		},
		"message": "Plugin usage guide fetched"
	}


func _call_feature_method(feature, method_name: String, args: Array, unavailable_message: String) -> Dictionary:
	if feature == null or not feature.has_method(method_name):
		return _error(unavailable_message)
	var result = feature.callv(method_name, args)
	return result if result is Dictionary else _error(unavailable_message)


func _call_server_dictionary(method_name: String, args: Array = []) -> Dictionary:
	if _server_controller == null or not _server_controller.has_method(method_name):
		return {}
	var result = _server_controller.callv(method_name, args)
	return result if result is Dictionary else {}


func _call_server_array(method_name: String, args: Array = []) -> Array:
	if _server_controller == null or not _server_controller.has_method(method_name):
		return []
	var result = _server_controller.callv(method_name, args)
	return result if result is Array else []


func _call_user_tool_summaries() -> Array[Dictionary]:
	if _user_tool_feature == null or not _user_tool_feature.has_method("get_user_tool_summaries"):
		return []
	var result = _user_tool_feature.get_user_tool_summaries()
	return result if result is Array else []


func _call_user_tool_audit(limit: int, filter_action: String, filter_session: String) -> Array[Dictionary]:
	if _user_tool_feature == null or not _user_tool_feature.has_method("get_user_tool_audit"):
		return []
	var result = _user_tool_feature.get_user_tool_audit(limit, filter_action, filter_session)
	return result if result is Array else []


func _success(data, message: String) -> Dictionary:
	return {
		"success": true,
		"data": data,
		"message": message
	}


func _error(message: String, data = {}) -> Dictionary:
	var result := {
		"success": false,
		"error": message
	}
	if data is Dictionary and not (data as Dictionary).is_empty():
		result["data"] = data
	return result
