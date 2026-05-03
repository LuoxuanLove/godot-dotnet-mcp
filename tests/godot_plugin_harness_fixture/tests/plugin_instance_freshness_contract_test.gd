extends RefCounted

# {"name": "plugin_instance_freshness_contracts"}

const PluginInstanceFreshness = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_instance_freshness.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	PluginInstanceFreshness.reset_for_contract_tests()
	var running: Dictionary = PluginInstanceFreshness.capture_running_instance("contract_test")
	if str(running.get("plugin_id", "")) != "godot_dotnet_mcp":
		return _failure("Running instance should expose the plugin id.")
	if int(running.get("loaded_at_unix", 0)) <= 0:
		return _failure("Running instance should expose a load timestamp.")
	if str(running.get("source_version", "")).is_empty():
		return _failure("Running instance should capture plugin.cfg version at load time.")
	if str(running.get("tool_schema_version", "")).is_empty():
		return _failure("Running instance should capture tool schema version at load time.")

	var requested: Dictionary = PluginInstanceFreshness.mark_lifecycle_reload_requested("contract_test")
	if not bool(requested.get("pending", false)) or str(requested.get("last_request_id", "")).is_empty():
		return _failure("Lifecycle reload metadata should record pending requests.")
	if str(requested.get("state", "")) != "requested":
		return _failure("Lifecycle reload should expose the requested state.")
	if not PluginInstanceFreshness.should_force_fresh_load():
		return _failure("Lifecycle reload requests should arm a one-shot force-fresh-load flag.")
	var scheduled: Dictionary = PluginInstanceFreshness.mark_lifecycle_reload_scheduled(str(requested.get("last_request_id", "")))
	if str(scheduled.get("state", "")) != "scheduled" or int(scheduled.get("last_scheduled_at_unix", 0)) <= 0:
		return _failure("Lifecycle reload should expose the scheduled state and timestamp.")
	if not PluginInstanceFreshness.consume_force_fresh_load():
		return _failure("Force-fresh-load should be consumable exactly once by the next server startup.")
	if PluginInstanceFreshness.consume_force_fresh_load():
		return _failure("Force-fresh-load should be one-shot.")
	var recaptured: Dictionary = PluginInstanceFreshness.capture_running_instance("contract_reload_complete")
	if recaptured.is_empty():
		return _failure("Recapturing the running instance should succeed.")

	var snapshot: Dictionary = PluginInstanceFreshness.get_freshness_snapshot()
	if not snapshot.has("running_instance") or not snapshot.has("disk_source") or not snapshot.has("sync") or not snapshot.has("comparison"):
		return _failure("Freshness snapshot should expose running, disk, sync and comparison sections.")
	var lifecycle: Dictionary = snapshot.get("lifecycle_reload", {})
	if bool(lifecycle.get("pending", true)):
		return _failure("Lifecycle reload should be marked complete after a new running instance capture.")
	if int(lifecycle.get("last_completed_at_unix", 0)) <= 0:
		return _failure("Lifecycle reload should expose the latest completion timestamp.")
	if str(lifecycle.get("state", "")) != "completed" or not bool(lifecycle.get("completion_observed", false)):
		return _failure("Lifecycle reload should expose an observed completed state after recapture.")
	var comparison: Dictionary = snapshot.get("comparison", {})
	if not comparison.has("source_fingerprint_changed_since_load"):
		return _failure("Freshness comparison should include source fingerprint change detection.")
	var disk_source: Dictionary = snapshot.get("disk_source", {})
	if not str(disk_source.get("source_fingerprint", "")).contains("tools/system/impl_project.gd"):
		return _failure("Freshness fingerprint should cover tool implementation files, not only plugin.gd/protocol facts.")

	return {
		"name": "plugin_instance_freshness_contracts",
		"success": true,
		"error": "",
		"details": {
			"status": str(snapshot.get("status", "")),
			"source_version": str(running.get("source_version", ""))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "plugin_instance_freshness_contracts",
		"success": false,
		"error": message
	}
