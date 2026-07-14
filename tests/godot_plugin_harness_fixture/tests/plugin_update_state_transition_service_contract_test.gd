extends RefCounted

# {"name": "plugin_update_state_transition_service_contracts"}

const PluginUpdateStateTransitionServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_state_transition_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var source_guard := _verify_plugin_entrypoint_delegates_update_state_transitions()
	if not source_guard.is_empty():
		return _failure(source_guard)

	var service = PluginUpdateStateTransitionServiceScript.new()
	var pending_failure: Dictionary = service.build_pending_sync_failure("refs failed")
	if bool(pending_failure.get("pending_sync_after_refs_discovery", true)) or str(pending_failure.get("sync_state", "")) != "error" or float(pending_failure.get("sync_progress", -1.0)) != 0.0:
		return _failure("PluginUpdateStateTransitionService should convert pending sync discovery failures into sync errors.", pending_failure)

	var sync_failure: Dictionary = service.build_sync_failure("sync failed")
	if str(sync_failure.get("sync_state", "")) != "error" or str(sync_failure.get("sync_status", "not-empty")) != "" or float(sync_failure.get("sync_progress", -1.0)) != 0.0:
		return _failure("PluginUpdateStateTransitionService should clear sync status/progress on failure.", sync_failure)

	var sync_success: Dictionary = service.build_sync_success("refactor/v2.0.0", 12, "Synced %s with %s files.")
	if str(sync_success.get("sync_state", "")) != "success" or str(sync_success.get("sync_error", "not-empty")) != "" or float(sync_success.get("sync_progress", 0.0)) != 1.0:
		return _failure("PluginUpdateStateTransitionService should mark completed syncs as successful.", sync_success)
	if str(sync_success.get("sync_status", "")).find("refactor/v2.0.0") == -1 or str(sync_success.get("sync_status", "")).find("12") == -1:
		return _failure("PluginUpdateStateTransitionService should preserve localized sync success placeholders.", sync_success)

	var compare_reset: Dictionary = service.build_compare_reset()
	if str(compare_reset.get("compare_state", "")) != "idle" or int(compare_reset.get("compare_ahead_by", 0)) != -1 or not str(compare_reset.get("compare_target_ref", "not-empty")).is_empty():
		return _failure("PluginUpdateStateTransitionService should reset compare state to idle sentinel values.", compare_reset)

	var compare_failure: Dictionary = service.build_compare_failure("bad compare")
	if str(compare_failure.get("compare_state", "")) != "error" or int(compare_failure.get("compare_behind_by", 0)) != -1:
		return _failure("PluginUpdateStateTransitionService should keep compare failures at sentinel counts.", compare_failure)

	var compare_success: Dictionary = service.build_compare_success("base", "target", {"ahead_by": 3, "behind_by": 1})
	if str(compare_success.get("compare_state", "")) != "success" or str(compare_success.get("compare_base_commit", "")) != "base" or int(compare_success.get("compare_ahead_by", -1)) != 3:
		return _failure("PluginUpdateStateTransitionService should preserve successful compare counts.", compare_success)

	var refs_success: Dictionary = service.build_refs_success("refs loaded")
	if str(refs_success.get("refs_state", "")) != "success" or not bool(refs_success.get("refs_discovery_loaded", false)):
		return _failure("PluginUpdateStateTransitionService should mark successful ref discovery loaded.", refs_success)

	var refs_failure: Dictionary = service.build_refs_failure(["branches failed", "tags failed"])
	if str(refs_failure.get("refs_state", "")) != "error" or str(refs_failure.get("refs_error", "")).find("; ") == -1 or bool(refs_failure.get("refs_discovery_loaded", true)):
		return _failure("PluginUpdateStateTransitionService should join ref discovery errors and clear loaded state.", refs_failure)

	return {"name": "plugin_update_state_transition_service_contracts", "success": true, "error": ""}


func _verify_plugin_entrypoint_delegates_update_state_transitions() -> String:
	var plugin_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin.gd")
	var service_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_state_transition_service.gd")
	if plugin_source.is_empty() or service_source.is_empty():
		return "Plugin update state transition sources should be readable."
	for required in [
		"PluginUpdateStateTransitionServiceScript.new()",
		"_ensure_plugin_update_state_transition_service().build_pending_sync_failure(",
		"_ensure_plugin_update_state_transition_service().build_sync_failure(",
		"_ensure_plugin_update_state_transition_service().build_sync_success(",
		"_ensure_plugin_update_state_transition_service().build_refs_success(",
		"_ensure_plugin_update_state_transition_service().build_refs_failure(",
		"_ensure_plugin_update_state_transition_service().build_compare_reset(",
		"func _apply_update_state_patch(patch: Dictionary) -> void:"
	]:
		if plugin_source.find(required) == -1:
			return "plugin.gd should delegate update state transitions: %s" % required
	for forbidden in [
		"_state.update_sync_error = message",
		"_state.update_refs_error = \"; \".join(errors)",
		"_state.update_sync_progress = 1.0"
	]:
		if plugin_source.find(forbidden) != -1:
			return "plugin.gd should not retain update transition internals: %s" % forbidden
	for required_service in [
		"func build_pending_sync_failure(message: String)",
		"func build_sync_success(target_ref: String, written: int, success_template: String)",
		"func build_compare_reset()",
		"func build_refs_failure(errors: Array)"
	]:
		if service_source.find(required_service) == -1:
			return "PluginUpdateStateTransitionService should own transition method: %s" % required_service
	return ""


func _failure(message: String, details: Dictionary = {}) -> Dictionary:
	return {"name": "plugin_update_state_transition_service_contracts", "success": false, "error": message, "details": details}
