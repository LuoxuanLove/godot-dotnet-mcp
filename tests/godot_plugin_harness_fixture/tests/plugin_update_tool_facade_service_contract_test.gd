extends RefCounted

# {"name": "plugin_update_tool_facade_service_contracts"}

const PluginUpdateToolFacadeServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_tool_facade_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var source_guard := _verify_plugin_entrypoint_delegates_update_tool_facade()
	if not source_guard.is_empty():
		return _failure(source_guard)

	var service = PluginUpdateToolFacadeServiceScript.new()
	var context := {
		"source": "custom_branch",
		"custom_branch": "refactor/v2.0.0",
		"release_tag": "v2.0.0",
		"target": {"kind": "branch", "ref": "refactor/v2.0.0", "commit": "target-sha"},
		"current_commit": "current-sha",
		"request_host_available": false,
		"discovery_retry_pending": false,
		"pending_sync_after_refs_discovery": false,
		"refs_state": "idle",
		"refs_status": "Ready",
		"refs_error": "",
		"refs_pending": {
			"serial": 9,
			"waiting_kinds": ["branches"],
			"active_requests": [{"kind": "branches", "elapsed_msec": 12000}]
		},
		"branches": ["dev", "refactor/v2.0.0"],
		"releases": ["v2.0.0"],
		"latest_stable_release": "v2.0.0",
		"latest_release": "v2.0.0",
		"release_source": "release",
		"commits": {"refactor/v2.0.0": "target-sha"},
		"versions": {"v2.0.0": "2.0.0"},
		"compare_state": "success",
		"compare_error": "",
		"compare_base_commit": "base-sha",
		"compare_target_ref": "refactor/v2.0.0",
		"compare_target_commit": "target-sha",
		"compare_ahead_by": 5,
		"compare_behind_by": 1,
		"sync_state": "idle",
		"sync_status": "Idle",
		"sync_error": "",
		"sync_target_ref": "",
		"sync_target_kind": ""
	}

	var status: Dictionary = service.build_status_snapshot(context)
	for required in ["status", "current", "source", "target", "refs", "compare", "sync", "lifecycle_reload"]:
		if not status.has(required):
			return _failure("PluginUpdateToolFacadeService should preserve status field: %s" % required)
	if str(status.get("status", "")) != "ready":
		return _failure("PluginUpdateToolFacadeService should resolve idle update state as ready.", {"status": status.get("status", "")})
	if str((status.get("refs", {}) as Dictionary).get("latest_stable_release", "")) != "v2.0.0":
		return _failure("PluginUpdateToolFacadeService should preserve ref discovery metadata.")
	if int(((status.get("refs", {}) as Dictionary).get("pending", {}) as Dictionary).get("serial", 0)) != 9:
		return _failure("PluginUpdateToolFacadeService should expose pending ref discovery diagnostics.")
	if int((status.get("compare", {}) as Dictionary).get("ahead_by", -1)) != 5:
		return _failure("PluginUpdateToolFacadeService should preserve compare metadata.")
	context["target"]["ref"] = "mutated-ref"
	context["commits"]["refactor/v2.0.0"] = "mutated-sha"
	if str((status.get("target", {}) as Dictionary).get("ref", "")) != "refactor/v2.0.0":
		return _failure("PluginUpdateToolFacadeService should defensively copy target metadata.")
	if str((status.get("refs", {}) as Dictionary).get("commits", {}).get("refactor/v2.0.0", "")) != "target-sha":
		return _failure("PluginUpdateToolFacadeService should defensively copy ref commit metadata.")

	var syncing_context := context.duplicate(true)
	syncing_context["sync_state"] = "loading"
	if service.resolve_overall_status(syncing_context) != "syncing":
		return _failure("PluginUpdateToolFacadeService should prioritize sync loading state.")
	var pending_context := context.duplicate(true)
	pending_context["pending_sync_after_refs_discovery"] = true
	if service.resolve_overall_status(pending_context) != "preparing_sync":
		return _failure("PluginUpdateToolFacadeService should report pending sync-after-discovery state.")
	if service.resolve_request_status("refs", false, context) != "unavailable":
		return _failure("PluginUpdateToolFacadeService should report unavailable ref discovery without a request host.")
	var retry_context := context.duplicate(true)
	retry_context["discovery_retry_pending"] = true
	if service.resolve_request_status("sync", false, retry_context) != "pending":
		return _failure("PluginUpdateToolFacadeService should report pending request status while retry is queued.")
	if service.shorten_fingerprint("1234567890abcdef-extra") != "1234567890abcdef":
		return _failure("PluginUpdateToolFacadeService should preserve short fingerprint compatibility.")

	var enriched := service.enrich_tool_response({"success": true, "data": status.duplicate(true), "message": "ok"})
	if not (enriched.get("data", {}) is Dictionary) or not (enriched.get("maintenance_window", {}) is Dictionary):
		return _failure("PluginUpdateToolFacadeService should enrich tool responses with maintenance metadata.")

	return {"name": "plugin_update_tool_facade_service_contracts", "success": true, "error": ""}


func _verify_plugin_entrypoint_delegates_update_tool_facade() -> String:
	var plugin_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin.gd")
	var service_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_tool_facade_service.gd")
	if plugin_source.is_empty() or service_source.is_empty():
		return "Plugin update tool facade sources should be readable."
	for required in [
		"PluginUpdateToolFacadeServiceScript.new()",
		"_ensure_plugin_update_tool_facade().build_current_response()",
		"_ensure_plugin_update_tool_facade().build_status_response(",
		"_ensure_plugin_update_tool_facade().build_status_snapshot(",
		"_ensure_plugin_update_tool_facade().enrich_tool_response(",
		"_ensure_plugin_update_tool_facade().resolve_request_status(",
		"_ensure_plugin_update_tool_facade().shorten_fingerprint("
	]:
		if plugin_source.find(required) == -1:
			return "plugin.gd should delegate update tool facade responsibility: %s" % required
	for forbidden in [
		"MCPMaintenanceContract.build_update_sync_maintenance(data)",
		"source_fingerprint_short\": short_fingerprint",
		"if str(_state.update_sync_state) == \"loading\":\n\t\treturn \"syncing\"",
		"return normalized.substr(0, 16)"
	]:
		if plugin_source.find(forbidden) != -1:
			return "plugin.gd should not retain update tool facade internals: %s" % forbidden
	for required_service in [
		"func build_current_snapshot()",
		"func build_status_snapshot(context: Dictionary)",
		"func enrich_tool_response(response: Dictionary)",
		"func resolve_overall_status(context: Dictionary)",
		"func resolve_request_status(kind: String, accepted: bool, context: Dictionary)"
	]:
		if service_source.find(required_service) == -1:
			return "PluginUpdateToolFacadeService should own update tool facade method: %s" % required_service
	return ""


func _failure(message: String, details: Dictionary = {}) -> Dictionary:
	return {"name": "plugin_update_tool_facade_service_contracts", "success": false, "error": message, "details": details}
